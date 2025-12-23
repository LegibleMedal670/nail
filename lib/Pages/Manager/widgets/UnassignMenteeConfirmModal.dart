import 'package:flutter/material.dart';
import 'package:nail/Pages/Chat/widgets/ConfirmModal.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 멘티 배정 해제 전용 컨펌 모달
///
/// - true  : 배정 해제 진행
/// - false : 취소
Future<bool> showUnassignMenteeConfirmDialog(
  BuildContext context, {
  required String menteeName,
}) {
  return showConfirmDialog(
    context,
    title: '멘티 배정 해제',
    message:
        '현재 멘토와 $menteeName님의 배정을 해제할까요?\n\n실습 기록 자체는 유지되지만, 이 멘토의 담당 멘티 목록에서는 제거됩니다.',
    confirmText: '배정 해제',
    cancelText: '취소',
    isDanger: true,
    icon: Icons.link_off_rounded,
    accentColor: const Color(0xFFD32F2F), // 채팅 삭제 계열과 톤 맞춤
  );
}


