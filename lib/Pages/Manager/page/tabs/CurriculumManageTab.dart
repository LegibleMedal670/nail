import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Manager/page/CurriculumCreatePage.dart';
import 'package:nail/Pages/Manager/page/PracticeCreatePage.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Services/SupabaseService.dart';

/// 상위(ManagerMainPage)와 공유하는 전환 키
const String kKindTheory = 'theory';
const String kKindPractice = 'practice';

class CurriculumManageTab extends StatefulWidget {
  /// AppBar 토글과 동기화하기 위한 외부 상태(Notifer).
  /// 주입되지 않으면 기본값(kKindTheory)로만 동작.
  final ValueNotifier<String>? kindNotifier;

  const CurriculumManageTab({super.key, this.kindNotifier});

  @override
  State<CurriculumManageTab> createState() => _CurriculumManageTabState();
}

class _CurriculumManageTabState extends State<CurriculumManageTab> {
  // ---- 전환 상태(이론/실습) ----
  late String _kind = widget.kindNotifier?.value ?? kKindTheory;

  // ---- 실습 목록용 로컬 상태 ----
  bool _pracLoading = false;
  String? _pracError;
  List<_PracticeSet> _pracItems = const [];

  // 상위(AppBar 토글) 변경 시 동기화
  void _onKindChanged() {
    final v = widget.kindNotifier!.value;
    if (v == _kind) return;
    setState(() => _kind = v);
    if (_kind == kKindPractice) _loadPractice();
  }

