// lib/Services/ExamService.dart
import 'package:nail/Pages/Manager/page/ManagerExamResultPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/model/ExamModel.dart';

/// 시험 관련 RPC 전용 경량 서비스
/// - get_exam_set(p_module_code)
/// - admin_upsert_exam_set(p_admin_key, p_module_code, p_pass_score, p_questions jsonb)
/// - mentee_submit_exam(p_login_key, p_module_code, p_answers jsonb, p_score int)
/// - mentee_list_attempts(p_login_key, p_module_code)
/// (선택) - admin_delete_exam_set(p_admin_key, p_module_code)
class ExamService {
  ExamService._();
  static final ExamService instance = ExamService._();

  final SupabaseClient _sb = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------------

  /// 관리자: 시험 세트 업서트
  Future<void> adminUpsertExamSet({
    required String adminKey,
    required String moduleCode,
    required int passScore,
    required List<ExamQuestion> questions,
  }) async {
    // ExamQuestion.toJson()이 프로젝트에 구현되어 있다는 가정
    final payload = questions.map((e) => e.toJson()).toList(growable: false);
    await _sb.rpc('admin_upsert_exam_set', params: {
      'p_admin_key': adminKey,
      'p_module_code': moduleCode,
      'p_pass_score': passScore,
      'p_questions': payload,
    });
  }

  /// (선택) 관리자: 시험 세트 삭제
  /// 서버에 admin_delete_exam_set RPC가 있을 때만 사용하세요.
  Future<void> adminDeleteExamSet({
    required String adminKey,
    required String moduleCode,
  }) async {
    await _sb.rpc('admin_delete_exam_set', params: {
      'p_admin_key': adminKey,
      'p_module_code': moduleCode,
    });
  }

  Future<List<RawExamAttempt>> adminGetExamAttempts({
    required String adminKey,
    required String moduleCode,
    required String userId, // uuid string
  }) async {
    final res = await _sb.rpc('admin_get_exam_attempts', params: {
      'p_admin_key': adminKey,
      'p_module_code': moduleCode,
      'p_user_id': userId,
    });

    if (res == null) return <RawExamAttempt>[];

    final List data = (res is List) ? res : <dynamic>[res];
    return data.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      return RawExamAttempt(
        id: (m['id'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
        score: (m['score'] ?? 0) as int,
        passed: (m['passed'] as bool?) ?? false,
        answers: Map<String, dynamic>.from(m['answers'] ?? const {}),
      );
    }).toList();
  }


  // ---------------------------------------------------------------------------
  // Mentee
  // ---------------------------------------------------------------------------

