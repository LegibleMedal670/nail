// lib/Pages/Chat/ChatRoomPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nail/Services/ChatService.dart';
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
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final List<String>? invitedNamesOnCreate;

  const ChatRoomPage({
    Key? key,
    required this.roomId,
    required this.roomName,
    this.invitedNamesOnCreate,
  }) : super(key: key);

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<MessageInputBarState> _inputKey = GlobalKey<MessageInputBarState>();

  final _svc = ChatService.instance;
  RealtimeChannel? _roomRt;

  bool _loading = false;
  bool _paging = false;
  bool _hasMore = true;
  int? _latestId;
  int? _oldestId;

  // 공지
  static const double _kNoticeCollapsed = 76.0;
  static const double _kNoticeExpanded  = 140.0;
  _PinnedNotice? _pinned;
  bool _noticeExpanded = false;

  // 메시지
  final List<_Msg> _messages = <_Msg>[];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bindRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadFirst();
      // 방 생성 직후 “초대했습니다” 시스템 메시지 (선택)
      if (widget.invitedNamesOnCreate != null && widget.invitedNamesOnCreate!.isNotEmpty) {
        final up = context.read<UserProvider>();
        final who = up.nickname.isNotEmpty ? up.nickname : '관리자';
        final list = widget.invitedNamesOnCreate!.join(', ');
        setState(() {
          _messages.insert(
            0,
            _Msg.system(
              id: -DateTime.now().millisecondsSinceEpoch, // 클라 가상 ID
              createdAt: DateTime.now(),
              systemText: '$who님이 $list님을 초대했습니다.',
            ),
          );
        });
      }


    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _roomRt?.unsubscribe();
    super.dispose();
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
    );
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
      final list = rows.map(_mapRowToMsg(my)).toList();

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
    final patch = { for (final r in rows) (r['id'] as num).toInt(): _mapRowToMsg(my)(r) };

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
        author: (m['author_id'] ?? '').toString(),
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
    try {
      await _svc.sendText(
        loginKey: key,
        roomId: widget.roomId,
        text: text,
        meta: {'client_ts': DateTime.now().toIso8601String()},
      );
      await _markRead();
      // 실시간 INSERT로 자연 갱신
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    }
  }

  // ---------- long-press 액션시트 ----------
  Future<void> _showMessageActionSheet(_Msg m, {required bool isAdmin}) async {
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
              if (isAdmin)
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공지로 등록했습니다.')));
    }
  }

  void _openImageFullscreen(_Msg imageMsg) {
    final src = imageMsg.imageUrl ?? imageMsg.imageLocal;
    if (src == null || src.isEmpty) return;
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
        title: Text(widget.roomName, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // 기존 InfoPage는 외부에서 멤버 목록을 받게 되어 있었음(목업 기반).
              // 우선 현재 대화 참여자 UI는 보류하고 방 정보 페이지로만 이동.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatRoomInfoPage(
                    roomId: widget.roomId,
                    roomName: widget.roomName,
                    isAdmin: isAdmin,
                    members: const <RoomMemberBrief>[],
                  ),
                ),
              );
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
                              readCount: m.isSystem ? null : m.readCount, // system 표시 숨김
                            );
                            break;
                          case _MsgType.image:
                            final heroTag = 'chat_img_${m.id}';
                            bubbleRow = ImageBubble(
                              isMe: isMe,
                              imageUrl: m.imageUrl,
                              localPreviewPath: m.imageLocal,
                              createdAt: m.createdAt,
                              readCount: m.readCount,
                              onTap: () => _openImageFullscreen(m),
                              heroTag: heroTag,
                            );
                            break;
                          case _MsgType.file:
                            bubbleRow = FileBubble(
                              isMe: isMe,
                              fileName: m.fileName ?? '파일',
                              fileBytes: m.fileBytes ?? 0,
                              localPath: m.fileLocal,
                              fileUrl: m.fileUrl,
                              createdAt: m.createdAt,
                              readCount: m.readCount,
                              onTapOpen: () {}, // TODO: 파일 열기 연동
                            );
                            break;
                        }
                      }

                      // ✅ 액션시트: 버블 외곽 래퍼에서 onLongPress로 처리 (버블에 삭제 핸들러 전달 X)
                      final wrapped = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => _showMessageActionSheet(m, isAdmin: isAdmin),
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
                                onViewProfile: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('프로필 보기 (구현 예정)')),
                                  );
                                },
                                onOpenDM: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('1:1 대화 (구현 예정)')),
                                  );
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
                  onSendImageLocalPath: (p) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이미지 업로드는 다음 단계에서 연결합니다.')),
                    );
                  },
                  onSendFileLocalPath: (p, n, b) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('파일 업로드는 다음 단계에서 연결합니다.')),
                    );
                  },
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