// lib/Pages/Chat/models/ReplyInfo.dart

/// 답장 메시지의 원본 정보
class ReplyInfo {
  final int messageId;
  final String senderId;
  final String senderNickname;
  final String type; // 'text' | 'image' | 'file'
  final String preview;
  final bool deleted;

  const ReplyInfo({
    required this.messageId,
    required this.senderId,
    required this.senderNickname,
    required this.type,
    required this.preview,
    this.deleted = false,
  });

  factory ReplyInfo.fromJson(Map<String, dynamic> json) {
    return ReplyInfo(
      messageId: json['message_id'] as int,
      senderId: json['sender_id'] as String,
      senderNickname: json['sender_nickname'] as String,
      type: json['type'] as String,
      preview: json['preview'] as String,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'sender_id': senderId,
      'sender_nickname': senderNickname,
      'type': type,
      'preview': preview,
      'deleted': deleted,
    };
  }

  ReplyInfo copyWith({
    int? messageId,
    String? senderId,
    String? senderNickname,
    String? type,
    String? preview,
    bool? deleted,
  }) {
    return ReplyInfo(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      type: type ?? this.type,
      preview: preview ?? this.preview,
      deleted: deleted ?? this.deleted,
    );
  }
}
