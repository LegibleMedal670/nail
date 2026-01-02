import 'package:flutter/foundation.dart';

import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Services/SupabaseService.dart';

class CurriculumProvider extends ChangeNotifier {
  final List<CurriculumItem> _items = [];
  List<CurriculumItem> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  int? _currentVersion;
  int? get currentVersion => _currentVersion;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> ensureLoaded() async {
    // 매번 서버에서 새로 로드 (캐시 없음)
    await _fetchFromServer();
  }

  Future<void> refresh({bool force = false}) async {
    await _fetchFromServer(force: force);
  }

  // ---- 내부 구현 ----

  Future<void> _fetchFromServer({bool force = false}) async {
    if (_loading && !force) return;
    _applyState(loading: true, error: null);

    try {
      // 1) 최신 버전 파악(있으면 그 버전만 조회)
      final latest = await SupabaseService.instance.latestCurriculumVersion();

      // 2) 아이템 조회 (옵션 A: 뷰 사용)
      final items = await SupabaseService.instance.listCurriculumItems(version: latest);

      // 빈 배열도 정상 처리 (에러 아님)
      final version = latest ?? _currentVersion ?? 1;
      final sorted = [...items]..sort((a, b) => a.week.compareTo(b.week));

      _applyState(items: sorted, version: version, loading: false, error: null);

      // 캐시 사용 안 함 - 매번 서버에서 로드
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

  void upsertLocal(CurriculumItem item) {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    _items.sort((a, b) => a.week.compareTo(b.week));
    notifyListeners();
  }
}
