import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Services/SupabaseService.dart';

class AdminMenteeService {
  AdminMenteeService._();
  static final instance = AdminMenteeService._();

  final _client = Supabase.instance.client;

  // 관리자 키는 UserProvider 또는 SupabaseService에서 가져와 써.
  String get _adminKey => SupabaseService.instance.adminKey ?? '';

  /// 1) 진도 상위 멘티 1명 가져오기 (신규 RPC)
  Future<Map<String, dynamic>?> fetchTopMenteeRow() async {
    if (_adminKey.isEmpty) throw 'admin key missing';

    // TABLE 반환 → .select()
    final rows = await _client.rpc(
      'admin_rank_mentees_by_progress',
      params: {'p_admin_key': _adminKey, 'p_limit': 1},
    ).select();

    if (rows is List && rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }


  /// [Deprecated] 커리큘럼은 Provider에서, 진행도만 RPC로 가져와 합칩니다.
  Future<({List<CurriculumItem> curriculum, Set<String> completedIds, Map<String,double> progressRatio})>
  fetchMenteeCourseData(String loginKey) async {
    // 커리큘럼은 Provider에서 읽어온 것을 그대로 돌려줄 뿐, 여기서 만들지 않습니다.
    // 이 함수는 하위호환용 래퍼로만 유지됩니다.

    // 1) 진행도만 RPC에서
    final prog = await fetchMenteeProgress(loginKey);

    // 2) 커리큘럼은 전역 Provider에서
    //  (여기서 context가 없으니, 이 함수는 더 이상 커리큘럼을 만들 수 없어요.
    //   호출측(ManagerMainPage)에서 Provider로 가져오도록 변경하세요.)
    return (curriculum: const <CurriculumItem>[], completedIds: prog.completedIds, progressRatio: prog.progressRatio);
  }

  /// (NEW) 멘티 한 명의 모듈별 진행도/완료 여부만 조회
  /// - 커리큘럼(주차/제목/썸네일 등)은 CurriculumProvider에서 가져오세요.
  /// - 반환: 완료 set + 시청비율 map
  Future<({Set<String> completedIds, Map<String,double> progressRatio})>
  fetchMenteeProgress(String loginKey) async {
    if (loginKey.isEmpty) throw 'login key missing';

    final data = await _client
        .rpc('mentee_course_progress', params: {'p_login_key': loginKey})
        .select(); // v2 문법: .execute() 아님

    final List rows = (data is List) ? data : <dynamic>[];

    final Set<String> completed = {};
    final Map<String,double> ratios = {};

    for (final r0 in rows) {
      final r = Map<String, dynamic>.from(r0 as Map);
      final code = (r['module_code'] ?? '').toString();
      if (code.isEmpty) continue;

      final watchedRatio = (r['watched_ratio'] as num?)?.toDouble() ?? 0.0;
      ratios[code] = watchedRatio.clamp(0.0, 1.0);

      final done = (r['module_completed'] as bool?) ?? false;
      if (done) completed.add(code);
    }

    return (completedIds: completed, progressRatio: ratios);
  }

}
