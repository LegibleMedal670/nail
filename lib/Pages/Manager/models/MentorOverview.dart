import 'package:flutter/foundation.dart';

@immutable
class MentorOverview {
  final String id;
  final String name;
  final DateTime joinedAt;
  final String? photoUrl;
  final int menteeCount;
  final int pendingTotal;
  final double? avgFeedbackDays; // null 가능
  final int handledLast7d;

  const MentorOverview({
    required this.id,
    required this.name,
    required this.joinedAt,
    required this.menteeCount,
    required this.pendingTotal,
    required this.handledLast7d,
    this.photoUrl,
    this.avgFeedbackDays,
  });

  factory MentorOverview.fromRow(Map<String, dynamic> r) {
    DateTime _d(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    double? _dn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return MentorOverview(
      id: (r['mentor_id'] ?? r['id']).toString(),
      name: (r['mentor_name'] ?? r['nickname'] ?? '').toString(),
      joinedAt: _d(r['joined_at']),
      photoUrl: r['photo_url'] as String?,
      menteeCount: _i(r['mentee_count']),
      pendingTotal: _i(r['pending_total']),
      handledLast7d: _i(r['handled_last_7d']),
      avgFeedbackDays: _dn(r['avg_feedback_days']),
    );
  }
}