  @override
  void initState() {
    super.initState();
    // 탭 초기 진입 시 커리큘럼 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CurriculumProvider>().ensureLoaded();
    });
    // 상위 Notifier 연동
    widget.kindNotifier?.addListener(_onKindChanged);
    if (_kind == kKindPractice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPractice());
    }
  }

  @override
  void dispose() {
    widget.kindNotifier?.removeListener(_onKindChanged);
    super.dispose();
  }

  // ===================== 기존 동작(이론) 그대로: 상세 열기 =====================
  Future<void> _openDetail(CurriculumItem item) async {
    final res = await Navigator.of(context).push<CurriculumDetailResult>(
      MaterialPageRoute(
        builder: (_) => CurriculumDetailPage(
          item: item,
          mode: CurriculumViewMode.adminEdit,
        ),
      ),
    );
    if (!mounted) return;
    if (res?.deleted == true) {
      await context.read<CurriculumProvider>().refresh(force: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('‘${item.title}’이(가) 삭제되었습니다.')),
      );
    } else {
      await context.read<CurriculumProvider>().refresh(force: true);
    }
  }

  // ===================== 실습 목록 로드 =====================
  Future<void> _loadPractice() async {
    setState(() {
      _pracLoading = true;
      _pracError = null;
    });
    try {
      final rows = await SupabaseService.instance.adminListPracticeSets(
        activeOnly: null, // 전체
        limit: 200,
        offset: 0,
      );

      _pracItems = rows
          .map((e) => _PracticeSet.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      _pracError = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _pracLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CurriculumProvider>();
    final items = provider.items;
    final loading = provider.loading;
    final error = provider.error;

    final bool isTheory = _kind == kKindTheory;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_course_add',
        backgroundColor: UiTokens.primaryBlue,
        onPressed: () async {
          if (isTheory) {
            // 기존 동작 그대로(이론 모듈 생성)
            final items = context.read<CurriculumProvider>().items;
            final nextWeek = items.isEmpty ? 1 : (items.map((e) => e.week).reduce(max) + 1);

            final res = await Navigator.push<CurriculumCreateResult>(
              context,
              MaterialPageRoute(
                builder: (_) => CurriculumCreatePage(suggestedWeek: nextWeek),
              ),
            );

            if (res != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('‘${res.item.title}’이(가) 생성되었습니다.')),
              );
            }
          } else {
            // 실습 생성(저장 → 목록 갱신)
            final nextCode = _computeNextPracticeCode();
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticeCreatePage(suggestedCode: nextCode),
              ),
            );
            if (!mounted) return;
            if (result != null) {
              await _loadPractice();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('실습 세트가 생성되었습니다')),
              );
            }
          }
        },
        icon: Icon(isTheory ? Icons.add_card_outlined : Icons.add_photo_alternate_outlined),
        label: Text(isTheory ? '이론 추가' : '실습 추가'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (isTheory) {
            await context.read<CurriculumProvider>().refresh(force: true);
          } else {
            await _loadPractice();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 카피(기존 디자인 유지)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  '교육 과정 목록',
                  style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // ===== 이론 뷰 =====
              if (isTheory) ...[
                if (loading && items.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Center(child: CircularProgressIndicator()),
                ] else if (error != null && items.isEmpty) ...[
                  const SizedBox(height: 40),
                  _ErrorBlock(
                    message: error,
                    onRetry: () => context.read<CurriculumProvider>().refresh(force: true),
                  ),
                ] else if (items.isEmpty) ...[
                  _EmptyBlock(onRetry: () => context.read<CurriculumProvider>().refresh(force: true)),
                ] else ...[
                  ListView.separated(
                    itemCount: items.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return CurriculumTile(
                        item: item,
                        onTap: () => _openDetail(item),
                      );
                    },
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('업데이트 중…', style: TextStyle(color: UiTokens.title)),
                      ],
                    ),
                  ],
                ],
              ]
              // ===== 실습 뷰: CurriculumTile.practice로 렌더 =====
              else ...[
                if (_pracLoading && _pracItems.isEmpty) ...[
                  const SizedBox(height: 80),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_pracError != null && _pracItems.isEmpty) ...[
                  const SizedBox(height: 40),
                  _ErrorBlock(
                    message: _pracError!,
                    onRetry: _loadPractice,
                  ),
                ] else if (_pracItems.isEmpty) ...[
                  _EmptyBlock(onRetry: _loadPractice),
                ] else ...[
                  ListView.separated(
                    itemCount: _pracItems.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final it = _pracItems[i];
                      final summary = _toSummary(it.instructions);
                      final badges = <String>[
                        '실습',
                        if (it.referenceImages.isNotEmpty) '예시사진 ${it.referenceImages.length}',
                        if (!it.active) 'inactive',
                      ];

                      return CurriculumTile.practice(
                        title: it.title,
                        summary: summary,
                        badges: badges,
                        onTap: () {
                          // TODO: 편집 페이지 연결
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('실습 ${it.code} 편집 화면은 추후 연결 예정입니다.')),
                          );
                        },
                      );
                    },
                  ),
                  if (_pracLoading) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('업데이트 중…', style: TextStyle(color: UiTokens.title)),
                      ],
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _toSummary(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '지시문 없음';
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  /// 현재 로컬에 로드된 실습 코드들(_pracItems)에서
  /// 'PS-###' 패턴만 모아 최대값+1을 반환. 없으면 'PS-001'.
  String _computeNextPracticeCode() {
    int maxNum = 0;
    final re = RegExp(r'^\s*PS-(\d+)\s*$');
    for (final it in _pracItems) {
      final m = re.firstMatch(it.code.trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    final next = maxNum + 1;
    return 'PS-${next.toString().padLeft(3, '0')}';
  }
}

class _EmptyBlock extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyBlock({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UiTokens.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 40, color: UiTokens.actionIcon),
          const SizedBox(height: 8),
          Text('등록된 교육 과정이 없습니다.', style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UiTokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(
            '불러오는 중 오류가 발생했어요',
            style: TextStyle(color: UiTokens.title.withOpacity(0.8), fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

// ===================== 실습 세트 모델 =====================
class _PracticeSet {
  final String id;
  final String code;
  final String title;
  final String? instructions;
  final List<String> referenceImages;
  final bool active;
  final String createdAt;
  final String updatedAt;

  _PracticeSet({
    required this.id,
    required this.code,
    required this.title,
    required this.instructions,
    required this.referenceImages,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _PracticeSet.fromJson(Map<String, dynamic> j) => _PracticeSet(
    id: j['id'] as String,
    code: j['code'] as String,
    title: j['title'] as String,
    instructions: j['instructions'] as String?,
    referenceImages: () {
      final v = j['reference_images'];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) {
        return (jsonDecode(v) as List).map((e) => e.toString()).toList();
      }
      return <String>[];
    }(),
    active: (j['active'] as bool?) ?? true,
    createdAt: j['created_at']?.toString() ?? '',
    updatedAt: j['updated_at']?.toString() ?? '',
  );
}
