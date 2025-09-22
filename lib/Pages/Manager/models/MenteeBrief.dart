import 'package:flutter/foundation.dart';

@immutable
class MenteeBrief {
  final String id;
  final String name;
  final DateTime startedAt;
  final String? photoUrl;
  final int pendingCount;

  const MenteeBrief({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.pendingCount,
    this.photoUrl,
  });

  factory MenteeBrief.fromRow(Map<String, dynamic> r) {
    DateTime _d(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return MenteeBrief(
      id: (r['id'] ?? '').toString(),
      name: (r['nickname'] ?? '').toString(),
      startedAt: _d(r['joined_at']),
      photoUrl: r['photo_url'] as String?,
      pendingCount: _i(r['pending_count']),
    );
  }
}
