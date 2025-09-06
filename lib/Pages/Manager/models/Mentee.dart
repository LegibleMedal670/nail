import 'package:flutter/foundation.dart';

@immutable
class Mentee {
  final String id;
  final String name;       // nickname
  final String mentor;
  final DateTime startedAt; // joined_at
  final double progress;
  final int courseDone;
  final int courseTotal;
  final int examDone;
  final int examTotal;
  final String? photoUrl;
  final double? score;
  final String accessCode; // login_key

  const Mentee({
    required this.id,
    required this.name,
    required this.mentor,
    required this.startedAt,
    required this.progress,
    required this.courseDone,
    required this.courseTotal,
    required this.examDone,
    required this.examTotal,
    this.photoUrl,
    this.score,
    this.accessCode = '',
  });

  Mentee copyWith({
    String? id,
    String? name,
    String? mentor,
    DateTime? startedAt,
    double? progress,
    int? courseDone,
    int? courseTotal,
    int? examDone,
    int? examTotal,
    String? photoUrl,
    double? score,
    String? accessCode,
  }) {
    return Mentee(
      id: id ?? this.id,
      name: name ?? this.name,
      mentor: mentor ?? this.mentor,
      startedAt: startedAt ?? this.startedAt,
      progress: progress ?? this.progress,
      courseDone: courseDone ?? this.courseDone,
      courseTotal: courseTotal ?? this.courseTotal,
      examDone: examDone ?? this.examDone,
      examTotal: examTotal ?? this.examTotal,
      photoUrl: photoUrl ?? this.photoUrl,
      score: score ?? this.score,
      accessCode: accessCode ?? this.accessCode,
    );
  }

  /// Supabase row -> model
  static Mentee fromRow(Map<String, dynamic> row) {
    return Mentee(
      id: row['id'] as String,
      name: (row['nickname'] as String?) ?? '이름없음',
      mentor: (row['mentor'] as String?) ?? '미배정',
      startedAt: DateTime.tryParse((row['joined_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      progress: (row['progress'] as num?)?.toDouble() ?? 0.0,
      courseDone: (row['course_done'] as num?)?.toInt() ?? 0,
      courseTotal: (row['course_total'] as num?)?.toInt() ?? 0,
      examDone: (row['exam_done'] as num?)?.toInt() ?? 0,
      examTotal: (row['exam_total'] as num?)?.toInt() ?? 0,
      score: (row['avg_score'] as num?)?.toDouble(),
      photoUrl: row['photo_url'] as String?,
      accessCode: (row['login_key'] as String?) ?? '',
    );
  }
}
