// lib/Pages/Chat/widgets/MemberProfileSheet.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MemberProfileSheet extends StatelessWidget {
  final String nickname;
  final String? photoUrl;
  final String role;

  /// ✅ 추가
  final bool isAdmin;       // 현재 보는 사람이 관리자면 true
  final bool isSelf;        // 본인이면 true → 추방 버튼 숨김
  final VoidCallback? onViewProfile;
  final VoidCallback? onOpenDM;
  final Future<bool> Function()? onKick; // true면 성공

  const MemberProfileSheet({
    Key? key,
    required this.nickname,
    required this.photoUrl,
    required this.role,
    this.isAdmin = false,
    this.isSelf = false,
    this.onViewProfile,
    this.onOpenDM,
    this.onKick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final showActions = isAdmin; // 관리자 액션(1:1, 강퇴)은 관리자만 보임
    final canKick = isAdmin && !isSelf && role != '관리자';
    final showProfile = isAdmin && !isSelf && role != '관리자'; // 관리자 대상은 프로필 버튼 숨김

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  foregroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: UiTokens.title)),
                      const SizedBox(height: 4),
                      Text(role, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 액션 칩: 프로필(관리자 아닌 대상에만), 1:1 대화(관리자이면 항상)
            if (!isSelf && isAdmin) Row(
              children: [
                if (showProfile)
                  _ActionChip(
                    icon: Icons.person_pin_circle_outlined,
                    label: '프로필 보기',
                    onTap: () { Navigator.pop(context); onViewProfile?.call(); },
                  ),
                if (showActions) ...[
                  if (showProfile) const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '1:1 대화',
                    onTap: () { Navigator.pop(context); onOpenDM?.call(); },
                  ),
                ],
              ],
            ),

            if (showActions && !isSelf) const SizedBox(height: 10),

            if (canKick)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: InkWell(
                  onTap: () async {
                    final success = await (onKick?.call() ?? Future.value(false));
                    if (context.mounted) {
                      Navigator.pop(context); // close sheet
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      border: Border.all(color: const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [UiTokens.cardShadow],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_remove_alt_1_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 6),
                        Text('강퇴하기', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: UiTokens.cardBorder),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [UiTokens.cardShadow],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: UiTokens.title),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
