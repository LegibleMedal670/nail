import 'package:flutter/foundation.dart';
import 'package:nail/Services/MentorService.dart';

enum HistoryFilter { d7, d30, d90 }

class MentorProvider extends ChangeNotifier {
  final String mentorLoginKey;

  // 프로필(선택): CheckPasswordPage에서 넘겨주면 즉시 표기
  String? mentorName;
  String? mentorPhotoUrl;
  DateTime? mentorHiredAt;

  MentorProvider({
    required this.mentorLoginKey,
    this.mentorName,
    this.mentorPhotoUrl,
    this.mentorHiredAt,
  });

  // 탭
  int _tabIndex = 0;
  int get tabIndex => _tabIndex;
  void setTab(int i) { _tabIndex = i; notifyListeners(); }

  // 공통 로딩/에러
  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  String? get error => _error;

  // KPI
  int pendingTotal = 0;
  double? avgFeedbackDays;
  int handledLast7d = 0;

  // 큐
  String queueStatus = 'submitted'; // 'submitted' | 'reviewed'
  List<Map<String, dynamic>> queueItems = [];

  // 내 후임
  List<Map<String, dynamic>> mentees = [];
  bool onlyPendingMentees = false;

  // 히스토리
  List<Map<String, dynamic>> history = [];
  HistoryFilter historyRange = HistoryFilter.d30;
  String get historyRangeLabel {
    switch (historyRange) {
      case HistoryFilter.d7: return '최근 7일';
      case HistoryFilter.d30: return '최근 30일';
      case HistoryFilter.d90: return '최근 90일';
    }
  }

  final _api = MentorService.instance;

  Future<void> ensureLoaded() async {
    if (_loading) return;
    _set(loading: true, error: null);
    try {
      await Future.wait([
        refreshKpi(),
        refreshQueue(status: queueStatus),
        refreshMentees(onlyPending: onlyPendingMentees),
        refreshHistory(),
      ]);
      _set(loading: false, error: null);
    } catch (e) {
      _set(loading: false, error: e.toString());
    }
  }

  Future<void> refreshKpi() async {
    final k = await _api.fetchKpi(loginKey: mentorLoginKey);
    pendingTotal = k.pendingTotal;
    avgFeedbackDays = k.avgFeedbackDays;
    handledLast7d = k.handledLast7d;
    notifyListeners();
  }

  Future<void> refreshQueue({required String status}) async {
    queueStatus = status;
    queueItems = await _api.listQueue(
      loginKey: mentorLoginKey, status: status, limit: 50, offset: 0,
    );
    notifyListeners();
  }

  Future<void> refreshMentees({required bool onlyPending}) async {
    onlyPendingMentees = onlyPending;
    mentees = await _api.listMyMentees(
      loginKey: mentorLoginKey, onlyPending: onlyPendingMentees,
    );
    notifyListeners();
  }

  Future<void> setHistoryRange(HistoryFilter range) async {
    historyRange = range;
    await refreshHistory();
  }

  Future<void> refreshHistory() async {
    final days = switch (historyRange) {
      HistoryFilter.d7 => 7,
      HistoryFilter.d30 => 30,
      HistoryFilter.d90 => 90,
    };
    history = await _api.listMyHistory(loginKey: mentorLoginKey, lastNDays: days);
    notifyListeners();
  }

  // 리뷰 액션
  Future<void> reviewAttempt({
    required String attemptId,
    required String gradeKor, // '상'|'중'|'하'
    required String feedback,
  }) async {
    await _api.reviewAttempt(
      loginKey: mentorLoginKey,
      attemptId: attemptId,
      gradeKor: gradeKor,
      feedback: feedback,
    );
    await Future.wait([
      refreshQueue(status: queueStatus),
      refreshKpi(),
    ]);
  }

  void _set({bool? loading, String? error}) {
    bool changed = false;
    if (loading != null && loading != _loading) { _loading = loading; changed = true; }
    if (error != _error) { _error = error; changed = true; }
    if (changed) notifyListeners();
  }

  Future<void> refreshAllAfterReview() async {
    await Future.wait([
      refreshKpi(),
      refreshQueue(status: queueStatus),
      refreshMentees(onlyPending: onlyPendingMentees),
      refreshHistory(),
    ]);
  }
}
