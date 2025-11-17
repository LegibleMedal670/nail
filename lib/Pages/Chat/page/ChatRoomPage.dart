// lib/Pages/Chat/ChatRoomPage.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nail/Pages/Chat/models/RoomMemberBrief.dart';
import 'package:nail/Pages/Chat/page/ChatRoomInfoPage.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Pages/Chat/widgets/FileBubble.dart';
import 'package:nail/Pages/Chat/widgets/ImageBubble.dart';
import 'package:nail/Pages/Chat/widgets/IncomingMessageTile.dart';
import 'package:nail/Pages/Chat/widgets/MessageBubble.dart';
import 'package:nail/Pages/Chat/widgets/MessageInputBar.dart';
import 'package:nail/Pages/Chat/widgets/SystemEventChip.dart';
import 'package:nail/Pages/Chat/widgets/MemberProfileSheet.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Pages/Manager/page/MentorDetailPage.dart';
import 'package:nail/Pages/Manager/page/MenteeDetailPage.dart';
import 'package:nail/Pages/Manager/models/mentor.dart' as legacy;
import 'package:nail/Pages/Manager/models/Mentee.dart' as mgr;
import 'package:nail/Services/AdminMenteeService.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/StorageService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart' as dio;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatRoomPage({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<MessageInputBarState> _inputKey = GlobalKey<MessageInputBarState>();

  final _svc = ChatService.instance;
  final _storage = StorageService();
  RealtimeChannel? _roomRt;
  int? _memberCount; // 방 인원수
  String? _roomName;  // 제목 갱신용

  bool _loading = false;
  bool _paging = false;
  bool _hasMore = true;
  int? _latestId;
  int? _oldestId;
  bool _sendingAttach = false;

  // 공지
  static const double _kNoticeCollapsed = 76.0;
  static const double _kNoticeExpanded  = 140.0;
  _PinnedNotice? _pinned;
  bool _noticeExpanded = false;

  // 메시지
  final List<_Msg> _messages = <_Msg>[];

  Future<void> _openAdminProfileForUser(String userId, String nickname, String? photoUrl) async {
    if (userId.isEmpty) return;
    try {
      // 1) 멘토 목록에서 id 매칭 시 멘토 상세로
      final mentors = await SupabaseService.instance.adminListMentors();
      final mrow = mentors.firstWhere(
        (e) => (e['id'] ?? '').toString() == userId,
        orElse: () => <String, dynamic>{},
      );
      if (mrow.isNotEmpty) {
        final joined = mrow['joined_at'];
        final joinedAt = joined is DateTime
            ? joined.toLocal()
            : DateTime.tryParse((joined ?? '').toString())?.toLocal() ?? DateTime.now();
        final ph = (mrow['photo_url'] ?? photoUrl)?.toString();
        final nn = (mrow['nickname'] ?? nickname).toString();
        final loginKey = (mrow['login_key'] ?? '').toString();
        final mentor = legacy.Mentor(
          id: userId,
          name: nn,
          hiredAt: joinedAt,
          menteeCount: 0,
          photoUrl: (ph?.isEmpty == true) ? null : ph,
          accessCode: loginKey,
        );
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MentorDetailPage(mentor: mentor)));
        return;
      }

      // 2) 멘토가 아니라면 멘티 메트릭에서 조회
      final metrics = await AdminMenteeService.instance.listMenteesMetrics();
      final row = metrics.firstWhere(
        (e) => (e['id'] ?? '').toString() == userId,
        orElse: () => <String, dynamic>{},
      );
      if (row.isNotEmpty) {
        final joined = row['joined_at'];
        final joinedAt = joined is DateTime
            ? joined.toLocal()
            : DateTime.tryParse((joined ?? '').toString())?.toLocal() ?? DateTime.now();
        final ph = (row['photo_url'] ?? photoUrl)?.toString();
        final nn = (row['nickname'] ?? nickname).toString();
        final loginKey = (row['login_key'] ?? '').toString();
        final mentee = mgr.Mentee(
          id: userId,
          name: nn,
          startedAt: joinedAt,
          progress: 0.0,
          courseDone: 0,
          courseTotal: 0,
          examDone: 0,
          examTotal: 0,
          photoUrl: (ph?.isEmpty == true) ? null : ph,
          accessCode: loginKey,
        );
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MenteeDetailPage(mentee: mentee)));
        return;
      }

      // 3) 둘 다 없으면 실패
      throw Exception('대상 사용자를 찾을 수 없습니다.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('프로필 열기 실패: $e')));
    }
  }
  @override
  void initState() {
    super.initState();
    _roomName = widget.roomName;
    _scroll.addListener(_onScroll);
    _loadFileCache();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareRealtimeThenLoad();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _roomRt?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMemberCount() async {
    final key = _loginKey();
    if (key.isEmpty) return;
    try {
      final rows = await _svc.listRoomMembers(loginKey: key, roomId: widget.roomId);
      // 멤버 수 갱신
      final count = rows.length;
      // 방 이름이 비어 있고(1:1 DM에서 그룹이 된 경우 등), 멤버 목록이 있으면
      // 멤버 닉네임을 ', '로 연결해 임시 방 이름으로 표시
      final currentName = _roomName?.trim() ?? '';
      if (currentName.isEmpty && rows.isNotEmpty) {
        final names = rows
            .map((r) => (r['nickname'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort((a, b) => a.compareTo(b));
        final joined = names.join(', ');
        if (joined.isNotEmpty) {
          if (mounted) {
            setState(() {
              _roomName = joined;
              _memberCount = count;
            });
          } else {
            _roomName = joined;
            _memberCount = count;
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _memberCount = count;
        });
      } else {
        _memberCount = count;
      }
    } catch (_) {}
  }

  // ---------- utils ----------
  String _loginKey() {
    final up = context.read<UserProvider>();
    return up.isAdmin ? (up.adminKey ?? '') : (up.current?.loginKey ?? '');
  }

  String _myUid() {
    final up = context.read<UserProvider>();
    return up.current?.userId ?? '';
  }

  void _jumpToBottom({bool animate = false}) {
    if (!_scroll.hasClients) return;
    final dest = _scroll.position.minScrollExtent; // reverse:true
    if (animate) {
      _scroll.animateTo(dest, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(dest);
    }
  }

  bool get _nearBottom {
    if (!_scroll.hasClients) return true;
    final pos = _scroll.position;
    return (pos.pixels - pos.minScrollExtent).abs() < 120;
  }

  void _autoScrollIfNearBottom() {
    if (_nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
    }
  }

  // ---------- realtime ----------
  Future<void> _prepareRealtimeThenLoad() async {
    // 관리자 세션인 경우: Realtime RLS 매핑 보장
    final up = context.read<UserProvider>();
    if (up.isAdmin) {
      try {
        await SupabaseService.instance.ensureAdminSessionLinked();
      } catch (_) {}
    } else {
      // 멘티/멘토: login_with_key 재호출로 매핑 재확인(가벼움)
      final k = up.current?.loginKey ?? '';
      if (k.isNotEmpty) {
        try {
          await SupabaseService.instance.loginWithKey(k);
        } catch (_) {
          // ignore
        }
      }
    }
    // 매핑 보장 후 구독 시작 및 첫 로드
    _bindRealtime();
    await _loadFirst();
    await _loadMemberCount();
  }

  void _bindRealtime() {
    _roomRt?.unsubscribe();
    _roomRt = _svc.subscribeRoomChanges(
      roomId: widget.roomId,
      onInsert: (_) async {
        await _reloadLatestWindow();
        await _markRead();
        _autoScrollIfNearBottom();
      },
      onUpdate: (_) async {
        await _reloadLatestWindow();
      },
      onPinUpdate: (_) async {
        await _loadNotice();
      },
      onMemberUpdate: (_) async {
        await _loadMemberCount();
        // 다른 참여자의 last_read_at 갱신에 맞춰 read_count를 최신화
        await _reloadLatestWindow();
      },
    );
  }

  // ---------- signed url cache ----------
  final Map<String, String> _signedUrlCache = {};
  final Map<int, String> _downloadedFileCache = {};
  SharedPreferences? _prefs;
  String get _fileCacheKey => 'chat_file_cache_${widget.roomId}';
  Future<void> _loadFileCache() async {
    _prefs = await SharedPreferences.getInstance();
    final jsonStr = _prefs!.getString(_fileCacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      _downloadedFileCache
        ..clear()
        ..addAll(map.map((k, v) => MapEntry(int.parse(k), v.toString())));
      // 기존 메시지에도 로컬 경로 반영
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          final cached = _downloadedFileCache[m.id];
          if (cached != null && (m.fileLocal == null || m.fileLocal!.isEmpty)) {
            _messages[i] = _Msg(
              id: m.id, me: m.me, type: m.type, text: m.text,
              senderId: m.senderId,
              imageUrl: m.imageUrl, imageLocal: m.imageLocal,
              fileUrl: m.fileUrl, fileLocal: cached,
              fileName: m.fileName, fileBytes: m.fileBytes,
              createdAt: m.createdAt, deleted: m.deleted,
              readCount: m.readCount, nickname: m.nickname,
              photoUrl: m.photoUrl, isSystem: m.isSystem,
              systemText: m.systemText, sendStatus: m.sendStatus,
            );
          }
        }
      });
    } catch (_) {}
  }
  Future<void> _persistFileCache() async {
    if (_prefs == null) return;
    final map = _downloadedFileCache.map((k, v) => MapEntry(k.toString(), v));
    await _prefs!.setString(_fileCacheKey, json.encode(map));
  }
  List<_Msg> _applyFileCache(List<_Msg> src) {
    if (_downloadedFileCache.isEmpty) return src;
    return src.map((m) {
      final cached = _downloadedFileCache[m.id];
      if (cached == null || (m.fileLocal != null && m.fileLocal!.isNotEmpty)) return m;
      return _Msg(
        id: m.id, me: m.me, type: m.type, text: m.text,
        senderId: m.senderId,
        imageUrl: m.imageUrl, imageLocal: m.imageLocal,
        fileUrl: m.fileUrl, fileLocal: cached,
        fileName: m.fileName, fileBytes: m.fileBytes,
        createdAt: m.createdAt, deleted: m.deleted,
        readCount: m.readCount, nickname: m.nickname,
        photoUrl: m.photoUrl, isSystem: m.isSystem,
        systemText: m.systemText, sendStatus: m.sendStatus,
      );
    }).toList();
  }
  Future<String?> _signedUrlForPath(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    final cached = _signedUrlCache[storagePath];
    if (cached != null) return cached;
    try {
      final url = await _storage.getOrCreateSignedUrlChat(storagePath);
      _signedUrlCache[storagePath] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendImageLocalPath(String localPath) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) return;
    final int size = await file.length();
    final String name = _basename(localPath);
    final String mime = _guessImageMime(localPath);
    // optimistic bubble
    _insertTempImageBubble(localPath);
    try {
      final storagePath = await _storage.uploadChatFile(
        file: file,
        roomId: widget.roomId,
        kind: 'images',
        contentType: mime,
      );
      await _svc.sendFile(
        loginKey: key,
        roomId: widget.roomId,
        fileName: name,
        sizeBytes: size,
        mime: mime,
        storagePath: storagePath,
        kind: 'image',
        meta: {'client_ts': DateTime.now().toIso8601String()},
      );
      await _reloadLatestWindow();
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.image);
      });
      await _markRead();
    } finally {
      // no-op
    }
  }

  Future<void> _sendFileLocalPath(String localPath, String fileName, int fileBytes) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) return;
    final int size = fileBytes > 0 ? fileBytes : await file.length();
    final String name = (fileName.isNotEmpty) ? fileName : _basename(localPath);
    final String mime = _guessFileMime(name);
    _insertTempFileBubble(localPath, name, size);
    try {
      final storagePath = await _storage.uploadChatFile(
        file: file,
        roomId: widget.roomId,
        kind: 'files',
        contentType: mime,
      );
      await _svc.sendFile(
        loginKey: key,
        roomId: widget.roomId,
        fileName: name,
        sizeBytes: size,
        mime: mime,
        storagePath: storagePath,
        kind: 'file',
        meta: {'client_ts': DateTime.now().toIso8601String()},
      );
      await _reloadLatestWindow();
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.file);
      });
      await _markRead();
    } finally {
      // no-op
    }
  }

  String _basename(String path) {
    final norm = path.replaceAll('\\', '/');
    final last = norm.split('/').last;
    return last;
  }

  String _guessImageMime(String path) {
    final n = _basename(path).toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  String _guessFileMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.txt')) return 'text/plain';
    if (n.endsWith('.zip')) return 'application/zip';
    if (n.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  // ---------- load ----------
  Future<void> _loadFirst() async {
    final key = _loginKey();
    if (key.isEmpty) return;

    setState(() => _loading = true);
    try {
      final rows = await _svc.fetchMessages(loginKey: key, roomId: widget.roomId, limit: 50);
      rows.sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
      final my = _myUid();
      final list = _applyFileCache(rows.map(_mapRowToMsg(my)).toList());

      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _oldestId = list.isNotEmpty ? list.first.id : null;
        _latestId = list.isNotEmpty ? list.last.id : null;
        _hasMore = list.length >= 50;
      });

      await _loadNotice();
      await _markRead();
      // 읽음 반영 직후 스냅샷을 한 번 더 갱신해 read_count를 즉시 업데이트
      await _reloadLatestWindow();
      _jumpToBottom();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadLatestWindow() async {
    if (_latestId == null) {
      await _loadFirst();
      return;
    }
    final key = _loginKey();
    if (key.isEmpty) return;

    final rows = await _svc.fetchMessages(
      loginKey: key,
      roomId: widget.roomId,
      afterId: (_latestId! - 200),
      limit: 200,
    );
    rows.sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
    final my = _myUid();
    final patch = {
      for (final r in rows)
        (r['id'] as num).toInt(): _applyFileCache([_mapRowToMsg(my)(r)]).first
    };

    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        final id = _messages[i].id;
        if (patch.containsKey(id)) _messages[i] = patch[id]!;
      }
      for (final e in patch.entries) {
        if (!_messages.any((m) => m.id == e.key)) _messages.add(e.value);
      }
      _messages.sort((a, b) => a.id.compareTo(b.id));
      _latestId = _messages.isNotEmpty ? _messages.last.id : _latestId;
    });
  }

  Future<void> _loadOlder() async {
    if (_paging || !_hasMore) return;
    final key = _loginKey();
    if (key.isEmpty || _oldestId == null) return;

    setState(() => _paging = true);
    try {
      final rows = await _svc.fetchMessages(
        loginKey: key,
        roomId: widget.roomId,
        beforeId: _oldestId,
        limit: 50,
      );
      rows.sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
      final my = _myUid();
      final list = rows.map(_mapRowToMsg(my)).toList();
      if (list.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }
      setState(() {
        _messages.insertAll(0, list);
        _oldestId = _messages.first.id;
        _hasMore = list.length >= 50;
      });
    } finally {
      if (mounted) setState(() => _paging = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.atEdge && pos.pixels != pos.minScrollExtent) {
      _loadOlder();
    }
  }

  Future<void> _loadNotice() async {
    final key = _loginKey();
    if (key.isEmpty) return;
    final m = await _svc.getNotice(loginKey: key, roomId: widget.roomId);
    if (!mounted) return;
    if (m.isEmpty) {
      setState(() => _pinned = null);
      return;
    }
    final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();
    setState(() {
      _pinned = _PinnedNotice(
        msgId: (m['message_id'] as num).toInt(),
        title: (m['title'] ?? '공지').toString(),
        body: (m['body'] ?? '').toString(),
        createdAt: createdAt,
        author: (m['author'] ?? '').toString(),
      );
    });
  }

  Future<void> _markRead() async {
    final key = _loginKey();
    if (key.isEmpty) return;
    await _svc.markRead(loginKey: key, roomId: widget.roomId);
  }

  // ---------- send ----------
  Future<void> _sendText(String text) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    _insertTempTextBubble(text);
    try {
      await _svc.sendText(
        loginKey: key,
        roomId: widget.roomId,
        text: text,
        meta: {'client_ts': DateTime.now().toIso8601String()},
      );
      await _reloadLatestWindow();
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.text);
      });
      await _markRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    }
  }

  void _insertTempImageBubble(String localPath) {
    final int nextId = (_messages.isNotEmpty ? _messages.map((e)=>e.id).reduce((a,b)=>a>b?a:b) : 0) + 1;
    final temp = _Msg(
      id: nextId,
      me: true,
      type: _MsgType.image,
      text: null,
      imageUrl: null,
      imageLocal: localPath,
      fileUrl: null,
      fileLocal: null,
      fileName: null,
      fileBytes: null,
      createdAt: DateTime.now(),
      deleted: false,
      readCount: null,
      nickname: null,
      photoUrl: null,
      isSystem: false,
      systemText: null,
      sendStatus: _SendStatus.sending,
    );
    setState(() {
      _messages.add(temp);
      _messages.sort((a, b) => a.id.compareTo(b.id));
    });
    _autoScrollIfNearBottom();
  }

  void _insertTempTextBubble(String text) {
    final int nextId = (_messages.isNotEmpty ? _messages.map((e)=>e.id).reduce((a,b)=>a>b?a:b) : 0) + 1;
    final temp = _Msg(
      id: nextId,
      me: true,
      type: _MsgType.text,
      text: text,
      imageUrl: null,
      imageLocal: null,
      fileUrl: null,
      fileLocal: null,
      fileName: null,
      fileBytes: null,
      createdAt: DateTime.now(),
      deleted: false,
      readCount: null,
      nickname: null,
      photoUrl: null,
      isSystem: false,
      systemText: null,
      sendStatus: _SendStatus.sending,
    );
    setState(() {
      _messages.add(temp);
      _messages.sort((a, b) => a.id.compareTo(b.id));
    });
    _autoScrollIfNearBottom();
  }

  void _insertTempFileBubble(String localPath, String fileName, int fileBytes) {
    final int nextId = (_messages.isNotEmpty ? _messages.map((e)=>e.id).reduce((a,b)=>a>b?a:b) : 0) + 1;
    final temp = _Msg(
      id: nextId,
      me: true,
      type: _MsgType.file,
      text: null,
      imageUrl: null,
      imageLocal: null,
      fileUrl: null,
      fileLocal: localPath,
      fileName: fileName,
      fileBytes: fileBytes,
      createdAt: DateTime.now(),
      deleted: false,
      readCount: null,
      nickname: null,
      photoUrl: null,
      isSystem: false,
      systemText: null,
      sendStatus: _SendStatus.sending,
    );
    setState(() {
      _messages.add(temp);
      _messages.sort((a, b) => a.id.compareTo(b.id));
    });
    _autoScrollIfNearBottom();
  }

  // ---------- long-press 액션시트 ----------
  Future<void> _showMessageActionSheet(_Msg m, {required bool isAdmin, required bool allowNotice}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (isAdmin && allowNotice)
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('공지로 등록'),
                  onTap: () => Navigator.of(sheetCtx).pop('notice'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('삭제'),
                onTap: () => Navigator.of(sheetCtx).pop('delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    final key = _loginKey();
    if (key.isEmpty) return;

    if (action == 'delete') {
      final ok = await confirmDeleteMessage(context);
      if (!ok) return;
      await _svc.deleteMessage(adminLoginKey: key, messageId: m.id);
      await _reloadLatestWindow();
      if (_pinned?.msgId == m.id) await _loadNotice();
      return;
    }

    if (action == 'notice' && isAdmin) {
      await _svc.pinNotice(adminLoginKey: key, roomId: widget.roomId, messageId: m.id);
      await _loadNotice(); // 실시간 갱신과 중복되어도 무해
      if (!mounted) return;
    }
  }

  void _openImageFullscreen(_Msg imageMsg) {
    final storagePath = imageMsg.imageUrl;
    final local = imageMsg.imageLocal;
    Future<String?> resolve() async {
      if (local != null && local.isNotEmpty) return local;
      return await _signedUrlForPath(storagePath);
    }
    resolve().then((src) {
    if (src == null || src.isEmpty) return;
      if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) => ChatImageViewer(
          images: [src],
          initialIndex: 0,
          heroTagPrefix: 'chat_img_',
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
    });
  }

  Future<void> _openFile(String? localPath, String? signedUrl) async {
    Uri? uri;
    if (localPath != null && localPath.isNotEmpty) {
      // 인앱: 기기에 저장된 파일을 시스템 뷰어로 열기
      try {
        await OpenFilex.open(localPath);
        return;
      } catch (_) {}
      uri = Uri.file(localPath); // fallback
    } else if (signedUrl != null && signedUrl.isNotEmpty) {
      uri = Uri.parse(signedUrl); // 외부 앱(브라우저) 열기 fallback
    }
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  // 다운로드 상태 관리 (messageId 집합)
  final Set<int> _downloadingFileMsgIds = <int>{};

  Future<void> _downloadFileToAppStorage(_Msg msg, String signedUrl) async {
    if (_downloadingFileMsgIds.contains(msg.id)) return;
    setState(() => _downloadingFileMsgIds.add(msg.id));
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chatDir = p.join(dir.path, 'chat', widget.roomId);
      await Directory(chatDir).create(recursive: true);
      final rawName = msg.fileName ?? 'file';
      final safeName = _sanitizeForStorage(rawName);
      final savePath = p.join(chatDir, safeName);
      final client = dio.Dio();
      await client.download(signedUrl, savePath);
      // 메시지에 로컬 경로 반영 → 아이콘이 open으로 전환
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].id == msg.id) {
            _messages[i] = _messages[i] = _Msg(
              id: _messages[i].id,
              me: _messages[i].me,
              type: _messages[i].type,
              text: _messages[i].text,
              imageUrl: _messages[i].imageUrl,
              imageLocal: _messages[i].imageLocal,
              fileUrl: _messages[i].fileUrl,
              fileLocal: savePath,
              fileName: _messages[i].fileName,
              fileBytes: _messages[i].fileBytes,
              createdAt: _messages[i].createdAt,
              deleted: _messages[i].deleted,
              readCount: _messages[i].readCount,
              nickname: _messages[i].nickname,
              photoUrl: _messages[i].photoUrl,
              isSystem: _messages[i].isSystem,
              systemText: _messages[i].systemText,
              sendStatus: _SendStatus.sent,
            );
            break;
          }
        }
        _downloadedFileCache[msg.id] = savePath;
      });
      await _persistFileCache();
    } catch (_) {
      // 무시(필요시 토스트)
    } finally {
      if (mounted) {
        setState(() => _downloadingFileMsgIds.remove(msg.id));
      }
    }
  }

  String _sanitizeForStorage(String filename) {
    String base = filename.trim();
    if (base.isEmpty) {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
    final dot = base.lastIndexOf('.');
    String namePart = dot > 0 ? base.substring(0, dot) : base;
    String extPart = dot > 0 ? base.substring(dot) : '';
    final reg = RegExp(r'[^a-zA-Z0-9._-]');
    namePart = namePart.replaceAll(reg, '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (namePart.isEmpty) namePart = 'file_${DateTime.now().millisecondsSinceEpoch}';
    extPart = extPart.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
    if (extPart.length > 20) extPart = extPart.substring(0, 20);
    return '$namePart$extPart';
  }

  String _currentRoleLabel(UserProvider up) {
    if (up.isAdmin) return '관리자';
    if (up.isMentor) return '멘토';
    return '멘티';
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final isAdmin = up.isAdmin;

    final items = _buildItemsWithSeparators(_messages);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Text(
                _roomName ?? widget.roomName,
                style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 6),
            if (_memberCount != null && _memberCount! > 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$_memberCount',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: UiTokens.title),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () async {
              // 기존 InfoPage는 외부에서 멤버 목록을 받게 되어 있었음(목업 기반).
              // 우선 현재 대화 참여자 UI는 보류하고 방 정보 페이지로만 이동.
              final newName = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => ChatRoomInfoPage(
                    roomId: widget.roomId,
                    roomName: _roomName ?? widget.roomName, // 최신 제목 전달
                    isAdmin: isAdmin,
                    members: const <RoomMemberBrief>[],
                  ),
                ),
              );
              if (newName != null && newName.isNotEmpty && mounted) {
                setState(() => _roomName = newName);
              }
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,

      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _inputKey.currentState?.closeExtraPanel();
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final it = items[items.length - 1 - index];

                      if (it.kind == _RowKind.separator && it.day != null) {
                        return ChatDaySeparator(day: it.day!);
                      }
                      if (it.kind == _RowKind.system && it.msg != null) {
                        return SystemEventChip(text: it.msg!.systemText ?? '');
                      }

                      final m = it.msg!;
                      final isMe = m.me;

                      // 버블 생성
                      Widget bubbleRow;
                      if (m.deleted) {
                        bubbleRow = MessageBubble(
                          isMe: isMe,
                          text: '관리자에 의해 삭제됨',
                          createdAt: m.createdAt,
                          readCount: null, // 삭제 메시지는 숨김
                        );
                      } else {
                        switch (m.type!) {
                          case _MsgType.text:
                            bubbleRow = MessageBubble(
                              isMe: isMe,
                              text: m.text ?? '',
                              createdAt: m.createdAt,
                              readCount: m.isSystem ? null : m.readCount,
                            );
                            break;
                          case _MsgType.image:
                            final heroTag = 'chat_img_${m.id}';
                            bubbleRow = FutureBuilder<String?>(
                              future: _signedUrlForPath(m.imageUrl),
                              builder: (context, snap) {
                                final url = snap.data;
                                final img = ImageBubble(
                              isMe: isMe,
                                  imageUrl: url,
                              localPreviewPath: m.imageLocal,
                              createdAt: m.createdAt,
                              readCount: m.readCount,
                                  loading: m.sendStatus == _SendStatus.sending,
                              onTap: () => _openImageFullscreen(m),
                              heroTag: heroTag,
                                );
                                return img;
                              },
                            );
                            break;
                          case _MsgType.file:
                            bubbleRow = FutureBuilder<String?>(
                              future: _signedUrlForPath(m.fileUrl),
                              builder: (context, snap) {
                                final url = snap.data;
                                final bool isDownloading = _downloadingFileMsgIds.contains(m.id);
                                final bool isDownloaded = (m.fileLocal != null && m.fileLocal!.isNotEmpty);
                                final file = FileBubble(
                              isMe: isMe,
                              fileName: m.fileName ?? '파일',
                              fileBytes: m.fileBytes ?? 0,
                              localPath: m.fileLocal,
                                  fileUrl: url,
                              createdAt: m.createdAt,
                              readCount: m.readCount,
                                  loading: m.sendStatus == _SendStatus.sending || isDownloading,
                                  downloaded: isDownloaded,
                                  onTapOpen: () {
                                    final hasLocal = (m.fileLocal != null && m.fileLocal!.isNotEmpty);
                                    if (hasLocal) {
                                      _openFile(m.fileLocal, url);
                                    } else if (url != null && url.isNotEmpty) {
                                      _downloadFileToAppStorage(m, url);
                                    }
                                  },
                                );
                                return file;
                              },
                            );
                            break;
                        }
                      }

                      // ✅ 액션시트: 버블 외곽 래퍼에서 onLongPress로 처리 (버블에 삭제 핸들러 전달 X)
                      final wrapped = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: m.deleted
                            ? null
                            : () => _showMessageActionSheet(
                                  m,
                                  isAdmin: isAdmin,
                                  allowNotice: m.type == _MsgType.text,
                                ),
                        child: bubbleRow,
                      );

                      if (!isMe) {
                        return IncomingMessageTile(
                          nickname: m.nickname ?? '사용자',
                          photoUrl: m.photoUrl,
                          childRow: wrapped,
                          onTapAvatar: () {
                            final role = _currentRoleLabel(up);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (_) => MemberProfileSheet(
                                nickname: m.nickname ?? '사용자',
                                photoUrl: m.photoUrl,
                                role: role,
                                isAdmin: isAdmin,
                                isSelf: false,
                                onViewProfile: isAdmin ? () => _openAdminProfileForUser(m.senderId ?? '', m.nickname ?? '사용자', m.photoUrl) : null,
                                onOpenDM: () async {
                                  try {
                                    final key = _loginKey();
                                    if (key.isEmpty) return;
                                    final targetId = m.senderId ?? '';
                                    if (targetId.isEmpty) return;
                                    final roomId = await _svc.getOrCreateDM(loginKey: key, targetUserId: targetId);
                                    if (!mounted) return;
                                    // 바텀시트 닫기 후 DM으로 이동(스택을 목록 페이지만 남김)
                                    Navigator.of(context).pop();
                                    await Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => ChatRoomPage(
                                          roomId: roomId,
                                          roomName: m.nickname ?? '대화상대',
                                        ),
                                      ),
                                      (route) => route.isFirst,
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('1:1 대화 시작 실패: $e')));
                                  }
                                },
                                onKick: () async {
                                  await Future.delayed(const Duration(milliseconds: 250));
                                  return true;
                                },
                              ),
                            );
                          },
                        );
                      }
                      return wrapped;
                    },
                  ),
                ),
                MessageInputBar(
                  key: _inputKey,
                  onSendText: _sendText,
                  onSendImageLocalPath: _sendImageLocalPath,
                  onSendFileLocalPath: _sendFileLocalPath,
                ),
              ],
            ),

            if (_pinned != null)
              Positioned(
                left: 0, right: 0, top: 0,
                child: SafeArea(
                  bottom: false,
                  child: _NoticeBanner(
                    data: _pinned!,
                    expanded: _noticeExpanded,
                    collapsedHeight: _kNoticeCollapsed,
                    expandedHeight: _kNoticeExpanded,
                    onToggle: () => setState(() => _noticeExpanded = !_noticeExpanded),
                    onOpenDetail: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => _NoticeDetailPage(data: _pinned!)),
                      );
                    },
                    onDismiss: () => setState(() {
                      _pinned = null;
                      _noticeExpanded = false;
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_RowItem> _buildItemsWithSeparators(List<_Msg> src) {
    final List<_RowItem> out = [];
    DateTime? lastDay;
    for (final m in src) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day.difference(lastDay).inDays != 0) {
        out.add(_RowItem.separator(day));
        lastDay = day;
      }
      if (m.isSystem) {
        out.add(_RowItem.system(m));
      } else {
        out.add(_RowItem.message(m));
      }
    }
    return out;
  }
}

