import 'package:flutter/material.dart';
import 'package:nail/Pages/Manager/page/AssignMenteesPage.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/mentor.dart' as legacy; // 기존 Mentor 모델
import 'package:nail/Providers/AdminMentorDetailProvider.dart';
import 'package:nail/Pages/Manager/models/MenteeBrief.dart';
import 'package:nail/Pages/Manager/page/MentorEditPage.dart';
import 'package:nail/Pages/Manager/page/MenteePracticeListPage.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';

class MentorDetailPage extends StatefulWidget {
  final legacy.Mentor mentor; // 목록에서 받아옴
  const MentorDetailPage({super.key, required this.mentor});

  @override
  State<MentorDetailPage> createState() => _MentorDetailPageState();
}

class _MentorDetailPageState extends State<MentorDetailPage> {
  late legacy.Mentor _mentor = widget.mentor; // ← 편집 반영용 로컬 스냅샷
  bool _edited = false; // ← 추가

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MentorDetailProvider(mentorId: _mentor.id)..ensureLoaded(),
      child: _MentorDetailBody(
        mentor: _mentor,
        onMentorChanged: (m) {
          setState(() {
            _mentor = m;
            _edited = true;
          });
        },
        edited: _edited,
      ),
    );
  }
}

class _MentorDetailBody extends StatelessWidget {
  final legacy.Mentor mentor;
  final ValueChanged<legacy.Mentor> onMentorChanged;
  final bool edited;

