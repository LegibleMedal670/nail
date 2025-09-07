// lib/Providers/UserProvider.dart
import 'package:flutter/foundation.dart';
import 'package:nail/Services/CacheService.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 런타임 사용자 세션 모델 (UI가 구독)
class UserAccount {
  final String userId;
  final String nickname;
  final bool isAdmin;
  final String loginKey; // 멘티 접속코드(관리자는 저장 안함)
  final DateTime joinedAt;
  final String? photoUrl;

  const UserAccount({
    required this.userId,
    required this.nickname,
    required this.isAdmin,
    required this.loginKey,
    required this.joinedAt,
    this.photoUrl,
  });

  UserAccount copyWith({
    String? userId,
    String? nickname,
    bool? isAdmin,
    String? loginKey,
    DateTime? joinedAt,
    String? photoUrl,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      isAdmin: isAdmin ?? this.isAdmin,
      loginKey: loginKey ?? this.loginKey,
      joinedAt: joinedAt ?? this.joinedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

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
  DateTime get joinedAt => _current?.joinedAt ?? DateTime.now();
  String? get photoUrl => _current?.photoUrl;

  /// ---- 안전 파서 유틸 ----
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        // 일부가 'yyyy-mm-dd'만 올 수도 있음 → 뒤에 'T00:00:00Z' 붙이는 것도 고려 가능
        return null;
      }
    }
    return null;
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == 't' || s == '1';
    }
    return false;
  }

  String _asString(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

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
      if (row == null || _asBool(row['is_admin'])) {
        // 캐시가 깨졌거나 관리자 키면 지움
        await _cache.clear();
        _current = null;
        return;
      }

      _current = UserAccount(
        userId: _asString(row['id']),
        nickname: _asString(row['nickname']),
        isAdmin: false,
        loginKey: savedKey,
        joinedAt: _parseDate(row['joined_at']) ?? DateTime.now(),
        photoUrl: row['photo_url'] as String?,
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

      final isAdmin = _asBool(row['is_admin']);
      final account = UserAccount(
        userId: _asString(row['id']),
        nickname: _asString(row['nickname']),
        isAdmin: isAdmin,
        loginKey: isAdmin ? '' : code, // 관리자는 로컬 저장 X
        joinedAt: _parseDate(row['joined_at']) ?? DateTime.now(),
        photoUrl: row['photo_url'] as String?,
      );

      _current = account;

      // 멘티만 캐시 저장
      if (!isAdmin) {
        await _cache.saveMenteeSession(
          loginKey: account.loginKey,
          userId: account.userId,
          nickname: account.nickname,
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

  /// 프로필 최신화 (닉네임/사진/시작일 등)
  Future<void> refreshProfile() async {
    if (_current == null) return;
    final key = _current!.loginKey;
    if (key.isEmpty) return; // 관리자는 패스

    final row = await _api.loginWithKey(key);
    if (row == null) return;

    _current = _current!.copyWith(
      nickname: _asString(row['nickname'], _current!.nickname),
      photoUrl: row['photo_url'] as String? ?? _current!.photoUrl,
      joinedAt: _parseDate(row['joined_at']) ?? _current!.joinedAt,
    );
    notifyListeners();
  }

  /// 로그아웃: 메모리/캐시 정리
  Future<void> signOut() async {
    _current = null;
    await _cache.clear();
    notifyListeners();
  }
}
