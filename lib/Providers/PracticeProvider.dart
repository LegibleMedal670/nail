// lib/Providers/PracticeProvider.dart
import 'package:flutter/foundation.dart';
import 'package:nail/Services/SignatureService.dart';
import 'package:nail/Services/SupabaseService.dart';

class PracticeProvider extends ChangeNotifier {
  final _api = SupabaseService.instance;

  bool loading = false;
  String? error;

  double completionRatio = 0.0;

  Map<String, dynamic>? currentAttempt; // 진행중 카드
  Map<String, dynamic>? currentSet;
  String? currentCardType; // 'pending' or 'signature_needed'

  List<Map<String, dynamic>> sets = [];                 // 세트 목록(정적)
  Map<String, Map<String, dynamic>> latestBySet = {};   // set_id -> 최신시도 row
  Map<String, Map<String, dynamic>> signatureStatus = {}; // attempt_id -> {mentor_signed, mentee_signed}
  bool onlyIncomplete = false;

  Future<void> refreshAll({String? loginKey}) async {
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

      // 3) 서명 상태 조회 (loginKey가 있는 경우)
      if (loginKey != null && loginKey.isNotEmpty) {
        try {
          signatureStatus = await SignatureService.instance.getSignedPracticeAttempts(
            loginKey: loginKey,
          );
        } catch (e) {
          debugPrint('[PracticeProvider] Failed to load signature status: $e');
          signatureStatus = {};
        }
      }

      // 4) 현재 진행중 카드: 
      //    우선순위 1) reviewed가 아닌 것 (검토 대기/검토 중)
      //    우선순위 2) reviewed지만 서명 대기 (멘토 서명 완료, 멘티 서명 미완료)
      Map<String, dynamic>? foundAttempt;
      Map<String, dynamic>? foundSet;
      String? foundCardType;

      // 먼저 검토 대기/검토 중 찾기
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
          foundCardType = 'pending';
          break;
        }
      }

      // 검토 대기가 없으면 서명 대기 찾기
      if (foundAttempt == null) {
        for (final s in sets) {
          final sid = s['id'] as String;
          final la = latestBySet[sid];
          if (la == null) continue;

          final st = la['latest_status'] as String?;
          final attemptId = la['latest_attempt_id'] as String?;
          
          if (st == 'reviewed' && attemptId != null) {
            final signData = signatureStatus[attemptId];
            final mentorSigned = signData?['mentor_signed'] == true;
            final menteeSigned = signData?['mentee_signed'] == true;
            
            // 멘토는 서명했지만 멘티가 아직 안 한 경우
            if (mentorSigned && !menteeSigned) {
              foundAttempt = {
                'attempt_id': attemptId,
                'set_id': la['set_id'],
                'attempt_no': la['latest_attempt_no'],
                'status': st,
                'grade': la['latest_grade'],
                'feedback': la['latest_feedback'],
                'submitted_at': la['submitted_at'],
                'reviewed_at': la['reviewed_at'],
              };
              foundSet = s;
              foundCardType = 'signature_needed';
              break;
            }
          }
        }
      }

      currentAttempt = foundAttempt;
      currentSet = foundSet;
      currentCardType = foundCardType;

      // 5) 완료율 (RPC 사용) — 혹은 latestBySet에서 reviewed 비율로 계산해도 됨
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
