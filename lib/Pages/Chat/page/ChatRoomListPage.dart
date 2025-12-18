// lib/Pages/Chat/ChatRoomListPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Chat/page/ChatRoomPage.dart';
import 'package:nail/Pages/Chat/page/CreateChatRoomPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Services/SupabaseService.dart';

class ChatRoomListPage extends StatefulWidget {
  final bool embedded; // ManagerMainPage 내 탭으로 포함 시 true → AppBar 없이 body만
  final int externalReloadToken; // 부모에서 증가시켜 강제 갱신 트리거
  const ChatRoomListPage({Key? key, this.embedded = false, this.externalReloadToken = 0}) : super(key: key);

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  final _svc = ChatService.instance;

  List<_RoomItem> _rooms = [];
  bool _loading = false;
  String? _error;
  final Map<String, int> _memberCounts = {}; // roomId -> count
  final Map<String, String> _displayNames = {}; // roomId -> computed joined names (when name is empty)

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

  @override
  void didUpdateWidget(covariant ChatRoomListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalReloadToken != widget.externalReloadToken) {
      _load();
    }
  }

  Future<void> _bindRealtime() async {
    // 구독 전에 매핑 보장
    final up = context.read<UserProvider>();
    if (up.isAdmin) {
      try {
        await SupabaseService.instance.ensureAdminSessionLinked();
      } catch (_) {
        // ignore
      }
    } else {
      final k = up.current?.loginKey ?? '';
      if (k.isNotEmpty) {
        try {
          await SupabaseService.instance.loginWithKey(k);
        } catch (_) {
          // ignore
        }
      }
    }
    _rt = _svc.subscribeListRefresh(onChanged: () {
      // 실시간 변화가 있으면 목록 재조회
      _load();
    });
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>();
    final loginKey = user.isAdmin ? user.adminKey! : user.current!.loginKey ; // UserProvider에 맞춰 사용

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
        final lastKind = (m['last_kind'] ?? '').toString();
        final unread = int.tryParse((m['unread'] ?? '0').toString()) ?? 0;

        // last_at 파싱 (서버에서 COALESCE로 항상 값이 내려옴)
        DateTime updatedAt;
        final lastAtRaw = m['last_at'];
        if (lastAtRaw is String && lastAtRaw.isNotEmpty) {
          updatedAt = DateTime.tryParse(lastAtRaw) ?? DateTime(2000, 1, 1);
        } else if (lastAtRaw is DateTime) {
          updatedAt = lastAtRaw;
        } else {
          // 서버에서 항상 값이 오지만, 만약의 경우 과거 날짜로 폴백 (최하단으로)
          updatedAt = DateTime(2000, 1, 1);
        }

        return _RoomItem(
          id: id,
          name: name,
          lastMessage: lastText,
          lastKind: lastKind,
          unread: unread,
          updatedAt: updatedAt,
        );
      }).toList();

      // 서버에서 이미 정렬해서 내려주므로 클라이언트 재정렬 제거
      // (서버 정렬 순서 그대로 사용)

      setState(() {
        _rooms = mapped;
      });
      // 사후 비동기: 각 방 멤버 수 로드(캐시)
      for (final r in mapped) {
        _ensureMemberCount(loginKey, r.id);
      }
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

  Future<int?> _ensureMemberCount(String loginKey, String roomId) async {
    if (_memberCounts.containsKey(roomId)) return _memberCounts[roomId];
    try {
      final rows = await _svc.listRoomMembers(loginKey: loginKey, roomId: roomId);
      final cnt = rows.length;
      // 이름 비어있는 방이면 멤버 닉네임을 조합해 표시용 이름 계산
      final room = _rooms.firstWhere((e) => e.id == roomId, orElse: () => _RoomItem(id: roomId, name: '', lastMessage: '', unread: 0, updatedAt: DateTime.now()));
      if ((room.name.trim().isEmpty) && rows.isNotEmpty) {
        final names = rows
            .map((r) => (r['nickname'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort((a, b) => a.compareTo(b));
        final joined = names.join(', ');
        if (joined.isNotEmpty) {
          if (mounted) {
            setState(() {
              _displayNames[roomId] = joined;
            });
          } else {
            _displayNames[roomId] = joined;
          }
        }
      }
      if (mounted) {
        setState(() {
          _memberCounts[roomId] = cnt;
        });
      } else {
        _memberCounts[roomId] = cnt;
      }
      return cnt;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final isAdmin = user.isAdmin;

    final content = RefreshIndicator(onRefresh: _load, child: _buildBody());

    if (widget.embedded) {
      // ManagerMainPage에서 AppBar를 일원화하므로 body만 반환
      return content;
    }

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
                await _load();
              },
            ),
        ],
      ),
      backgroundColor: Colors.white,
      body: content,
    );
  }

  Widget _buildBody() {
    // 멤버 수 조회용 로그인 키(하위 빌더들에서 캡처해 사용)
    final upForCounts = context.read<UserProvider>();
    final String loginKeyForCounts = upForCounts.isAdmin
        ? (upForCounts.adminKey ?? '')
        : (upForCounts.current?.loginKey ?? '');

    if (_loading && _rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {

      print(_error);

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
      separatorBuilder: (_, __) => const Divider(height: 2, thickness: 0.5, color: UiTokens.cardBorder),
      itemBuilder: (context, index) {
        final r = _rooms[index];
        final displayName = (r.name.trim().isNotEmpty) ? r.name : (_displayNames[r.id] ?? r.name);
        return InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatRoomPage(roomId: r.id, roomName: displayName)),
            );
            await _load(); // 복귀 후 갱신(읽음 수 반영)
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _RoomAvatar(name: displayName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: UiTokens.title,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 6),
                                // 멤버 수 배지 (1:1 = 2명인 경우는 표시 안 함)
                                Builder(
                                  builder: (_) {
                                    final cnt = _memberCounts[r.id];
                                    if (cnt == null) {
                                      // 로딩 트리거 (최초 1회)
                                      if (loginKeyForCounts.isNotEmpty) {
                                        _ensureMemberCount(loginKeyForCounts, r.id);
                                      }
                                      return const SizedBox.shrink();
                                    }
                                    if (cnt <= 2) return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$cnt',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: UiTokens.title),
                                      ),
                                    );
                                  },
                                ),
                              ],
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
                              r.previewText,
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
  final String lastKind; // 'text' | 'image' | 'file' | ''
  final int unread;
  final DateTime updatedAt;

  _RoomItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    this.lastKind = '',
    required this.unread,
    required this.updatedAt,
  });

  _RoomItem copyWith({String? name, String? lastMessage, int? unread, DateTime? updatedAt}) {
    return _RoomItem(
      id: id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastKind: lastKind,
      unread: unread ?? this.unread,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get previewText {
    final k = (lastKind).toLowerCase();
    if (k == 'image') return '사진';
    if (k == 'file') return '파일';
    return lastMessage.isEmpty ? '메시지가 없습니다' : lastMessage;
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
