import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:nail/Pages/Manager/models/MentorOverview.dart';
import 'package:nail/Pages/Manager/models/MenteeBrief.dart';
import 'package:nail/Pages/Manager/models/PracticeAttempt.dart';
import 'package:nail/Services/SupabaseService.dart';

class MentorDetailProvider extends ChangeNotifier {
  final String mentorId;
  MentorDetailProvider({required this.mentorId});

  final _api = SupabaseService.instance;

  bool _loading = false;
  String? _error;

  MentorOverview? _overview;
  final List<MenteeBrief> _mentees = [];
  bool _onlyPending = false;

  bool get loading => _loading;
  String? get error => _error;
  MentorOverview? get overview => _overview;
  UnmodifiableListView<MenteeBrief> get mentees => UnmodifiableListView(_mentees);
  bool get onlyPending => _onlyPending;

  Future<void> ensureLoaded() async {
    if (_overview != null && _mentees.isNotEmpty) return;
    await refresh();
  }

  Future<void> refresh() async {
    _set(loading: true, error: null);
    try {
      final kpiRow = await _api.adminMentorOverview(mentorId: mentorId);
      _overview = (kpiRow == null) ? null : MentorOverview.fromRow(kpiRow);

      final rows = await _api.adminListMenteesOfMentor(
        mentorId: mentorId,
        onlyPending: _onlyPending,
        limit: 500,
      );
      _mentees
        ..clear()
        ..addAll(rows.map(MenteeBrief.fromRow));
      _set(loading: false, error: null);
    } catch (e) {
      _set(loading: false, error: '불러오기 실패: $e');
    }
  }

  Future<void> toggleOnlyPending(bool v) async {
    _onlyPending = v;
    await refresh();
  }

  Future<int> assignMentees(List<String> menteeIds) async {
    final cnt = await _api.adminAssignMenteesToMentor(
      mentorId: mentorId,
      menteeIds: menteeIds,
    );
    await refresh();
    return cnt;
  }

  Future<int> unassignMentees(List<String> menteeIds) async {
    final cnt = await _api.adminUnassignMentees(menteeIds: menteeIds);
    await refresh();
    return cnt;
  }

  // 상세 페이지(멘티 시도 이력)
  Future<List<PracticeAttempt>> listAttempts(String menteeId) async {
    final rows = await _api.adminListMenteePracticeAttempts(menteeId: menteeId, limit: 200);
    return rows.map(PracticeAttempt.fromRow).toList();
  }

  void _set({bool? loading, String? error}) {
    var changed = false;
    if (loading != null && loading != _loading) { _loading = loading; changed = true; }
    if (error != _error) { _error = error; changed = true; }
    if (changed) notifyListeners();
  }
}
