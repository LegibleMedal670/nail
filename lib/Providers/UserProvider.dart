// lib/Providers/UserProvider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:nail/Services/CacheService.dart';
import 'package:nail/Services/FirebaseAuthService.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/FCMService.dart';

/// 런타임 사용자 세션 모델 (UI가 구독)
class UserAccount {
  final String id;
  final String firebaseUid;
  final String phone;
  final String nickname;
  final String role; // 'admin', 'mentor', 'mentee', 'pending'
  final bool isAdmin;
  final bool isMentor;
  final DateTime joinedAt;
  final String? mentorId;
  final String? mentorName;
  final String? photoUrl;

  const UserAccount({
    required this.id,
    required this.firebaseUid,
    required this.phone,
    required this.nickname,
    required this.role,
    required this.isAdmin,
    required this.isMentor,
    required this.joinedAt,
    this.mentorId,
    this.mentorName,
    this.photoUrl,
  });

  /// role이 pending이면 역할 미배정 상태
  bool get isPending => role == 'pending';

  /// 멘티 여부 (role 기반)
  bool get isMentee => role == 'mentee';

  // ===== 호환성 getter (레거시 코드용) =====
  /// @deprecated Use `id` instead
  String get userId => id;
  
  /// @deprecated Use `firebaseUid` instead - RPC 마이그레이션 후 제거
  String get loginKey => firebaseUid;

