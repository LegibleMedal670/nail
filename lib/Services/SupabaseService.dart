import 'package:supabase_flutter/supabase_flutter.dart';

/// 서버와의 통신을 한 곳에서 관리.
/// 화면은 저수준 RPC/쿼리를 몰라도 되고, 메서드만 호출하면 됩니다.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final SupabaseClient _sb = Supabase.instance.client;

  /// 로그인: login_key로 사용자 1명 조회 (관리자/멘티 겸용)
  /// 성공: { id, is_admin, nickname, joined_at, mentor, photo_url }
  /// 실패: null
  Future<Map<String, dynamic>?> loginWithKey(String loginKey) async {
    final res = await _sb.rpc('login_with_key', params: {'p_key': loginKey});
    if (res == null) return null;

    // Supabase는 단일 row도 List로 오는 경우가 있어 방어
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) return null;

    return Map<String, dynamic>.from(rows.first);
  }

// === 확장 포인트 예시 (필요해지면 추가) ===
// Future<void> updateVideoProgress(...) async { ... }
// Future<Map<String, dynamic>> submitExam(...) async { ... }
// Future<List<Map<String, dynamic>>> getExamForCurriculum(...) async { ... }
}
