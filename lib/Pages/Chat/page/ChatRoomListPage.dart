// lib/Pages/Chat/ChatRoomListPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/page/ChatRoomPage.dart';
import 'package:nail/Pages/Chat/widgets/CreateChatRoomModal.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';

class ChatRoomListPage extends StatefulWidget {
  const ChatRoomListPage({Key? key}) : super(key: key);

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  // ✅ 목업 데이터 (서버 연결 전)
  List<_RoomItem> rooms = [
    _RoomItem(id: 'r1', name: '공지방', lastMessage: '내일 10시 전체회의입니다.', unread: 3, updatedAt: DateTime.now().subtract(const Duration(minutes: 5))),
    _RoomItem(id: 'r2', name: '디자인방', lastMessage: '새 로고 시안 업로드했어요.', unread: 0, updatedAt: DateTime.now().subtract(const Duration(hours: 2))),
    _RoomItem(id: 'r3', name: '재고방', lastMessage: 'A-23 모델 50개 추가 입고됨', unread: 1, updatedAt: DateTime.now().subtract(const Duration(days: 1))),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final isAdmin = user.isAdmin;

    rooms.sort((a,b)=> b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final created = await showModalBottomSheet<_RoomItem>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => const CreateChatRoomModal(),
                );
                if (created != null) {
                  setState(() {
                    rooms.insert(0, created);
                  });
                }
              },
            ),
        ],
      ),
      backgroundColor: Colors.white,
      body: ListView.separated(
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: UiTokens.cardBorder),
        itemBuilder: (context, index) {
          final r = rooms[index];
          return InkWell(
            onTap: () async {
              // 채팅방 입장 (UI만)
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatRoomPage(roomId: r.id, roomName: r.name)),
              );
              // 복귀 시 읽음/미확인 갱신 등은 서버 연결 단계에서 처리
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _RoomAvatar(name: r.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                  color: UiTokens.title,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _friendlyTime(r.updatedAt),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.lastMessage,
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (r.unread > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: UiTokens.primaryBlue,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [UiTokens.cardShadow],
                                ),
                                child: Text(
                                  r.unread.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              )
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _friendlyTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inMinutes < 1) return '지금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }
}

class _RoomItem {
  final String id;
  final String name;
  final String lastMessage;
  final int unread;
  final DateTime updatedAt;

  _RoomItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.unread,
    required this.updatedAt,
  });

  _RoomItem copyWith({String? name, String? lastMessage, int? unread, DateTime? updatedAt}) {
    return _RoomItem(
      id: id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      unread: unread ?? this.unread,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  final String name;
  const _RoomAvatar({required this.name});
  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
        border: Border.all(color: UiTokens.cardBorder),
        boxShadow: const [UiTokens.cardShadow],
      ),
      alignment: Alignment.center,
      child: Text(initials, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
    );
  }
}