  /// 멘티: 시험 제출 (결과 attempt_id, passed 반환)
  Future<MenteeSubmitResult> menteeSubmitExam({
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

    final map = _firstRowAsMap(res);
    return MenteeSubmitResult(
      attemptId: (map['attempt_id'] ?? '').toString(),
      passed: (map['passed'] as bool?) ?? false,
    );
  }

  /// 멘티: 시도 이력(점수/통과/시간)
  Future<List<MenteeAttempt>> menteeListAttempts({
    required String loginKey,
    required String moduleCode,
  }) async {
    final res = await _sb.rpc('mentee_list_attempts', params: {
      'p_firebase_uid': loginKey,
      'p_module_code': moduleCode,
    });

    final list = (res is List) ? res : (res == null ? [] : [res]);
    return list.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      final scoreDyn = m['score'];
      final score = scoreDyn is int ? scoreDyn : (scoreDyn is num ? scoreDyn.toInt() : 0);
      final passed = (m['passed'] as bool?) ?? false;

      DateTime createdAt;
      final rawTs = m['created_at'];
      if (rawTs is String) {
        createdAt = DateTime.tryParse(rawTs) ?? DateTime.now();
      } else if (rawTs is DateTime) {
        createdAt = rawTs;
      } else {
        createdAt = DateTime.now();
      }

      return MenteeAttempt(score: score, passed: passed, createdAt: createdAt);
    }).toList(growable: false);
  }

  /// 멘티: 간단 통계(횟수/최고점/통과여부)
  Future<MenteeExamStats> getMyStats({
    required String loginKey,
    required String moduleCode,
  }) async {
    final res = await _sb.rpc('mentee_list_attempts', params: {
      'p_firebase_uid': loginKey,
      'p_module_code': moduleCode,
    });

    final list = (res is List) ? res : const [];

    int attempts = list.length;
    int? bestScore;
    bool anyPassed = false;

    for (final row in list) {
      final m = (row as Map).cast<String, dynamic>();
      final sDyn = m['score'];
      final s = sDyn is int ? sDyn : (sDyn is num ? sDyn.toInt() : null);
      if (s != null) {
        bestScore = (bestScore == null) ? s : (s > bestScore! ? s : bestScore);
      }
      if (m['passed'] == true) anyPassed = true;
    }

    return MenteeExamStats(
      attempts: attempts,
      bestScore: bestScore,
      passed: anyPassed,
    );
  }

  // ---------------------------------------------------------------------------
  // Common
  // ---------------------------------------------------------------------------

  /// 시험 세트 가져오기 (없으면 null)
  Future<ExamSet?> getExamSet(String moduleCode) async {
    final res = await _sb.rpc('get_exam_set', params: {'p_module_code': moduleCode});
    if (res == null) return null;

    final map = _firstRowAsMap(res);

    final psDyn = map['pass_score'];
    final passScore = psDyn is int ? psDyn : (psDyn is num ? psDyn.toInt() : 0);

    final rawQs = map['questions'];
    final list = (rawQs is List) ? rawQs : <dynamic>[];

    final qs = list.map((e) {
      if (e is Map) {
        return ExamQuestion.fromJson(e.cast<String, dynamic>());
      } else {
        throw StateError('Question item is not an object: ${e.runtimeType}');
      }
    }).toList(growable: false);

    return ExamSet(moduleCode: moduleCode, passScore: passScore, questions: qs);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// RPC 결과에서 "첫 행"을 Map으로 안전 추출
  Map<String, dynamic> _firstRowAsMap(dynamic res) {
    if (res == null) {
      throw StateError('RPC returned null');
    }
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    if (res is List) {
      if (res.isEmpty) throw StateError('RPC returned empty list');
      final first = res.first;
      if (first is Map) return first.cast<String, dynamic>();
      // 드문 드라이버 케이스: 위치 기반 배열(테이블 리턴에서 컬럼 2개만 받을 때 등)
      if (first is List) {
        if (first.length >= 2) {
          return {
            'attempt_id': first[0],
            'passed': first[1],
          };
        }
        throw StateError('Unexpected row shape: List but length < 2');
      }
      throw StateError('Unexpected row type: ${first.runtimeType}');
    }
    throw StateError('Unexpected RPC result type: ${res.runtimeType}');
  }
}

// -----------------------------------------------------------------------------
// POJOs
// -----------------------------------------------------------------------------

/// 제출 결과
class MenteeSubmitResult {
  final String attemptId;
  final bool passed;
  const MenteeSubmitResult({required this.attemptId, required this.passed});
}

/// 멘티 시도 내역 아이템
class MenteeAttempt {
  final int score;
  final bool passed;
  final DateTime createdAt;
  const MenteeAttempt({
    required this.score,
    required this.passed,
    required this.createdAt,
  });
}

/// 멘티 간단 통계
class MenteeExamStats {
  final int attempts;
  final int? bestScore;
  final bool passed;
  const MenteeExamStats({
    required this.attempts,
    required this.bestScore,
    required this.passed,
  });
}

/// 서버에서 가져오는 시험 세트(편의형)
class ExamSet {
  final String moduleCode;
  final int passScore;
  final List<ExamQuestion> questions;
  const ExamSet({
    required this.moduleCode,
    required this.passScore,
    required this.questions,
  });
}

class AdminExamReport {
  final int passScore;
  final List<ExamAttemptResult> attempts;
  const AdminExamReport({required this.passScore, required this.attempts});
}

class RawExamAttempt {
  final String id;
  final DateTime createdAt;
  final int score;
  final bool passed;
  final Map<String, dynamic> answers;

  RawExamAttempt({
    required this.id,
    required this.createdAt,
    required this.score,
    required this.passed,
    required this.answers,
  });
}

