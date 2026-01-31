// lib/Pages/Chat/widgets/ImageBubble.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nail/Pages/Chat/models/ReplyInfo.dart';

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
  final bool loading;
  
  /// 답장 정보 (원본 메시지)
  final ReplyInfo? replyTo;
  /// 답장 인용 클릭 시 원본으로 이동
  final VoidCallback? onReplyTap;

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
    this.loading = false,
    this.replyTo,
    this.onReplyTap,
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
          maxWidth: MediaQuery.of(context).size.width * 0.60,
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 답장 인용 부분
              if (replyTo != null) ...[
                _buildReplyQuote(context, replyTo!),
                // 구분선 (버블 전체 너비)
                Padding(
                  padding: EdgeInsets.only(left: 4, right: 4),
                  child: Container(
                    height: 1,
                    color: Colors.grey[400],
                  ),
                ),
                SizedBox(height: 6),
              ],
              // 이미지
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 260),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: UiTokens.cardBorder),
                      boxShadow: const [UiTokens.cardShadow],
                    ),
                    child: wrapped,
                  ),
                  if (loading) ...[
                    Positioned.fill(child: Container(color: Colors.black26)),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
        final img = CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover);
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
    final lt = t.toLocal();
    final h = lt.hour.toString().padLeft(2, '0');
    final m = lt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 답장 인용 박스 위젯
  Widget _buildReplyQuote(BuildContext context, ReplyInfo reply) {
    return GestureDetector(
      onTap: onReplyTap,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: EdgeInsets.only(bottom: 6, left: 4, right: 4),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // "[닉네임]에게 답장" 텍스트
              Text(
                '${reply.senderNickname}에게 답장',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              // 프리뷰 텍스트
              Text(
                reply.deleted ? '삭제된 메시지입니다' : reply.preview,
                style: TextStyle(
                  fontSize: 12,
                  color: reply.deleted ? Colors.grey[500] : Colors.grey[700],
                  fontStyle: reply.deleted ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
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
