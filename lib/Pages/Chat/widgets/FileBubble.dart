import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:path/path.dart' as p;
import 'package:nail/Pages/Chat/models/ReplyInfo.dart';

class FileBubble extends StatelessWidget {
  final bool isMe;
  final String fileName;
  final int fileBytes;
  final String? localPath; // 목업
  final String? fileUrl;   // 서버 서명 URL
  final DateTime createdAt;
  final int? readCount;
  final VoidCallback? onTapOpen;
  final VoidCallback? onLongPressDelete;
  final bool loading;
  final bool downloaded;
  
  /// 답장 정보 (원본 메시지)
  final ReplyInfo? replyTo;
  /// 답장 인용 클릭 시 원본으로 이동
  final VoidCallback? onReplyTap;

  const FileBubble({
    Key? key,
    required this.isMe,
    required this.fileName,
    required this.fileBytes,
    required this.createdAt,
    this.localPath,
    this.fileUrl,
    this.readCount,
    this.onTapOpen,
    this.onLongPressDelete,
    this.loading = false,
    this.downloaded = false,
    this.replyTo,
    this.onReplyTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(fileName).replaceFirst('.', '').toUpperCase();
    final icon = _iconFor(ext);

    final card = GestureDetector(
      onTap: onTapOpen,
      onLongPress: onLongPressDelete,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
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
              // 파일 카드
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMe ? UiTokens.primaryBlue.withOpacity(0.08) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UiTokens.cardBorder),
                boxShadow: const [UiTokens.cardShadow],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: UiTokens.cardBorder),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: UiTokens.title),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: UiTokens.title,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(_formatSize(fileBytes),
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!loading)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(
                        downloaded
                            ? Icons.open_in_new_rounded
                            : Icons.download_rounded,
                        size: 22,
                        color: Colors.black54,
                      ),
                    )
                  else
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );

    final meta = _MetaColumn(
      time: _friendlyTime(createdAt),
      readCount: readCount,
      leftSide: isMe,
    );

    final rowChildren = isMe
        ? <Widget>[meta, const SizedBox(width: 2), card]
        : <Widget>[card, const SizedBox(width: 2), meta];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }

  IconData _iconFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'xls':
      case 'xlsx': return Icons.grid_on_outlined;
      case 'ppt':
      case 'pptx': return Icons.slideshow_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      case 'zip':
      case 'rar': return Icons.archive_outlined;
      case 'txt': return Icons.notes_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)}MB';
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
