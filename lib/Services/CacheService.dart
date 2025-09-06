import 'package:shared_preferences/shared_preferences.dart';

/// 앱 로컬 캐시/세션 보관.
/// 현재 정책: "관리자 제외" 멘티만 자동로그인을 위해 저장합니다.
class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  // _ : 라이브러리 private
  // k : 상수(constant) 키 네이밍 컨벤션
  static const String _kLoginKey = 'login_key'; // 멘티 접속코드(=login_key)
  static const String _kUserId = 'user_id';
  static const String _kNickname = 'nickname';
  static const String _kIsAdmin = 'is_admin';

  /// 멘티 로그인 성공 시 세션 저장
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

  /// 저장된 접속코드 꺼내기 (멘티 자동 로그인에서 사용)
  Future<String?> getSavedLoginKey() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLoginKey);
  }

  /// 멘티 자동 로그인 여부
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

  /// 로그아웃 등 세션 정리
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kLoginKey);
    await sp.remove(_kUserId);
    await sp.remove(_kNickname);
    await sp.remove(_kIsAdmin);
  }
}
