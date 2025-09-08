import 'package:flutter/foundation.dart';

/// 옵션 A(정규화) 기준 커리큘럼 모델
/// - examSetCode 제거
/// - requiresExam = 서버 뷰 컬럼(has_exam)
class CurriculumItem {
  final String id;                 // == code
  final int week;
  final String title;
  final String summary;

  final bool hasVideo;
  final String? videoUrl;

  final bool requiresExam;         // from has_exam
  final int? version;

  final List<Map<String, dynamic>> resources;
  final List<String> goals;

  /// (호환성 유지) 앱 일부에서 참조하던 필드 – DB엔 없음
  final int durationMinutes;

  const CurriculumItem({
    required this.id,
    required this.week,
    required this.title,
    required this.summary,
    required this.hasVideo,
    required this.requiresExam,
    this.videoUrl,
    this.version,
    required this.resources,
    required this.goals,
    this.durationMinutes = 0,
  });

  CurriculumItem copyWith({
    String? id,
    int? week,
    String? title,
    String? summary,
    bool? hasVideo,
    String? videoUrl,
    bool? requiresExam,
    int? version,
    List<Map<String, dynamic>>? resources,
    List<String>? goals,
    int? durationMinutes,
  }) {
    return CurriculumItem(
      id: id ?? this.id,
      week: week ?? this.week,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      hasVideo: hasVideo ?? this.hasVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      requiresExam: requiresExam ?? this.requiresExam,
      version: version ?? this.version,
      resources: resources ?? this.resources,
      goals: goals ?? this.goals,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
