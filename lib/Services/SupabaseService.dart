// SupabaseService.dart
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
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

  /// 현재 세션 로그인 키
  String? loginKey;

  bool _adminLinkEnsured = false;

  // ---------------- 유저/멘티/멘토 관련 ----------------
  /// 서버 RPC(login_with_key) 결과를 맵으로 그대로 반환
  /// - B안 기준: mentor(uuid), mentor_name(text), is_mentor(bool) 포함
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

  /// 멘티 생성 (멘토 지정은 uuid 사용)
  Future<Map<String, dynamic>> createMentee({
    required String nickname,
    String? mentorId,   // ✅ uuid
  }) async {
    final res = await _sb.rpc('create_mentee', params: {
      'p_nickname': nickname,
      'p_mentor': mentorId,             // ✅ uuid 그대로 전달
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('create_mentee returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

  /// 최소 사용자 업데이트 (멘토 변경은 uuid 사용)
  Future<Map<String, dynamic>> updateUserMin({
    required String id,
    String? nickname,
    String? mentorId,   // ✅ uuid
  }) async {
    final res = await _sb.rpc('update_user_min', params: {
      'p_id': id,
      'p_nickname': nickname,
      'p_mentor': mentorId,            // ✅ uuid 그대로 전달
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

  // SupabaseService.dart (클래스 내부)
  Future<List<Map<String, dynamic>>> listMentors() async {
    final rows = await Supabase.instance.client
        .from('app_users')
        .select('id, nickname, photo_url')
        .eq('is_mentor', true)
        .order('nickname', ascending: true);
    if (rows is! List) return const [];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> adminListMentors() async {
    final key = adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    final res = await _sb.rpc('admin_list_mentors', params: {'p_firebase_uid': key});
    if (res == null) return <Map<String, dynamic>>[];
    final rows = (res is List) ? res : [res];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  /// 관리자: 멘토 생성
  Future<Map<String, dynamic>> adminCreateMentor({
    required String nickname,
    required DateTime hiredAt,
    String? photoUrl,
    required String loginKey,
  }) async {
    final key = adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    final res = await _sb.rpc('admin_create_mentor', params: {
      'p_firebase_uid': key,
      'p_nickname': nickname,
      'p_joined': hiredAt.toIso8601String().substring(0, 10),
      'p_photo_url': photoUrl,
      'p_firebase_uid': loginKey,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('admin_create_mentor returned empty');
    return Map<String, dynamic>.from(rows.first as Map);
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
      'p_firebase_uid': key,
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

  /// (선택) 커리큘럼 생성 RPC – 프로젝트에 이미 있으면 그대로 사용
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
      'p_firebase_uid': key,
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

  /// (관리자) 커리큘럼 삭제 — 서버에서 p_admin_key 검증
  /// - 보통 연관 시험/파일 정리까지 처리하는 RPC 이름을 가정: admin_delete_curriculum
  Future<void> adminDeleteCurriculum({
    required String code,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    await _sb.rpc('admin_delete_curriculum', params: {
      'p_firebase_uid': key,
      'p_code': code,
    });
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
      'p_firebase_uid': key,
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
      'p_firebase_uid': loginKey,
      'p_module_code': moduleCode,
      'p_answers': answers,
      'p_score': score,
    });
    final rows = (res is List) ? res : [res];
    if (rows.isEmpty) throw Exception('mentee_submit_exam returned empty');
    return Map<String, dynamic>.from(rows.first);
  }

  // ---------------- 갤러리에서 동영상 선택 (image_picker 기반) ----------------
  /// 기존 호출부 호환을 위해 메서드명/반환타입 유지
  /// - iOS: 사진 앱(PHPicker) → 사용자 경험상 "갤러리"가 열림
  /// - Android: Android Photo Picker(13+) / MediaStore(하위)
  Future<PickedLocalFile?> pickOneFile() async {
    final ImagePicker picker = ImagePicker();

    // 갤러리(사진 앱)에서 비디오 선택
    final XFile? x = await picker.pickVideo(
      source: ImageSource.gallery,
      // 필요시 길이 제한
      // maxDuration: const Duration(minutes: 10),
    );

    if (x == null) return null;

    final String path = x.path;
    final String name = path.split(Platform.pathSeparator).last;
    String? ext;
    final int dotIdx = name.lastIndexOf('.');
    if (dotIdx >= 0 && dotIdx < name.length - 1) {
      ext = name.substring(dotIdx + 1).toLowerCase();
    }

    return PickedLocalFile(
      name: name,
      path: path,
      extension: ext,
    );
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

  // ===================== Mentors (Admin) =====================

  Future<Map<String, dynamic>?> _rpcSingle(String fn, Map<String, dynamic> params) async {
    // ✅ .select() 제거
    final res = await _sb.rpc(fn, params: params);
    if (res == null) return null;
    if (res is List && res.isNotEmpty) return Map<String, dynamic>.from(res.first as Map);
    if (res is Map) return Map<String, dynamic>.from(res as Map);
    return null;
  }

  Future<List<Map<String, dynamic>>> _rpcList(String fn, Map<String, dynamic> params) async {
    // ✅ .select() 제거
    final res = await _sb.rpc(fn, params: params);
    if (res == null) return const <Map<String, dynamic>>[];
    final rows = (res is List) ? res : [res];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  Future<Map<String, dynamic>?> adminMentorOverview({
    required String mentorId,
    int avgDays = 90,
    int recentDays = 7,
    String? adminKey,
  }) async {

    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) throw Exception('adminKey is missing');
    return _rpcSingle('admin_mentor_overview', {
      'p_firebase_uid': key,
      'p_avg_days': avgDays,
      'p_mentor_id': mentorId,
      'p_recent_days': recentDays,
    });
  }

  Future<List<Map<String, dynamic>>> adminListMenteesOfMentor({
    required String mentorId,
    bool onlyPending = false,
    int limit = 200,
    int offset = 0,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) throw Exception('adminKey is missing');
    return _rpcList('admin_list_mentees_of_mentor', {
      'p_firebase_uid': key,
      'p_mentor_id': mentorId,
      'p_only_pending': onlyPending,
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  Future<int> adminAssignMenteesToMentor({
    required String mentorId,
    required List<String> menteeIds,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) throw Exception('adminKey is missing');
    final rows = await _rpcList('admin_assign_mentees_to_mentor', {
      'p_firebase_uid': key,
      'p_mentor_id': mentorId,
      'p_mentee_ids': menteeIds,
    });
    if (rows.isEmpty) return 0;
    return (rows.first['updated_count'] as num?)?.toInt() ?? 0;
  }

  Future<int> adminUnassignMentees({
    required List<String> menteeIds,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) throw Exception('adminKey is missing');
    final rows = await _rpcList('admin_unassign_mentees', {
      'p_firebase_uid': key,
      'p_mentee_ids': menteeIds,
    });
    // 서버는 {id, nickname, mentor} 행들을 반환하므로
    // 반환된 행 수를 업데이트된 멘티 수로 사용한다.
    return rows.length;
  }

  Future<Map<String, dynamic>?> adminReassignMentee({
    required String menteeId,
    required String newMentorId,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) throw Exception('adminKey is missing');
    return _rpcSingle('admin_reassign_mentee', {
      'p_firebase_uid': key,
      'p_mentee_id': menteeId,
      'p_new_mentor_id': newMentorId,
    });
  }

  Future<List<Map<String, dynamic>>> adminListMenteePracticeAttempts({
    required String menteeId,
    int limit = 50,
    int offset = 0,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) throw Exception('adminKey is missing');
    return _rpcList('admin_list_mentee_practice_attempts', {
      'p_firebase_uid': key,
      'p_mentee_id': menteeId,
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  Future<List<Map<String, dynamic>>> adminListUnassignedMentees({
    String? search,
    int limit = 200,
    int offset = 0,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    return _rpcList('admin_list_unassigned_mentees', {
      'p_firebase_uid': key,
      'p_search': (search == null || search.trim().isEmpty) ? null : search.trim(),
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  // ===================== 실습 세트(Practice Sets) =====================

  /// (관리자) 실습 세트 Upsert
  /// - 서버 RPC: admin_upsert_practice_set
  /// - referenceImages: jsonb 배열 (URL 또는 스토리지 경로)
  Future<Map<String, dynamic>> adminUpsertPracticeSet({
    required String code,
    required String title,
    String? instructions,
    required List<String> referenceImages,
    required bool active,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }

    final res = await _sb.rpc('admin_upsert_practice_set', params: {
      'p_firebase_uid': key,
      'p_code': code,
      'p_title': title,
      'p_instructions': instructions,
      'p_reference_images': referenceImages, // ← 반드시 배열(jsonb)
      'p_active': active,
    });

    final row = (res is List && res.isNotEmpty) ? res.first : res;
    if (row == null) {
      throw Exception('admin_upsert_practice_set returned null');
    }
    return Map<String, dynamic>.from(row as Map);
  }

  /// (관리자) 실습 세트 목록
  /// - activeOnly: true=active만 / false=inactive만 / null=전체
  /// - 서버 RPC: admin_list_practice_sets
  Future<List<Map<String, dynamic>>> adminListPracticeSets({
    bool? activeOnly,
    int limit = 200,
    int offset = 0,
    String? adminKey,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }

    final res = await _sb.rpc('admin_list_practice_sets', params: {
      'p_firebase_uid': key,
      'p_active_only': activeOnly, // null 허용
      'p_limit': limit,
      'p_offset': offset,
    });

    if (res == null) return const <Map<String, dynamic>>[];
    final rows = (res is List) ? res : [res];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  /// (관리자) 실습 세트 삭제
  /// - 서버 RPC: admin_delete_practice_set
  Future<void> adminDeletePracticeSet({
    required String code,
    String? adminKey, // 필요하면 외부에서 주입
  }) async {
    final key = adminKey ?? this.adminKey; // this.adminKey를 쓰고 있다면 유지
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }
    await _sb.rpc(
      'admin_delete_practice_set',
      params: {
        'p_firebase_uid': key,
        'p_code': code,
      },
    );
  }

  // ===================== Mentor RPCs =====================

  Future<Map<String, dynamic>?> mentorOverview({
    int avgDays = 90,
    int recentDays = 7,
  }) {
    return _rpcSingle('mentor_overview', {
      'p_firebase_uid': loginKey,
      'p_avg_days': avgDays,
      'p_recent_days': recentDays,
    });
  }

  Future<List<Map<String, dynamic>>> mentorListMyMentees({
    bool onlyPending = false,
    int limit = 200,
    int offset = 0,
  }) {
    return _rpcList('mentor_list_my_mentees', {
      'p_firebase_uid': loginKey,
      'p_only_pending': onlyPending,
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  Future<List<Map<String, dynamic>>> mentorListPendingQueue({
    int limit = 50,
    int offset = 0,
  }) {
    return _rpcList('mentor_list_pending_queue', {
      'p_firebase_uid': loginKey,
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  Future<List<Map<String, dynamic>>> mentorListHistory({
    int lastNDays = 30,
    int limit = 50,
    int offset = 0,
  }) {
    return _rpcList('mentor_list_history', {
      'p_firebase_uid': loginKey,
      'p_last_n_days': lastNDays,
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  Future<Map<String, dynamic>?> mentorGetAttempt(String attemptId) {
    return _rpcSingle('mentor_get_attempt', {
      'p_firebase_uid': loginKey,
      'p_attempt_id': attemptId,
    });
  }

  Future<List<Map<String, dynamic>>> mentorListPrevAttempts({
    required String menteeId,
    required String setId,
    String? excludeAttemptId,
    int limit = 20,
  }) {
    return _rpcList('mentor_list_prev_attempts', {
      'p_firebase_uid': loginKey,
      'p_mentee_id': menteeId,
      'p_set_id': setId,
      'p_exclude_id': excludeAttemptId,
      'p_limit': limit,
    });
  }

  Future<Map<String, dynamic>?> mentorReviewAttempt({
    required String attemptId,
    required String gradeKor, // '상'|'중'|'하'
    required String feedback,
  }) {
    return _rpcSingle('mentor_review_attempt', {
      'p_firebase_uid': loginKey,
      'p_attempt_id': attemptId,
      'p_grade_kor': gradeKor,
      'p_feedback': feedback,
    });
  }

  // ---------- Practice: Mentee ----------

  // A) 실습 세트 목록 (active=true만) — RPC 없이 테이블 셀렉트로 시작해도 OK
  Future<List<Map<String, dynamic>>> menteeListPracticeSets({bool onlyActive = true}) async {
    final rows = await _sb
        .from('practice_sets')
        .select('id, code, title, instructions, reference_images, active')
        .eq('active', true)                 // ← filter 먼저
        .order('code', ascending: true);    // ← order는 마지막

    if (rows is! List) return const [];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // B) 세트 상세 (code 기반, attempts는 jsonb로 반환됨)
  Future<Map<String, dynamic>?> menteePracticeSetDetail({
    required String code,
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing. Please ensure Firebase authentication is complete.');
    }
    
    final res = await _sb.rpc('mentee_practice_set_detail', params: {
      'p_code': code,
      'p_firebase_uid': key,
    });
    if (res == null) return null;
    final row = (res is List && res.isNotEmpty) ? res.first : res;
    return Map<String, dynamic>.from(row as Map);
  }

  // C) 시작/이어하기
  Future<Map<String, dynamic>?> menteeStartOrContinue({required String setId}) async {
    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing. Please ensure Firebase authentication is complete.');
    }
    
    final res = await _sb.rpc('mentee_start_or_continue', params: {
      'p_login_key': key,
      'p_set_id': setId,
    });
    if (res == null) return null;
    final row = (res is List && res.isNotEmpty) ? res.first : res;
    return Map<String, dynamic>.from(row as Map);
  }

  // D) 제출(이미 경로 배열이 준비됐다고 가정; 스토리지 후반)
  Future<Map<String, dynamic>?> menteeSubmitAttempt({
    required String attemptId,
    required List<String> imagePaths,
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing. Please ensure Firebase authentication is complete.');
    }
    
    final res = await _sb.rpc('mentee_submit_attempt', params: {
      'p_login_key': key,
      'p_attempt_id': attemptId,
      'p_image_paths': imagePaths,
    });
    if (res == null) return null;
    final row = (res is List && res.isNotEmpty) ? res.first : res;
    return Map<String, dynamic>.from(row as Map);
  }

  // 공용 헬퍼: 상태 → 뱃지 라벨
  String practiceStatusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'draft': return '제출 준비';
      case 'submitted': return '검토 대기';
      case 'reviewing': return '검토 중';
      case 'reviewed': return '검토 완료';
      default: return '시도 없음';
    }
  }

  // 완료율 계산(“검토 완료” 건 기준)
  Future<double> menteePracticeCompletionRatio() async {

    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing. Make sure UserProvider injected SupabaseService.loginKey after sign-in/hydrate.');
    }

    final res = await _sb.rpc('mentee_practice_completion_ratio', params: {
      'p_firebase_uid': key,
    });

    if (res == null) return 0.0;
    // RPC는 row 또는 rows로 올 수 있음 → 통일 처리
    final row = (res is List && res.isNotEmpty) ? res.first : res;
    if (row is! Map) return 0.0;

    final r = row['ratio'];
    if (r is num) return r.toDouble();
    return double.tryParse(r?.toString() ?? '0') ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> menteeListLatestAttemptsBySet() async {
    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing');
    }
    final res = await _sb.rpc('mentee_list_latest_attempts_by_set', params: {
      'p_firebase_uid': key,
    });
    if (res == null) return const <Map<String, dynamic>>[];
    final rows = (res is List) ? res : [res];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMenteeSetsForMentor({
    required String menteeId,
    int limit = 200,
    int offset = 0,
  }) async {
    final key = loginKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('mentor loginKey가 필요합니다.');
    }

    try {
      final result = await _sb.rpc(
        'mentor_list_mentee_sets',
        params: {
          'p_firebase_uid': key,
          'p_mentee_id': menteeId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      // supabase rpc()는 List/Map 그대로 내려옵니다.
      final list = (result as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return list;
    } on PostgrestException catch (e) {
      // 서버 에러 메시지 그대로 보면서 디버그 용이하게
      throw Exception('RPC mentor_list_mentee_sets 실패: ${e.message}');
    } catch (e) {
      throw Exception('RPC mentor_list_mentee_sets 실패: $e');
    }
  }

  /// 진행률 계산 도우미 (필요시 사용)
  /// - attempted == true 인 항목 수를 완료로 간주
  Map<String, dynamic> computeMenteeProgress(List<Map<String, dynamic>> sets) {
    final total = sets.length;
    final done = sets.where((e) => (e['attempted'] == true)).length;
    final percent = total == 0 ? 0.0 : (done / total);
    return {
      'total': total,
      'done': done,
      'percent': percent, // 0.0 ~ 1.0
    };
  }

  Future<List<Map<String, dynamic>>> adminFetchMenteeSets({
    required String menteeId,
    int limit = 200,
    int offset = 0,
  }) async {
    final key = adminKey ?? this.adminKey;
    if (key == null || key.isEmpty) {
      throw Exception('adminKey is missing');
    }

    final rows = await _sb
        .rpc('admin_list_mentee_sets', params: {
      'p_firebase_uid': key,
      'p_mentee_id': menteeId,
      'p_limit': limit,
      'p_offset': offset,
    })
        .select(); // Supabase Dart v2

    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ===================== Daily Journal (일일 일지) =====================

  /// [멘티] 오늘의 일지 조회 (없으면 null)
  Future<Map<String, dynamic>?> menteeGetTodayJournal() async {
    final key = loginKey;
    if (key == null || key.isEmpty) throw Exception('loginKey is missing');

    return _rpcSingle('mentee_get_today_journal', {
      'p_firebase_uid': key,
    });
  }

  /// [멘티] 일일 일지 배지 필요 여부
  /// - true: 하단 탭에 빨간 점 표시
  ///   - 오늘 일지를 아직 한 번도 제출하지 않았거나
  ///   - 오늘 일지의 최신 메시지가 멘토(from mentor)이고, 아직 확인/답장(멘티 메시지)으로 처리되지 않은 경우
  /// - false: 점 숨김
  Future<bool> menteeJournalNeedDot() async {
    final data = await menteeGetTodayJournal();
    // 오늘 일지가 아예 없으면 → 제출 유도용 점
    if (data == null) return true;

    final rawMsgs = (data['messages'] as List?) ?? const [];
    if (rawMsgs.isEmpty) {
      // 일지는 있지만 메시지가 없다면(이상 케이스) 점은 숨김
      return false;
    }

    // mentee_get_today_journal은 오래된 순으로 내려오므로 마지막이 최신
    final Map<String, dynamic> latest =
        Map<String, dynamic>.from(rawMsgs.last as Map);

    final bool isMine = latest['is_mine'] == true;
    final bool confirmed = latest['confirmed_at'] != null;

    // 최신 메시지가 멘티(나)의 메시지이거나, 이미 확인 처리된 경우 → 새 피드백 없음
    if (isMine || confirmed) return false;

    // 최신 메시지가 멘토 메시지이고 아직 미확인이라면 → 새 피드백 알림 점
    return true;
  }

  /// [멘티] 일지 제출 (생성 또는 메시지 추가)
  Future<Map<String, dynamic>> menteeSubmitJournalEntry({
    required String content,
    required List<String> photos,
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) throw Exception('loginKey is missing');

    final res = await _rpcSingle('mentee_submit_journal_entry', {
      'p_firebase_uid': key,
      'p_content': content,
      'p_photos': photos,
    });
    if (res == null) throw Exception('mentee_submit_journal_entry returned null');
    return res;
  }

  /// [멘토] 일지 목록 조회 (대시보드용)
  Future<List<Map<String, dynamic>>> mentorListDailyJournals({
    DateTime? date,
    String? statusFilter, // 'pending' | 'replied' | etc
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) throw Exception('loginKey is missing');

    return _rpcList('mentor_list_daily_journals', {
      'p_firebase_uid': key,
      'p_date': date?.toIso8601String().substring(0, 10),
      'p_status': statusFilter, // ✅ p_status_filter → p_status
    });
  }

  /// [멘토] 특정 멘티의 월별 일지 목록 (히스토리/달력용)
  /// - from, to: YYYY-MM-DD (보통 한 달 범위)
  /// - 반환: [{ journal_id, date, status }, ...]
  Future<List<Map<String, dynamic>>> mentorListMenteeJournalsByMonth({
    required String menteeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing');
    }
    return _rpcList('mentor_list_mentee_journals_by_month', {
      'p_firebase_uid': key,
      'p_mentee_id': menteeId,
      'p_from': from.toIso8601String().substring(0, 10),
      'p_to': to.toIso8601String().substring(0, 10),
    });
  }

  /// [멘토] 답장하기
  Future<void> mentorReplyJournal({
    required String journalId,
    required String content,
    required List<String> photos,
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) throw Exception('loginKey is missing');

    await _rpcSingle('mentor_reply_journal', {
      'p_firebase_uid': key,
      'p_journal_id': journalId,
      'p_content': content,
      'p_photos': photos,
    });
  }

  /// [공통] 메시지 확인(Ack) 처리
  Future<void> commonConfirmMessage({required int messageId}) async {
    final key = loginKey;
    if (key == null || key.isEmpty) throw Exception('loginKey is missing');

    await _rpcSingle('common_confirm_message', {
      'p_firebase_uid': key,
      'p_message_id': messageId,
    });
  }

  /// [공통] 일지 상세(메시지 스레드) 조회
  Future<Map<String, dynamic>?> getJournalDetail({required String journalId}) async {
    final key = loginKey;
    if (key == null || key.isEmpty) throw Exception('loginKey is missing');

    return _rpcSingle('get_journal_detail', {
      'p_firebase_uid': key,
      'p_journal_id': journalId,
    });
  }

  /// [멘티] 오늘 제출 여부 확인 (배지용)

  /// [멘티] 월별 일지 목록 (히스토리/달력용)
  /// - from, to는 YYYY-MM-DD 기준 (보통 한 달 범위)
  /// - 반환: [{ journal_id, date, status }, ...]
  Future<List<Map<String, dynamic>>> menteeListJournalsByMonth({
    required DateTime from,
    required DateTime to,
  }) async {
    final key = loginKey;
    if (key == null || key.isEmpty) {
      throw Exception('loginKey is missing');
    }
    return _rpcList('mentee_list_journals_by_month', {
      'p_firebase_uid': key,
      'p_from': from.toIso8601String().substring(0, 10),
      'p_to': to.toIso8601String().substring(0, 10),
    });
  }

  /// [공통] 일지 사진 업로드 (단건) -> Storage Path 반환
  Future<String> uploadJournalPhoto(File file) async {
    final now = DateTime.now();
    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final timestamp = now.millisecondsSinceEpoch;
    final ext = file.path.split('.').last;
    final name = "${timestamp}_${_randomString(6)}.$ext";
    // loginKey로 user_id를 알 수 있지만, 여기선 단순하게 날짜별 폴더링만 함 (RPC에서 검증)
    final path = "$dateStr/$name";

    await _sb.storage.from('daily_journals').upload(
      path,
      file,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    return path;
  }

  /// [공통] 일지 사진 URL 조회
  String getJournalPhotoUrl(String path) {
    if (path.startsWith('http')) return path;
    return _sb.storage.from('daily_journals').getPublicUrl(path);
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}
