import 'package:supabase_flutter/supabase_flutter.dart';

class MentorKpi {
  final int pendingTotal;
  final double? avgFeedbackDays;
  final int handledLast7d;
  MentorKpi({required this.pendingTotal, this.avgFeedbackDays, required this.handledLast7d});
}

class MentorService {
  MentorService._();
  static final instance = MentorService._();
  final SupabaseClient _sb = Supabase.instance.client;

  // KPI (stub)
  Future<MentorKpi> fetchKpi({required String loginKey}) async {
    // TODO: mentor KPI RPC로 교체
    return MentorKpi(pendingTotal: 0, avgFeedbackDays: null, handledLast7d: 0);
  }

  // 큐 목록 (stub)
  Future<List<Map<String, dynamic>>> listQueue({
    required String loginKey,
    String status = 'submitted',
    int limit = 50,
    int offset = 0,
  }) async {
    // 더미 1건 (status에 따라 표시만 다르게)
    final now = DateTime.now().toIso8601String();
    return [
      {
        'id': 'test-attempt-1',
        'attempt_no': 3,
        'set_code': 'PS-001',
        'mentee_id': 'uuid-mentee-1',
        'mentee_name': '홍길동',
        'submitted_at': now,
        'reviewed_at': null,
        'status': status == 'reviewed' ? 'reviewed' : 'submitted',
        'rating': null,
      },
    ];
  }

  // 내 멘티 (stub) — ✅ onlyPending 추가
  Future<List<Map<String, dynamic>>> listMyMentees({
    required String loginKey,
    bool onlyPending = false,
  }) async {
    // TODO: mentor_list_my_mentees RPC + onlyPending 서버 필터 적용
    return <Map<String, dynamic>>[];
  }

  // 히스토리 (stub) — ✅ lastNDays 추가
  Future<List<Map<String, dynamic>>> listMyHistory({
    required String loginKey,
    int lastNDays = 30,
  }) async {
    // TODO: reviewed 상태 + 기간 필터 RPC로 교체
    return <Map<String, dynamic>>[];
  }

  // 리뷰 저장 (stub → 나중에 RPC 연결)
  Future<Map<String, dynamic>> reviewAttempt({
    required String loginKey,
    required String attemptId,
    required String gradeKor, // '상'|'중'|'하'
    required String feedback,
  }) async {
    // TODO: mentor_review_practice_attempt RPC로 교체
    return {
      'id': attemptId,
      'status': 'reviewed',
      'rating': (gradeKor == '상') ? 'high' : (gradeKor == '중') ? 'mid' : 'low',
      'feedback_text': feedback,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewer_id': 'stub',
    };
  }
}
