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
    String _asS(dynamic v, {String or = ''}) => (v == null) ? or : v.toString();

    DateTime _asT(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v.toLocal();
      if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    double? _asDOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int _asI(dynamic v, {int or = 0}) {
      if (v == null) return or;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? or;
      return or;
    }

    return Mentee(
      id: _asS(row['id']),
      name: _asS(row['nickname'], or: '이름없음'),
      mentor: _asS(row['mentor'], or: '미배정'),
      startedAt: _asT(row['joined_at']),
      progress: (_asDOrNull(row['progress']) ?? 0.0),
      courseDone: _asI(row['course_done']),
      courseTotal: _asI(row['course_total']),
      examDone: _asI(row['exam_done']),
      examTotal: _asI(row['exam_total']),
      score: _asDOrNull(row['avg_score']),
      photoUrl: (row['photo_url'] == null) ? null : _asS(row['photo_url']),
      accessCode: _asS(row['login_key']), // 숫자여도 문자열로 통일
    );
  }
}
