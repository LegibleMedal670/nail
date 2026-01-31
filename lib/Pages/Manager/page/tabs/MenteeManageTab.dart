// lib/Pages/Manager/page/tabs/MenteeManageTab.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Manager/models/MenteeEdtitResult.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';
import 'package:nail/Pages/Manager/page/MenteeDetailPage.dart';
import 'package:nail/Pages/Manager/page/MenteeEditPage.dart';
import 'package:nail/Pages/Manager/widgets/MenteeSummaryTile.dart';
import 'package:nail/Pages/Manager/widgets/MetricCard.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';

import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Providers/AdminProgressProvider.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';

/// 정렬 옵션
enum MenteeSort { latest, name, progress }

/// ===== 후임 관리 탭 =====
class MenteeManageTab extends StatefulWidget {
  const MenteeManageTab({super.key});

  @override
  State<MenteeManageTab> createState() => _MenteeManageTabState();
}

class _MenteeManageTabState extends State<MenteeManageTab> {
  MenteeSort _sort = MenteeSort.latest;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후 안전하게 전역 데이터 보장 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CurriculumProvider>().ensureLoaded();
      context.read<AdminProgressProvider>().ensureLoaded(); // 후임+메트릭 일괄 로드
    });
  }

  // ===== 정렬 =====
  String _sortLabel(MenteeSort s) => switch (s) {
    MenteeSort.latest => '최신 시작순',
    MenteeSort.name => '가나다순',
    MenteeSort.progress => '진척도순',
  };

  List<Mentee> _sorted({
    required List<Mentee> src,
    required AdminProgressProvider admin,
  }) {
    final list = [...src];
    int cmpNum(num a, num b) => a.compareTo(b);
    switch (_sort) {
      case MenteeSort.latest:
        list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        break;
      case MenteeSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case MenteeSort.progress:
        list.sort((a, b) => cmpNum(
          admin.progressOfUser(b.id), // ✅ Provider의 퍼센트
          admin.progressOfUser(a.id),
        ));
        break;
    }
    return list;
  }

  Future<void> _showSortSheet() async {
    final result = await showModalBottomSheet<MenteeSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<MenteeSort>(
        title: '정렬 선택',
        current: _sort,
        options: const [
          SortOption(value: MenteeSort.latest, label: '최신 시작순', icon: Icons.history_toggle_off),
          SortOption(value: MenteeSort.name, label: '가나다순', icon: Icons.sort_by_alpha),
          SortOption(value: MenteeSort.progress, label: '진척도순', icon: Icons.trending_up),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _sort = result);
  }

  // ===== 추가 버튼 처리 =====
  Future<void> _addMentee(List<Mentee> mentees) async {
    final existing =
    mentees.map((m) => m.accessCode).where((s) => s.isNotEmpty).toSet();

    final res = await Navigator.of(context).push<MenteeEditResult>(
      MaterialPageRoute(builder: (_) => MenteeEditPage(existingCodes: existing)),
    );

    if (!mounted) return;
    if (res?.mentee != null) {
      await context.read<AdminProgressProvider>().refreshAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('후임 "${res!.mentee!.name}" 추가됨')),
      );
    }
  }

  // ===== 빈 목록 상태 =====
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: UiTokens.title.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 후임가 없습니다',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아래 버튼을 눌러 후임를 추가해보세요',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// ===== KPI Grid (고정 높이 ❌ / 내용 기반 높이 ✅) =====
  Widget _buildKpiGrid({
    required BuildContext context,
    required int totalMentees,
    required int unassignedCount,
    required double avgScore,
    required int keyPeople,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;

        // 화면 폭에 따라 칼럼 수 반응형
        final int crossAxisCount = width >= 900
            ? 4
            : (width >= 600 ? 3 : 2);

        // 접근성 텍스트 배율을 반영해 타일 높이 보정
        final textScale =
        MediaQuery.textScaleFactorOf(ctx).clamp(1.0, 1.6);
        const baseTileHeight = 140.0; // 내용이 쾌적하게 들어가는 기준 높이
        final tileHeight = baseTileHeight * textScale;

        return GridView(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(), // 바깥 스크롤에 위임
          shrinkWrap: true, // 내용 크기만큼만 차지
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            mainAxisExtent: tileHeight, // 비율 대신 고정 높이로 안정화
          ),
          children: [
            MetricCard.rich(
              icon: Icons.people_alt_outlined,
              title: '총 후임 수',
              rich: TextSpan(
                text: '$totalMentees',
                style: const TextStyle(
                  color: UiTokens.title,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
                children: [
                  const TextSpan(
                    text: ' 명',
                    style: TextStyle(
                      color: UiTokens.primaryBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: '\n미배정 $unassignedCount명',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // MetricCard.simple(
            //   icon: Icons.grade_outlined,
            //   title: '후임 평균 점수',
            //   value: avgScore.toStringAsFixed(0),
            //   unit: '점',
            // ),
            // const MetricCard.simple(
            //   icon: Icons.hourglass_bottom_outlined,
            //   title: '최종 평가를 기다리는 후임',
            //   value: '18',
            //   unit: '명',
            // ),
            MetricCard.simple(
              icon: Icons.priority_high_rounded,
              title: '주요 인물',
              value: '$keyPeople',
              unit: '명',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProgressProvider>();
    final curri = context.watch<CurriculumProvider>();

    final loading = admin.loading;
    final error = admin.error;
    final mentees = admin.mentees;

    // KPI
    final totalMentees = mentees.length;

    // ✅ 미배정: mentorId == null 으로 판정 (표시 텍스트 의존 X)
    final unassignedCount =
        mentees.where((m) => m.mentorId == null).length;

    final avgScore = () {
      final xs = mentees.map((m) => m.score).whereType<double>().toList();
      if (xs.isEmpty) return 0.0;
      return xs.reduce((a, b) => a + b) / xs.length;
    }();
    final keyPeople = admin.keyPeopleCount;

    final sorted = _sorted(src: mentees, admin: admin);

    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : (error != null
        ? Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error,
              style: const TextStyle(
                  color: UiTokens.title,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => admin.refreshAll(),
            style: FilledButton.styleFrom(
                backgroundColor: UiTokens.primaryBlue),
            child: const Text('다시 시도',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: () => admin.refreshAll(),
      color: UiTokens.primaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== KPI 카드 (반응형, 내용 기반 높이) =====
            _buildKpiGrid(
              context: context,
              totalMentees: totalMentees,
              unassignedCount: unassignedCount,
              avgScore: avgScore,
              keyPeople: keyPeople,
            ),
            const SizedBox(height: 8),

            // ===== 목록 헤더 + 정렬 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  const Text('후임 목록',
                      style: TextStyle(
                          color: UiTokens.title,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showSortSheet,
                    icon: const Icon(Icons.filter_list_rounded,
                        color: UiTokens.actionIcon, size: 18),
                    label: Text(_sortLabel(_sort),
                        style: const TextStyle(
                            color: UiTokens.actionIcon,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      foregroundColor: UiTokens.actionIcon,
                      minimumSize: const Size(0, 0),
                      tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

                            // ===== 후임 목록 =====
                            if (sorted.isEmpty)
                              _buildEmptyState()
                            else
                              ListView.separated(
                                itemCount: sorted.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                                itemBuilder: (itemCtx, i) {
                                  final m = sorted[i];

                // 지연 로딩: 모듈별 진행 맵
                admin.loadMenteeProgress(m.id);

                final curriculum = curri.items;

                // 모듈별 진행 맵 -> 타일 바인딩용으로 변환
                final pm = admin.progressMapFor(m.id) ??
                    const <String, CurriculumProgress>{};

                final watchRatio = <String, double>{
                  for (final e in pm.entries)
                    e.key: e.value.watchedRatio.clamp(0.0, 1.0),
                };
                final examMap = <String, ExamRecord>{
                  for (final e in pm.entries)
                    e.key: ExamRecord(
                      attempts: e.value.attempts,
                      bestScore: e.value.bestScore,
                      passed: (e.value.examPassed ?? e.value.passed),
                    ),
                };

                final progress =
                admin.progressOfUser(m.id); // ✅ 단일 공식

                return MenteeSummaryTile(
                  mentee: m,
                  curriculum: curriculum,
                  watchRatio: watchRatio,
                  examMap: examMap,
                  overrideProgress:
                  progress, // ✅ 게이지 강제 일치(타일에 필드 추가 필요)
                  onDetail: () async {
                    final pageCtx = this.context;
                    final existing = mentees
                        .where((x) => x.id != m.id)
                        .map((x) => x.accessCode)
                        .where((s) => s.isNotEmpty)
                        .toSet();

                    // 현재 상세는 기존 시그니처 유지
                    final res = await Navigator.of(pageCtx)
                        .push<MenteeEditResult?>(
                      MaterialPageRoute(
                        builder: (_) => MenteeDetailPage(
                          mentee: m,
                          existingCodes: existing,
                        ),
                      ),
                    );

                    if (!mounted) return;

                    // 상세에서 변경 후 목록 최신화
                    await admin.refreshAll();

                    if (res?.deleted == true) {
                      ScaffoldMessenger.of(pageCtx).showSnackBar(
                        const SnackBar(
                            content: Text('후임가 삭제되었습니다')),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: body,
    );
  }
}
