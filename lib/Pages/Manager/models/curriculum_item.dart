import 'package:flutter/foundation.dart';

/// 커리큘럼 단위 아이템
/// DB: public.curriculum_modules 와 1:1 (파생 필드는 별도 표시)
class CurriculumItem {
  /// 고유 식별자: DB의 code 사용(없으면 id fallback)
  final String id;

  final int week;
  final String title;

  /// 간단 요약 (DB: summary)
  final String summary;

  /// 학습 목표 (DB: goals jsonb array of strings)
  final List<String> goals;

  /// 영상 길이(현재 DB 미보유 → 0 고정)
  final int durationMinutes;

  /// 영상 존재 여부 (DB: has_video OR video_url non-empty)
  final bool hasVideo;

  /// 영상 URL (nullable)
  final String? videoUrl;

  /// 시험 필요 여부 (파생: exam_set_code 유무)
  final bool requiresExam;

  /// 시험 세트 코드 (nullable)
  final String? examSetCode;

  /// 자료들 (DB: resources jsonb array of objects)
  /// 예: [{title,url,type?}, ...]
  final List<Map<String, dynamic>> resources;

  const CurriculumItem({
    required this.id,
    required this.week,
    required this.title,
    required this.summary,
    required this.goals,
    required this.durationMinutes,
    required this.hasVideo,
    required this.videoUrl,
    required this.requiresExam,
    required this.examSetCode,
    required this.resources,
  });

  CurriculumItem copyWith({
    String? id,
    int? week,
    String? title,
    String? summary,
    List<String>? goals,
    int? durationMinutes,
    bool? hasVideo,
    String? videoUrl,
    bool? requiresExam,
    String? examSetCode,
    List<Map<String, dynamic>>? resources,
  }) {
    return CurriculumItem(
      id: id ?? this.id,
      week: week ?? this.week,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      goals: goals ?? this.goals,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      hasVideo: hasVideo ?? this.hasVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      requiresExam: requiresExam ?? this.requiresExam,
      examSetCode: examSetCode ?? this.examSetCode,
      resources: resources ?? this.resources,
    );
  }

  @override
  String toString() {
    return 'CurriculumItem(id:$id, week:$week, title:$title, goals:${goals.length}, '
        'hasVideo:$hasVideo, requiresExam:$requiresExam, resources:${resources.length})';
  }
}