  UserAccount copyWith({
    String? id,
    String? firebaseUid,
    String? phone,
    String? nickname,
    String? role,
    bool? isAdmin,
    bool? isMentor,
    DateTime? joinedAt,
    String? mentorId,
    String? mentorName,
    String? photoUrl,
  }) {
    return UserAccount(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      phone: phone ?? this.phone,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      isMentor: isMentor ?? this.isMentor,
      joinedAt: joinedAt ?? this.joinedAt,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

class UserProvider extends ChangeNotifier {
  final _cache = CacheService.instance;
  final _firebaseAuth = FirebaseAuthService();
  final _sb = Supabase.instance.client;

  UserAccount? _current;
  bool _loading = false;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;

  // ===== 공개 게터 =====
  UserAccount? get current => _current;
  bool get isLoading => _loading;
  bool get isLoggedIn => _current != null;
  bool get isPending => _current?.isPending == true;
  bool get isAdmin => _current?.isAdmin == true;
  bool get isMentor => _current?.isMentor == true;
  bool get isMentee => _current?.isMentee == true;
  String get role => _current?.role ?? 'pending';
  String get nickname => _current?.nickname ?? '';
  String get odl => _current?.id ?? '';
  DateTime get joinedAt => _current?.joinedAt ?? DateTime.now();
  String? get mentorId => _current?.mentorId;
  String? get mentorName => _current?.mentorName;
  String? get photoUrl => _current?.photoUrl;

  /// Firebase UID (RPC 호출에 사용)
  String? get firebaseUid => _current?.firebaseUid ?? _firebaseAuth.currentUid;

  // ===== 호환성 getter/method (레거시 코드용) =====
  /// @deprecated Use `firebaseUid` instead - 서버에서 권한 검증
  String? get adminKey => firebaseUid;
  
  /// @deprecated Use `firebaseUid` instead
  String? get loginKey => firebaseUid;

  /// @deprecated - 레거시 코드 로그인. 전화번호 인증으로 대체됨
  Future<bool> signInWithCode(String code) async {
    debugPrint('[UserProvider] signInWithCode is deprecated. Use phone auth instead.');
    return false;
  }

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

  /// 앱 시작 시 호출: Firebase 세션 확인 → Supabase 프로필 복원
  Future<void> hydrate() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      // 1. Firebase 인증 상태 변경 리스너 등록 (최초 1회만)
      _authStateSubscription ??= firebase_auth.FirebaseAuth.instance
          .authStateChanges()
          .listen(_onAuthStateChanged);

      // 2. 현재 Firebase 사용자 확인
      final fbUid = _firebaseAuth.currentUid;
      if (fbUid == null) {
        _current = null;
        return;
      }

      // 3. Supabase 익명 로그인 (Storage RLS용)
      if (_sb.auth.currentSession == null) {
        await _sb.auth.signInAnonymously();
      }

      // 4. Supabase에서 프로필 조회
      final row = await _getProfile(fbUid);
      if (row == null) {
        // Firebase는 로그인됐지만 Supabase에 없음 → 신규 사용자 생성 필요
        _current = null;
        return;
      }

      _current = _mapRowToAccount(row);
      
      // SupabaseService에 키 설정 (레거시 호환)
      _syncSupabaseServiceKeys();

      // FCM 초기화 (백그라운드에서 실행)
      FCMService.instance.initialize(firebaseUid: fbUid).catchError((e) {
        debugPrint('[UserProvider] FCM initialization failed: $e');
      });
    } catch (e) {
      debugPrint('[UserProvider] hydrate error: $e');
      _current = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Firebase 인증 상태 변경 리스너
  /// - 토큰 갱신 시 자동으로 프로필 동기화
  /// - 로그아웃 시 세션 정리
  Future<void> _onAuthStateChanged(firebase_auth.User? user) async {
    debugPrint('[UserProvider] Auth state changed: ${user?.uid}');

    if (user == null) {
      // 로그아웃됨
      if (_current != null) {
        _current = null;
        _syncSupabaseServiceKeys();
        notifyListeners();
      }
      return;
    }

    // 이미 로그인된 사용자와 동일하면 스킵 (불필요한 재로드 방지)
    if (_current?.firebaseUid == user.uid) {
      return;
    }

    // 새로운 사용자 또는 토큰 갱신 → 프로필 다시 로드
    try {
      // Supabase 익명 로그인 (Storage RLS용)
      if (_sb.auth.currentSession == null) {
        await _sb.auth.signInAnonymously();
      }

      final row = await _getProfile(user.uid);
      if (row != null) {
        _current = _mapRowToAccount(row);
        _syncSupabaseServiceKeys();
        
        // FCM 토큰이 없으면 초기화
        if (FCMService.instance.currentToken == null) {
          FCMService.instance.initialize(firebaseUid: user.uid).catchError((e) {
            debugPrint('[UserProvider] FCM initialization failed: $e');
          });
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UserProvider] _onAuthStateChanged error: $e');
    }
  }

  /// Firebase 전화번호 인증 완료 후 Supabase 연동
  /// - 기존 사용자면 로그인, 신규면 생성
  /// - 반환: (UserAccount, isNewUser)
  Future<({UserAccount? user, bool isNewUser})> syncWithSupabase({
    required String firebaseUid,
    required String phone,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      // 1. Supabase 익명 로그인 (Storage RLS용)
      if (_sb.auth.currentSession == null) {
        await _sb.auth.signInAnonymously();
      }

      // 2. RPC 호출: 조회/생성
      final res = await _sb.rpc('rpc_get_or_create_user', params: {
        'p_firebase_uid': firebaseUid,
        'p_phone': phone,
      });

      if (res == null) {
        throw Exception('rpc_get_or_create_user returned null');
      }

      final rows = (res is List) ? res : [res];
      if (rows.isEmpty) {
        throw Exception('rpc_get_or_create_user returned empty');
      }

      final row = Map<String, dynamic>.from(rows.first);
      final isNewUser = _asBool(row['is_new_user']);
      _current = _mapRowToAccount(row);

      // 3. SupabaseService에 키 설정 (레거시 호환)
      _syncSupabaseServiceKeys();

      // 4. 캐시에 Firebase UID 저장 (다음 앱 시작 시 복원용)
      await _cache.saveFirebaseUid(firebaseUid);

      // 5. FCM 초기화 (백그라운드에서 실행)
      FCMService.instance.initialize(firebaseUid: firebaseUid).catchError((e) {
        debugPrint('[UserProvider] FCM initialization failed: $e');
      });

      return (user: _current, isNewUser: isNewUser);
    } catch (e) {
      debugPrint('[UserProvider] syncWithSupabase error: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 닉네임(이름) 업데이트
  Future<void> updateNickname(String nickname) async {
    final fbUid = firebaseUid;
    if (fbUid == null) {
      throw Exception('Not logged in');
    }

    final res = await _sb.rpc('rpc_update_my_nickname', params: {
      'p_firebase_uid': fbUid,
      'p_nickname': nickname,
    });

    if (res is Map && res['success'] == true) {
      // 로컬 상태 업데이트
      if (_current != null) {
        _current = _current!.copyWith(nickname: res['nickname'] as String?);
        notifyListeners();
      }
    } else {
      throw Exception('Failed to update nickname');
    }
  }

  /// 프로필 새로고침
  Future<void> refreshProfile() async {
    final fbUid = firebaseUid;
    if (fbUid == null) return;

    try {
      final row = await _getProfile(fbUid);
      if (row != null) {
        _current = _mapRowToAccount(row);
        _syncSupabaseServiceKeys();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UserProvider] refreshProfile error: $e');
    }
  }

  /// 로그아웃: Firebase + Supabase + 캐시 정리
  Future<void> signOut() async {
    final uid = _current?.firebaseUid;
    
    try {
      // FCM 토큰 제거
      if (uid != null) {
        await FCMService.instance.removeToken(firebaseUid: uid);
      }
      
      await _firebaseAuth.signOut();
      await _sb.auth.signOut();
      await _cache.clear();
    } catch (e) {
      debugPrint('[UserProvider] signOut error: $e');
    }

    _current = null;
    
    // SupabaseService 키 초기화
    SupabaseService.instance.adminKey = null;
    SupabaseService.instance.loginKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // ===== Private Helpers =====

  /// SupabaseService에 레거시 키 설정
  void _syncSupabaseServiceKeys() {
    final svc = SupabaseService.instance;
    svc.adminKey = _current?.firebaseUid;
    svc.loginKey = _current?.firebaseUid;
  }

  Future<Map<String, dynamic>?> _getProfile(String firebaseUid) async {
    final res = await _sb.rpc('rpc_get_my_profile', params: {
      'p_firebase_uid': firebaseUid,
    });

    if (res == null) return null;
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  UserAccount _mapRowToAccount(Map<String, dynamic> row) {
    return UserAccount(
      id: _asString(row['id']),
      firebaseUid: _asString(row['firebase_uid']),
      phone: _asString(row['phone']),
      nickname: _asString(row['nickname'], '신규회원'),
      role: _asString(row['role'], 'pending'),
      isAdmin: _asBool(row['is_admin']),
      isMentor: _asBool(row['is_mentor']),
      joinedAt: _parseDate(row['joined_at']) ?? DateTime.now(),
      mentorId: row['mentor'] as String?,
      mentorName: row['mentor_name'] as String?,
      photoUrl: row['photo_url'] as String?,
    );
  }
}
