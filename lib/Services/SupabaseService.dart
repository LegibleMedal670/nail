import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:nail/Pages/Manager/models/curriculum_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  /// 커리큘럼 모듈 목록 (주차 오름차순).
  /// 테이블 컬럼: code, week, title, summary, has_video, video_url, exam_set_code, version, resources, goals
  Future<List<CurriculumItem>> listCurriculumItems({int? version}) async {
    const sel =
        'code, week, title, summary, has_video, video_url, exam_set_code, version, resources, goals';

    PostgrestFilterBuilder<dynamic> q = _sb.from('curriculum_modules').select(sel);
    if (version != null) q = q.eq('version', version);

    final data = await q.order('week', ascending: true);
    if (data is! List) return const <CurriculumItem>[];

    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_mapCurriculumRow)
        .toList(growable: false);
  }

  /// 단일 모듈 조회 (code 기준)
  Future<CurriculumItem?> getCurriculumItemByCode(String code) async {
    const sel =
        'code, week, title, summary, has_video, video_url, exam_set_code, version, resources, goals';

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

  /// (관리자) 목표/자료를 한 번에 저장 — 앱은 Supabase Auth 미사용 → 서버에서 p_admin_key 검증
  Future<void> saveEditsViaRpc({
    required String code,
    required List<String> goals,
    required List<Map<String, dynamic>> resources,
    String? adminKey, // 주입 없으면 필드 사용
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }

    final res = await _sb.rpc('admin_update_curriculum', params: {
      'p_admin_key': key,
      'p_code': code,
      'p_goals': goals,
      'p_resources': resources,
    });

    // RPC가 오류 시 PostgrestException을 던짐. 별도 처리 필요 시 여기에.
    // res는 보통 void 또는 {ok:true} 정도로 가정.
  }

  // ---- 내부 매퍼: DB row -> UI 모델 ----
  CurriculumItem _mapCurriculumRow(Map<String, dynamic> r) {
    // code 우선, 없으면 id fallback
    final String id = (r['code'] ?? r['id'] ?? '').toString();

    final int week = int.tryParse('${r['week']}') ?? 0;
    final String title = (r['title'] ?? '') as String;
    final String summary = (r['summary'] ?? '') as String;

    // 동영상 여부: has_video 또는 video_url 유무
    final String? videoUrl = (r['video_url'] as String?)?.trim();
    final bool hasVideo =
        (r['has_video'] == true) || (videoUrl != null && videoUrl.isNotEmpty);

    // 시험 필요 여부: exam_set_code 존재 시 true
    final String? examSetCode = (r['exam_set_code'] as String?)?.trim();
    final bool requiresExam = (examSetCode != null && examSetCode.isNotEmpty);

    // resources: jsonb 배열 가정. 형태 안전 처리
    final dynamic resourcesRaw = r['resources'];
    final List<Map<String, dynamic>> resources = (resourcesRaw is List)
        ? resourcesRaw
        .whereType<dynamic>()
        .map<Map<String, dynamic>>(
          (e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{},
    )
        .toList(growable: false)
        : const <Map<String, dynamic>>[];

    // goals: text[] 또는 jsonb[] 가정. 문자열 리스트로 표준화
    final dynamic goalsRaw = r['goals'];
    final List<String> goals = (goalsRaw is List)
        ? goalsRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList(growable: false)
        : const <String>[];

    return CurriculumItem(
      id: id,
      week: week,
      title: title,
      summary: summary,
      durationMinutes: 0, // 아직 DB 없음
      hasVideo: hasVideo,
      videoUrl: (videoUrl?.isEmpty == true) ? null : videoUrl,
      requiresExam: requiresExam,
      examSetCode: examSetCode,
      resources: resources,
      goals: goals,
    );
  }

  // ---------------- 파일피커(UI용) ----------------
  /// 업로드는 하지 않고, 파일 1개 선택만 수행. (디테일 페이지 자료 편집 시트에서 사용)
  Future<PickedLocalFile?> pickOneFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withReadStream: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    return PickedLocalFile(
      name: f.name,
      path: f.path,
      extension: f.extension,
    );
  }
}
