import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 공용 확인 다이얼로그
/// true = 진행(나가기/삭제 등), false/null = 취소/머무르기
Future<bool> showDiscardChangesDialog(
    BuildContext context, {
      String title = '변경사항을 저장하지 않고 나갈까요?',
      String message = '저장하지 않은 변경사항이 사라집니다.',
      String stayText = '계속 작성',
      String leaveText = '나가기',
      bool barrierDismissible = true,

      /// ↓ 추가 옵션: 삭제/위험 작업용 스타일
      bool isDanger = false,
      IconData? icon,
      Color? accentColor,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _DiscardConfirmDialog(
      title: title,
      message: message,
      stayText: stayText,
      leaveText: leaveText,
      isDanger: isDanger,
      icon: icon,
      accentColor: accentColor,
    ),
  );
  return result == true;
}

class _DiscardConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String stayText;
  final String leaveText;

  /// ↓ 추가 필드
  final bool isDanger;
  final IconData? icon;
  final Color? accentColor;

  const _DiscardConfirmDialog({
    required this.title,
    required this.message,
    required this.stayText,
    required this.leaveText,
    this.isDanger = false,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 스타일 분기: 기본 파랑 / 위험 빨강
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

            // 액션 버튼들
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
                    child: Text(
                      stayText,
                      style: const TextStyle(
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
                      leaveText,
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
