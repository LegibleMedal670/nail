import 'package:flutter/foundation.dart';

@immutable
class PracticeAttempt {
  final String id;
  final int attemptNo;
  final String setCode;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String status;        // 'pending' | 'reviewed'
  final String? rating;       // 'high' | 'mid' | 'low' | null
  final String? feedbackText; // null 가능
  final String? reviewerId;
  final String? reviewerName;
  final List<String> images;
  final double? feedbackDays; // 일 단위 평균 계산용

  const PracticeAttempt({
    required this.id,
    required this.attemptNo,
    required this.setCode,
    required this.submittedAt,
    required this.status,
    this.reviewedAt,
    this.rating,
    this.feedbackText,
    this.reviewerId,
    this.reviewerName,
    this.images = const [],
    this.feedbackDays,
  });

  factory PracticeAttempt.fromRow(Map<String, dynamic> r) {
    DateTime? _dN(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      return null;
    }

    DateTime _d(dynamic v) => _dN(v) ?? DateTime.fromMillisecondsSinceEpoch(0);

    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double? _dn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    List<String> _imgs(dynamic j) {
      if (j is List) {
        return j.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    return PracticeAttempt(
      id: (r['id'] ?? '').toString(),
      attemptNo: _i(r['attempt_no']),
      setCode: (r['set_code'] ?? '').toString(),
      submittedAt: _d(r['submitted_at']),
      reviewedAt: _dN(r['reviewed_at']),
      status: (r['status'] ?? '').toString(),
      rating: (r['rating'] as String?),
      feedbackText: (r['feedback_text'] as String?),
      reviewerId: r['reviewer_id']?.toString(),
      reviewerName: r['reviewer_name']?.toString(),
      images: _imgs(r['images']),
      feedbackDays: _dn(r['feedback_days']),
    );
  }
}
