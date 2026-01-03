// lib/Pages/Common/widgets/WithdrawDialog.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 회원 탈퇴 확인 다이얼로그
/// 
/// 사용자에게 탈퇴 시 주의사항을 안내하고 확인을 받습니다.
/// 
/// Returns: 사용자가 '탈퇴' 버튼을 눌렀으면 true, 취소했으면 false 또는 null
Future<bool?> showWithdrawConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text(
            '회원 탈퇴',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: UiTokens.title,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '정말로 탈퇴하시겠습니까?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: UiTokens.title,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '탈퇴 시 다음 사항을 확인해주세요:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: UiTokens.title,
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('소속 채팅방에서 자동으로 나가집니다.'),
            const SizedBox(height: 8),
            _buildBulletPoint(
              '서명 정보 등의 인증 정보는 법적 분쟁에 대비하여 일정 기간 보관됩니다.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint('학습 이력 및 활동 기록은 보존됩니다.'),
            const SizedBox(height: 8),
            _buildBulletPoint('재가입을 원하시면 관리자에게 문의해주세요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            '취소',
            style: TextStyle(
              color: UiTokens.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '탈퇴',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBulletPoint(String text, {bool highlight = false}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: highlight ? Colors.orange : UiTokens.title,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: highlight ? Colors.orange.shade700 : UiTokens.title,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

