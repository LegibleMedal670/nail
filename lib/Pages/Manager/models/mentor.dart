import 'package:flutter/foundation.dart';

@immutable
class Mentor {
  final String id;              // app_users.id (uuid)
  final String name;            // nickname
  final DateTime hiredAt;       // joined_at (멘토 입사일/등록일로 사용)
  final int menteeCount;        // 담당 멘티 수
  final double? avgScore;       // 담당 멘티 평균 점수(없으면 null)
  final int? avgGraduateDays;   // 평균 교육 기간(일) (없으면 null)
  final String? photoUrl;       // 프로필
  final String accessCode;      // login_key (4자리)

  const Mentor({
    required this.id,
    required this.name,
    required this.hiredAt,
    required this.menteeCount,
    this.avgScore,
    this.avgGraduateDays,
    this.photoUrl,
    this.accessCode = '',
  });

  Mentor copyWith({
    String? id,
    String? name,
    DateTime? hiredAt,
    int? menteeCount,
    double? avgScore,
    int? avgGraduateDays,
    String? photoUrl,
    String? accessCode,
  }) {
    return Mentor(
      id: id ?? this.id,
      name: name ?? this.name,
      hiredAt: hiredAt ?? this.hiredAt,
      menteeCount: menteeCount ?? this.menteeCount,
      avgScore: avgScore ?? this.avgScore,
      avgGraduateDays: avgGraduateDays ?? this.avgGraduateDays,
      photoUrl: photoUrl ?? this.photoUrl,
      accessCode: accessCode ?? this.accessCode,
    );
  }

  static Mentor fromRow(Map<String, dynamic> row) {
    DateTime _asT(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v.toLocal();
      if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    int _asI(dynamic v, {int or = 0}) {
      if (v == null) return or;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? or;
      return or;
    }
    double? _asD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    String _asS(dynamic v, {String or = ''}) => (v == null) ? or : v.toString();

    return Mentor(
      id: _asS(row['id']),
      name: _asS(row['nickname'], or: '이름없음'),
      hiredAt: _asT(row['joined_at']),
      menteeCount: _asI(row['mentee_count']),
      avgScore: _asD(row['avg_score']),
      avgGraduateDays: (row['avg_graduate_days'] == null)
          ? null
          : _asI(row['avg_graduate_days']),
      photoUrl: (row['photo_url'] == null) ? null : _asS(row['photo_url']),
      accessCode: _asS(row['login_key'], or: ''),
    );
  }
}
