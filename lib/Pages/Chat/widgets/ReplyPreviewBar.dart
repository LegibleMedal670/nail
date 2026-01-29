// lib/Pages/Chat/widgets/ReplyPreviewBar.dart
import 'package:flutter/material.dart';

/// 메시지 입력창 위에 표시되는 답장 미리보기 바
class ReplyPreviewBar extends StatelessWidget {
  final String senderNickname;
  final String preview;
  final String type; // 'text' | 'image' | 'file'
  final bool isDeleted;
  final VoidCallback onCancel;

  const ReplyPreviewBar({
    Key? key,
    required this.senderNickname,
    required this.preview,
    required this.type,
    required this.isDeleted,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
          // left: BorderSide(color: Color(0xFF007AFF), width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: Colors.grey[600]),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$senderNickname에게 답장',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  isDeleted ? '삭제된 메시지입니다' : preview,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDeleted ? Colors.grey[500] : Colors.grey[700],
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 20,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
