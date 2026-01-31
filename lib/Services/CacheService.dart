import 'package:shared_preferences/shared_preferences.dart';

/// 앱 로컬 캐시/세션 보관.
/// 현재 정책: "관리자 제외" 후임만 자동로그인을 위해 저장합니다.
class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  // _ : 라이브러리 private
  // k : 상수(constant) 키 네이밍 컨벤션
  static const String _kLoginKey = 'login_key'; // (레거시) 후임 접속코드
  static const String _kUserId = 'user_id';
  static const String _kNickname = 'nickname';
  static const String _kIsAdmin = 'is_admin';
  static const String _kFirebaseUid = 'firebase_uid'; // Firebase UID

  /// 후임 로그인 성공 시 세션 저장
  Future<void> saveMenteeSession({
    required String loginKey, // 접속코드(4자리)
    required String userId,
    required String nickname,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLoginKey, loginKey);
    await sp.setString(_kUserId, userId);
    await sp.setString(_kNickname, nickname);
    await sp.setBool(_kIsAdmin, false);
  }

  /// 저장된 접속코드 꺼내기 (후임 자동 로그인에서 사용)
  Future<String?> getSavedLoginKey() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLoginKey);
  }

  /// 후임 자동 로그인 여부
  Future<bool> isMenteeLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    final key = sp.getString(_kLoginKey);
    final isAdmin = sp.getBool(_kIsAdmin);
    return (key != null && key.isNotEmpty && isAdmin == false);
  }

  /// (옵션) 캐시된 간단 프로필 읽기
  Future<({String? userId, String? nickname, bool? isAdmin})>
  getCachedProfile() async {
    final sp = await SharedPreferences.getInstance();
    return (
      userId: sp.getString(_kUserId),
      nickname: sp.getString(_kNickname),
      isAdmin: sp.getBool(_kIsAdmin),
    );
  }

  /// Firebase UID 저장 (전화번호 인증 후)
  Future<void> saveFirebaseUid(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFirebaseUid, uid);
  }

  /// 저장된 Firebase UID 가져오기
  Future<String?> getFirebaseUid() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kFirebaseUid);
  }

  /// 로그아웃 등 세션 정리
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kLoginKey);
    await sp.remove(_kUserId);
    await sp.remove(_kNickname);
    await sp.remove(_kIsAdmin);
    await sp.remove(_kFirebaseUid);
  }
}
