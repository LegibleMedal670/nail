import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nail/Pages/Manager/models/curriculum_item.dart';
import 'package:nail/Services/SupabaseService.dart';

class CurriculumProvider extends ChangeNotifier {
  static const _kCacheVersionKey = 'curriculum.version';
  static const _kCachePayloadKey = 'curriculum.payload.v2'; // ← 모델 변경으로 키 승격

  final List<CurriculumItem> _items = [];
  List<CurriculumItem> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  int? _currentVersion;
  int? get currentVersion => _currentVersion;

  bool _initialized = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> ensureLoaded() async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromCache();

    // 비차단 SWR
    // ignore: unawaited_futures
    _fetchFromServer();
  }

  Future<void> refresh({bool force = false}) async {
    await _fetchFromServer(force: force);
  }

  // ---- 내부 구현 ----

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kCachePayloadKey);
      final ver = prefs.getInt(_kCacheVersionKey);

      if (cachedJson != null) {
        final List list = jsonDecode(cachedJson) as List;
        final parsed = list
            .map((e) => _itemFromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.week.compareTo(b.week));

        _applyState(items: parsed, version: ver, loading: false, error: null);
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Curriculum cache load error: $e');
      }
    }
  }

  Future<void> _saveCache(int version, List<CurriculumItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(list.map(_itemToJson).toList());
      await prefs.setInt(_kCacheVersionKey, version);
      await prefs.setString(_kCachePayloadKey, payload);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Curriculum cache save error: $e');
      }
    }
  }

  Future<void> _fetchFromServer({bool force = false}) async {
    if (_loading && !force) return;
    _applyState(loading: true, error: null);

    try {
      // 1) 최신 버전 먼저 파악(있으면 그 버전만 조회 → 일관성 보장)
      final latest = await SupabaseService.instance.latestCurriculumVersion();

      // 2) 아이템 조회
      final items = await SupabaseService.instance.listCurriculumItems(version: latest);

      if (items.isEmpty) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Curriculum items empty from server');
        }
        _applyState(loading: false, error: '서버에서 커리큘럼을 찾을 수 없어요');
        return;
      }

      final version = latest ?? _currentVersion ?? 1;
      final sorted = [...items]..sort((a, b) => a.week.compareTo(b.week));

      _applyState(items: sorted, version: version, loading: false, error: null);

      // ignore: unawaited_futures
      _saveCache(version, sorted);
    } catch (e) {
      _applyState(loading: false, error: '불러오기 실패: $e');
    }
  }

  void _applyState({
    List<CurriculumItem>? items,
    int? version,
    bool? loading,
    String? error,
  }) {
    if (_disposed) return;

    var changed = false;

    if (items != null) {
      _items
        ..clear()
        ..addAll(items);
      changed = true;
    }
    if (version != null && version != _currentVersion) {
      _currentVersion = version;
      changed = true;
    }
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

  // ---- 캐시 직렬화 유틸 ----
  CurriculumItem _itemFromJson(Map<String, dynamic> j) {
    // goals: 캐시에 배열로 저장됨을 가정, 없으면 빈 배열
    final dynamic goalsRaw = j['goals'];
    final List<String> goals = (goalsRaw is List)
        ? goalsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : const <String>[];

    // resources: 캐시에 배열로 저장됨을 가정, 없으면 빈 배열
    final dynamic resourcesRaw = j['resources'];
    final List<Map<String, dynamic>> resources = (resourcesRaw is List)
        ? resourcesRaw
        .whereType<dynamic>()
        .map<Map<String, dynamic>>(
          (e) => e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{},
    )
        .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final String? examSetCode = (j['examSetCode'] as String?)?.trim();

    // requiresExam: 캐시 값이 있으면 우선, 없으면 examSetCode로 파생
    final bool requiresExam = (j['requiresExam'] == true) || ((examSetCode?.isNotEmpty ?? false));

    return CurriculumItem(
      id: j['id'] as String,
      week: j['week'] as int,
      title: j['title'] as String,
      summary: j['summary'] as String,
      goals: goals,
      durationMinutes: (j['durationMinutes'] as int?) ?? 0,
      hasVideo: j['hasVideo'] == true,
      videoUrl: (j['videoUrl'] as String?)?.trim().isEmpty == true ? null : j['videoUrl'] as String?,
      requiresExam: requiresExam,
      examSetCode: examSetCode,
      resources: resources,
    );
  }

  Map<String, dynamic> _itemToJson(CurriculumItem i) {
    return {
      'id': i.id,
      'week': i.week,
      'title': i.title,
      'summary': i.summary,
      'goals': i.goals,
      'durationMinutes': i.durationMinutes,
      'hasVideo': i.hasVideo,
      'videoUrl': i.videoUrl,
      'requiresExam': i.requiresExam,
      'examSetCode': i.examSetCode,
      'resources': i.resources,
    };
  }
}
