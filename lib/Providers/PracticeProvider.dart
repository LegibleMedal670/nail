// lib/Providers/PracticeProvider.dart
import 'package:flutter/foundation.dart';
import 'package:nail/Services/SupabaseService.dart';

class PracticeProvider extends ChangeNotifier {
  final _api = SupabaseService.instance;

  bool loading = false;
  String? error;

  double completionRatio = 0.0;

  Map<String, dynamic>? currentAttempt; // 진행중 카드
  Map<String, dynamic>? currentSet;

  List<Map<String, dynamic>> sets = [];                 // 세트 목록(정적)
  Map<String, Map<String, dynamic>> latestBySet = {};   // set_id -> 최신시도 row
  bool onlyIncomplete = false;

  Future<void> refreshAll() async {
    loading = true; error = null; notifyListeners();
    try {
      // 1) 세트 목록
      final allSets = await _api.menteeListPracticeSets();
      sets = allSets;

      // 2) 세트별 최신 시도(상태) 한 방에
      final latest = await _api.menteeListLatestAttemptsBySet();
      latestBySet = {
        for (final r in latest)
          (r['set_id'] as String): r,
      };

      // 3) 현재 진행중 카드: reviewed가 아닌 것 중 최근(제출일/회차) 우선
      Map<String, dynamic>? foundAttempt;
      Map<String, dynamic>? foundSet;

      for (final s in sets) {
        final sid = s['id'] as String;
        final la = latestBySet[sid];
        if (la == null) continue;

        final st = la['latest_status'] as String?;
        if (st != null && st != 'reviewed') {
          foundAttempt = {
            'attempt_id': la['latest_attempt_id'],
            'set_id': la['set_id'],
            'attempt_no': la['latest_attempt_no'],
            'status': st,
            'grade': la['latest_grade'],
            'feedback': la['latest_feedback'],
            'submitted_at': la['submitted_at'],
            'reviewed_at': la['reviewed_at'],
          };
          foundSet = s;
          break; // 가장 위의 첫 미완료 세트
        }
      }
      currentAttempt = foundAttempt;
      currentSet = foundSet;

      // 4) 완료율 (RPC 사용) — 혹은 latestBySet에서 reviewed 비율로 계산해도 됨
      completionRatio = await _api.menteePracticeCompletionRatio();

      loading = false; notifyListeners();
    } catch (e) {
      loading = false; error = '$e'; notifyListeners();
    }
  }

  void setFilter({required bool incompleteOnly}) {
    onlyIncomplete = incompleteOnly;
    notifyListeners();
  }

  List<Map<String, dynamic>> get filteredSets {
    if (!onlyIncomplete) return sets;
    return sets.where((s) {
      final sid = s['id'] as String;
      final la = latestBySet[sid];
      final st = la?['latest_status'] as String?;
      return st != 'reviewed'; // 최신 시도가 아직 검토완료가 아닌 세트만
    }).toList();
  }

  /// UI에서 배지 라벨 뽑을 때 사용
  String? statusLabelFor(String setId) {
    final la = latestBySet[setId];
    final st = la?['latest_status'] as String?;
    if (st == null) return null;
    return SupabaseService.instance.practiceStatusLabel(st);
  }
}
