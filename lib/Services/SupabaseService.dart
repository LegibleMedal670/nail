import 'package:nail/Pages/Manager/models/curriculum_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  final SupabaseClient _sb = Supabase.instance.client;

  // ---------------- 유저/멘티 관련은 그대로 유지 ----------------
  Future<Map<String, dynamic>?> loginWithKey(String loginKey) async {
    final res = await _sb.rpc('login_with_key', params: {'p_key': loginKey});
    if (res == null) return null;
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<String> generateUniqueLoginCode({int digits = 4}) async {
    final res = await _sb.rpc('generate_unique_login_code', params: {'digits': digits});
    if (res is String) return res;
    if (res is List && res.isNotEmpty) return res.first as String;
    throw Exception('failed to generate login code');
  }

  Future<Map<String, dynamic>> createMentee({
    required String nickname,
    required DateTime joinedAt,
    String? mentor,
    String? photoUrl,
    String? loginKey,
  }) async {
    final res = await _sb.rpc('create_mentee', params: {
      'p_nickname': nickname,
      'p_joined': joinedAt.toIso8601String().substring(0, 10),
      'p_mentor': mentor,
      'p_photo_url': photoUrl,
      'p_login_key': loginKey,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('create_mentee returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

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

  Future<List<Map<String, dynamic>>> listMentees() async {
    final res = await _sb.rpc('list_mentees');
    if (res == null) return [];
    final rows = (res is List) ? res : [res];
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> deleteUser({required String id}) async {
    await _sb.rpc('delete_user', params: {'p_id': id});
  }

  // ---------------- 커리큘럼: 테이블 스키마와 1:1로 맞춤 ----------------

  /// 커리큘럼 모듈 목록 (주차 오름차순). 테이블 컬럼: code, week, title, summary, has_video, video_url, exam_set_code, version
  Future<List<CurriculumItem>> listCurriculumItems({int? version}) async {
    const sel = 'code, week, title, summary, has_video, video_url, exam_set_code, version';

    PostgrestFilterBuilder<dynamic> q = _sb.from('curriculum_modules').select(sel);
    if (version != null) q = q.eq('version', version);

    final data = await q.order('week', ascending: true);

    print(data);

    if (data is! List) return const <CurriculumItem>[];

    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_mapCurriculumRow)
        .toList(growable: false);
  }

  /// 단일 모듈 조회 (code 기준)
  Future<CurriculumItem?> getCurriculumItemByCode(String code) async {
    const sel = 'code, week, title, summary, has_video, video_url, exam_set_code, version';

    final row = await _sb
        .from('curriculum_modules')
        .select(sel)
        .eq('code', code)
        .maybeSingle();

    if (row == null) return null;
    return _mapCurriculumRow(Map<String, dynamic>.from(row as Map));
  }

  /// 최신 커리큘럼 버전
  Future<int?> latestCurriculumVersion() async {
    final row = await _sb
        .from('curriculum_modules')
        .select('version')
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    final v = (row as Map)['version'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  // ---- 내부 매퍼: DB row -> UI 모델 ----
  CurriculumItem _mapCurriculumRow(Map<String, dynamic> r) {
    final String id = (r['code'] ?? r['id'] ?? '').toString();

    final int week = int.tryParse('${r['week']}') ?? 0;
    final String title = (r['title'] ?? '') as String;
    final String summary = (r['summary'] ?? '') as String;

    final String? videoUrl = (r['video_url'] as String?)?.trim();
    final bool hasVideo =
        (r['has_video'] == true) || (videoUrl != null && videoUrl.isNotEmpty);

    // exam_set_code가 비어있지 않으면 시험 필요
    final bool requiresExam =
    ((r['exam_set_code'] as String?)?.trim().isNotEmpty ?? false);

    return CurriculumItem(
      id: id,
      week: week,
      title: title,
      summary: summary,
      // 모델에 아직 durationMinutes가 남아있으므로 0으로 채움
      durationMinutes: 0,
      hasVideo: hasVideo,
      videoUrl: (videoUrl?.isEmpty == true) ? null : videoUrl,
      requiresExam: requiresExam,
    );
  }
}
