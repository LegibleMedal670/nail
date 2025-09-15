// lib/Pages/Common/model/CurriculumProgress.dart
//
// 프로젝트 전역에서 사용하는 "코스 진행" 공용 모델.
// 기존 필드(watchedRatio, attempts, bestScore, passed)는 유지하면서,
// 진행도 UI/배지 계산에 필요한 필드를 확장했다.
//
// - hasVideo / hasExam: 모듈 요구사항 종류
// - videoCompleted / examPassed: 요구사항별 완료 여부
// - moduleCompleted: 최종 모듈 완료 여부 (영상+시험 동시 요구시 AND 규칙)
//
// JSON 키는 최대한 기존과의 호환을 유지한다.

class CurriculumProgress {
  // ===== 기존(레거시) 필드 =====
  final double watchedRatio;   // 0.0 ~ 1.0 (영상 시청 비율)
  final int attempts;          // 시험 시도 수
  final int? bestScore;        // 최고 점수(없으면 null)

  /// [DEPRECATED?] 과거 '시험 통과 여부'로 사용되던 필드.
  /// 이제는 [examPassed]와 동일 의미로 유지한다(호환 목적).
  final bool passed;

  // ===== 확장 필드 =====
  final bool hasVideo;         // 이 모듈이 영상을 요구하는가
  final bool hasExam;          // 이 모듈이 시험을 요구하는가
  final bool videoCompleted;   // 영상 요구 시 시청 완료(soft rule) 여부
  final bool examPassed;       // 시험 요구 시 통과 여부
  final bool moduleCompleted;  // 최종 모듈 완료(매트릭스 규칙에 따름)

  const CurriculumProgress({
    this.watchedRatio = 0.0,
    this.attempts = 0,
    this.bestScore,
    this.passed = false,
    // 확장 필드 디폴트
    this.hasVideo = false,
    this.hasExam = false,
    this.videoCompleted = false,
    this.examPassed = false,
    this.moduleCompleted = false,
  });

  // ========= JSON 변환 =========
  factory CurriculumProgress.fromJson(Map<String, dynamic> j) {
    // 레거시 키 호환
    final watchedRatio = (j['watchedRatio'] as num?)?.toDouble() ?? 0.0;
    final attempts = j['attempts'] as int? ?? 0;
    final bestScore = j['bestScore'] as int?;
    final passed = j['passed'] as bool? ?? false;

    // 확장 키 (없으면 false로 안전 기본값)
    final hasVideo = j['hasVideo'] as bool? ?? false;
    final hasExam = j['hasExam'] as bool? ?? false;
    final videoCompleted = j['videoCompleted'] as bool? ?? false;
    final examPassed = (j['examPassed'] as bool?) ?? (j['passed'] as bool? ?? false);
    final moduleCompleted = j['moduleCompleted'] as bool? ?? false;

    return CurriculumProgress(
      watchedRatio: watchedRatio,
      attempts: attempts,
      bestScore: bestScore,
      passed: passed,
      hasVideo: hasVideo,
      hasExam: hasExam,
      videoCompleted: videoCompleted,
      examPassed: examPassed,
      moduleCompleted: moduleCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    // 레거시 키
    'watchedRatio': watchedRatio,
    'attempts': attempts,
    'bestScore': bestScore,
    'passed': passed,
    // 확장 키
    'hasVideo': hasVideo,
    'hasExam': hasExam,
    'videoCompleted': videoCompleted,
    'examPassed': examPassed,
    'moduleCompleted': moduleCompleted,
  };

  // 진행 상태 헬퍼
  bool get hasAnyProgress =>
      (hasVideo && videoCompleted) || (hasExam && examPassed);

  CurriculumProgress copyWith({
    double? watchedRatio,
    int? attempts,
    int? bestScore,
    bool? passed,
    bool? hasVideo,
    bool? hasExam,
    bool? videoCompleted,
    bool? examPassed,
    bool? moduleCompleted,
  }) {
    return CurriculumProgress(
      watchedRatio: watchedRatio ?? this.watchedRatio,
      attempts: attempts ?? this.attempts,
      bestScore: bestScore ?? this.bestScore,
      passed: passed ?? this.passed,
      hasVideo: hasVideo ?? this.hasVideo,
      hasExam: hasExam ?? this.hasExam,
      videoCompleted: videoCompleted ?? this.videoCompleted,
      examPassed: examPassed ?? this.examPassed,
      moduleCompleted: moduleCompleted ?? this.moduleCompleted,
    );
  }
}
