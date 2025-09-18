import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';
import 'package:nail/Services/AdminMenteeService.dart';
import 'package:nail/Services/CourseProgressService.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';

/// 관리자 전용: 멘티 목록 + 진행 메트릭 + (지연)모듈별 상세 진행.
/// - 모든 화면(가장 빠른 신입 / 멘티 관리 / 멘티 상세)이 이 Provider만 보게 하여
///   '진행도 %'의 일관성을 보장.
/// - 게이지/퍼센트는 1차적으로 서버 메트릭(progress)을 사용.
/// - 뱃지/현재 모듈 등 세부는 per-mentee progressMap(지연 로딩) 사용.
/// - 필요 시 모듈맵으로 Fallback 계산하되, 최종 값은 clamp(0..1)로 방어(125% 등 방지).
class AdminProgressProvider extends ChangeNotifier {
  // ===== 1) 목록/메트릭 층 =====
  final List<Mentee> _mentees = [];
  bool _loading = false;
  String? _error;

  // userId -> loginKey (per-mentee 상세 로딩용)
  final Map<String, String> _loginKeyByUser = {};

  // ===== 2) 멘티별 상세(지연 로딩) =====
  // userId -> (moduleCode -> CurriculumProgress)
  final Map<String, Map<String, CurriculumProgress>> _progressByUser = {};
  final Set<String> _inflightUsers = {}; // 중복 로딩 방지

  // ===== 공개 Getter =====
  bool get loading => _loading;
  String? get error => _error;
  UnmodifiableListView<Mentee> get mentees => UnmodifiableListView(_mentees);

  /// 메트릭 기반 진행도(0~1). 없으면 모듈맵으로 Fallback.
  double progressOfUser(String userId) {
    final m = _menteesFirstWhere(userId);
    if (m != null) {
      final p = (m.progress.isNaN || m.progress.isInfinite) ? 0.0 : m.progress;
      return _clamp01(p);
    }
    // 없으면 Fallback
    final pm = _progressByUser[userId];
    if (pm != null) {
      final ratio = ProgressMath.ratioFromProgressMap(pm);
      return _clamp01(ratio);
    }
    return 0.0;
  }

  /// 진행 맵(모듈별)
  Map<String, CurriculumProgress>? progressMapFor(String userId) => _progressByUser[userId];

  /// 가장 진도가 빠른 멘티(동률이면 첫 번째)
  Mentee? get topMentee {
    if (_mentees.isEmpty) return null;
    final sorted = [..._mentees]..sort(
          (a,b) => (b.progress).compareTo(a.progress),
    );
    return sorted.first;
  }

  /// “주요 인물” 간단 집계(임시 규칙): 시작 30일↑ & (진행<100% or 평균점수<60)
  int get keyPeopleCount {
    final now = DateTime.now();
    int cnt = 0;
    for (final m in _mentees) {
      final days = now.difference(m.startedAt).inDays;
      final lowScore = (m.score ?? 101) < 60;
      final incomplete = progressOfUser(m.id) < 1.0;
      if (days >= 30 && (lowScore || incomplete)) cnt++;
    }
    return cnt;
  }

  // ===== 로드/리프레시 =====
  Future<void> ensureLoaded() async {
    if (_mentees.isNotEmpty || _loading) return;
    await refreshAll();
  }

  Future<void> refreshAll() async {
    _set(loading: true, error: null);

    try {
      // 관리자 메트릭: id, nickname, joined_at, mentor, photo_url, login_key, progress, ...
      final baseRows = await AdminMenteeService.instance.listMenteesMetrics(
        days: 30, lowScore: 60, maxAttempts: 5,
      );

      // 파싱(이미 AdminMenteeService에서 안전 처리했다면 단순 매핑)
      final list = <Mentee>[];
      _loginKeyByUser.clear();

      for (final raw in baseRows) {
        final r = Map<String, dynamic>.from(raw as Map);
        final uid = (r['id'] ?? '').toString();
        if (uid.isEmpty) continue;

        final mentee = Mentee.fromRow(r); // 너가 준 모델의 fromRow 사용
        list.add(mentee);

        final lk = (r['login_key'] ?? '').toString();
        if (lk.isNotEmpty) _loginKeyByUser[uid] = lk;
      }

      _mentees
        ..clear()
        ..addAll(list);
      _set(loading: false, error: null);
    } catch (e) {
      _set(loading: false, error: '불러오기 실패: $e');
    }
  }

  /// 멘티별 모듈 진행(지연 로딩). 없을 때만 가져옴.
  Future<void> loadMenteeProgress(String userId) async {
    if (_progressByUser.containsKey(userId)) return;
    if (_inflightUsers.contains(userId)) return;

    final loginKey = _loginKeyByUser[userId];
    if (loginKey == null || loginKey.isEmpty) return;

    _inflightUsers.add(userId);
    try {
      final map = await CourseProgressService.listCurriculumProgress(loginKey: loginKey);
      // clamp 방어 + 저장
      final fixed = <String, CurriculumProgress>{};
      map.forEach((moduleId, pr) {
        fixed[moduleId] = pr.copyWith(
          watchedRatio: _clamp01(pr.watchedRatio),
          // 나머지 필드는 그대로
        );
      });
      _progressByUser[userId] = fixed;
      notifyListeners();
    } catch (e) {
      // 조용히 실패 로그만
      if (kDebugMode) debugPrint('loadMenteeProgress($userId) failed: $e');
    } finally {
      _inflightUsers.remove(userId);
    }
  }

  /// 상세에서 진행 변화 발생 시(혹은 강제 최신화)
  Future<void> refreshMentee(String userId) async {
    // 캐시 무효화 후 재로딩
    _progressByUser.remove(userId);
    await loadMenteeProgress(userId);
  }

  // ===== 내부 유틸 =====
  void _set({bool? loading, String? error}) {
    var changed = false;
    if (loading != null && loading != _loading) {
      _loading = loading;
      changed = true;
    }
    if (error != _error) {
      _error = error;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Mentee? _menteesFirstWhere(String userId) {
    for (final m in _mentees) {
      if (m.id == userId) return m;
    }
    return null;
  }

  double _clamp01(double v) {
    if (v.isNaN || v.isInfinite) return 0.0;
    if (v < 0) return 0.0;
    if (v > 1) return 1.0;
    return v;
  }
}

/// 모든 화면이 동일한 '진행도 공식'을 쓰도록 제공하는 정적 헬퍼.
/// - 가급적 서버 메트릭(progress)을 1차로 사용하되,
///   필요 시 모듈맵만으로 동일 규칙을 재계산할 때 사용.
/// 규칙:
///   eligible = (hasVideo == true) || (hasExam == true)
///   done     = (moduleCompleted == true)
///   ratio    = done / eligible (0..1)
class ProgressMath {
  static double ratioFromProgressMap(Map<String, CurriculumProgress> map) {
    if (map.isEmpty) return 0.0;
    int eligible = 0;
    int done = 0;
    map.forEach((_, pr) {
      final hasVideo = pr.hasVideo ?? false;
      final hasExam = pr.hasExam ?? false;
      final eligibleThis = hasVideo || hasExam;
      if (!eligibleThis) return;
      eligible += 1;
      if (pr.moduleCompleted == true) {
        done += 1;
      }
    });
    if (eligible == 0) return 0.0;
    final r = done / eligible;
    if (r.isNaN || r.isInfinite) return 0.0;
    if (r < 0) return 0.0;
    if (r > 1) return 1.0;
    return r;
  }
}
