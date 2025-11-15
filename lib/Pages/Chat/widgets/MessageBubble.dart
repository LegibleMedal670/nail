import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final DateTime createdAt;
  final int? readCount;
  final VoidCallback? onLongPressDelete;

  const MessageBubble({
    Key? key,
    required this.isMe,
    required this.text,
    required this.createdAt,
    this.readCount,
    this.onLongPressDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? UiTokens.primaryBlue : Colors.grey[100]!;
    final fg = isMe ? Colors.white : UiTokens.title;

    final bubble = GestureDetector(
      onLongPress: onLongPressDelete,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: isMe ? null : Border.all(color: UiTokens.cardBorder),
            boxShadow: const [UiTokens.cardShadow],
          ),
          child: Text(text, style: TextStyle(color: fg, fontSize: 14, height: 1.30, fontWeight: FontWeight.w500)),
        ),
      ),
    );

    // ㄴ / 역-ㄴ 모양 메타
    final meta = _MetaColumn(
      time: _friendlyTime(createdAt),
      readCount: readCount,
      leftSide: isMe, // 내가 보낸 메시지면 메타가 왼쪽(역-ㄴ), 아니면 오른쪽(ㄴ)
    );

    // 상대: [버블][2][메타(오른쪽 ㄴ)], 나: [메타(왼쪽 역-ㄴ)][2][버블]
    final rowChildren = isMe
        ? <Widget>[meta, const SizedBox(width: 2), bubble]
        : <Widget>[bubble, const SizedBox(width: 2), meta];

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end, // 하단 기준 정렬
          children: rowChildren,
        ));
  }

  String _friendlyTime(DateTime t) {
    final lt = t.toLocal();
    final h = lt.hour.toString().padLeft(2, '0');
    final m = lt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MetaColumn extends StatelessWidget {
  final String time;
  final int? readCount;
  final bool leftSide; // true면 버블 왼쪽(역-ㄴ), false면 오른쪽(ㄴ)
  const _MetaColumn({required this.time, required this.readCount, required this.leftSide});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: leftSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (readCount != null && readCount != 0)
          Text('${readCount!}', style: const TextStyle(color: UiTokens.primaryBlue, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 0),
        Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
