// 공용 멤버 요약 모델 (다른 페이지에서 import 해서 사용)
class RoomMemberBrief {
  final String userId;
  final String nickname;   // DB: nickname
  final String role;       // 관리자/멘토/멘티
  final String? photoUrl;  // DB: photo_url

  const RoomMemberBrief({
    required this.userId,
    required this.nickname,
    required this.role,
    this.photoUrl,
  });

  // 필요시 중복 제거용 equals/hashCode (userId 기준)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RoomMemberBrief && runtimeType == other.runtimeType && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
