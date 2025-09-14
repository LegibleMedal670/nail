// lib/Pages/Common/model/CurriculumProgress.dart
class CurriculumProgress {
  final double watchedRatio;   // 0.0 ~ 1.0
  final int attempts;          // 시험 시도 수
  final int? bestScore;        // 최고 점수(없으면 null)
  final bool passed;           // 통과 여부

  const CurriculumProgress({
    this.watchedRatio = 0.0,
    this.attempts = 0,
    this.bestScore,
    this.passed = false,
  });

  factory CurriculumProgress.fromJson(Map<String, dynamic> j) => CurriculumProgress(
    watchedRatio: (j['watchedRatio'] as num?)?.toDouble() ?? 0.0,
    attempts: j['attempts'] as int? ?? 0,
    bestScore: j['bestScore'] as int?,
    passed: j['passed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'watchedRatio': watchedRatio,
    'attempts': attempts,
    'bestScore': bestScore,
    'passed': passed,
  };
}
