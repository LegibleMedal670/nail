import 'package:flutter/material.dart';

class CurriculumItem {
  final String id;
  final int week;              // 주차 (1~14)
  final String title;          // 과정 제목
  final String summary;        // 한 줄 요약
  final int durationMinutes;   // 소요 시간(분)
  final bool hasVideo;         // 영상 유무
  final String? videoUrl;      // (옵션) 영상 URL
  final bool requiresExam;     // 과정 후 시험 필요 여부

  const CurriculumItem({
    required this.id,
    required this.week,
    required this.title,
    required this.summary,
    required this.durationMinutes,
    required this.hasVideo,
    this.videoUrl,
    this.requiresExam = false,
  });
}