  const _MentorDetailBody({
    required this.mentor,
    required this.onMentorChanged,
    required this.edited,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MentorDetailProvider>(
      builder: (context, p, _) {
        final loading = p.loading;
        final err = p.error;
        final mentees = p.mentees; // 직접 참조하여 변경 감지
        final overview = p.overview; // 직접 참조하여 변경 감지
        final menteesCount = mentees.length;
        final overviewMenteeCount = overview?.menteeCount;

        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context).pop(edited ? mentor : null);
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text(
                '선임 상세',
                style: TextStyle(
                  color: UiTokens.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: UiTokens.title),
                tooltip: '뒤로가기',
                onPressed: () {
                  Navigator.of(context).pop(edited ? mentor : null);
                },
              ),
              backgroundColor: Colors.white,
              elevation: 0,

              // 필요하면 다시 켜기
              actions: [
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit_rounded, color: UiTokens.title),
                  onPressed: () async {
                    final res = await Navigator.of(context).push<MentorEditResult>(
                      MaterialPageRoute(builder: (_) => MentorEditPage(initial: mentor)),
                    );
                    if (!context.mounted || res == null) return;

                    if (res.deleted) {
                      Navigator.of(context).pop(true); // 삭제는 그대로 bool
                      return;
                    }
                    if (res.mentor != null) {
                      onMentorChanged(res.mentor!);
                    }
                    await p.refresh();
                  },
                ),
              ],
            ),
            body: (loading && p.overview == null)
                ? const Center(child: CircularProgressIndicator())
                : (err != null)
                ? _Error(onRetry: p.refresh, message: err)
                : RefreshIndicator(
              onRefresh: p.refresh,
              color: UiTokens.primaryBlue,
              displacement: 36,
              child: CustomScrollView(
                // ✅ 핵심: 단일 스크롤 + AlwaysScrollable (후임가 적어도 당겨짐)
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          // ===== 상단 프로필 카드 =====
                          _HeaderCard(
                            name: mentor.name,
                            hiredAt: mentor.hiredAt,
                            menteeCount: overviewMenteeCount ??
                                (mentor.menteeCount ?? 0),
                            photoUrl: mentor.photoUrl,
                          ),
                          const SizedBox(height: 10),

                          // ===== KPI 3종 =====
                          _KpiGrid(
                            pendingTotal: p.overview?.pendingTotal ?? 0,
                            avgFeedbackDays: p.overview?.avgFeedbackDays,
                            handled7d: p.overview?.handledLast7d ?? 0,
                          ),

                          // ===== 후임 배정하기 버튼 =====
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: () async {
                                final assigned = await Navigator.of(context).push<int>(
                                  MaterialPageRoute(
                                    builder: (_) => AssignMenteesPage(targetMentorId: mentor.id),
                                  ),
                                );

                                if (!context.mounted) return;

                                // ✅ 무조건 갱신 (assigned가 0/null이어도 서버 데이터는 바뀌었을 수 있음)
                                await p.refresh();

                                if (assigned != null && assigned > 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$assigned명 배정 완료')),
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: UiTokens.primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '후임 배정하기',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== 목록 헤더 + 필터 =====
                          Row(
                            children: [
                              const Text(
                                '담당 후임',
                                style: TextStyle(
                                  color: UiTokens.title,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _openFilter(context, p),
                                icon: const Icon(
                                  Icons.filter_list_rounded,
                                  color: UiTokens.actionIcon,
                                  size: 18,
                                ),
                                label: Text(
                                  _filterLabel(p.onlyPending),
                                  style: const TextStyle(
                                    color: UiTokens.actionIcon,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ===== 후임 목록 (Sliver로) =====
                  if (menteesCount == 0)
                    SliverPadding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                      sliver: SliverToBoxAdapter(
                        child: _EmptyMentees(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, index) {
                            // 짝수: 타일 / 홀수: 간격
                            if (index.isOdd) {
                              return const SizedBox(height: 10);
                            }

                            final i = index ~/ 2;
                            final m = mentees[i];

                            return _MenteeTile(
                              mentee: m,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider<
                                        MentorDetailProvider>.value(
                                      value: p, // ✅ 동일 Provider 인스턴스 공유
                                      child: MenteePracticeListPage(
                                        mentorId: mentor.id,
                                        mentee: m,
                                        onUnassign: () async {
                                          final cnt =
                                          await p.unassignMentees([m.id]);
                                          return cnt > 0;
                                        },
                                      ),
                                    ),
                                  ),
                                );
                                if (context.mounted) p.refresh();
                              },
                            );
                          },
                          childCount: menteesCount * 2 - 1, // 타일+간격
                        ),
                      ),
                    ),

                  // ✅ Tail Spacer: pull 당길 때 아래 “짤림 체감” 완화
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 24 +
                          MediaQuery.of(context).padding.bottom +
                          120,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyMentees extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [UiTokens.cardShadow],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_outlined,
            size: 52,
            color: UiTokens.title.withOpacity(0.25),
          ),
          const SizedBox(height: 12),
          Text(
            '담당 후임가 없습니다',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.6),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '위의 “후임 배정하기” 버튼으로 후임를 배정해보세요',
            style: TextStyle(
              color: UiTokens.title.withOpacity(0.45),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const _Error({required this.onRetry, required this.message});

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print(message);

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          message,
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
          child: const Text('다시 시도'),
        ),
      ]),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final DateTime hiredAt;
  final int menteeCount;
  final String? photoUrl;

  const _HeaderCard({
    required this.name,
    required this.hiredAt,
    required this.menteeCount,
    this.photoUrl,
  });

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey[300],
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, color: Color(0xFF8C96A1))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                name,
                style: const TextStyle(
                  color: UiTokens.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '입사일: ${_fmtDate(hiredAt)}   후임: $menteeCount명',
                style: TextStyle(
                  color: UiTokens.title.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final int pendingTotal;
  final double? avgFeedbackDays;
  final int handled7d;

  const _KpiGrid({
    required this.pendingTotal,
    required this.avgFeedbackDays,
    required this.handled7d,
  });

  @override
  Widget build(BuildContext context) {
    final avgText =
    (avgFeedbackDays == null) ? '—' : avgFeedbackDays!.toStringAsFixed(1);

    return GridView(
      padding: EdgeInsets.only(bottom: 15),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      children: [
        _KpiTile(
          icon: Icons.fact_check_outlined,
          title: '검수 대기',
          value: '$pendingTotal',
          unit: '건',
        ),
        _KpiTile(
          icon: Icons.hourglass_bottom_rounded,
          title: '평균 소요일',
          value: avgText,
          unit: '일',
        ),
        _KpiTile(
          icon: Icons.done_all_rounded,
          title: '최근 7일 처리',
          value: '$handled7d',
          unit: '건',
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  const _KpiTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: UiTokens.actionIcon),
        const Spacer(),
        Text(
          title,
          style: TextStyle(
            color: UiTokens.title.withOpacity(0.7),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(
              color: UiTokens.title,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            children: [
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  color: UiTokens.primaryBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MenteeTile extends StatelessWidget {
  final MenteeBrief mentee;
  final VoidCallback? onTap;
  const _MenteeTile({required this.mentee, this.onTap});

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UiTokens.cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [UiTokens.cardShadow],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage:
              mentee.photoUrl != null ? NetworkImage(mentee.photoUrl!) : null,
              child: mentee.photoUrl == null
                  ? const Icon(Icons.person, color: Color(0xFF8C96A1))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mentee.name,
                    style: const TextStyle(
                      color: UiTokens.title,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '시작일: ${_fmtDate(mentee.startedAt)}',
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _PendingBadge(count: mentee.pendingCount),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: UiTokens.actionIcon),
          ],
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    final bool has = count > 0;
    final Color bg = has ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9);
    final Color border = has ? const Color(0xFFFCCFB3) : const Color(0xFFE2E8F0);
    final Color fg = has ? const Color(0xFFEA580C) : const Color(0xFF64748B);
    final String label = has ? '대기 ${count}건' : '대기 없음';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

enum MenteeFilter { all, pending }

String _filterLabel(bool onlyPending) => onlyPending ? '평가 대기 후임' : '전체';

Future<void> _openFilter(BuildContext context, MentorDetailProvider p) async {
  final current = p.onlyPending ? MenteeFilter.pending : MenteeFilter.all;

  final result = await showModalBottomSheet<MenteeFilter>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SortBottomSheet<MenteeFilter>(
      title: '필터',
      current: current,
      options: const [
        SortOption(value: MenteeFilter.all, label: '전체', icon: Icons.list_alt),
        SortOption(
          value: MenteeFilter.pending,
          label: '평가 대기 후임',
          icon: Icons.hourglass_bottom_rounded,
        ),
      ],
    ),
  );

  if (result != null) {
    await p.toggleOnlyPending(result == MenteeFilter.pending);
  }
}
