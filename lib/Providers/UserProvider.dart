import 'package:flutter/foundation.dart';
import 'package:nail/Services/CacheService.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 런타임 사용자 세션 모델 (UI가 구독)
class UserAccount {
  final String userId;
  final String nickname;
  final bool isAdmin;
  final String loginKey; // 멘티 접속코드(관리자는 저장 안함)

  const UserAccount({
    required this.userId,
    required this.nickname,
    required this.isAdmin,
    required this.loginKey,
  });

  UserAccount copyWith({
    String? userId,
    String? nickname,
    bool? isAdmin,
    String? loginKey,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      isAdmin: isAdmin ?? this.isAdmin,
      loginKey: loginKey ?? this.loginKey,
    );
  }
}

/// 세션 컨트롤러 (ChangeNotifier 기반)
class UserProvider extends ChangeNotifier {
  final _cache = CacheService.instance;
  final _api = SupabaseService.instance;

  UserAccount? _current;
  bool _loading = false;

  UserAccount? get current => _current;
  bool get isLoading => _loading;
  bool get isLoggedIn => _current != null;
  bool get isAdmin => _current?.isAdmin == true;
  String get nickname => _current?.nickname ?? '';

  /// 앱 시작 시 호출: 캐시 → 서버 재검증 → 메모리 탑재
  Future<void> hydrate() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final savedKey = await _cache.getSavedLoginKey();
      if (savedKey == null || savedKey.isEmpty) {
        _current = null;
        return;
      }

      final row = await _api.loginWithKey(savedKey);
      if (row == null || (row['is_admin'] == true)) {
        // 캐시가 깨졌거나 관리자 키면 지움
        await _cache.clear();
        _current = null;
        return;
      }

      _current = UserAccount(
        userId: row['id'] as String,
        nickname: (row['nickname'] as String?) ?? '',
        isAdmin: false,
        loginKey: savedKey,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 접속코드/비밀번호로 로그인 (관리자/멘티 겸용)
  /// 성공 시: 세션/캐시 갱신
  Future<bool> signInWithCode(String code) async {
    if (_loading) return false;
    _loading = true;
    notifyListeners();

    try {
      final row = await _api.loginWithKey(code);
      if (row == null) return false;

      final isAdmin = row['is_admin'] == true;
      _current = UserAccount(
        userId: row['id'] as String,
        nickname: (row['nickname'] as String?) ?? '',
        isAdmin: isAdmin,
        loginKey: isAdmin ? '' : code, // 관리자는 로컬 저장 X
      );

      // 멘티만 캐시 저장
      if (!isAdmin) {
        await _cache.saveMenteeSession(
          loginKey: code,
          userId: _current!.userId,
          nickname: _current!.nickname,
        );
      } else {
        await _cache.clear(); // 혹시 남아있던 멘티 캐시 제거
      }
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 프로필만 최신화 (닉네임/멘토/사진 등 fetch하여 _current 갱신하는 용도)
  Future<void> refreshProfile() async {
    if (_current == null) return;
    final key = _current!.loginKey;
    if (key.isEmpty) return; // 관리자는 패스(별도 흐름로 처리 예정)

    final row = await _api.loginWithKey(key);
    if (row == null) return;
    _current = _current!.copyWith(nickname: (row['nickname'] as String?) ?? _current!.nickname);
    notifyListeners();
  }

  /// 로그아웃: 메모리/캐시 정리
  Future<void> signOut() async {
    _current = null;
    await _cache.clear();
    notifyListeners();
  }
}
