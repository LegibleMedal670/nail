import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 채팅용 위험/일반 작업 확인 다이얼로그
/// true = 진행, false/null = 취소
Future<bool> showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String cancelText = '취소',
      String confirmText = '확인',
      bool isDanger = false,          // 방 삭제 등 위험 작업이면 true (빨강)
      IconData? icon,                 // 없으면 isDanger에 따라 기본 아이콘
      bool barrierDismissible = true,
      Color? accentColor,             // 필요 시 포스 색상
    }) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
      isDanger: isDanger,
      icon: icon,
      accentColor: accentColor,
    ),
  );
  return result == true;
}

/// 사용 편의 헬퍼들
Future<bool> confirmDeleteMessage(BuildContext ctx) => showConfirmDialog(
  ctx,
  title: '메시지를 삭제할까요?',
  message: '삭제 후 복구할 수 없습니다.',
  confirmText: '삭제',
  isDanger: true,
  icon: Icons.delete_outline_rounded,
);

Future<bool> confirmKickUser(BuildContext ctx, String nickname) =>
    showConfirmDialog(
      ctx,
      title: '이 사용자를 강퇴할까요?',
      message: '$nickname 님을 대화방에서 내보냅니다.',
      confirmText: '강퇴',
      isDanger: true,
      icon: Icons.person_remove_alt_1_rounded,
    );

Future<bool> confirmDeleteRoom(BuildContext ctx, String roomName) =>
    showConfirmDialog(
      ctx,
      title: '방을 삭제할까요?',
      message: '‘$roomName’의 메시지는 삭제 처리됩니다.',
      confirmText: '방 삭제',
      isDanger: true, // 방 삭제는 항상 빨강 톤
      icon: Icons.delete_forever_rounded,
    );

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool isDanger;
  final IconData? icon;
  final Color? accentColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.cancelText,
    required this.confirmText,
    required this.isDanger,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 스타일: 기본 파랑 / 위험 빨강
    final Color accent =
        accentColor ?? (isDanger ? const Color(0xFFD32F2F) : UiTokens.primaryBlue);
    final Color badgeBg =
    isDanger ? const Color(0xFFFFEBEE) : const Color(0xFFEAF3FF);
    final IconData usedIcon =
        icon ?? (isDanger ? Icons.delete_outline_rounded : Icons.help_outline_rounded);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 아이콘 배지
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
              child: Icon(usedIcon, size: 30, color: accent),
            ),
            const SizedBox(height: 14),

            // 제목
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiTokens.title,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),

            // 메시지
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: UiTokens.title.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: cs.outline.withOpacity(0.4)),
                      backgroundColor: const Color(0xFFF5F7FA),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: UiTokens.title,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent, // 위험 작업이면 빨강
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
