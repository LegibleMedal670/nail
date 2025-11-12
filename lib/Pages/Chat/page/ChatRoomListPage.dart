// lib/Pages/Chat/ChatRoomListPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Chat/page/ChatRoomPage.dart';
import 'package:nail/Pages/Chat/page/CreateChatRoomPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomListPage extends StatefulWidget {
  const ChatRoomListPage({Key? key}) : super(key: key);

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  final _svc = ChatService.instance;

  List<_RoomItem> _rooms = [];
  bool _loading = false;
  String? _error;

  RealtimeChannel? _rt; // 실시간 채널

  @override
  void initState() {
    super.initState();
    _load();
    _bindRealtime();
  }

  @override
  void dispose() {
    _rt?.unsubscribe();
    super.dispose();
  }

  Future<void> _bindRealtime() async {
    _rt = _svc.subscribeListRefresh(onChanged: () {
      // 실시간 변화가 있으면 목록 재조회
      _load();
    });
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>();
    final loginKey = user.current!.loginKey; // UserProvider에 맞춰 사용

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _svc.listRooms(loginKey: loginKey);
      final mapped = rows.map<_RoomItem>((m) {
        final id = (m['room_id'] ?? '').toString();
        final name = (m['name'] ?? '').toString();
        final lastText = (m['last_text'] ?? '').toString();
        final unread = int.tryParse((m['unread'] ?? '0').toString()) ?? 0;

        // last_at이 null일 수 있으므로 updatedAt은 last_at fallback now
        DateTime updatedAt;
        final lastAtRaw = m['last_at'];
        if (lastAtRaw is String && lastAtRaw.isNotEmpty) {
          updatedAt = DateTime.tryParse(lastAtRaw) ?? DateTime.now();
        } else if (lastAtRaw is DateTime) {
          updatedAt = lastAtRaw;
        } else {
          updatedAt = DateTime.now();
        }

        return _RoomItem(
          id: id,
          name: name,
          lastMessage: lastText,
          unread: unread,
          updatedAt: updatedAt,
        );
      }).toList();

      // 최신순 정렬(서버가 이미 정렬하지만 방어로 한 번 더)
      mapped.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      setState(() {
        _rooms = mapped;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final isAdmin = user.isAdmin;

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
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateChatRoomPage()),
                );
                // 방 생성 후 목록 갱신
                await _load();
              },
            ),
        ],
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          Center(child: Text('오류: $_error', style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('다시 시도'),
            ),
          ),
        ],
      );
    }
    if (_rooms.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 48),
          Center(child: Text('참여 중인 채팅방이 없습니다.', style: TextStyle(color: Colors.black54))),
        ],
      );
    }

    return ListView.separated(
      itemCount: _rooms.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: UiTokens.cardBorder),
      itemBuilder: (context, index) {
        final r = _rooms[index];
        return InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatRoomPage(roomId: r.id, roomName: r.name)),
            );
            await _load(); // 복귀 후 갱신(읽음 수 반영)
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
                              r.lastMessage.isEmpty ? '메시지가 없습니다' : r.lastMessage,
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
