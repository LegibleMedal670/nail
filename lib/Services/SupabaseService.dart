import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';

/// UI에서 파일 업로드는 아직 하지 않으므로, 선택 결과만 담는 경량 모델
class PickedLocalFile {
  final String name;
  final String? path;
  final String? extension;
  const PickedLocalFile({required this.name, this.path, this.extension});
}

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  final SupabaseClient _sb = Supabase.instance.client;

  /// 관리자 편집용 키(관리자 접속코드). 로그인 성공 시 UserProvider가 주입.
  String? adminKey;

  bool _adminLinkEnsured = false;

  // ---------------- 유저/멘티 관련 ----------------
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

  // ---------------- 커리큘럼 ----------------
  /// ✅ 뷰 curriculum_modules_v 사용 (has_exam 포함)
  Future<List<CurriculumItem>> listCurriculumItems({int? version}) async {
    const sel =
        'code, week, title, summary, has_video, video_url, version, resources, goals, has_exam, thumb_url';

    PostgrestFilterBuilder<dynamic> q = _sb.from('curriculum_modules_v').select(sel);
    if (version != null) q = q.eq('version', version);

    final data = await q.order('week', ascending: true);
    if (data is! List) return const <CurriculumItem>[];

    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_mapCurriculumRow)
        .toList(growable: false);
  }

  /// ✅ 단건 조회도 뷰 사용
  Future<CurriculumItem?> getCurriculumItemByCode(String code) async {
    const sel =
        'code, week, title, summary, has_video, video_url, version, resources, goals, has_exam, thumb_url';

    final row = await _sb
        .from('curriculum_modules_v')
        .select(sel)
        .eq('code', code)
        .maybeSingle();

    if (row == null) return null;
    return _mapCurriculumRow(Map<String, dynamic>.from(row as Map));
  }

  /// ✅ 최신 커리큘럼 버전 (호환 유지)
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

  /// (관리자) 목표/자료/비디오 경로를 한 번에 저장 — 서버에서 p_admin_key 검증
  /// (관리자) 목표/자료 + 비디오/썸네일 경로 저장
  /// - videoPathOrNull: null=변경없음, ''=해제, 'path'=설정
  /// - thumbPathOrNull: 규칙 동일
  Future<void> saveEditsViaRpc({
    required String code,
    required List<String> goals,
    required List<Map<String, dynamic>> resources,
    String? videoPathOrNull,
    String? thumbPathOrNull,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    await _sb.rpc('admin_update_curriculum', params: {
      'p_admin_key': key,
      'p_code': code,
      'p_goals': goals,
      'p_resources': resources,
      'p_video_url': videoPathOrNull,
      'p_thumb_url': thumbPathOrNull,
    });
  }


  Future<void> ensureAdminSessionLinked({String? adminKeyOverride}) async {
    // 1) 세션이 없으면 익명 로그인
    if (_sb.auth.currentSession == null || _sb.auth.currentUser == null) {
      await _sb.auth.signInAnonymously();
    }

    // 2) 관리자 키 확인
    final key = adminKeyOverride ?? adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing (관리자 접속코드가 필요합니다)');
    }

    // 3) 너무 자주 호출하지 않기 위한 1회캐시 (앱 재시작 전까지)
    if (_adminLinkEnsured) return;

    // 4) 로그인 RPC 호출 → app_user_auth_links에 (user_id, auth_user_id) 매핑 생성
    await _sb.rpc('login_with_key', params: {'p_key': key});

    _adminLinkEnsured = true;
  }


  /// (선택) 커리큘럼 생성 RPC – 프로젝트에 이미 있으면 그대로 사용 TODO 동영상
  Future<CurriculumItem> createCurriculumViaRpc({
    required String code,
    required int week,
    required String title,
    required String summary,
    required List<String> goals,
    required List<Map<String, dynamic>> resources,
    String? videoUrl,
    String? adminKeyOverride,
  }) async {
    final key = adminKeyOverride ?? adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing (관리자 접속코드가 필요합니다)');
    }

    final res = await _sb.rpc('admin_create_curriculum', params: {
      'p_admin_key': key,
      'p_code': code,
      'p_week': week,
      'p_title': title,
      'p_summary': summary,
      'p_goals': goals,
      'p_resources': resources,
      'p_video_url': videoUrl,
    });

    final row = (res is List && res.isNotEmpty) ? res.first : res;
    if (row == null) {
      throw Exception('admin_create_curriculum returned null');
    }
    return _mapCurriculumRow(Map<String, dynamic>.from(row as Map));
  }

  /// 제안 주차
  Future<int> nextSuggestedWeek() async {
    final res = await _sb.rpc('next_suggested_week');
    if (res is int) return res;
    if (res is num) return res.toInt();
    return 1;
  }

  // ---------------- 시험 ----------------
  Future<Map<String, dynamic>?> getExamSet({required String moduleCode}) async {
    final res = await _sb.rpc('get_exam_set', params: {'p_module_code': moduleCode});
    if (res == null) return null;
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> adminUpsertExamSet({
    required String moduleCode,
    required int passScore,
    required List<Map<String, dynamic>> questions,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    final res = await _sb.rpc('admin_upsert_exam_set', params: {
      'p_admin_key': key,
      'p_module_code': moduleCode,
      'p_pass_score': passScore,
      'p_questions': questions,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('admin_upsert_exam_set returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> menteeSubmitExam({
    required String loginKey,
    required String moduleCode,
    required Map<String, dynamic> answers,
    required int score,
  }) async {
    final res = await _sb.rpc('mentee_submit_exam', params: {
      'p_login_key': loginKey,
      'p_module_code': moduleCode,
      'p_answers': answers,
      'p_score': score,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('mentee_submit_exam returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

  // ---------------- 파일피커(UI용) ----------------
  Future<PickedLocalFile?> pickOneFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withReadStream: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    return PickedLocalFile(name: f.name, path: f.path, extension: f.extension);
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

    final bool requiresExam = r['has_exam'] == true;

    final dynamic resourcesRaw = r['resources'];
    final List<Map<String, dynamic>> resources = (resourcesRaw is List)
        ? resourcesRaw
        .whereType<dynamic>()
        .map<Map<String, dynamic>>(
          (e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{},
    )
        .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final dynamic goalsRaw = r['goals'];
    final List<String> goals = (goalsRaw is List)
        ? goalsRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList(growable: false)
        : const <String>[];

    final int? version = (r['version'] is int)
        ? r['version'] as int
        : int.tryParse('${r['version'] ?? ''}');

    final String? thumbUrl = (r['thumb_url'] as String?)?.trim();

    return CurriculumItem(
      id: id,
      week: week,
      title: title,
      summary: summary,
      hasVideo: hasVideo,
      videoUrl: (videoUrl?.isEmpty == true) ? null : videoUrl,
      requiresExam: requiresExam,
      version: version,
      resources: resources,
      goals: goals,
      durationMinutes: 0,
      thumbUrl: (thumbUrl?.isEmpty == true) ? null : thumbUrl,
    );
  }

}
