import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MemberProfileSheet extends StatelessWidget {
  final String nickname;
  final String? photoUrl;
  final String role;

  const MemberProfileSheet({
    Key? key,
    required this.nickname,
    required this.photoUrl,
    required this.role,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  foregroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
                  child: (photoUrl == null || photoUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null,
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
            Row(
              children: [
                _ActionChip(icon: Icons.person_pin_circle_outlined, label: '프로필 보기', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                _ActionChip(icon: Icons.chat_bubble_outline_rounded, label: '1:1 대화', onTap: () => Navigator.pop(context)),
              ],
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
