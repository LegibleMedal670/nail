// lib/Providers/UserProvider.dart
import 'package:flutter/foundation.dart';
import 'package:nail/Services/CacheService.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 런타임 사용자 세션 모델 (UI가 구독)
class UserAccount {
  final String userId;
  final String nickname;
  final bool isAdmin;
  final bool isMentor;     // ✅ 멘토 역할
  final String loginKey;
  final DateTime joinedAt;
  final String? mentorId;   // ✅ mentor(uuid)
  final String? mentorName; // ✅ mentor 표시용 이름
  final String? photoUrl;


  const UserAccount({
    required this.userId,
    required this.nickname,
    required this.isAdmin,
    required this.isMentor,
    required this.loginKey,
    required this.joinedAt,
    this.mentorId,
    this.mentorName,
    this.photoUrl,
  });

  UserAccount copyWith({
    String? userId,
    String? nickname,
    bool? isAdmin,
    bool? isMentor,
    String? loginKey,
    DateTime? joinedAt,
    String? mentorId,
    String? mentorName,
    String? photoUrl,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      isAdmin: isAdmin ?? this.isAdmin,
      isMentor: isMentor ?? this.isMentor,
      loginKey: loginKey ?? this.loginKey,
      joinedAt: joinedAt ?? this.joinedAt,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

class UserProvider extends ChangeNotifier {
  final _cache = CacheService.instance;
  final _api = SupabaseService.instance;

  UserAccount? _current;
  bool _loading = false;

  /// 관리자 세션에서만 사용하는 **비영구(메모리) adminKey**
  /// - Supabase Auth 미사용 환경이므로, 관리자 권한 검증은 RPC(p_admin_key)로 처리.
  /// - 앱 재시작/로그아웃 시 사라짐. (디스크에 저장하지 않음)
  String? _adminKey;

  // ===== 공개 게터 =====
  UserAccount? get current => _current;
  bool get isLoading => _loading;
  bool get isLoggedIn => _current != null;
  bool get isAdmin => _current?.isAdmin == true;
  bool get isMentor => _current?.isMentor == true; // ✅
  String get nickname => _current?.nickname ?? '';
  DateTime get joinedAt => _current?.joinedAt ?? DateTime.now();
  String? get mentorId => _current?.mentorId;       // ✅
  String? get mentorName => _current?.mentorName;   // ✅
  String? get photoUrl => _current?.photoUrl;

  /// 현재 세션이 관리자라면 adminKey, 아니라면 null
  String? get adminKey => isAdmin ? _adminKey : null;

  // ===== 내부 유틸 =====
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
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

  // ===== 라이프사이클 =====

  /// 앱 시작 시 호출: (멘티/멘토) 캐시 → 서버 재검증 → 메모리 탑재
  /// - 관리자는 캐시하지 않으므로 복원 대상 아님
  Future<void> hydrate() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      // 관리자 키는 비영구 메모리이므로 부팅 시 항상 null
      _adminKey = null;
      _api.adminKey = null;

      final savedKey = await _cache.getSavedLoginKey();
      if (savedKey == null || savedKey.isEmpty) {
        _current = null;
        return;
      }

      // 캐시에 저장된 건 멘티/멘토 키여야 정상 (관리자는 캐시 안 함)
      final row = await _api.loginWithKey(savedKey);
      if (row == null || _asBool(row['is_admin'])) {
        // 캐시가 깨졌거나 관리자인 경우 → 캐시 제거
        await _cache.clear();
        _current = null;
        return;
      }

      _current = UserAccount(
        userId: _asString(row['id']),
        nickname: _asString(row['nickname']),
        isAdmin: false,
        isMentor: _asBool(row['is_mentor']),        // ✅
        loginKey: savedKey,
        joinedAt: _parseDate(row['joined_at']) ?? DateTime.now(),
        mentorId: row['mentor'] as String?,         // uuid
        mentorName: row['mentor_name'] as String?,  // display
        photoUrl: row['photo_url'] as String?,
      );

      // 멘티/멘토 세션이므로 adminKey는 null 유지
      _api.adminKey = null;

      _api.loginKey = savedKey;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 접속코드로 로그인 (관리자/멘티/멘토 겸용)
  /// - 관리자: _adminKey = code 를 메모리에만 유지, 캐시는 비움
  /// - 멘티/멘토: 접속코드 캐시에 저장
  Future<bool> signInWithCode(String code) async {
    if (_loading) return false;
    _loading = true;
    notifyListeners();

    try {
      final row = await _api.loginWithKey(code);
      if (row == null) return false;

      final isAdmin = _asBool(row['is_admin']);
      final isMentor = _asBool(row['is_mentor']); // ✅

      _current = UserAccount(
        userId: _asString(row['id']),
        nickname: _asString(row['nickname']),
        isAdmin: isAdmin,
        isMentor: isMentor,
        loginKey: isAdmin ? '' : code, // 관리자는 로컬에 저장하지 않음
        joinedAt: _parseDate(row['joined_at']) ?? DateTime.now(),
        mentorId: row['mentor'] as String?,         // uuid
        mentorName: row['mentor_name'] as String?,  // display
        photoUrl: row['photo_url'] as String?,
      );

      if (isAdmin) {
        // 관리자 세션: adminKey 메모리 보관(+서비스에 주입), 캐시는 비움
        _adminKey = code;
        _api.adminKey = _adminKey;
        await _cache.clear();

        _api.loginKey = null;
      } else {
        // 멘티/멘토 세션: 캐시에 저장, adminKey는 비움
        _adminKey = null;
        _api.adminKey = null;
        await _cache.saveMenteeSession( // 기존 API를 멘토도 공용 사용
          loginKey: _current!.loginKey,
          userId: _current!.userId,
          nickname: _current!.nickname,
        );

        _api.loginKey = _current!.loginKey;
      }
      return true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 프로필 최신화 (멘티/멘토; 관리자는 접속키를 영구 저장하지 않으므로 스킵)
  Future<void> refreshProfile() async {
    if (_current == null) return;
    if (_current!.isAdmin) return;

    final key = _current!.loginKey;
    if (key.isEmpty) return;

    final row = await _api.loginWithKey(key);
    if (row == null) return;

    _current = _current!.copyWith(
      nickname: _asString(row['nickname'], _current!.nickname),
      photoUrl: row['photo_url'] as String? ?? _current!.photoUrl,
      joinedAt: _parseDate(row['joined_at']) ?? _current!.joinedAt,
      mentorId: row['mentor'] as String? ?? _current!.mentorId,          // ✅
      mentorName: row['mentor_name'] as String? ?? _current!.mentorName, // ✅
      isMentor: _asBool(row['is_mentor']),                               // ✅
    );
    notifyListeners();
  }

  /// 로그아웃: 메모리/캐시 정리 + 서비스 adminKey 초기화
  Future<void> signOut() async {
    _current = null;
    _adminKey = null;
    _api.adminKey = null;
    _api.loginKey = null;

    await _cache.clear();
    notifyListeners();
  }
}
