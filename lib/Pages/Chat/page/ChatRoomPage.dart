// lib/Pages/Chat/ChatRoomPage.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'package:nail/Pages/Common/ui_tokens.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatRoomPage({Key? key, required this.roomId, required this.roomName})
    : super(key: key);

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<MessageInputBarState> _inputKey =
      GlobalKey<MessageInputBarState>();

  static const double _kInputBarHeight = 68;

  final List<_Msg> _messages = [
    // 그제: 방 생성
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

    // 어제: 여러 명 초대
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
      imageUrl: null, // 로컬 미리보기만 있는 케이스 등 테스트용
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4, minutes: 35)),
      readCount: 1,
      nickname: '디자이너A',
      photoUrl: 'https://example.com/avatar.png',
    ),

    // 오늘: 단건 초대 + 실패/재전송 시나리오
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
      sendStatus: _SendStatus.sending, // ⬅️ 전송 중 케이스
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
    // 첫 프레임 이후 최신으로 점프
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom({bool animate = false}) {
    if (!_scroll.hasClients) return;
    final dest = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(dest, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(dest);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<String> _collectImageSources() {
    final list = <String>[];
    for (final m in _messages) {
      if (m.type == _MsgType.image && !m.deleted) {
        final src = m.imageUrl ?? m.imageLocal;
        if (src != null && src.isNotEmpty) list.add(src);
      }
    }
    return list;
  }

  int _indexOfImageMsg(_Msg target) {
    int idx = 0;
    for (final m in _messages) {
      if (m.type == _MsgType.image && !m.deleted) {
        final same = m.id == target.id;
        if (same) return idx;
        idx++;
      }
    }
    return 0;
  }

  void _openImageFullscreen(_Msg imageMsg) {
    final src = imageMsg.imageUrl ?? imageMsg.imageLocal;
    if (src == null || src.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        barrierColor: Colors.black,
        opaque: false,
        pageBuilder: (_, __, ___) => ChatImageViewer(
          images: [src],     // ✅ 단건만 전달
          initialIndex: 0,
          heroTagPrefix: 'chat_img_', // 버블과 맞춤
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
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
    // 새 메시지 → 살짝 늦춰 최신으로
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
    // 새 메시지 → 살짝 늦춰 최신으로
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
    // 새 메시지 → 살짝 늦춰 최신으로
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  @override
  Widget build(BuildContext context) {
    // 메시지를 일자 기준으로 그룹화하며 DaySeparator 삽입
    final items = _buildItemsWithSeparators(_messages);

    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double listBottomPadding = _kInputBarHeight + bottomSafe + 24;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.roomName,
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              final members =
                  _messages
                      .where((m) => !m.isSystem)
                      .map(
                        (m) => RoomMemberBrief(
                          userId: m.me ? 'me' : 'u${m.id}',
                          nickname: m.nickname ?? (m.me ? '나' : '사용자'),
                          role: m.me ? '관리자' : '멘티',
                          photoUrl: m.photoUrl,
                        ),
                      )
                      .toSet()
                      .toList();

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => ChatRoomInfoPage(
                        roomId: widget.roomId,
                        roomName: widget.roomName,
                        isAdmin: true,
                        members: members,
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
            ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(12, 12, 12, listBottomPadding),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];

                // DaySeparator
                if (it.kind == _RowKind.separator && it.day != null) {
                  return ChatDaySeparator(day: it.day!);
                }

                // 시스템 이벤트 칩
                if (it.kind == _RowKind.system && it.msg != null) {
                  return SystemEventChip(text: it.msg!.systemText ?? '');
                }

                // 일반 메시지
                final m = it.msg!;
                final isMe = m.me;

                Widget bubbleRow;
                if (m.deleted) {
                  bubbleRow = MessageBubble(
                    isMe: isMe,
                    text: '관리자에 의해 삭제됨',
                    createdAt: m.createdAt,
                    readCount: m.readCount,
                    onLongPressDelete: () => _confirmDelete(context, m),
                  );
                } else {
                  switch (m.type!) {
                    case _MsgType.text:
                      bubbleRow = MessageBubble(
                        isMe: isMe,
                        text: m.text ?? '',
                        createdAt: m.createdAt,
                        readCount: m.readCount,
                        onLongPressDelete: () => _confirmDelete(context, m),
                      );
                      break;
                    case _MsgType.image:
                      final heroTag = 'chat_img_${m.id}'; // ✅ 메시지 id 기반
                      bubbleRow = ImageBubble(
                        isMe: isMe,
                        imageUrl: m.imageUrl,
                        localPreviewPath: m.imageLocal,
                        createdAt: m.createdAt,
                        readCount: m.readCount,
                        onLongPressDelete: () => _confirmDelete(context, m),
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
                        onLongPressDelete: () => _confirmDelete(context, m),
                      );
                      break;
                  }
                }

                if (!isMe) {
                  return IncomingMessageTile(
                    nickname: m.nickname ?? '사용자',
                    photoUrl: m.photoUrl,
                    childRow: bubbleRow,
                  );
                }
                return bubbleRow;
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: MessageInputBar(
                key: _inputKey,
                onSendText: _appendMockText,
                onSendImageLocalPath: _appendMockImage,
                onSendFileLocalPath: _appendMockFile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 날짜 구분 삽입 로직
  List<_RowItem> _buildItemsWithSeparators(List<_Msg> src) {
    final List<_RowItem> out = [];
    DateTime? lastDay;
    for (final m in src) {
      final day = DateTime(
        m.createdAt.year,
        m.createdAt.month,
        m.createdAt.day,
      );
      if (lastDay == null || day.difference(lastDay!).inDays != 0) {
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

  Future<void> _confirmDelete(BuildContext context, _Msg m) async {
    final ok = await confirmDeleteMessage(context);
    if (ok) {
      setState(() {
        final idx = _messages.indexWhere((x) => x.id == m.id);
        if (idx >= 0) _messages[idx] = _messages[idx].copyAsDeleted();
      });
    }
  }

}

enum _MsgType { text, image, file }

enum _SendStatus { sending, sent }

class _Msg {
  final int id;
  final bool me;
  final _MsgType? type; // 시스템 이벤트면 null
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

  // 서버 컬럼
  final String? nickname; // DB: nickname
  final String? photoUrl; // DB: photo_url

  // 시스템 이벤트
  final bool isSystem;
  final String? systemText;

  // 전송 상태
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
  }) : me = false,
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

  factory _RowItem.separator(DateTime day) =>
      _RowItem._(_RowKind.separator, day: day);

  factory _RowItem.system(_Msg m) => _RowItem._(_RowKind.system, msg: m);

  factory _RowItem.message(_Msg m) => _RowItem._(_RowKind.message, msg: m);
}

String formatRoomCreated({required String creator}) {
  return '$creator님이 대화방을 생성했습니다.';
}

String formatInvitedSingle({required String inviter, required String invitee}) {
  return '$inviter님이 $invitee님을 초대했습니다.';
}

String formatInvitedMany({
  required String inviter,
  required List<String> invitees,
}) {
  // 예: A, B, C, D, E님을 초대했습니다.
  final list = invitees.map((e) => '$e님').join(', ');
  return '$inviter님이 $list을 초대했습니다.';
}

class ChatDaySeparator extends StatelessWidget {
  final DateTime day;
  final Color background; // 살짝 투명한 배경
  final EdgeInsets padding;

  const ChatDaySeparator({
    Key? key,

    required this.day,
    this.background = const Color.fromRGBO(230, 230, 230, 1),
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  }) : super(key: key);

  String _labelKo(DateTime d) {
    // 예: 2025년 11월 7일 금요일
    return DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(d);
  }

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
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: UiTokens.title.withOpacity(0.85),
                ),
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
