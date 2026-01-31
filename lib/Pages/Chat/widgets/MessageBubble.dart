import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Chat/models/ReplyInfo.dart';

class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final DateTime createdAt;
  final int? readCount;
  final VoidCallback? onLongPressDelete;
  
  /// 검색어 하이라이트용 (null이면 하이라이트 없음)
  final String? highlightQuery;
  /// 현재 포커스된 검색 결과인지 (더 진한 하이라이트)
  final bool isCurrentSearchResult;
  
  /// 답장 정보 (원본 메시지)
  final ReplyInfo? replyTo;
  /// 답장 인용 클릭 시 원본으로 이동
  final VoidCallback? onReplyTap;

  const MessageBubble({
    Key? key,
    required this.isMe,
    required this.text,
    required this.createdAt,
    this.readCount,
    this.onLongPressDelete,
    this.highlightQuery,
    this.isCurrentSearchResult = false,
    this.replyTo,
    this.onReplyTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? UiTokens.primaryBlue : Colors.grey[100]!;
    final fg = isMe ? Colors.white : UiTokens.title;

    // 검색어 하이라이트 적용된 텍스트 위젯
    final textWidget = _buildHighlightedText(text, fg);

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
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 답장 인용 부분
                if (replyTo != null) ...[
                  _buildReplyQuote(context, replyTo!),
                  // 구분선 (버블 전체 너비)
                  Container(
                    height: 1,
                    color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey[400],
                  ),
                  SizedBox(height: 6),
                ],
                // 실제 메시지 내용
                textWidget,
              ],
            ),
          ),
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

  /// 검색어 하이라이트가 적용된 텍스트 위젯 빌드
  Widget _buildHighlightedText(String content, Color defaultColor) {
    // 검색어가 없거나 빈 문자열이면 일반 텍스트
    if (highlightQuery == null || highlightQuery!.trim().isEmpty) {
      return Text(
        content,
        style: TextStyle(color: defaultColor, fontSize: 14, height: 1.30, fontWeight: FontWeight.w500),
      );
    }

    final query = highlightQuery!.toLowerCase();
    final lowerContent = content.toLowerCase();
    
    // 검색어가 포함되지 않으면 일반 텍스트
    if (!lowerContent.contains(query)) {
      return Text(
        content,
        style: TextStyle(color: defaultColor, fontSize: 14, height: 1.30, fontWeight: FontWeight.w500),
      );
    }

    // 하이라이트 색상: 현재 결과는 진한 주황, 그 외는 연한 노랑
    final highlightBg = isCurrentSearchResult
        ? const Color(0xFFFFAB40) // 진한 주황 (현재 포커스)
        : const Color(0xFFFFEB3B); // 연한 노랑 (다른 결과)
    
    // 하이라이트된 텍스트 색상 (가독성을 위해 어두운 색)
    const highlightFg = UiTokens.title;

    // TextSpan 리스트 생성
    final spans = <TextSpan>[];
    int start = 0;
    
    while (true) {
      final matchIndex = lowerContent.indexOf(query, start);
      if (matchIndex == -1) {
        // 남은 텍스트 추가
        if (start < content.length) {
          spans.add(TextSpan(
            text: content.substring(start),
            style: TextStyle(color: defaultColor, fontSize: 14, height: 1.30, fontWeight: FontWeight.w500),
          ));
        }
        break;
      }
      
      // 매치 전 텍스트 추가
      if (matchIndex > start) {
        spans.add(TextSpan(
          text: content.substring(start, matchIndex),
          style: TextStyle(color: defaultColor, fontSize: 14, height: 1.30, fontWeight: FontWeight.w500),
        ));
      }
      
      // 하이라이트된 텍스트 추가
      spans.add(TextSpan(
        text: content.substring(matchIndex, matchIndex + query.length),
        style: TextStyle(
          color: highlightFg,
          fontSize: 14,
          height: 1.30,
          fontWeight: FontWeight.w600,
          backgroundColor: highlightBg,
        ),
      ));
      
      start = matchIndex + query.length;
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _friendlyTime(DateTime t) {
    final lt = t.toLocal();
    final h = lt.hour.toString().padLeft(2, '0');
    final m = lt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 답장 인용 박스 위젯 (카카오톡 스타일)
  Widget _buildReplyQuote(BuildContext context, ReplyInfo reply) {
    return GestureDetector(
      onTap: onReplyTap,
      behavior: HitTestBehavior.translucent,
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
                color: isMe ? Colors.white : Colors.grey[600],
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
                color: reply.deleted
                    ? (isMe ? Colors.white : Colors.grey[500])
                    : (isMe ? Colors.white : Colors.grey[700]),
                fontStyle: reply.deleted ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
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
