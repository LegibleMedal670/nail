// lib/Pages/Chat/widgets/ImageBubble.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

class ImageBubble extends StatelessWidget {
  final bool isMe;
  final String? imageUrl;         // 서버 서명 URL
  final String? localPreviewPath; // 로컬 경로
  final DateTime createdAt;
  final int? readCount;
  final VoidCallback? onLongPressDelete;

  // ✅ 풀스크린 전환용(선택): ChatRoomPage에서 heroTag, onTap을 넘겨 사용
  final String? heroTag;
  final VoidCallback? onTap;

  const ImageBubble({
    Key? key,
    required this.isMe,
    required this.imageUrl,
    required this.localPreviewPath,
    required this.createdAt,
    this.readCount,
    this.onLongPressDelete,
    this.heroTag,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 버블(이미지 카드)
    final imgWidget = _buildImage();
    final wrapped = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(aspectRatio: 4 / 3, child: imgWidget),
    );

    final imageCard = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPressDelete,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65, // ▶ FileBubble과 통일
          maxHeight: 320,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UiTokens.cardBorder),
            boxShadow: const [UiTokens.cardShadow],
          ),
          child: wrapped,
        ),
      ),
    );

    // 메타(읽음/시간)
    final meta = _MetaColumn(
      time: _friendlyTime(createdAt),
      readCount: readCount,
      leftSide: isMe, // 내가 보낸 메시지면 메타가 왼쪽(역-ㄴ)
    );

    // 상대: [버블][2][메타], 나: [메타][2][버블]
    final rowChildren = isMe
        ? <Widget>[meta, const SizedBox(width: 2), imageCard]
        : <Widget>[imageCard, const SizedBox(width: 2), meta];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // 하단 정렬 → 메타가 항상 보임
        mainAxisSize: MainAxisSize.max,
        children: rowChildren,
      ),
    );
  }

  // --- helpers ---
  Widget _buildImage() {
    final core = () {
      if (localPreviewPath != null && localPreviewPath!.isNotEmpty) {
        final f = File(localPreviewPath!);
        if (f.existsSync()) return Image.file(f, fit: BoxFit.cover);
      }
      if (imageUrl != null && imageUrl!.isNotEmpty) {
        final img = Image.network(imageUrl!, fit: BoxFit.cover);
        return heroTag == null ? img : Hero(tag: heroTag!, child: img);
      }
      return Container(color: Colors.grey[200]);
    }();

    // heroTag가 있고 로컬 이미지인 경우도 Hero 적용
    if (heroTag != null &&
        (localPreviewPath != null && localPreviewPath!.isNotEmpty)) {
      return Hero(tag: heroTag!, child: core);
    }
    return core;
  }

  String _friendlyTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MetaColumn extends StatelessWidget {
  final String time;
  final int? readCount;
  final bool leftSide;
  const _MetaColumn({required this.time, required this.readCount, required this.leftSide});

  @override
  Widget build(BuildContext context) {
    // 텍스트 잘림 방지용 최소 폭 확보
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: leftSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (readCount != null && readCount != 0)
            Text('${readCount!}',
                style: const TextStyle(
                  color: UiTokens.primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                )),
          const SizedBox(height: 0),
          Text(
            time,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false),
          ),
        ],
      ),
    );
  }
}
