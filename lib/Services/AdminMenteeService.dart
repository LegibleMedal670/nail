// lib/Services/AdminMenteeService.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Services/SupabaseService.dart';
import 'package:nail/Services/CourseProgressService.dart'; // ✅ 추가

class AdminMenteeService {
  AdminMenteeService._();
  static final instance = AdminMenteeService._();
  final _client = Supabase.instance.client;
  String get _adminKey => SupabaseService.instance.adminKey ?? '';

  Future<Map<String, dynamic>?> fetchTopMenteeRow() async {
    if (_adminKey.isEmpty) throw 'admin key missing';
    final data = await _client
        .rpc('admin_rank_mentees_by_progress', params: {
      'p_admin_key': _adminKey,
      'p_limit': 1,
    })
        .select();                            // ✅ v2
    if (data == null) return null;
    final rows = (data is List) ? data : [data];
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  /// 커리큘럼 + 완료집합 + 시청비율 + (추가) 모듈별 진행맵(CurriculumProgress)
  Future<({
  List<CurriculumItem> curriculum,
  Set<String> completedIds,
  Map<String,double> progressRatio,
  Map<String, CurriculumProgress> progressMap, // ✅ 추가
  })> fetchMenteeCourseData(String loginKey) async {
    // 1) 모듈별 진행(raw)로부터 기본 카드 구성(주차/제목/비디오 플래그/시청률/완료여부)
    final data = await _client
        .rpc('mentee_course_progress', params: {'p_login_key': loginKey})
        .select();                            // ✅ v2

    final List rows = (data is List) ? data : <dynamic>[];
    final items = <CurriculumItem>[];
    final completed = <String>{};
    final ratios = <String,double>{};

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

      if ((r['module_completed'] as bool?) ?? false) completed.add(code);
    }
    items.sort((a,b) => a.week.compareTo(b.week));

    // 2) ✅ 동일 RPC를 CourseProgressService 파서를 통해 한 번 더 읽어 "attempts/bestScore" 포함 맵 생성
    final progressMap = await CourseProgressService.listCurriculumProgress(loginKey: loginKey);

    return (curriculum: items, completedIds: completed, progressRatio: ratios, progressMap: progressMap);
  }

  // === NEW === 멘티 메트릭 목록 (관리자용)
  Future<List<Map<String, dynamic>>> listMenteesMetrics({
    int days = 30,
    int lowScore = 60,
    int maxAttempts = 10,
  }) async {
    if (_adminKey.isEmpty) throw 'admin key missing';
    final res = await _client.rpc('admin_list_mentees_metrics', params: {
      'p_admin_key': _adminKey,
      'p_days': days,
      'p_low_score': lowScore,
      'p_max_attempts': maxAttempts,
    });

    if (res == null) return <Map<String, dynamic>>[];
    final rows = (res is List) ? res : [res];

    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

}
