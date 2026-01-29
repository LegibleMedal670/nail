import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nail/Pages/Chat/models/ReplyInfo.dart';

class ImageGroupBubble extends StatelessWidget {
  final bool isMe;
  final List<String>? imageUrls;          // 서명 URL들
  final List<String>? localPreviewPaths;  // 로컬 경로들 (낙관적 렌더)
  final DateTime createdAt;
  final int? readCount;
  final bool loading;
  final VoidCallback? onTap; // 전체를 탭하면 풀스크린 뷰어 열기
  final int? expectedCount;   // URL 준비 전 셀 개수
  
  /// 답장 정보 (원본 메시지)
  final ReplyInfo? replyTo;
  /// 답장 인용 클릭 시 원본으로 이동
  final VoidCallback? onReplyTap;

  const ImageGroupBubble({
    Key? key,
    required this.isMe,
    required this.createdAt,
    this.imageUrls,
    this.localPreviewPaths,
    this.readCount,
    this.loading = false,
    this.onTap,
    this.expectedCount,
    this.replyTo,
    this.onReplyTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final previews = _resolvePreviews();
    final grid = _ImageGrid(previews: previews);

    final bubble = GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.70,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 답장 인용 부분
            if (replyTo != null) ...[
              _buildReplyQuote(context, replyTo!),
              SizedBox(height: 6),
            ],
            // 이미지 그리드
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: UiTokens.cardBorder),
                    boxShadow: const [UiTokens.cardShadow],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: grid,
                ),
                if (loading) ...[
                  Positioned.fill(child: Container(color: Colors.black26)),
                  Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    final meta = _MetaColumn(
      time: _friendlyTime(createdAt),
      readCount: readCount,
      leftSide: isMe,
    );

    final rowChildren = isMe
        ? <Widget>[meta, const SizedBox(width: 2), bubble]
        : <Widget>[bubble, const SizedBox(width: 2), meta];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }

  List<_Preview> _resolvePreviews() {
    final list = <_Preview>[];
    if (localPreviewPaths != null && localPreviewPaths!.isNotEmpty) {
      for (final p in localPreviewPaths!) {
        list.add(_Preview(localPath: p));
      }
      return list;
    }
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      for (final u in imageUrls!) {
        list.add(_Preview(url: u));
      }
      return list;
    }
    final n = (expectedCount ?? 0);
    if (n > 0) {
      for (int i = 0; i < n; i++) {
        list.add(const _Preview()); // 회색 플레이스홀더
      }
    }
    return list;
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
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? UiTokens.primaryBlue.withOpacity(0.2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? UiTokens.primaryBlue : Color(0xFF007AFF),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply,
                  size: 12,
                  color: isMe ? UiTokens.primaryBlue : Colors.grey[600],
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    reply.senderNickname,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMe ? UiTokens.primaryBlue : Color(0xFF007AFF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 3),
            Text(
              reply.deleted ? '삭제된 메시지입니다' : reply.preview,
              style: TextStyle(
                fontSize: 12,
                color: reply.deleted
                    ? Colors.grey[500]
                    : (isMe ? UiTokens.title : Colors.grey[700]),
                fontStyle: reply.deleted ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<_Preview> previews;
  const _ImageGrid({required this.previews});

  @override
  Widget build(BuildContext context) {
    final count = previews.length;
    if (count <= 0) {
      return Container(color: Colors.grey[200]);
    }
    final cells = count.clamp(1, 10);
    final cols = (count == 2) ? 2 : 3; // 2장일 때: 2열 1행
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: cells,
      itemBuilder: (_, i) => _Tile(preview: previews[i]),
    );
  }
}

class _Tile extends StatelessWidget {
  final _Preview preview;
  const _Tile({required this.preview});
  @override
  Widget build(BuildContext context) {
    final core = () {
      if (preview.localPath != null && preview.localPath!.isNotEmpty) {
        final f = File(preview.localPath!);
        if (f.existsSync()) return Image.file(f, fit: BoxFit.cover);
      }
      if (preview.url != null && preview.url!.isNotEmpty) {
        return CachedNetworkImage(imageUrl: preview.url!, fit: BoxFit.cover);
      }
      return Container(color: Colors.grey[300]);
    }();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: core,
    );
  }
}

class _Preview {
  final String? url;
  final String? localPath;
  const _Preview({this.url, this.localPath});
}

class _MetaColumn extends StatelessWidget {
  final String time;
  final int? readCount;
  final bool leftSide;
  const _MetaColumn({required this.time, required this.readCount, required this.leftSide});
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: leftSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (readCount != null && readCount != 0)
            Text('$readCount',
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


