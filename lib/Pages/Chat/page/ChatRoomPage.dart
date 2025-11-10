// lib/Pages/Chat/ChatRoomPage.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  // ------- 공지 상태(간단 버전: 오버레이만) -------
  static const double _kNoticeCollapsed = 76.0;
  static const double _kNoticeExpanded  = 140.0;
  _PinnedNotice? _pinned;
  bool _noticeExpanded = false;

  // 목업 데이터
  final List<_Msg> _messages = [
    _Msg.system(
      id: 900,
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      systemText: formatRoomCreated(creator: '홍원준'),
    ),
    _Msg(
      id: 1,
      me: false,
      type: _MsgType.text,
      text: '안녕하세요! 방 생성 확인합니다.',
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 3, minutes: 50)),
      readCount: 3,
      nickname: '노브살롱외주',
    ),
    _Msg.system(
      id: 901,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      systemText: formatInvitedMany(
        inviter: '홍원준',
        invitees: ['호소', '탁경', '이지원', '이병준', '안지원', '김안호', '김서영', '정우혁'],
      ),
    ),
    _Msg(
      id: 2,
      me: true,
      type: _MsgType.text,
      text: '회의는 내일 10시에 시작할게요.',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 40)),
      readCount: 2,
      nickname: '나',
    ),
    _Msg(
      id: 3,
      me: false,
      type: _MsgType.image,
      imageLocal: null,
      imageUrl: null,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 35)),
      readCount: 1,
      nickname: '디자이너A',
      photoUrl: 'https://example.com/avatar.png',
    ),
    _Msg.system(
      id: 902,
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 32)),
      systemText: formatInvitedSingle(inviter: '홍원준', invitee: '안지원'),
    ),
    _Msg(
      id: 4,
      me: false,
      type: _MsgType.text,
      text: '디자인 시안 올렸습니다.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      readCount: 1,
      nickname: '디자이너A',
      photoUrl: 'https://example.com/avatar.png',
    ),
    _Msg(
      id: 6,
      me: true,
      type: _MsgType.file,
      fileLocal: '/tmp/mock.pdf',
      fileName: '요구사항정의서.pdf',
      fileBytes: 1_024_000,
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      readCount: 0,
      nickname: '나',
      sendStatus: _SendStatus.sending,
    ),
    _Msg(
      id: 7,
      me: true,
      type: _MsgType.image,
      imageLocal: '/tmp/preview.png',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      readCount: 0,
      nickname: '나',
      sendStatus: _SendStatus.sent,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 방 생성 직후 “초대했습니다” 시스템 메시지(목업)
    if (widget.invitedNamesOnCreate != null && widget.invitedNamesOnCreate!.isNotEmpty) {
      final up = context.read<UserProvider>();
      final who = up.nickname.isNotEmpty ? up.nickname : '관리자';
      final list = widget.invitedNamesOnCreate!.join(', ');
      _messages.insert(
        0,
        _Msg.system(
          id: 8000 + DateTime.now().millisecondsSinceEpoch % 1000,
          createdAt: DateTime.now(),
          systemText: '$who님이 $list님을 초대했습니다.',
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom({bool animate = false}) {
    if (!_scroll.hasClients) return;
    final dest = _scroll.position.minScrollExtent; // reverse:true일 때 min이 바닥
    if (animate) {
      _scroll.animateTo(dest, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(dest);
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

  void _openMemberSheetFromMsg(_Msg m, UserProvider up) {
    final isAdmin = up.isAdmin;
    final isSelf = m.me;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MemberProfileSheet(
        nickname: m.nickname ?? (m.me ? up.nickname : '사용자'),
        photoUrl: m.photoUrl,
        role: m.me ? _currentRoleLabel(up) : '멘티',
        isAdmin: isAdmin,
        isSelf: isSelf,
        onViewProfile: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 보기 (구현 예정)')));
        },
        onOpenDM: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1:1 대화 (구현 예정)')));
        },
        onKick: () async {
          await Future.delayed(const Duration(milliseconds: 250));
          return true;
        },
      ),
    );
  }

  void _appendMockText(String text) {
    setState(() {
      _messages.add(
        _Msg(
          id: _messages.last.id + 1,
          me: true,
          type: _MsgType.text,
          text: text,
          createdAt: DateTime.now(),
          readCount: 0,
          nickname: '나',
          sendStatus: _SendStatus.sending,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  void _appendMockImage(String localPath) {
    setState(() {
      _messages.add(
        _Msg(
          id: _messages.last.id + 1,
          me: true,
          type: _MsgType.image,
          imageLocal: localPath,
          createdAt: DateTime.now(),
          readCount: 0,
          nickname: '나',
          sendStatus: _SendStatus.sending,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  void _appendMockFile(String localPath, String name, int bytes) {
    setState(() {
      _messages.add(
        _Msg(
          id: _messages.last.id + 1,
          me: true,
          type: _MsgType.file,
          fileLocal: localPath,
          fileName: name,
          fileBytes: bytes,
          createdAt: DateTime.now(),
          readCount: 0,
          nickname: '나',
          sendStatus: _SendStatus.sending,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  // ===== 공지 등록/삭제(간단 시트) =====
  Future<void> _onLongPressMessage(BuildContext ctx, _Msg m, {required bool isAdmin}) async {
    final action = await showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
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
                  onTap: () => Navigator.pop(ctx, 'notice'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('삭제'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == 'delete') {
      _confirmDelete(ctx, m);
      return;
    }
    if (action == 'notice' && isAdmin) {
      setState(() {
        _pinned = _PinnedNotice(
          msgId: m.id,
          title: _buildNoticeTitleFromMessage(m),
          body:  _buildNoticeBodyFromMessage(m),
          createdAt: m.createdAt,
          author: m.nickname ?? '사용자',
        );
        _noticeExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공지로 등록했습니다.')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, _Msg m) async {
    final ok = await confirmDeleteMessage(context);
    if (!ok) return;
    setState(() {
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx >= 0) _messages[idx] = _messages[idx].copyAsDeleted();
      if (_pinned?.msgId == m.id) _pinned = null;
    });
  }

  String _buildNoticeTitleFromMessage(_Msg m) {
    if (m.type == _MsgType.text && (m.text ?? '').trim().isNotEmpty) {
      final firstLine = m.text!.split('\n').first.trim();
      return firstLine.length > 30 ? '${firstLine.substring(0, 30)}…' : firstLine;
    }
    if (m.type == _MsgType.file) return m.fileName ?? '파일 공지';
    if (m.type == _MsgType.image) return '이미지 공지';
    return '공지';
  }

  String _buildNoticeBodyFromMessage(_Msg m) {
    if (m.type == _MsgType.text) return m.text ?? '';
    if (m.type == _MsgType.file) return '${m.fileName ?? '파일'} • ${(m.fileBytes ?? 0) ~/ 1024}KB';
    if (m.type == _MsgType.image) return '이미지 1장';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final isAdmin = user.isAdmin;
    final items = _buildItemsWithSeparators(_messages);

    return Scaffold(
      resizeToAvoidBottomInset: true, // 키보드 뜨면 body(=Column) 높이 자동 조절
      appBar: AppBar(
        title: Text(
          widget.roomName,
          style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              final myRole = _currentRoleLabel(user);
              final members = _messages
                  .where((m) => !m.isSystem)
                  .map((m) => RoomMemberBrief(
                userId: m.me ? (user.current?.userId ?? 'me') : 'u${m.id}',
                nickname: m.nickname ?? (m.me ? user.nickname : '사용자'),
                role: m.me ? myRole : '멘티',
                photoUrl: m.photoUrl,
              ))
                  .toSet()
                  .toList();

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatRoomInfoPage(
                    roomId: widget.roomId,
                    roomName: widget.roomName,
                    isAdmin: isAdmin,
                    members: members,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,

      // ===== 핵심: Column(리스트+입력바) 위에 공지 오버레이를 Stack으로 얹기 =====
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _inputKey.currentState?.closeExtraPanel();
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // 본체: 리스트 + 입력바 (추가 패딩/보정 없음)
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true, // 바닥 앵커
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      // reverse:true 구조에 맞춰 역인덱싱
                      final it = items[items.length - 1 - index];

                      if (it.kind == _RowKind.separator && it.day != null) {
                        return ChatDaySeparator(day: it.day!);
                      }
                      if (it.kind == _RowKind.system && it.msg != null) {
                        return SystemEventChip(text: it.msg!.systemText ?? '');
                      }

                      final m = it.msg!;
                      final isMe = m.me;

                      // 롱프레스: 관리자일 때 공지/삭제, 일반은 삭제만(모달에서 분기)
                      void _onLong() => _onLongPressMessage(context, m, isAdmin: isAdmin);

                      Widget bubbleRow;
                      if (m.deleted) {
                        bubbleRow = MessageBubble(
                          isMe: isMe,
                          text: '관리자에 의해 삭제됨',
                          createdAt: m.createdAt,
                          readCount: m.readCount,
                          onLongPressDelete: _onLong,
                        );
                      } else {
                        switch (m.type!) {
                          case _MsgType.text:
                            bubbleRow = MessageBubble(
                              isMe: isMe,
                              text: m.text ?? '',
                              createdAt: m.createdAt,
                              readCount: m.readCount,
                              onLongPressDelete: _onLong,
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
                              onLongPressDelete: _onLong,
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
                              onTapOpen: () {},
                              onLongPressDelete: _onLong,
                            );
                            break;
                        }
                      }

                      if (!isMe) {
                        return IncomingMessageTile(
                          nickname: m.nickname ?? '사용자',
                          photoUrl: m.photoUrl,
                          childRow: bubbleRow,
                          onTapAvatar: () => _openMemberSheetFromMsg(m, user),
                        );
                      }
                      return bubbleRow;
                    },
                  ),
                ),
                // 입력바 (SafeArea 내부)
                MessageInputBar(
                  key: _inputKey,
                  onSendText: _appendMockText,
                  onSendImageLocalPath: _appendMockImage,
                  onSendFileLocalPath: _appendMockFile,
                ),
              ],
            ),

            // 상단 공지 오버레이 (레이아웃에 영향 없음, 가려지더라도 단순성 유지)
            if (_pinned != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
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

// ===== 내부 모델 =====
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

  _Msg copyAsDeleted() => _Msg(
    id: id,
    me: me,
    type: type,
    text: '관리자에 의해 삭제됨',
    createdAt: createdAt,
    deleted: true,
    readCount: readCount,
    nickname: nickname,
    photoUrl: photoUrl,
    imageUrl: imageUrl,
    imageLocal: imageLocal,
    fileUrl: fileUrl,
    fileLocal: fileLocal,
    fileName: fileName,
    fileBytes: fileBytes,
    isSystem: isSystem,
    systemText: systemText,
    sendStatus: sendStatus,
  );

  _Msg copyWith({_SendStatus? sendStatus}) => _Msg(
    id: id,
    me: me,
    type: type,
    text: text,
    imageUrl: imageUrl,
    imageLocal: imageLocal,
    fileUrl: fileUrl,
    fileLocal: fileLocal,
    fileName: fileName,
    fileBytes: fileBytes,
    createdAt: createdAt,
    deleted: deleted,
    readCount: readCount,
    nickname: nickname,
    photoUrl: photoUrl,
    isSystem: isSystem,
    systemText: systemText,
    sendStatus: sendStatus ?? this.sendStatus,
  );
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

// ===== 공지 모델 & 위젯 =====
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

  const _NoticeBanner({
    Key? key,
    required this.data,
    required this.expanded,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.onToggle,
    required this.onOpenDetail,
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
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenDetail,
            child: Column(
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_outlined, color: UiTokens.title),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(date, style: const TextStyle(fontWeight: FontWeight.w800, color: UiTokens.title)),
                            const SizedBox(height: 2),
                            Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: UiTokens.title),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                        onPressed: onToggle,
                      ),
                    ],
                  ),
                ),
                // 본문(펼침 시)
                if (expanded)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            data.body.isEmpty ? '(내용 없음)' : data.body,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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

// ===== 헬퍼 위젯 =====
String formatRoomCreated({required String creator}) => '$creator님이 대화방을 생성했습니다.';
String formatInvitedSingle({required String inviter, required String invitee}) =>
    '$inviter님이 $invitee님을 초대했습니다.';
String formatInvitedMany({required String inviter, required List<String> invitees}) {
  final list = invitees.map((e) => '$e님').join(', ');
  return '$inviter님이 $list을 초대했습니다.';
}

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
