import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 방 생성/초대 등의 시스템 메시지 칩
class SystemEventChip extends StatelessWidget {
  final String text;

  const SystemEventChip({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.80; // 조금 더 타이트하게
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(235, 235, 235, 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  color: UiTokens.title.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
