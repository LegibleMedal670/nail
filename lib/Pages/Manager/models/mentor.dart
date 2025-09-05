import 'package:flutter/material.dart';

/// 멘토 모델 (단순화 버전)
class Mentor {
  final String name;
  final DateTime hiredAt;      // 입사일
  final int menteeCount;       // 현재 멘티 수
  final int avgGraduateDays;   // 평균 멘티 졸업 소요 일수
  final String? photoUrl;      // 프로필 사진 (null 이면 아이콘 대체)
  final double? avgScore;      // 지금까지 담당 멘티 평균 점수 (선택)

  const Mentor({
    required this.name,
    required this.hiredAt,
    required this.menteeCount,
    required this.avgGraduateDays,
    this.photoUrl,
    this.avgScore,
  });

  /// UI 표시용: 'YYYY-MM-DD'
  String get hiredAtText {
    final y = hiredAt.year.toString().padLeft(4, '0');
    final m = hiredAt.month.toString().padLeft(2, '0');
    final d = hiredAt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// UI 표시용: 평균 졸업 시간(2주 이상이면 '약 n주', 그 미만은 'n일')
  String get avgGraduateText {
    if (avgGraduateDays >= 14) {
      final w = (avgGraduateDays / 7).round();
      return '약 ${w}주';
    }
    return '${avgGraduateDays}일';
  }
}

/// 데모 데이터
List<Mentor> kDemoMentors = [
  Mentor(
    name: '박태현',
    hiredAt: DateTime(2023, 3, 12),
    menteeCount: 9,
    avgGraduateDays: 12,
    avgScore: 88.3,
  ),
  Mentor(
    name: '김하늘',
    hiredAt: DateTime(2024, 1, 8),
    menteeCount: 6,
    avgGraduateDays: 17,
    avgScore: 91.0,
  ),
  Mentor(
    name: '이도윤',
    hiredAt: DateTime(2022, 11, 2),
    menteeCount: 12,
    avgGraduateDays: 14,
    avgScore: 85.5,
  ),
  Mentor(
    name: '정가은',
    hiredAt: DateTime(2024, 6, 20),
    menteeCount: 4,
    avgGraduateDays: 24,
    avgScore: 89.7,
  ),
];