// ===== 내부 모델/뷰 =====
enum _MsgType { text, image, file }
enum _SendStatus { sending, sent }

class _Msg {
  final int id;
  final bool me;
  final _MsgType? type;
  final String? text;
  final String? senderId;
  final String? imageUrl;
  final String? imageLocal;
  final String? fileUrl;
  final String? fileLocal;
  final String? fileName;
  final int? fileBytes;
  final DateTime createdAt;
  final bool deleted;
  final int? readCount;
  final String? nickname;
  final String? photoUrl;
  final bool isSystem;
  final String? systemText;
  final _SendStatus sendStatus;

  _Msg({
    required this.id,
    required this.me,
    this.type,
    this.text,
    this.senderId,
    this.imageUrl,
    this.imageLocal,
    this.fileUrl,
    this.fileLocal,
    this.fileName,
    this.fileBytes,
    required this.createdAt,
    this.deleted = false,
    this.readCount,
    this.nickname,
    this.photoUrl,
    this.isSystem = false,
    this.systemText,
    this.sendStatus = _SendStatus.sent,
  });

  _Msg.system({
    required this.id,
    required this.createdAt,
    required this.systemText,
  })  : me = false,
        senderId = null,
        type = null,
        text = null,
        imageUrl = null,
        imageLocal = null,
        fileUrl = null,
        fileLocal = null,
        fileName = null,
        fileBytes = null,
        deleted = false,
        readCount = null,
        nickname = null,
        photoUrl = null,
        isSystem = true,
        sendStatus = _SendStatus.sent;
}

