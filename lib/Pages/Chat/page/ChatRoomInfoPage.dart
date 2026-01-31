import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/models/RoomMemberBrief.dart';
import 'package:nail/Pages/Chat/page/FilesListPage.dart';
import 'package:nail/Pages/Chat/page/MediaGridPage.dart';
import 'package:nail/Pages/Chat/page/NoticeListPage.dart';
import 'package:nail/Pages/Chat/page/ChatRoomPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Chat/widgets/MemberProfileSheet.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/ChatService.dart';
import 'package:provider/provider.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/AdminMenteeService.dart';
import 'package:nail/Pages/Manager/page/MentorDetailPage.dart';
import 'package:nail/Pages/Manager/page/MenteeDetailPage.dart';
import 'package:nail/Pages/Manager/models/mentor.dart' as legacy;
import 'package:nail/Pages/Manager/models/Mentee.dart' as mgr;

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
  String? _roomName; // 로컬표시용

  @override
  void initState() {
    super.initState();
    _liveMembers = [...widget.members];
    _roomName = widget.roomName;
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
        role: _roleKo(
          ((r['is_admin'] == true)
              ? 'admin'
              : (r['is_mentor'] == true) ? 'mentor' : 'mentee'),
        ),
        photoUrl: (r['photo_url'] ?? '').toString().isEmpty ? null : (r['photo_url'] as String),
      )).toList();
    });
  }

  String _roleKo(String role) {
    switch (role) {
      case 'admin': return '관리자';
      case 'mentor': return '선임';
      default: return '후임';
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
              tooltip: '방 이름 변경',
              icon: const Icon(Icons.edit, color: Colors.black87),
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
              tooltip: '메시지 전체 삭제',
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: _confirmClearRoomMessages,
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
          _GroupHeader(roomName: _roomName ?? widget.roomName), // ← 변경: 이니셜 배지
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
    final ctrl = TextEditingController(text: _roomName ?? widget.roomName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.edit_note_rounded, color: UiTokens.title),
                  SizedBox(width: 8),
                  Text('방 이름 변경', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: UiTokens.title)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '새 방 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final newName = ctrl.text.trim();
                        if (newName.isEmpty) return;
                        try {
                          final up = context.read<UserProvider>();
                          final adminKey = up.adminKey?.trim() ?? '';
                          if (adminKey.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 인증 정보가 없습니다.')));
                            return;
                          }
                          await _svc.renameRoom(adminLoginKey: adminKey, roomId: widget.roomId, name: newName);
                          if (!mounted) return;
                          setState(() => _roomName = newName);
                          Navigator.pop(ctx);           // close sheet
                          Navigator.pop(context, newName); // close Info and return name
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('변경', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _inviteMembers() {
    _openInviteSheet();
  }

  void _confirmDeleteRoom() async {
    final ok = await confirmDeleteRoom(context, widget.roomName);
    if (ok == true) {
      try {
        final up = context.read<UserProvider>();
        final adminKey = up.adminKey?.trim() ?? '';
        if (adminKey.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 인증 정보가 없습니다.')));
          return;
        }
        await _svc.deleteRoom(adminLoginKey: adminKey, roomId: widget.roomId);
        if (!mounted) return;
        // Info → pop, ChatRoomPage → pop → 목록으로
        Navigator.of(context).pop(); // close Info
        Navigator.of(context).pop(); // close ChatRoomPage → back to list
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('방 삭제 실패: $e')));
      }
    }
  }

  Future<void> _confirmClearRoomMessages() async {
    final ok = await showConfirmDialog(
      context,
      title: '메시지를 모두 삭제할까요?',
      message: '방은 유지되고 메시지 기록만 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '전체 삭제',
      isDanger: true,
      icon: Icons.delete_sweep_rounded,
    );
    if (!ok) return;
    try {
      final up = context.read<UserProvider>();
      final adminKey = up.adminKey?.trim() ?? '';
      if (adminKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 인증 정보가 없습니다.')));
        return;
      }
      await _svc.clearRoomMessages(adminLoginKey: adminKey, roomId: widget.roomId);
      if (!mounted) return;
      // Info → pop 해서 ChatRoomPage로 복귀 + 결과 전달
      Navigator.of(context).pop('__cleared__');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('메시지 전체 삭제 실패: $e')));
    }
  }

  Future<void> _startDM(String userId, String nickname) async {
    try {
      final up = context.read<UserProvider>();
      final key = up.isAdmin ? (up.adminKey ?? '') : (up.current?.loginKey ?? '');
      if (key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }
      final roomId = await _svc.getOrCreateDM(loginKey: key, targetUserId: userId);
      if (!mounted) return;
      // 프로필 시트 닫기
      Navigator.of(context).pop();
      // DM으로 이동(스택을 목록 페이지만 남김)
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(roomId: roomId, roomName: nickname),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      print(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('1:1 대화 시작 실패: $e')));
    }
  }

  void _openProfileSheet(RoomMemberBrief m) {
    final isSelf = m.userId == (context.read<UserProvider>().current?.userId ?? '');
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
        onViewProfile: () async {
          if (!widget.isAdmin) return;
          try {
            // 역할 문자열로 분기: '선임' | '후임'
            if (m.role == '선임') {
              final list = await SupabaseService.instance.adminListMentors();
              final row = list.firstWhere(
                (e) => (e['id'] ?? '').toString() == m.userId,
                orElse: () => <String, dynamic>{},
              );
              final nickname = (row['nickname'] ?? m.nickname).toString();
              final joined = row['joined_at'];
              final joinedAt = joined is DateTime
                  ? joined.toLocal()
                  : DateTime.tryParse((joined ?? '').toString())?.toLocal() ?? DateTime.now();
              final photoUrl = (row['photo_url'] ?? m.photoUrl)?.toString();
              final loginKey = (row['login_key'] ?? '').toString();
              final mentor = legacy.Mentor(
                id: m.userId,
                name: nickname,
                hiredAt: joinedAt,
                menteeCount: 0,
                photoUrl: (photoUrl?.isEmpty == true) ? null : photoUrl,
                accessCode: loginKey,
              );
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MentorDetailPage(mentor: mentor)));
              return;
            } else {
              // 후임: 메트릭 목록에서 id 매칭(관리자용 RPC)
              final metrics = await AdminMenteeService.instance.listMenteesMetrics();
              final row = metrics.firstWhere(
                (e) => (e['id'] ?? '').toString() == m.userId,
                orElse: () => <String, dynamic>{},
              );
              final nickname = (row['nickname'] ?? m.nickname).toString();
              final joined = row['joined_at'];
              final joinedAt = joined is DateTime
                  ? joined.toLocal()
                  : DateTime.tryParse((joined ?? '').toString())?.toLocal() ?? DateTime.now();
              final photoUrl = (row['photo_url'] ?? m.photoUrl)?.toString();
              final loginKey = (row['login_key'] ?? '').toString();
              final mentee = mgr.Mentee(
                id: m.userId,
                name: nickname,
                startedAt: joinedAt,
                progress: 0.0,
                courseDone: 0,
                courseTotal: 0,
                examDone: 0,
                examTotal: 0,
                photoUrl: (photoUrl?.isEmpty == true) ? null : photoUrl,
                accessCode: loginKey,
              );
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MenteeDetailPage(mentee: mentee)));
              return;
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('프로필 조회 실패: $e')));
          }
        },
        onOpenDM: () => _startDM(m.userId, m.nickname),
        onKick: () async {
          try {
            final ok1 = await confirmKickUser(context, m.nickname);
            if (!ok1) return false;
            final up = context.read<UserProvider>();
            final adminKey = up.adminKey?.trim() ?? '';
            if (adminKey.isEmpty) return false;
            final ok = await _svc.kickMember(
              adminLoginKey: adminKey,
              roomId: widget.roomId,
              memberId: m.userId,
            );
            if (ok) {
              if (!mounted) return true;
              // 시트는 MemberProfileSheet 내부에서 닫음. 여기서는 Info 페이지에서 빠져나가 채팅방으로 복귀
              Navigator.of(context).pop();
            }
            return ok;
          } catch (e) {

            print(e);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('강퇴 실패: $e')));
            }
            return false;
          }
        },
      ),
    );
  }

  Future<void> _openInviteSheet() async {
    final up = context.read<UserProvider>();
    final adminKey = up.adminKey?.trim() ?? '';
    if (adminKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('관리자 인증 정보가 없습니다.')));
      return;
    }
    // 불러오기
    List<_InviteVm> candidates = [];
    try {
      final rows = await _svc.listRoomNonMembers(adminLoginKey: adminKey, roomId: widget.roomId);
      candidates = rows.map((r) => _InviteVm(
        id: (r['user_id'] ?? '').toString(),
        nickname: (r['nickname'] ?? '사용자').toString(),
        photoUrl: (r['photo_url'] ?? '').toString(),
        role: ((r['is_admin'] == true)
            ? 'admin'
            : (r['is_mentor'] == true) ? 'mentor' : 'mentee').toString(),
      )).toList();
    } catch (e) {

      print(e);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('목록 로드 실패: $e')));
      return;
    }
    if (!mounted) return;
    final selected = <String>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 10),
                const Text('멤버 초대', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: UiTokens.title)),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_add_disabled_rounded, size: 40, color: Colors.black38),
                          SizedBox(height: 10),
                          Text('초대할 사용자가 없습니다.', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: candidates.length,
                      itemBuilder: (_, i) {
                        final u = candidates[i];
                        final checked = selected.contains(u.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            if (v == true) {
                              selected.add(u.id);
                            } else {
                              selected.remove(u.id);
                            }
                            (ctx as Element).markNeedsBuild();
                          },
                        title: Row(
                          children: [
                            Expanded(child: Text(u.nickname, style: const TextStyle(fontWeight: FontWeight.w700, color: UiTokens.title))),
                            const SizedBox(width: 8),
                            _RoleBadge(role: _roleKo(u.role)),
                          ],
                        ),
                          secondary: CircleAvatar(
                            backgroundColor: const Color(0xFFE8EDF3),
                            foregroundImage: (u.photoUrl.isNotEmpty) ? NetworkImage(u.photoUrl) : null,
                            child: (u.photoUrl.isEmpty) ? const Icon(Icons.person, size: 16, color: UiTokens.actionIcon) : null,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selected.isEmpty ? null : () async {
                          try {
                            final added = await _svc.inviteMembers(
                              adminLoginKey: adminKey,
                              roomId: widget.roomId,
                              memberIds: selected.toList(),
                            );

                            if (!mounted) return;
                            Navigator.of(ctx).pop(); // close sheet
                            // InfoPage → ChatRoomPage로 이동(또는 뒤로가기)
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              await Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => ChatRoomPage(roomId: widget.roomId, roomName: widget.roomName)),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('초대 실패: $e')));
                            print(e);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: UiTokens.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        child: const Text('초대하기', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
      case '선임':
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

/// 초대 후보 표시용 간단 뷰모델
class _InviteVm {
  final String id;
  final String nickname;
  final String photoUrl;
  final String role;
  const _InviteVm({
    required this.id,
    required this.nickname,
    required this.photoUrl,
    this.role = 'mentee',
  });
}
