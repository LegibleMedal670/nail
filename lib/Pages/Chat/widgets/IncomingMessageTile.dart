import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// 상대방 메시지 전용 래퍼
/// Row(
///   [아바타],
///   8,
///   Expanded(
///     child: Column(mainAxisSize: min, crossAxisAlignment: start, children: [닉네임, 4, 버블Row])
///   )
/// )
class IncomingMessageTile extends StatelessWidget {
  final String nickname;   // DB: nickname
  final String? photoUrl;  // DB: photo_url
  final Widget childRow;   // MessageBubble/ImageBubble/FileBubble 등 (Row 반환 위젯)

  const IncomingMessageTile({
    Key? key,
    required this.nickname,
    required this.childRow,
    this.photoUrl,
  }) : super(key: key);

  static const double _avatarRadius = 16; // 지름 32
  static const double _gap = 8;

  String _initials(String name) {
    if (name.isEmpty) return '·';
    final runes = name.runes.toList();
    return String.fromCharCodes([runes.first]);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: Colors.grey[400],
      foregroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(
        _initials(nickname),
        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
      )
          : null,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2, left: 4, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: _gap),
          // 폭은 남는 만큼 차지하되, 높이는 내용만큼: mainAxisSize.min
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임
                Text(
                  nickname,
                  style: const TextStyle(
                    color: UiTokens.title,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // ⚠️ 여기서 Flexible/Expanded 사용 금지 (세로 무한 제약과 충돌)
                childRow, // 이미 내부에서 가로 maxWidth 제약을 가짐
              ],
            ),
          ),
        ],
      ),
    );
  }
}
