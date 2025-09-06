import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient _sb = Supabase.instance.client;

  // 로그인 (login_key로 조회)
  Future<Map<String, dynamic>?> loginWithKey(String loginKey) async {
    final res = await _sb.rpc('login_with_key', params: {'p_key': loginKey});
    if (res == null) return null;
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  // (옵션) 고유 4자리 코드 생성
  Future<String> generateUniqueLoginCode({int digits = 4}) async {
    final res = await _sb.rpc('generate_unique_login_code', params: {'digits': digits});
    if (res is String) return res;
    if (res is List && res.isNotEmpty) return res.first as String;
    throw Exception('failed to generate login code');
  }

  // 멘티 생성: p_login_key가 null이면 서버가 자동 생성
  Future<Map<String, dynamic>> createMentee({
    required String nickname,
    required DateTime joinedAt,
    String? mentor,
    String? photoUrl,
    String? loginKey,
  }) async {
    final res = await _sb.rpc('create_mentee', params: {
      'p_nickname': nickname,
      'p_joined': joinedAt.toIso8601String().substring(0, 10), // yyyy-mm-dd
      'p_mentor': mentor,
      'p_photo_url': photoUrl,
      'p_login_key': loginKey,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('create_mentee returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

  // 유저 최소 업데이트
  Future<Map<String, dynamic>> updateUserMin({
    required String id,
    String? nickname,
    DateTime? joinedAt,
    String? mentor,
    String? photoUrl,
    String? loginKey,
  }) async {
    final res = await _sb.rpc('update_user_min', params: {
      'p_id': id,
      'p_nickname': nickname,
      'p_joined': joinedAt == null ? null : joinedAt.toIso8601String().substring(0, 10),
      'p_mentor': mentor,
      'p_photo_url': photoUrl,
      'p_login_key': loginKey,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('update_user_min returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

  /// 멘티 목록 조회 (list_mentees RPC 사용)
  Future<List<Map<String, dynamic>>> listMentees() async {
    final res = await _sb.rpc('list_mentees');
    if (res == null) return [];
    final rows = (res is List) ? res : [res];
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// 멘티/유저 삭제 (RPC: delete_user)
  Future<void> deleteUser({required String id}) async {
    final res = await _sb.rpc('delete_user', params: {'p_id': id});
    // Supabase rpc()는 성공 시 data가 null일 수 있음 → 에러면 PostgrestException이 throw됨.
    return;
  }

}