enum _RowKind { separator, system, message }
class _RowItem {
  final _RowKind kind;
  final DateTime? day;
  final _Msg? msg;
  _RowItem._(this.kind, {this.day, this.msg});
  factory _RowItem.separator(DateTime day) => _RowItem._(_RowKind.separator, day: day);
  factory _RowItem.system(_Msg m) => _RowItem._(_RowKind.system, msg: m);
  factory _RowItem.message(_Msg m) => _RowItem._(_RowKind.message, msg: m);
}

// ===== 공지 =====
class _PinnedNotice {
  final int msgId;
  final String title;
  final String body;
  final DateTime createdAt;
  final String author;
  _PinnedNotice({
    required this.msgId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.author,
  });
}

class _NoticeBanner extends StatelessWidget {
  final _PinnedNotice data;
  final bool expanded;
  final double collapsedHeight;
  final double expandedHeight;
  final VoidCallback onToggle;
  final VoidCallback onOpenDetail;
  final VoidCallback onDismiss;

  const _NoticeBanner({
    Key? key,
    required this.data,
    required this.expanded,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.onToggle,
    required this.onOpenDetail,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd').format(data.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: expanded ? expandedHeight : collapsedHeight,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28, height: 28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x14FF6B6B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.campaign_outlined, color: UiTokens.title, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenDetail,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(date, style: const TextStyle(
                                fontWeight: FontWeight.w800, color: UiTokens.title, fontSize: 12.5)),
                            const SizedBox(height: 2),
                            Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: UiTokens.title, fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                      onPressed: onToggle,
                    ),
                  ],
                ),
              ),

              // 본문
              if (expanded)
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.body.isEmpty ? '(내용 없음)' : data.body,
                            style: const TextStyle(color: Colors.black87, height: 1.34, fontSize: 14.5),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: onDismiss,
                              icon: const Icon(Icons.visibility_off_outlined, size: 18),
                              label: const Text('다시 보지 않기'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                foregroundColor: const Color(0xFF555555),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeDetailPage extends StatelessWidget {
  final _PinnedNotice data;
  const _NoticeDetailPage({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(data.createdAt);
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지 상세', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(data.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: UiTokens.title)),
          const SizedBox(height: 6),
          Text('$date · ${data.author}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Text(data.body.isEmpty ? '(내용 없음)' : data.body, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ---------- mapping ----------
typedef MsgMapper = _Msg Function(Map<String, dynamic>);
MsgMapper _mapRowToMsg(String myUid) => (Map<String, dynamic> r) {
  final id = (r['id'] as num).toInt();
  final t  = (r['type'] ?? 'text').toString();
  final createdRaw = r['created_at'];
  final created = createdRaw is DateTime
      ? createdRaw
      : DateTime.tryParse((createdRaw ?? '').toString()) ?? DateTime.now();

  final senderId = (r['sender_id'] ?? '').toString();
  final me = senderId.isNotEmpty && senderId == myUid;

  final isSystem = t == 'system';
  final deleted = r['is_deleted'] == true;

  // meta 추출 (파일/이미지 보조 정보)
  Map<String, dynamic> meta = {};
  final m = r['meta'];
  if (m is Map) {
    meta = Map<String, dynamic>.from(m);
  } else if (m is String && m.isNotEmpty) {
    try { meta = jsonDecode(m) as Map<String, dynamic>; } catch (_) {}
  }

  final fileName  = (r['file_name'] ?? meta['file_name'])?.toString();
  final fileBytes = (r['size_bytes'] ?? meta['size_bytes']);
  final storagePath = (r['storage_path'] ?? meta['storage_path'])?.toString();

  return _Msg(
    id: id,
    me: me,
    type: switch (t) {
      'image' => _MsgType.image,
      'file'  => _MsgType.file,
      'system'=> _MsgType.text, // 시스템은 칩으로 렌더
      _       => _MsgType.text,
    },
    text: (r['text'] ?? '').toString(),
    senderId: senderId.isNotEmpty ? senderId : null,
    imageUrl: (t == 'image') ? storagePath : null, // 공개 URL 변환 로직은 스토리지 정책 확정 후
    fileUrl:  (t == 'file')  ? storagePath : null,
    fileName: fileName,
    fileBytes: (fileBytes is num) ? fileBytes.toInt() : null,
    createdAt: created,
    deleted: deleted,
    readCount: (r['read_count'] as num?)?.toInt(),
    nickname: (r['sender_nick'] ?? '') as String?,
    photoUrl: (r['sender_photo'] ?? '') as String?,
    isSystem: isSystem,
    systemText: isSystem ? (r['text'] ?? '').toString() : null,
  );
};

class ChatDaySeparator extends StatelessWidget {
  final DateTime day;
  final Color background;
  final EdgeInsets padding;

  const ChatDaySeparator({
    Key? key,
    required this.day,
    this.background = const Color.fromRGBO(230, 230, 230, 1),
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  }) : super(key: key);

  String _labelKo(DateTime d) => DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(d);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const Expanded(child: SizedBox.shrink()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: UiTokens.title.withOpacity(0.85)),
                const SizedBox(width: 6),
                Text(
                  _labelKo(day),
                  style: TextStyle(
                    color: UiTokens.title.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}