import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/models/RoomMemberBrief.dart';
import 'package:nail/Pages/Chat/page/FilesListPage.dart';
import 'package:nail/Pages/Chat/page/MediaGridPage.dart';
import 'package:nail/Pages/Chat/page/NoticeListPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Chat/widgets/MemberProfileSheet.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:provider/provider.dart';

class ChatRoomInfoPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool isAdmin;
  final List<RoomMemberBrief> members;

  const ChatRoomInfoPage({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.isAdmin,
    required this.members,
  }) : super(key: key);

  @override
  State<ChatRoomInfoPage> createState() => _ChatRoomInfoPageState();
}

class _ChatRoomInfoPageState extends State<ChatRoomInfoPage> {
  // 포인트 컬러(타일 아이콘에 사용)
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);

  final _svc = ChatService.instance;
  List<RoomMemberBrief> _liveMembers = [];

  @override
  void initState() {
    super.initState();
    _liveMembers = [...widget.members];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    final up = context.read<UserProvider>();
    final key = up.isAdmin ? (up.adminKey ?? '') : (up.current?.loginKey ?? '');
    if (key.isEmpty) return;
    final rows = await _svc.listRoomMembers(loginKey: key, roomId: widget.roomId);
    setState(() {
      _liveMembers = rows.map((r) => RoomMemberBrief(
        userId: (r['user_id'] ?? '').toString(),
        nickname: (r['nickname'] ?? '사용자').toString(),
        role: _roleKo((r['role'] ?? '').toString()),
        photoUrl: (r['photo_url'] ?? '').toString().isEmpty ? null : (r['photo_url'] as String),
      )).toList();
    });
  }

  String _roleKo(String role) {
    switch (role) {
      case 'admin': return '관리자';
      case 'mentor': return '멘토';
      default: return '멘티';
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = [..._liveMembers]..sort((a,b)=>a.nickname.compareTo(b.nickname));
    final memberCount = members.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4), // 배경 244,244,244
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F4),
        elevation: 0,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          if (widget.isAdmin)
            IconButton(
              tooltip: '관리자 설정',
              icon: const Icon(Icons.settings_outlined, color: Colors.black87),
              onPressed: _openAdminSettings,
            ),
          if (widget.isAdmin)
            IconButton(
              tooltip: '멤버 초대',
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black87),
              onPressed: _inviteMembers,
            ),
          if (widget.isAdmin)
            IconButton(
              tooltip: '방 삭제',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _confirmDeleteRoom,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 16),
          _GroupHeader(roomName: widget.roomName), // ← 변경: 이니셜 배지
          const SizedBox(height: 16),

          // 액션 카드
          _SectionCard(
            child: Column(
              children: [
                _Tile(
                  leading: Icons.photo_library_outlined,
                  accent: _green,
                  title: '사진/동영상',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MediaGridPage(roomId: widget.roomId)),
                  ),
                ),
                const _DividerInset(),
                _Tile(
                  leading: Icons.insert_drive_file_outlined,
                  accent: UiTokens.primaryBlue,
                  title: '파일',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FilesListPage(roomId: widget.roomId)),
                  ),
                ),
                const _DividerInset(),
                _Tile(
                  leading: Icons.campaign_outlined,
                  accent: _amber,
                  title: '공지 모아보기',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoticeListPage(roomId: widget.roomId)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 멤버 섹션 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                const Text('대화상대',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: UiTokens.title)),
                const Spacer(),
                Text(
                  '$memberCount',
                  style: const TextStyle(color: UiTokens.primaryBlue, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 멤버 리스트
          _SectionCard(
            child: Column(
              children: [
                for (int i = 0; i < members.length; i++) ...[
                  _MemberTile(member: members[i], onTap: () => _openProfileSheet(members[i])),
                  if (i != members.length - 1) const _DividerInset(),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAdminSettings() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('관리자 설정 페이지 (구현 예정)')));
  }

  void _inviteMembers() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('멤버 초대 (구현 예정)')));
  }

  void _confirmDeleteRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('채팅방 삭제'),
        content: const Text('채팅방을 삭제하시겠어요? 메시지는 소프트 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      Navigator.of(context).pop();
    }
  }

  void _openProfileSheet(RoomMemberBrief m) {
    final isSelf = m.userId == 'me'; // 본인 체크 규칙에 맞게 수정
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MemberProfileSheet(
        nickname: m.nickname,
        photoUrl: m.photoUrl,
        role: m.role,
        isAdmin: widget.isAdmin,   // ✅ 관리자만 액션 보이기
        isSelf: isSelf,            // ✅ 본인이면 추방 숨김
        onViewProfile: () {
          // TODO: 프로필 페이지로 이동
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 보기 (구현 예정)')));
        },
        onOpenDM: () {
          // TODO: 1:1 대화방 열기
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1:1 대화 (구현 예정)')));
        },
        onKick: () async {
          // TODO: 실제 추방 API 연결
          await Future.delayed(const Duration(milliseconds: 300));
          // 성공/실패 반환
          return true;
        },
      ),
    );
  }
}

// ===== 아래는 보조 위젯들 =====

class _GroupHeader extends StatelessWidget {
  final String roomName;
  const _GroupHeader({required this.roomName});

  String _firstGrapheme(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    // 합성 문자까지 1글자 안전 추출
    return trimmed.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final initial = _firstGrapheme(roomName);

    return Column(
      children: [
        // 이니셜 원형 배지
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF6F7F9), // 아주 옅은 회색
            border: Border.all(color: const Color(0xFFE1E6ED)), // 연한 외곽선
            boxShadow: const [UiTokens.cardShadow],
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: UiTokens.title,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          roomName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: UiTokens.title),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [UiTokens.cardShadow],
      ),
      child: child,
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData leading;
  final String title;
  final VoidCallback onTap;
  final Color accent;

  const _Tile({
    required this.leading,
    required this.title,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Icon(leading, color: accent, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: UiTokens.title)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
      dense: true,
    );
  }
}

class _DividerInset extends StatelessWidget {
  const _DividerInset();
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: UiTokens.cardBorder,
    );
  }
}

class _MemberTile extends StatelessWidget {
  final RoomMemberBrief member;
  final VoidCallback onTap;
  const _MemberTile({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Avatar(photoUrl: member.photoUrl),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member.nickname,
              style: const TextStyle(fontWeight: FontWeight.w700, color: UiTokens.title),
            ),
          ),
          const SizedBox(width: 8),
          _RoleBadge(role: member.role),
        ],
      ),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (role) {
      case '관리자':
        bg = const Color(0xFFE8F0FF);
        break;
      case '멘토':
        bg = const Color(0xFFEAF7EE);
        break;
      default:
        bg = const Color(0xFFF4F4F6);
    }
    const color = Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  const _Avatar({this.photoUrl, this.size = 32});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE8EDF3),
      foregroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? const Icon(Icons.person, size: 16, color: UiTokens.actionIcon)
          : null,
    );
  }
}
