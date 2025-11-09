import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 방 생성/초대 등의 시스템 메시지 칩
class SystemEventChip extends StatelessWidget {
  final String text;

  const SystemEventChip({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.85; // 너무 넓지 않게
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(230, 230, 230, 1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  color: UiTokens.title.withOpacity(0.85),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
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
