// lib/Pages/Chat/ChatRoomPage.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:nail/Pages/Chat/models/RoomMemberBrief.dart';
import 'package:nail/Pages/Chat/models/ReplyInfo.dart';
import 'package:nail/Pages/Chat/page/ChatRoomInfoPage.dart';
import 'package:nail/Pages/Chat/widgets/ChatImageViewer.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Pages/Chat/widgets/FileBubble.dart';
import 'package:nail/Pages/Chat/widgets/ImageBubble.dart';
import 'package:nail/Pages/Chat/widgets/ImageGroupBubble.dart';
import 'package:nail/Pages/Chat/widgets/IncomingMessageTile.dart';
import 'package:nail/Pages/Chat/widgets/MessageBubble.dart';
import 'package:nail/Pages/Chat/widgets/MessageInputBar.dart';
import 'package:nail/Pages/Chat/widgets/SystemEventChip.dart';
import 'package:nail/Pages/Chat/widgets/MemberProfileSheet.dart';
import 'package:nail/Pages/Chat/widgets/SwipeableMessageBubble.dart';
import 'package:nail/Pages/Chat/widgets/ReplyPreviewBar.dart';
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
  // scrollable_positioned_list 컨트롤러들
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
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

  // ========== 검색 모드 ==========
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<int> _searchResultIds = []; // 검색 결과 메시지 ID 목록
  int _currentSearchIndex = 0; // 현재 보고 있는 검색 결과 인덱스
  
  // 검색 전 상태 저장 (취소 시 복귀용)
  List<_Msg> _preSearchMessages = [];
  int? _preSearchLatestId;
  int? _preSearchOldestId;
  // ScrollablePositionedList는 offset이 아닌 index 기반 (현재 사용 안 함)

  // 공지
  static const double _kNoticeCollapsed = 76.0;
  static const double _kNoticeExpanded  = 140.0;
  _PinnedNotice? _pinned;
  bool _noticeExpanded = false;

  // 메시지
  final List<_Msg> _messages = <_Msg>[];
  
  // ========== 답장 모드 ==========
  _Msg? _replyToMessage; // 현재 답장 대상 메시지

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
    // ItemPositionsListener로 스크롤 감지
    _itemPositionsListener.itemPositions.addListener(_onScrollPositionChanged);
    _loadFileCache();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareRealtimeThenLoad();
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScrollPositionChanged);
    _roomRt?.unsubscribe();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  Future<void> _dismissNotice() async {
    final current = _pinned;
    if (current == null) return;
    // 로컬에 마지막으로 숨긴 공지 ID 저장
    if (_prefs != null) {
      await _prefs!.setInt('chat_notice_dismiss_${widget.roomId}', current.msgId);
    }
    if (!mounted) return;
    setState(() {
      _pinned = null;
      _noticeExpanded = false;
    });
  }

  // ---------- utils ----------
  String _loginKey() {
    if (!mounted) return '';
    final up = context.read<UserProvider>();
    return up.isAdmin ? (up.adminKey ?? '') : (up.current?.loginKey ?? '');
  }

  String _myUid() {
    if (!mounted) return '';
    final up = context.read<UserProvider>();
    return up.current?.userId ?? '';
  }
  
  // ========== 답장 관련 헬퍼 ==========
  
  /// 답장 설정
  void _setReplyTo(_Msg msg) {
    if (!_canReply(msg)) return;
    setState(() {
      _replyToMessage = msg;
    });
    // 입력창에 포커스
    _inputKey.currentState?.focusInput();
  }
  
  /// 답장 취소
  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }
  
  /// 답장 가능 여부 체크
  bool _canReply(_Msg msg) {
    if (msg.isSystem) return false;
    if (msg.type == null) return false;
    return msg.type == _MsgType.text || 
           msg.type == _MsgType.image || 
           msg.type == _MsgType.file;
  }
  
  /// 미리보기 텍스트 생성
  String _buildReplyPreview(_Msg msg) {
    if (msg.type == _MsgType.text) {
      return msg.text ?? '';
    } else if (msg.type == _MsgType.image) {
      return '사진';
    } else if (msg.type == _MsgType.file) {
      return '파일';
    }
    return '';
  }
  
  /// 원본 메시지의 실시간 삭제 상태를 반영한 ReplyInfo 반환
  ReplyInfo? _getReplyInfoWithDeletedStatus(ReplyInfo? replyTo) {
    if (replyTo == null) return null;
    
    // 원본 메시지 찾기
    final originalMsg = _messages.firstWhere(
      (m) => m.id == replyTo.messageId,
      orElse: () => _Msg.system(
        id: -1,
        createdAt: DateTime.now(),
        systemText: '',
      ),
    );
    
    // 원본을 찾았고 삭제 상태가 다르면 업데이트
    if (originalMsg.id != -1 && originalMsg.deleted != replyTo.deleted) {
      return ReplyInfo(
        messageId: replyTo.messageId,
        senderId: replyTo.senderId,
        senderNickname: replyTo.senderNickname,
        type: replyTo.type,
        preview: replyTo.preview,
        deleted: originalMsg.deleted, // 원본의 실시간 삭제 상태 반영
      );
    }
    
    return replyTo;
  }
  
  /// 원본 메시지로 스크롤 이동
  Future<void> _scrollToMessage(int messageId) async {
    // 1. 현재 로드된 메시지 중 찾기
    final index = _messages.indexWhere((m) => m.id == messageId);
    
    if (index >= 0) {
      // reverse: true이므로 역순 인덱스 계산
      final items = _buildItemsWithSeparators(_messages);
      final targetItem = items.indexWhere((item) => item.msg?.id == messageId);
      
      if (targetItem >= 0) {
        // reverse 리스트이므로 역순 인덱스로 변환
        final reverseIndex = items.length - 1 - targetItem;
        await _itemScrollController.scrollTo(
          index: reverseIndex,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5, // 화면 중앙에 위치
        );
      }
      return;
    }
    
    // 2. 없으면 토스트로 알림
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('원본 메시지를 찾을 수 없습니다')),
      );
    }
  }

  void _jumpToBottom({bool animate = false}) {
    if (!_itemScrollController.isAttached) return;
    final items = _buildItemsWithSeparators(_messages);
    if (items.isEmpty) return;
    
    // reverse: true이므로 index 0이 최신(맨 아래)
    if (animate) {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _itemScrollController.jumpTo(index: 0);
    }
  }

  bool get _nearBottom {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return true;
    // reverse ListView에서 index 0이 보이면 맨 아래에 있는 것
    return positions.any((pos) => pos.index == 0);
  }

  void _autoScrollIfNearBottom() {
    if (_nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
    }
  }
  
  /// 스크롤 위치 변경 감지 (과거 메시지 로드 트리거)
  void _onScrollPositionChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    
    final items = _buildItemsWithSeparators(_messages);
    if (items.isEmpty) return;
    
    // 가장 큰 인덱스 (reverse에서 가장 오래된 메시지 방향)
    final maxIndex = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    
    // 끝에서 5개 이내면 과거 메시지 로드
    if (maxIndex >= items.length - 5) {
      _loadOlder();
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
        if (!mounted) return;
        await _reloadLatestWindow();
        if (!mounted) return;
        await _markRead();
        if (!mounted) return;
        _autoScrollIfNearBottom();
      },
      onUpdate: (_) async {
        if (!mounted) return;
        await _reloadLatestWindow();
      },
      onPinUpdate: (_) async {
        if (!mounted) return;
        await _loadNotice();
      },
      onMemberUpdate: (_) async {
        if (!mounted) return;
        await _loadMemberCount();
        // 다른 참여자의 last_read_at 갱신에 맞춰 read_count를 최신화
        if (!mounted) return;
        await _reloadLatestWindow();
      },
    );
  }

  // ========== 검색 모드 함수들 ==========
  
  /// 검색 모드 진입
  void _enterSearchMode() {
    // 현재 상태 저장 (취소 시 현재 위치 유지하므로 스크롤 위치 저장 불필요)
    _preSearchMessages = List.from(_messages);
    _preSearchLatestId = _latestId;
    _preSearchOldestId = _oldestId;
    
    setState(() {
      _isSearchMode = true;
      _searchQuery = '';
      _searchResultIds = [];
      _currentSearchIndex = 0;
    });
    
    // 텍스트필드에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  /// 검색 모드 종료 (취소) - 현재 위치 유지
  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _searchQuery = '';
      _searchResultIds = [];
      _currentSearchIndex = 0;
      _searchController.clear();
      // 현재 보고 있는 메시지/위치는 그대로 유지
    });
  }
  
  /// 검색 실행 (Enter 시)
  Future<void> _executeSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResultIds = [];
        _currentSearchIndex = 0;
      });
      return;
    }
    
    final key = _loginKey();
    if (key.isEmpty) return;
    
    try {
      final results = await _svc.searchMessages(
        loginKey: key,
        roomId: widget.roomId,
        query: query,
        limit: 100,
      );
      
      if (!mounted) return;
      
      // 검색 결과 ID 목록 (오래된 순으로 정렬)
      final ids = results
          .map((r) => (r['id'] as num).toInt())
          .toList()
        ..sort();
      
      setState(() {
        _searchQuery = query;
        _searchResultIds = ids;
        _currentSearchIndex = ids.isNotEmpty ? ids.length - 1 : 0; // 최신 결과부터
      });
      
      // 첫 번째 결과로 점프
      if (ids.isNotEmpty) {
        await _jumpToMessage(ids[_currentSearchIndex]);
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }
  
  /// 위로 이동 (▲) - 더 최신 메시지로
  Future<void> _goToPreviousResult() async {
    if (_searchResultIds.isEmpty) return;
    
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1).clamp(0, _searchResultIds.length - 1);
    });
    
    await _jumpToMessage(_searchResultIds[_currentSearchIndex]);
  }
  
  /// 아래로 이동 (▼) - 더 오래된 메시지로
  Future<void> _goToNextResult() async {
    if (_searchResultIds.isEmpty) return;
    
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1).clamp(0, _searchResultIds.length - 1);
    });
    
    await _jumpToMessage(_searchResultIds[_currentSearchIndex]);
  }
  
  /// 날짜 선택 바텀시트 표시
  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final key = _loginKey();
    if (key.isEmpty) return;
    
    // 메시지가 있는 날짜 목록 조회
    Set<DateTime> availableDates = {};
    try {
      availableDates = await _svc.getMessageDates(
        loginKey: key,
        roomId: widget.roomId,
      );
    } catch (e) {
      debugPrint('Get message dates error: $e');
    }
    
    if (!mounted) return;
    
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DatePickerSheet(
        initialDate: now,
        firstDate: DateTime(2020, 1, 1),
        lastDate: now,
        availableDates: availableDates,
      ),
    );
    
    if (picked == null || !mounted) return;
    
    await _jumpToDate(picked);
  }
  
  /// 선택한 날짜의 첫 메시지로 점프
  Future<void> _jumpToDate(DateTime date) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    
    try {
      final messageId = await _svc.findFirstMessageByDate(
        loginKey: key,
        roomId: widget.roomId,
        date: date,
      );
      
      if (!mounted) return;
      if (messageId == null) return; // 대화 있는 날짜만 선택 가능하므로 발생하지 않음
      
      await _jumpToMessage(messageId);
    } catch (e) {
      debugPrint('Jump to date error: $e');
    }
  }
  
  /// 특정 메시지로 점프
  Future<void> _jumpToMessage(int targetId) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    
    // 이미 로드된 메시지에 있는지 확인
    final existingIndex = _messages.indexWhere((m) => m.id == targetId);
    if (existingIndex != -1) {
      // 이미 있으면 스크롤만 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessageId(targetId);
      });
      return;
    }
    
    try {
      // targetId 기준으로 앞뒤 메시지 로드
      final rows = await _svc.fetchMessages(
        loginKey: key,
        roomId: widget.roomId,
        afterId: targetId - 100,
        beforeId: targetId + 100,
        limit: 200,
      );
      
      if (!mounted) return;
      
      rows.sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
      final my = _myUid();
      final newMessages = _applyFileCache(rows.map(_mapRowToMsg(my)).toList());
      
      if (newMessages.isEmpty) return;
      
      setState(() {
        // 기존 메시지와 새 메시지 병합 (중복 제거)
        final existingIds = _messages.map((m) => m.id).toSet();
        for (final msg in newMessages) {
          if (!existingIds.contains(msg.id)) {
            _messages.add(msg);
          }
        }
        // 정렬
        _messages.sort((a, b) => a.id.compareTo(b.id));
        
        // ID 범위 갱신
        if (_messages.isNotEmpty) {
          _oldestId = _messages.first.id;
          _latestId = _messages.last.id;
        }
        _hasMore = true;
      });
      
      // 해당 메시지로 스크롤
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessageId(targetId);
      });
    } catch (e) {
      debugPrint('Jump to message error: $e');
    }
  }
  
  /// 특정 메시지 ID로 스크롤 (정확한 인덱스 기반)
  void _scrollToMessageId(int targetId) {
    if (!_itemScrollController.isAttached) return;
    
    final items = _buildItemsWithSeparators(_messages);
    
    // 해당 메시지의 아이템 인덱스 찾기
    int itemIndex = -1;
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.msg != null && it.msg!.id == targetId) {
        itemIndex = i;
        break;
      }
    }
    
    if (itemIndex == -1) return;
    
    // reverse ListView에서의 인덱스
    final reverseIndex = items.length - 1 - itemIndex;
    
    // 정확한 인덱스 기반 스크롤!
    _itemScrollController.scrollTo(
      index: reverseIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.3, // 화면의 30% 위치에 표시
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
              meta: m.meta,
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
        meta: m.meta,
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

  Future<List<String>> _resolveSignedUrls(List<String>? storagePaths) async {
    if (storagePaths == null || storagePaths.isEmpty) return <String>[];
    final out = <String>[];
    for (final p in storagePaths) {
      final u = await _signedUrlForPath(p);
      if (u != null && u.isNotEmpty) out.add(u);
    }
    return out;
  }

  Future<void> _sendImageLocalPath(String localPath) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) return;
    if (!mounted) return;

    // optimistic bubble (단일 이미지 미리보기)
    _insertTempImageBubble(localPath);
    try {
      // ✅ Supabase 세션 확인 (Storage RLS 우회)
      await _ensureSupabaseSession();
      
      // 스토리지에 업로드
      final mime = _guessImageMime(localPath);
      final storagePath = await _storage.uploadChatFile(
        file: file,
        roomId: widget.roomId,
        kind: 'images',
        contentType: mime,
      );
      if (!mounted) return;

      final size = await file.length();
      final name = _basename(localPath);

      // rpc_send_images 를 단일 파일로 호출해서 type='image' 메시지 생성
      await _svc.sendImagesGroup(
        loginKey: key,
        roomId: widget.roomId,
        files: [
          {
            'file_name': name,
            'size_bytes': size,
            'mime': mime,
            'storage_path': storagePath,
          },
        ],
        meta: {'client_ts': DateTime.now().toIso8601String()},
      );
      if (!mounted) return;
      await _reloadLatestWindow();
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.image);
      });
      await _markRead();
    } catch (e) {
      debugPrint('sendImage error: $e');
    }
  }

  Future<void> _sendFileLocalPath(String localPath, String fileName, int fileBytes) async {
    final key = _loginKey();
    if (key.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) return;
    if (!mounted) return;
    final int size = fileBytes > 0 ? fileBytes : await file.length();
    final String name = (fileName.isNotEmpty) ? fileName : _basename(localPath);
    final String mime = _guessFileMime(name);
    _insertTempFileBubble(localPath, name, size);
    try {
      // ✅ Supabase 세션 확인 (Storage RLS 우회)
      await _ensureSupabaseSession();
      
      final storagePath = await _storage.uploadChatFile(
        file: file,
        roomId: widget.roomId,
        kind: 'files',
        contentType: mime,
      );
      if (!mounted) return;
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
      if (!mounted) return;
      await _reloadLatestWindow();
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.file);
      });
      await _markRead();
    } catch (e) {
      debugPrint('sendFile error: $e');
    }
  }

  /// Supabase 익명 세션 확인/갱신 (Storage RLS 우회용)
  Future<void> _ensureSupabaseSession() async {
    final sb = Supabase.instance.client;
    
    // 현재 세션 확인
    final session = sb.auth.currentSession;
    
    if (session == null) {
      // 세션 없음 → 익명 로그인
      debugPrint('[ChatRoom] No Supabase session, signing in anonymously');
      await sb.auth.signInAnonymously();
    } else {
      // 세션 만료 임박 시 자동 갱신
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final bufferSeconds = 60; // 1분 버퍼
        
        if (expiresAt - now < bufferSeconds) {
          debugPrint('[ChatRoom] Supabase session expiring soon, refreshing');
          try {
            await sb.auth.refreshSession();
          } catch (e) {
            debugPrint('[ChatRoom] Session refresh failed, re-authenticating: $e');
            await sb.auth.signInAnonymously();
          }
        }
      }
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
      if (!mounted) return;
      rows.sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
      final my = _myUid();
      final list = _applyFileCache(rows.map(_mapRowToMsg(my)).toList());

      setState(() {
        // ✅ 버그 수정: 전송중인 임시 버블은 유지 (단, 서버에서 같은 타입의 메시지를 받았으면 제외)
        final tempMessages = _messages.where((m) => m.sendStatus == _SendStatus.sending).toList();
        final serverTypes = list.map((m) => m.type).toSet();
        // 서버에서 같은 타입의 진짜 메시지를 받았으면 해당 임시 버블은 복원 안 함
        final tempToRestore = tempMessages.where((t) => !serverTypes.contains(t.type)).toList();
        
        _messages
          ..clear()
          ..addAll(list)
          ..addAll(tempToRestore);  // 중복 안 되는 임시 버블만 복원
        _messages.sort((a, b) => a.id.compareTo(b.id));
        
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

    // 조회 범위: (_latestId - 200) 이후의 메시지
    final queryAfterId = _latestId! - 200;
    
    List<Map<String, dynamic>> rows;
    try {
      rows = await _svc.fetchMessages(
        loginKey: key,
        roomId: widget.roomId,
        afterId: queryAfterId,
        limit: 200,
      );
    } catch (e) {
      // 네트워크 에러 시 메시지 삭제 로직 실행 안 함 (기존 상태 유지)
      debugPrint('fetchMessages error: $e');
      return;
    }
    
    if (!mounted) return;
    rows.sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
    final my = _myUid();
    final patch = {
      for (final r in rows)
        (r['id'] as num).toInt(): _applyFileCache([_mapRowToMsg(my)(r)]).first
    };

    // 서버에서 받은 메시지 ID 집합
    final serverIds = patch.keys.toSet();
    
    // 서버 조회가 성공했을 때만 삭제 로직 실행
    // (빈 결과도 정상 응답이므로 삭제된 메시지 정리)
    if (!mounted) return;
    setState(() {
      // ✅ 버그 수정: 조회 범위 내에서 서버에 없는 메시지는 삭제된 것 → 제거
      // (단, 임시 전송중인 메시지는 유지)
      _messages.removeWhere((m) {
        // 전송중인 임시 메시지는 유지
        if (m.sendStatus == _SendStatus.sending) return false;
        // 조회 범위 밖의 메시지는 건드리지 않음
        if (m.id <= queryAfterId) return false;
        // 조회 범위 내인데 서버에 없으면 삭제됨 → 제거
        return !serverIds.contains(m.id);
      });

      // 기존 메시지 업데이트
      for (int i = 0; i < _messages.length; i++) {
        final id = _messages[i].id;
        if (patch.containsKey(id)) _messages[i] = patch[id]!;
      }
      // 새 메시지 추가
      for (final e in patch.entries) {
        if (!_messages.any((m) => m.id == e.key)) _messages.add(e.value);
      }
      _messages.sort((a, b) => a.id.compareTo(b.id));
      
      // ✅ 버그 수정: 모든 메시지가 삭제되었으면 ID 초기화
      final realMessages = _messages.where((m) => m.sendStatus != _SendStatus.sending);
      if (realMessages.isEmpty) {
        _latestId = null;
        _oldestId = null;
      } else {
        _latestId = realMessages.last.id;
        _oldestId = realMessages.first.id;
      }
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
      if (!mounted) return;
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
    final msgId = (m['message_id'] as num).toInt();
    // 이미 '보지 않기'로 숨긴 공지라면 표시하지 않음
    final lastDismissedId = _prefs?.getInt('chat_notice_dismiss_${widget.roomId}');
    if (lastDismissedId != null && lastDismissedId == msgId) {
      setState(() => _pinned = null);
      return;
    }
    final body = (m['body'] ?? '').toString();
    // 접혀 있을 때는 제목 대신 본문 1줄을 보여준다.
    final firstLine = body.trim().isEmpty ? '공지' : body.trim().split('\n').first;
    setState(() {
      _pinned = _PinnedNotice(
        msgId: msgId,
        title: firstLine,
        body: body,
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
    
    // 답장 정보 구성
    Map<String, dynamic> meta = {
      'client_ts': DateTime.now().toIso8601String(),
      'kind': 'text',
    };
    
    if (_replyToMessage != null) {
      meta['reply_to'] = {
        'message_id': _replyToMessage!.id,
        'sender_id': _replyToMessage!.senderId,
        'sender_nickname': _replyToMessage!.nickname ?? '알 수 없음',
        'type': _replyToMessage!.type.toString().split('.').last,
        'preview': _buildReplyPreview(_replyToMessage!),
        'deleted': _replyToMessage!.deleted,
      };
    }
    
    _insertTempTextBubble(text);
    
    try {
      await _svc.sendText(
        loginKey: key,
        roomId: widget.roomId,
        text: text,
        meta: meta,
      );
      
      // 답장 모드 해제
      _clearReply();
      
      if (!mounted) return;
      await _reloadLatestWindow();
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.text);
      });
      await _markRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    }
  }

  Future<void> _sendImagesLocalPaths(List<String> localPaths) async {
    if (localPaths.isEmpty) return;
    final key = _loginKey();
    if (key.isEmpty) return;
    final paths = localPaths.take(10).toList(growable: false);
    _insertTempImageGroupBubble(paths);
    try {
      final files = <File>[];
      for (final pth in paths) {
        final f = File(pth);
        if (await f.exists()) files.add(f);
      }
      if (!mounted) return;
      final storagePaths = await _storage.uploadChatFilesBatch(
        files: files,
        roomId: widget.roomId,
        kind: 'images',
        contentTypeResolver: (f) => _guessImageMime(f.path),
      );
      if (!mounted) return;
      final filesMeta = <Map<String, dynamic>>[];
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        final size = await f.length();
        final name = _basename(f.path);
        final mime = _guessImageMime(f.path);
        filesMeta.add({
          'file_name': name,
          'size_bytes': size,
          'mime': mime,
          'storage_path': storagePaths[i],
        });
      }
      // 메타 구성 (답장 정보 제외 - 이미지는 텍스트로만 답장 가능)
      Map<String, dynamic> meta = {
        'client_ts': DateTime.now().toIso8601String(),
      };
      
      await _svc.sendImagesGroup(
        loginKey: key,
        roomId: widget.roomId,
        files: filesMeta,
        meta: meta,
      );
      
      if (!mounted) return;
      await _reloadLatestWindow();
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.sendStatus == _SendStatus.sending && m.type == _MsgType.imageGroup);
      });
      await _markRead();
    } catch (e) {
      debugPrint('sendImagesGroup error: $e');
    }
  }

  void _insertTempImageBubble(String localPath) {
    final int nextId = (_messages.isNotEmpty ? _messages.map((e)=>e.id).reduce((a,b)=>a>b?a:b) : 0) + 1;
    
    // 이미지는 답장 모드 사용 불가 (메타 없음)
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
      meta: null, // 이미지는 답장 메타 없음
    );
    setState(() {
      _messages.add(temp);
      _messages.sort((a, b) => a.id.compareTo(b.id));
    });
    _autoScrollIfNearBottom();
  }

  void _insertTempImageGroupBubble(List<String> localPaths) {
    final int nextId = (_messages.isNotEmpty ? _messages.map((e)=>e.id).reduce((a,b)=>a>b?a:b) : 0) + 1;
    
    // 이미지 그룹은 답장 모드 사용 불가 (메타 없음)
    final temp = _Msg(
      id: nextId,
      me: true,
      type: _MsgType.imageGroup,
      text: null,
      imageUrl: null,
      imageLocal: null,
      imageUrls: null,
      imageLocals: localPaths,
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
      meta: null, // 이미지 그룹은 답장 메타 없음
    );
    setState(() {
      _messages.add(temp);
      _messages.sort((a, b) => a.id.compareTo(b.id));
    });
    _autoScrollIfNearBottom();
  }

  void _insertTempTextBubble(String text) {
    final int nextId = (_messages.isNotEmpty ? _messages.map((e)=>e.id).reduce((a,b)=>a>b?a:b) : 0) + 1;
    
    // 답장 정보 구성
    Map<String, dynamic>? meta;
    if (_replyToMessage != null) {
      meta = {
        'reply_to': {
          'message_id': _replyToMessage!.id,
          'sender_id': _replyToMessage!.senderId,
          'sender_nickname': _replyToMessage!.nickname ?? '알 수 없음',
          'type': _replyToMessage!.type.toString().split('.').last,
          'preview': _buildReplyPreview(_replyToMessage!),
          'deleted': _replyToMessage!.deleted,
        }
      };
    }
    
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
      meta: meta,
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
        final meUid = _myUid();
        final isMine = (m.senderId != null && m.senderId!.isNotEmpty && m.senderId == meUid);
        final canReply = _canReply(m);
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
              if (isAdmin || isMine)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('삭제'),
                  onTap: () => Navigator.of(sheetCtx).pop('delete'),
                ),
              if (canReply)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('답장'),
                  onTap: () => Navigator.of(sheetCtx).pop('reply'),
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

    if (action == 'reply') {
      _setReplyTo(m);
      return;
    }

    if (action == 'delete') {
      final ok = await confirmDeleteMessage(context);
      if (!ok) return;
      // 관리자면 관리자 삭제, 아니면 본인 삭제
      final meUid = _myUid();
      final isMine = (m.senderId != null && m.senderId!.isNotEmpty && m.senderId == meUid);
      if (isAdmin) {
        await _svc.deleteMessage(adminLoginKey: key, messageId: m.id);
      } else if (isMine) {
        await _svc.deleteMyMessage(loginKey: key, messageId: m.id);
      }
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

  Future<void> _openImagesFullscreen(_Msg m) async {
    List<String> imgs = [];
    if (m.imageLocals != null && m.imageLocals!.isNotEmpty) {
      imgs = List<String>.from(m.imageLocals!);
    } else if (m.imageUrls != null && m.imageUrls!.isNotEmpty) {
      imgs = await _resolveSignedUrls(m.imageUrls!);
    }
    if (imgs.isEmpty) return;
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) => ChatImageViewer(
          images: imgs,
          initialIndex: 0,
          heroTagPrefix: 'chat_imgs_${m.id}_',
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  String _deletedLabel(_Msg m) {
    if (m.deletedBy == 'admin') return '관리자에 의해 삭제됨';
    if (m.deletedBy == 'user') return '사용자에 의해 삭제됨';
    return '삭제됨';
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
              meta: _messages[i].meta,
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

  // ---------- AppBar 빌드 ----------
  AppBar _buildNormalAppBar(bool isAdmin) {
    return AppBar(
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
        // 검색 버튼 추가
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _enterSearchMode,
        ),
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () async {
            final result = await Navigator.of(context).push<dynamic>(
              MaterialPageRoute(
                builder: (_) => ChatRoomInfoPage(
                  roomId: widget.roomId,
                  roomName: _roomName ?? widget.roomName,
                  isAdmin: isAdmin,
                  members: const <RoomMemberBrief>[],
                ),
              ),
            );
            if (!mounted) return;
            if (result == '__cleared__') {
              await _loadFirst();
              _jumpToBottom();
            } else if (result is String && result.isNotEmpty) {
              setState(() => _roomName = result);
            }
          },
        ),
      ],
    );
  }
  
  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 12),
          // 검색 아이콘
          const Icon(Icons.search, color: Colors.grey, size: 22),
          const SizedBox(width: 8),
          // 검색 텍스트필드
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '대화내용 검색',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                // X 버튼 (텍스트 지우기)
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _searchResultIds = [];
                            _currentSearchIndex = 0;
                          });
                        },
                      )
                    : null,
              ),
              style: const TextStyle(fontSize: 16, color: UiTokens.title),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}), // X 버튼 표시 갱신용
              onSubmitted: (_) => _executeSearch(),
            ),
          ),
          // 취소 버튼
          TextButton(
            onPressed: _exitSearchMode,
            child: const Text(
              '취소',
              style: TextStyle(
                color: UiTokens.title,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // ---------- 검색 하단 네비게이션 바 ----------
  Widget _buildSearchNavigationBar() {
    final hasResults = _searchResultIds.isNotEmpty;
    final currentDisplay = hasResults ? _searchResultIds.length - _currentSearchIndex : 0;
    final totalDisplay = _searchResultIds.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 좌측: 달력 버튼
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              color: UiTokens.title,
              onPressed: _showDatePicker,
              tooltip: '날짜로 이동',
            ),
            // 중앙: 결과 카운터 또는 "검색 결과 없음"
            Expanded(
              child: Center(
                child: hasResults
                    ? Text(
                        '$currentDisplay/$totalDisplay',
                        style: const TextStyle(
                          fontSize: 14,
                          color: UiTokens.title,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : Text(
                        _searchQuery.isNotEmpty ? '검색 결과 없음' : '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
              ),
            ),
            // 위로 (▲) - 더 최신 메시지로
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: hasResults && _currentSearchIndex > 0
                    ? UiTokens.title
                    : Colors.grey[300],
              ),
              onPressed: hasResults && _currentSearchIndex > 0
                  ? _goToPreviousResult
                  : null,
            ),
            // 아래로 (▼) - 더 오래된 메시지로
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: hasResults && _currentSearchIndex < _searchResultIds.length - 1
                    ? UiTokens.title
                    : Colors.grey[300],
              ),
              onPressed: hasResults && _currentSearchIndex < _searchResultIds.length - 1
                  ? _goToNextResult
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final isAdmin = up.isAdmin;

    final items = _buildItemsWithSeparators(_messages);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar(isAdmin),
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
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
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

                      // 검색 모드에서 현재 결과인지 확인
                      final isCurrentResult = _isSearchMode && 
                          _searchResultIds.isNotEmpty && 
                          _currentSearchIndex < _searchResultIds.length &&
                          m.id == _searchResultIds[_currentSearchIndex];
                      
                      // 버블 생성
                      Widget bubbleRow;
                      if (m.deleted) {
                        bubbleRow = MessageBubble(
                          isMe: isMe,
                          text: _deletedLabel(m),
                          createdAt: m.createdAt,
                          readCount: null, // 삭제 메시지는 숨김
                        );
                      } else {
                        switch (m.type!) {
                          case _MsgType.text:
                            final replyInfo = _getReplyInfoWithDeletedStatus(m.replyTo);
                            bubbleRow = MessageBubble(
                              isMe: isMe,
                              text: m.text ?? '',
                              createdAt: m.createdAt,
                              readCount: m.isSystem ? null : m.readCount,
                              highlightQuery: _isSearchMode ? _searchQuery : null,
                              isCurrentSearchResult: isCurrentResult,
                              replyTo: replyInfo,
                              onReplyTap: replyInfo != null && !replyInfo.deleted ? () => _scrollToMessage(replyInfo.messageId) : null,
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
                          case _MsgType.imageGroup:
                            bubbleRow = FutureBuilder<List<String>>(
                              future: _resolveSignedUrls(m.imageUrls),
                              builder: (context, snap) {
                                final urls = snap.data;
                                return ImageGroupBubble(
                                  isMe: isMe,
                                  createdAt: m.createdAt,
                                  readCount: m.readCount,
                                  loading: m.sendStatus == _SendStatus.sending,
                                  imageUrls: (urls == null || urls.isEmpty) ? null : urls,
                                  localPreviewPaths: m.imageLocals,
                                  expectedCount: m.imageUrls?.length,
                                  onTap: () => _openImagesFullscreen(m),
                                );
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

                      // ✅ 스와이프 답장 + 롱프레스 메뉴
                      final wrapped = SwipeableMessageBubble(
                        canReply: _canReply(m) && !m.deleted,
                        onReply: () => _setReplyTo(m),
                        isMine: isMe,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () {
                            if (m.deleted) return;
                            final meUid = _myUid();
                            final isMine = (m.senderId != null && m.senderId!.isNotEmpty && m.senderId == meUid);
                            // 관리자가 아니고 내 메시지도 아니면 액션시트 자체를 열지 않음
                            if (!isAdmin && !isMine) return;
                            _showMessageActionSheet(
                              m,
                              isAdmin: isAdmin,
                              allowNotice: m.type == _MsgType.text,
                            );
                          },
                          child: bubbleRow,
                        ),
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
                // 답장 프리뷰 바 (답장 모드일 때만 표시)
                if (_replyToMessage != null)
                  ReplyPreviewBar(
                    senderNickname: _replyToMessage!.nickname ?? '알 수 없음',
                    preview: _buildReplyPreview(_replyToMessage!),
                    type: _replyToMessage!.type.toString().split('.').last,
                    isDeleted: _replyToMessage!.deleted,
                    onCancel: _clearReply,
                  ),
                // 검색 모드일 때는 네비게이션 바, 아니면 입력바
                if (_isSearchMode)
                  _buildSearchNavigationBar()
                else
                  MessageInputBar(
                    key: _inputKey,
                    onSendText: _sendText,
                    onSendImageLocalPath: _sendImageLocalPath,
                    onSendFileLocalPath: _sendFileLocalPath,
                    onSendImagesLocalPaths: _sendImagesLocalPaths,
                    isReplyMode: _replyToMessage != null, // 답장 모드 전달
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
                    onDismiss: _dismissNotice,
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
      // UTC → Local 변환 후 날짜 비교 (시간대 버그 수정)
      final local = m.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
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
enum _MsgType { text, image, imageGroup, file }
enum _SendStatus { sending, sent }

class _Msg {
  final int id;
  final bool me;
  final _MsgType? type;
  final String? text;
  final String? senderId;
  final String? imageUrl;
  final String? imageLocal;
  final List<String>? imageUrls;
  final List<String>? imageLocals;
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
  final String? deletedBy; // 'admin' | 'user'
  final Map<String, dynamic>? meta; // 메타데이터 (답장 정보 포함)

  _Msg({
    required this.id,
    required this.me,
    this.type,
    this.text,
    this.senderId,
    this.imageUrl,
    this.imageLocal,
    this.imageUrls,
    this.imageLocals,
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
    this.deletedBy,
    this.meta,
  });
  
  /// 답장 정보 getter
  ReplyInfo? get replyTo {
    if (meta == null || meta!['reply_to'] == null) return null;
    try {
      return ReplyInfo.fromJson(meta!['reply_to'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

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
        imageUrls = null,
        imageLocals = null,
        fileUrl = null,
        fileLocal = null,
        fileName = null,
        fileBytes = null,
        deleted = false,
        readCount = null,
        nickname = null,
        photoUrl = null,
        isSystem = true,
        sendStatus = _SendStatus.sent,
        deletedBy = null,
        meta = null;
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
  final deletedBy = (meta['deleted_by'] ?? '').toString();
  final fileName  = (meta['file_name'] ?? meta['filename'])?.toString();
  final fileBytes = (meta['size_bytes']);

  // urls는 스토리지 경로 배열 (단일/그룹 이미지 및 파일 공통)
  final urlsRaw = r['urls'];
  final urlList = <String>[];
  if (urlsRaw is List) {
    for (final u in urlsRaw) {
      final s = u?.toString() ?? '';
      if (s.isNotEmpty) urlList.add(s);
    }
  }
  final storagePath = urlList.isNotEmpty ? urlList.first : null;
  final isGroup = t == 'image' && urlList.length > 1;

  return _Msg(
    id: id,
    me: me,
    type: switch (t) {
      'image' => (isGroup ? _MsgType.imageGroup : _MsgType.image),
      'file'  => _MsgType.file,
      'system'=> _MsgType.text, // 시스템은 칩으로 렌더
      _       => _MsgType.text,
    },
    text: (r['text'] ?? '').toString(),
    senderId: senderId.isNotEmpty ? senderId : null,
    imageUrl: (t == 'image' && !isGroup) ? storagePath : null, // 단일 이미지
    imageUrls: (t == 'image' && isGroup) ? urlList : null,     // 이미지 그룹
    fileUrl:  (t == 'file')  ? storagePath : null,
    fileName: fileName,
    fileBytes: (fileBytes is num) ? fileBytes.toInt() : null,
    createdAt: created,
    deleted: deleted,
    // 서버에서 계산된 '아직 안 읽은 사람 수' (전체 인원 - 읽은 사람 - 보낸 사람)
    readCount: (r['read_remaining'] as num?)?.toInt(),
    nickname: (r['nickname'] ?? '') as String?,
    photoUrl: (r['photo_url'] ?? '') as String?,
    isSystem: isSystem,
    systemText: isSystem ? (r['text'] ?? '').toString() : null,
    deletedBy: deletedBy.isEmpty ? null : deletedBy,
    meta: meta.isNotEmpty ? meta : null, // ✨ meta 전달 추가
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

// ========== 커스텀 날짜 선택 바텀시트 ==========
class _DatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> availableDates; // 대화가 있는 날짜만

  const _DatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.availableDates,
  });

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
  }
  
  /// 해당 날짜에 대화가 있는지 확인
  bool _hasMessages(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return widget.availableDates.contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 핸들
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // 달력
            TableCalendar(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                // 대화가 없는 날짜는 선택 불가
                if (!_hasMessages(selectedDay)) return;
                
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                
                // 선택 후 바로 닫기
                Navigator.of(context).pop(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              locale: 'ko_KR',
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: UiTokens.title,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left, color: UiTokens.title),
                rightChevronIcon: const Icon(Icons.chevron_right, color: UiTokens.title),
                headerPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                weekendStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              calendarStyle: CalendarStyle(
                // 오늘 (대화가 있는 경우)
                todayDecoration: BoxDecoration(
                  color: _hasMessages(DateTime.now()) 
                      ? UiTokens.primaryBlue.withOpacity(0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: _hasMessages(DateTime.now()) 
                      ? UiTokens.primaryBlue 
                      : Colors.grey[300],
                  fontWeight: FontWeight.w700,
                ),
                // 선택된 날짜
                selectedDecoration: const BoxDecoration(
                  color: UiTokens.primaryBlue,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                // 기본 날짜
                defaultTextStyle: const TextStyle(
                  color: UiTokens.title,
                  fontWeight: FontWeight.w500,
                ),
                // 주말
                weekendTextStyle: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
                // 범위 밖 날짜 (대화 없음)
                disabledTextStyle: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w400,
                ),
                // 외부 날짜 (다른 달)
                outsideTextStyle: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w400,
                ),
                outsideDaysVisible: true,
                cellMargin: const EdgeInsets.all(4),
              ),
              // 대화가 있는 날짜만 선택 가능
              enabledDayPredicate: (day) => _hasMessages(day),
              // 대화가 있는 날짜에 마커 표시
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (_hasMessages(day) && !isSameDay(_selectedDay, day)) {
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: UiTokens.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}