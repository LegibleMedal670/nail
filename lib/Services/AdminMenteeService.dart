import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/CourseProgressService.dart';

class AdminMenteeService {
  AdminMenteeService._();
  static final instance = AdminMenteeService._();

  final SupabaseClient _client = Supabase.instance.client;
  String get _adminKey => SupabaseService.instance.adminKey ?? '';

  /// 진행 상위 1명의 행을 가져온다.
  /// - RPC: admin_rank_mentees_by_progress
  /// - 반환 컬럼(요지): id, nickname, mentor(uuid), mentor_name, joined_at, photo_url, login_key, progress, ...
  Future<Map<String, dynamic>?> fetchTopMenteeRow() async {
    if (_adminKey.isEmpty) {
      throw 'admin key missing';
    }
    final data = await _client.rpc(
      'admin_rank_mentees_by_progress',
      params: {
        'p_firebase_uid': _adminKey,
        'p_limit': 1,
      },
    ).select(); // supabase 2.x

    if (data == null) return null;
    final rows = (data is List) ? data : [data];
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  /// 후임 한 명의 코스 관련 데이터 묶음
  /// - 커리큘럼 아이템 리스트(요약)
  /// - 완료된 모듈 id 집합
  /// - 모듈별 시청 비율
  /// - 모듈별 상세 진행 맵(CurriculumProgress): attempts/bestScore 포함
  Future<({
  List<CurriculumItem> curriculum,
  Set<String> completedIds,
  Map<String, double> progressRatio,
  Map<String, CurriculumProgress> progressMap,
  })> fetchMenteeCourseData(String loginKey) async {
    // 1) 기본 모듈 진행 요약 (후임 뷰 카드 구성에 사용)
    final data = await _client
        .rpc('mentee_course_progress', params: {'p_firebase_uid': loginKey})
        .select(); // supabase 2.x

    final List rows = (data is List) ? data : <dynamic>[];
    final items = <CurriculumItem>[];
    final completed = <String>{};
    final ratios = <String, double>{};

    for (final r0 in rows) {
      final r = Map<String, dynamic>.from(r0 as Map);
      final code = (r['module_code'] ?? '').toString();
      if (code.isEmpty) continue;

      items.add(CurriculumItem(
        id: code,
        week: (r['week'] as num?)?.toInt() ?? 0,
        title: (r['title'] ?? '').toString(),
        summary: (r['title'] ?? '').toString(),
        goals: const [],
        requiresExam: (r['has_exam'] as bool?) ?? false,
        videoUrl: r['video_url'] as String?, // 없으면 null
        resources: const [],
        version: 1,
        thumbUrl: null,
        hasVideo: r['video_url'] != null,
      ));

      final watched = (r['watched_ratio'] as num?)?.toDouble() ?? 0.0;
      ratios[code] = watched.clamp(0.0, 1.0);

      if ((r['module_completed'] as bool?) ?? false) {
        completed.add(code);
      }
    }
    items.sort((a, b) => a.week.compareTo(b.week));

    // 2) attempts/bestScore 포함 상세 맵 (동일 RPC를 다른 파서로)
    final progressMap =
    await CourseProgressService.listCurriculumProgress(loginKey: loginKey);

    return (
    curriculum: items,
    completedIds: completed,
    progressRatio: ratios,
    progressMap: progressMap
    );
  }

  /// 관리자용 후임 메트릭 목록
  /// - RPC: admin_list_mentees_metrics
  /// - 반환 컬럼에 mentor(uuid) + mentor_name(text) 포함 (B안)
  Future<List<Map<String, dynamic>>> listMenteesMetrics({
    int days = 30,
    int lowScore = 60,
    int maxAttempts = 10,
  }) async {
    if (_adminKey.isEmpty) {
      throw 'admin key missing';
    }

    final res = await _client.rpc('admin_list_mentees_metrics', params: {
      'p_firebase_uid': _adminKey,
      'p_days': days,
      'p_low_score': lowScore,
      'p_max_attempts': maxAttempts,
    });

    if (res == null) return <Map<String, dynamic>>[];
    final rows = (res is List) ? res : [res];

    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
