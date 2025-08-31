import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';

/// 변경사항 폐기(나가기) 확인을 위한 공용 다이얼로그.
/// true = 나가기, false/null = 머무르기
Future<bool> showDiscardChangesDialog(
    BuildContext context, {
      String title = '변경사항을 저장하지 않고 나갈까요?',
      String message = '저장하지 않은 변경사항이 사라집니다.',
      String stayText = '계속 작성',
      String leaveText = '나가기',
      bool barrierDismissible = true,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _DiscardConfirmDialog(
      title: title,
      message: message,
      stayText: stayText,
      leaveText: leaveText,
    ),
  );
  return result == true;
}

class _DiscardConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String stayText;
  final String leaveText;

  const _DiscardConfirmDialog({
    required this.title,
    required this.message,
    required this.stayText,
    required this.leaveText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline_rounded,
                  size: 30, color: UiTokens.primaryBlue),
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
                      backgroundColor: Colors.grey[200]
                    ),
                    child: Text(
                      stayText,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: UiTokens.title),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
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
