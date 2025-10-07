// lib/Providers/PracticeProvider.dart
import 'package:flutter/foundation.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 실습(멘티) 화면 전용 Provider
/// - 상단 게이지(검토완료 비율)
/// - 진행중 카드(가장 최근 'reviewed'가 아닌 시도)
/// - 실습 세트 목록 + (선택) 상세 캐시
class PracticeProvider extends ChangeNotifier {
  final _api = SupabaseService.instance;

  bool loading = false;
  String? error;

  // 상단 프로필 게이지(검토완료 비율 0.0~1.0)
  double completionRatio = 0.0;

  // 현재 진행중 카드 (reviewed가 아닌 가장 최근 시도)
  Map<String, dynamic>? currentAttempt; // {attempt_id, set_id, attempt_no, status, grade, feedback, submitted_at, reviewed_at}
  Map<String, dynamic>? currentSet;     // {id, code, title, ...}

  // 세트 목록
  List<Map<String, dynamic>> sets = [];
  bool onlyIncomplete = false;

  // 상세 캐시(과호출 방지)
  final Map<String, Map<String, dynamic>> _detailCache = {};

  /// 메인 새로고침: 세트 → 진행중 추출 → 완료율
  Future<void> refreshAll() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // 1) 세트 목록
      final all = await _api.menteeListPracticeSets();
      sets = all;

      // 2) 진행중(= reviewed 아님)인 첫 세트 탐색
      Map<String, dynamic>? foundAttempt;
      Map<String, dynamic>? foundSet;

      for (final s in sets) {
        final setId = '${s['id']}';
        final det = await menteePracticeSetDetailCached(setId: setId, force: true);
        final status = det?['current_status']?.toString();

        // 진행중 조건: submitted/reviewing 등 reviewed가 아닌 것
        if (status != null && status != 'reviewed') {
          foundAttempt = {
            'attempt_id': det?['current_attempt_id'],
            'set_id': det?['set_id'],
            'attempt_no': det?['current_attempt_no'],
            'status': det?['current_status'],
            'grade': det?['current_grade'],
            'feedback': det?['current_feedback'],
            'submitted_at': det?['current_submitted_at'],
            'reviewed_at': det?['current_reviewed_at'],
          };
          foundSet = s;
          break;
        }
      }
      currentAttempt = foundAttempt;
      currentSet = foundSet;

      // 3) 완료율(RPC)
      completionRatio = await _api.menteePracticeCompletionRatio();

      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = '$e';
      notifyListeners();
    }
  }

  /// 단일 세트 상세(캐시 우선, force=true면 갱신)
  Future<Map<String, dynamic>?> menteePracticeSetDetailCached({
    required String setId,
    bool force = false,
  }) async {
    if (!force && _detailCache.containsKey(setId)) {
      return _detailCache[setId];
    }
    final det = await _api.menteePracticeSetDetail(setId: setId);
    if (det != null) {
      _detailCache[setId] = det;
      // 상세가 갱신되면 뱃지/필터가 달라질 수 있으므로 통지
      notifyListeners();
    }
    return det;
  }

  /// 특정 세트에 대한 상태 문자열(타일 뱃지용) — 캐시 없으면 null
  String? cachedStatusForSetId(String setId) {
    final det = _detailCache[setId];
    return det?['current_status']?.toString();
  }

  /// 목록 필터 토글
  void setFilter({required bool incompleteOnly}) {
    onlyIncomplete = incompleteOnly;
    notifyListeners();
  }

  /// 필터된 목록(현재는 전체 반환; 상세 캐시 확장 시 '미완료' 구분 적용)
  List<Map<String, dynamic>> get filteredSets {
    if (!onlyIncomplete) return sets;
    // 간단 버전: 상세 캐시가 있는 항목만 대상으로 미완료 필터를 적용할 수 있음
    // 이후 서버에서 "세트별 최신상태 요약 리스트" RPC가 생기면 그 결과를 기반으로 정확히 필터링.
    return sets;
  }

  /// 진행중 카드만 갱신(상태 새로고침 버튼 등에서 사용)
  Future<void> refreshCurrentCard() async {
    try {
      Map<String, dynamic>? foundAttempt;
      Map<String, dynamic>? foundSet;

      for (final s in sets) {
        final setId = '${s['id']}';
        final det = await menteePracticeSetDetailCached(setId: setId, force: true);
        final status = det?['current_status']?.toString();
        if (status != null && status != 'reviewed') {
          foundAttempt = {
            'attempt_id': det?['current_attempt_id'],
            'set_id': det?['set_id'],
            'attempt_no': det?['current_attempt_no'],
            'status': det?['current_status'],
            'grade': det?['current_grade'],
            'feedback': det?['current_feedback'],
            'submitted_at': det?['current_submitted_at'],
            'reviewed_at': det?['current_reviewed_at'],
          };
          foundSet = s;
          break;
        }
      }
      currentAttempt = foundAttempt;
      currentSet = foundSet;
      notifyListeners();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  /// 완료율만 별도 갱신(프로필 카드의 "새로고침" 등에서 사용)
  Future<void> refreshCompletionRatio() async {
    try {
      completionRatio = await _api.menteePracticeCompletionRatio();
      notifyListeners();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  /// 내부 캐시 비우기(로그아웃/하드 리프레시 등)
  void clearCache() {
    _detailCache.clear();
    currentAttempt = null;
    currentSet = null;
    notifyListeners();
  }
}
