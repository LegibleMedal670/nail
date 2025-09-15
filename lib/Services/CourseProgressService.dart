/// CourseProgressService
/// - mentee_course_progress / mentee_course_overview RPC를 호출.
/// - 외부엔 'CurriculumProgress' (공용 모델)로 노출.
/// - 내부 파서는 _ModuleProgress(비공개) 사용.
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';

final _sb = Supabase.instance.client;

/// 코스 전체 요약 KPI
class CourseOverview {
  final int totalModules;
  final int completedModules;
  final double moduleCompletionRatio; // 0.0~1.0
  final int reqTotal;
  final int reqDone;
  final double reqRatio;              // 0.0~1.0
  final double avgRatio;              // (참고) 영상모듈 평균 시청
  final int watchedSec;
  final int suggestedWeek;

  const CourseOverview({
    required this.totalModules,
    required this.completedModules,
    required this.moduleCompletionRatio,
    required this.reqTotal,
    required this.reqDone,
    required this.reqRatio,
    required this.avgRatio,
    required this.watchedSec,
    required this.suggestedWeek,
  });

  factory CourseOverview.fromMap(Map<String, dynamic> m) {
    double _asD(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int _asI(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return CourseOverview(
      totalModules: _asI(m['total_modules']),
      completedModules: _asI(m['completed_modules']),
      moduleCompletionRatio: _asD(m['module_completion_ratio']),
      reqTotal: _asI(m['req_total']),
      reqDone: _asI(m['req_done']),
      reqRatio: _asD(m['req_ratio']),
      avgRatio: _asD(m['avg_ratio']),
      watchedSec: _asI(m['watched_sec']),
      suggestedWeek: _asI(m['suggested_week']),
    );
  }
}

/// 내부 전용 파서(서비스 외부에 노출하지 않음)
class _ModuleProgress {
  final String moduleCode;
  final int week;
  final String title;
  final bool hasVideo;

  // 영상
  final int durationSec;
  final int bucketSize;
  final int watchedBuckets;
  final int watchedSec;
  final double watchedRatio;
  final int lastPosSec;
  final bool? videoCompleted;

  // 시험
  final bool hasExam;
  final int attempts;
  final int? bestScore;
  final DateTime? lastAttemptAt;
  final bool? examPassed;
  final int? passScore;

  // 최종
  final bool moduleCompleted;
  final DateTime? updatedAt;

  const _ModuleProgress({
    required this.moduleCode,
    required this.week,
    required this.title,
    required this.hasVideo,
    required this.durationSec,
    required this.bucketSize,
    required this.watchedBuckets,
    required this.watchedSec,
    required this.watchedRatio,
    required this.lastPosSec,
    required this.videoCompleted,
    required this.hasExam,
    required this.attempts,
    required this.bestScore,
    required this.lastAttemptAt,
    required this.examPassed,
    required this.passScore,
    required this.moduleCompleted,
    required this.updatedAt,
  });

  factory _ModuleProgress.fromMap(Map<String, dynamic> m) {
    bool _asB(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        return (s == 'true' || s == 't' || s == '1');
      }
      return false;
    }

    double _asD(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int _asI(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? _asT(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is String) {
        try { return DateTime.parse(v).toLocal(); } catch (_) { return null; }
      }
      return null;
    }

    bool? _asBOrNull(dynamic v) => v == null ? null : _asB(v);
    int? _asIOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return _ModuleProgress(
      moduleCode: (m['module_code'] ?? '') as String,
      week: _asI(m['week']),
      title: (m['title'] ?? '') as String,
      hasVideo: _asB(m['has_video']),
      durationSec: _asI(m['duration_sec']),
      bucketSize: _asI(m['bucket_size']),
      watchedBuckets: _asI(m['watched_buckets']),
      watchedSec: _asI(m['watched_sec']),
      watchedRatio: _asD(m['watched_ratio']),
      lastPosSec: _asI(m['last_pos_sec']),
      videoCompleted: _asBOrNull(m['video_completed']),
      hasExam: _asB(m['has_exam']),
      attempts: _asI(m['attempts']),
      bestScore: _asIOrNull(m['best_score']),
      lastAttemptAt: _asT(m['last_attempt_at']),
      examPassed: _asBOrNull(m['exam_passed']),
      passScore: _asIOrNull(m['pass_score']),
      moduleCompleted: _asB(m['module_completed']),
      updatedAt: _asT(m['updated_at']),
    );
  }
}

/// 완료/부분진척 스냅샷(화면 바인딩 보조용)
class CompletionSnapshot {
  final double moduleCompletionRatio; // 0.0~1.0
  final Set<String> completed;
  final Set<String> partial;
  const CompletionSnapshot({
    required this.moduleCompletionRatio,
    required this.completed,
    required this.partial,
  });
}

class CourseProgressService {
  CourseProgressService._();

  // ---------- Overview ----------
  static Future<CourseOverview> getCourseOverview({
    required String loginKey,
  }) async {
    final res = await _sb.rpc('mentee_course_overview', params: {
      'p_login_key': loginKey,
    });

    if (res is List && res.isNotEmpty) {
      final map = (res.first as Map).cast<String, dynamic>();
      return CourseOverview.fromMap(map);
    } else if (res is Map) {
      final map = res.cast<String, dynamic>();
      return CourseOverview.fromMap(map);
    } else {
      return const CourseOverview(
        totalModules: 0,
        completedModules: 0,
        moduleCompletionRatio: 0,
        reqTotal: 0,
        reqDone: 0,
        reqRatio: 0,
        avgRatio: 0,
        watchedSec: 0,
        suggestedWeek: 1,
      );
    }
  }

  // ---------- Detail: 내부 파서 ----------
  static Future<List<_ModuleProgress>> _listModuleProgressInternal({
    required String loginKey,
  }) async {
    final res = await _sb.rpc('mentee_course_progress', params: {
      'p_login_key': loginKey,
    });

    final List<Map<String, dynamic>> rows;
    if (res is List) {
      rows = res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (res is Map) {
      rows = [res.cast<String, dynamic>()];
    } else {
      rows = const [];
    }

    return rows.map(_ModuleProgress.fromMap).toList(growable: false);
  }

  // ---------- Detail: 공용 모델(CurriculumProgress)로 노출 ----------
  /// 모듈코드 -> CurriculumProgress 맵
  static Future<Map<String, CurriculumProgress>> listCurriculumProgress({
    required String loginKey,
  }) async {
    final mods = await _listModuleProgressInternal(loginKey: loginKey);
    final map = <String, CurriculumProgress>{};

    for (final m in mods) {
      map[m.moduleCode] = CurriculumProgress(
        watchedRatio: m.watchedRatio,
        attempts: m.attempts,
        bestScore: m.bestScore,
        // 레거시 'passed'는 시험통과를 의미하므로 examPassed와 동기화
        passed: (m.examPassed ?? false),
        hasVideo: m.hasVideo,
        hasExam: m.hasExam,
        videoCompleted: (m.videoCompleted ?? false),
        examPassed: (m.examPassed ?? false),
        moduleCompleted: m.moduleCompleted,
      );
    }
    return map;
  }

  // ---------- Badge/Gauge 전용 스냅샷 ----------
  static Future<CompletionSnapshot> getCompletionSnapshot({
    required String loginKey,
  }) async {
    final ov = await getCourseOverview(loginKey: loginKey);
    final mods = await _listModuleProgressInternal(loginKey: loginKey);

    final completed = <String>{};
    final partial = <String>{};
    for (final m in mods) {
      if (m.moduleCompleted) {
        completed.add(m.moduleCode);
      } else {
        final vc = (m.hasVideo && (m.videoCompleted ?? false));
        final ep = (m.hasExam && (m.examPassed ?? false));
        if (vc || ep) partial.add(m.moduleCode);
      }
    }

    return CompletionSnapshot(
      moduleCompletionRatio: ov.moduleCompletionRatio,
      completed: completed,
      partial: partial,
    );
  }
}
