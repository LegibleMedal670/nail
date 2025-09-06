import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nail/Pages/Manager/models/curriculum_item.dart';
import 'package:nail/Services/SupabaseService.dart';

class CurriculumProvider extends ChangeNotifier {
  static const _kCacheVersionKey = 'curriculum.version';
  static const _kCachePayloadKey = 'curriculum.payload';

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
        final parsed = list.map((e) => _itemFromJson(e as Map<String, dynamic>)).toList()
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
      // ✅ 서비스에서 곧바로 모델을 받아온다
      final items = await SupabaseService.instance.listCurriculumItems();

      if (items.isEmpty) {
        print('아이템비어있음');
        _applyState(loading: false, error: '서버에서 커리큘럼을 찾을 수 없어요');
        return;
      }

      final version =
          await SupabaseService.instance.latestCurriculumVersion() ??
              _currentVersion ??
              1;

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
    return CurriculumItem(
      id: j['id'] as String,
      week: j['week'] as int,
      title: j['title'] as String,
      summary: j['summary'] as String,
      durationMinutes: (j['durationMinutes'] as int?) ?? 0,
      hasVideo: j['hasVideo'] == true,
      videoUrl: (j['videoUrl'] as String?)?.trim().isEmpty == true ? null : j['videoUrl'] as String?,
      requiresExam: j['requiresExam'] == true,
    );
  }

  Map<String, dynamic> _itemToJson(CurriculumItem i) {
    return {
      'id': i.id,
      'week': i.week,
      'title': i.title,
      'summary': i.summary,
      'durationMinutes': i.durationMinutes,
      'hasVideo': i.hasVideo,
      'videoUrl': i.videoUrl,
      'requiresExam': i.requiresExam,
    };
  }
}
