import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Services/SupabaseService.dart';

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
  final _api = SupabaseService.instance;

  // ===== KPI =====
  Future<MentorKpi> fetchKpi({required String loginKey}) async {
    // SupabaseService에 현재 세션의 loginKey를 주입해두면 RPC는 내부에서 사용합니다.
    final row = await _api.mentorOverview();
    // row 예시: { pending_total:int, avg_feedback_days:numeric|null, handled_last_7d:int }
    final int pending = (row?['pending_total'] as num?)?.toInt() ?? 0;
    final double? avg = switch (row?['avg_feedback_days']) {
      null => null,
      num v => v.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };
    final int handled = (row?['handled_last_7d'] as num?)?.toInt() ?? 0;

    return MentorKpi(pendingTotal: pending, avgFeedbackDays: avg, handledLast7d: handled);
  }

  // ===== 큐 목록 =====
  // status == 'submitted' → 대기 큐, 'reviewed' → 최근 완료를 간단히 7일치 조회
  Future<List<Map<String, dynamic>>> listQueue({
    required String loginKey,
    String status = 'submitted',
    int limit = 50,
    int offset = 0,
  }) async {
    if (status == 'submitted') {
      return _api.mentorListPendingQueue(limit: limit, offset: offset);
    } else {
      // 탭 호환을 위해 reviewed 요청이 오면 최근 7일 완료 목록을 반환
      return _api.mentorListHistory(lastNDays: 7, limit: limit, offset: offset);
    }
  }

  // ===== 내 멘티 =====
  Future<List<Map<String, dynamic>>> listMyMentees({
    required String loginKey,
    bool onlyPending = false,
  }) {
    return _api.mentorListMyMentees(onlyPending: onlyPending);
  }

  // ===== 히스토리 =====
  Future<List<Map<String, dynamic>>> listMyHistory({
    required String loginKey,
    int lastNDays = 30,
  }) {
    return _api.mentorListHistory(lastNDays: lastNDays);
  }

  // ===== 리뷰 저장 =====
  Future<Map<String, dynamic>> reviewAttempt({
    required String loginKey,
    required String attemptId,
    required String gradeKor, // '상'|'중'|'하'
    required String feedback,
  }) async {
    final row = await _api.mentorReviewAttempt(
      attemptId: attemptId,
      gradeKor: gradeKor,
      feedback: feedback,
    );
    if (row == null) {
      throw Exception('mentor_review_attempt returned null');
    }
    return row;
  }
}
