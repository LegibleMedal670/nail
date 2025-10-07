// lib/Pages/Mentor/page/MentorMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:provider/provider.dart';
import 'package:nail/Providers/MentorProvider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Mentor/page/AttemptReviewPage.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';

class MentorMainPage extends StatelessWidget {
  final String mentorLoginKey;

  /// 체크패스워드에서 넘어오는 간단 프로필 (없으면 Provider가 KPI 로드 후 표기)
  final String? mentorName;
  final String? mentorPhotoUrl;
  final DateTime? mentorHiredAt;

  const MentorMainPage({
    super.key,
    required this.mentorLoginKey,
    this.mentorName,
    this.mentorPhotoUrl,
    this.mentorHiredAt,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MentorProvider(
        mentorLoginKey: mentorLoginKey,
        mentorName: mentorName,
        mentorPhotoUrl: mentorPhotoUrl,
        mentorHiredAt: mentorHiredAt,
      )..ensureLoaded(),
      child: const _ScaffoldView(),
    );
  }
}

class _ScaffoldView extends StatelessWidget {
  const _ScaffoldView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    return WillPopScope(
      onWillPop: () async => false, // ⛔ 뒤로가기 금지
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, // ⛔ 기본 뒤로가기 제거
          title: const Text(
            '멘토 대시보드',
            style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout_rounded, color: UiTokens.actionIcon),
              onPressed: () async {
                await context.read<UserProvider>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                  );
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: p.loading && p.error == null
            ? const Center(child: CircularProgressIndicator())
            : p.error != null
            ? _Error(message: p.error!, onRetry: () => p.ensureLoaded())
            : RefreshIndicator(
          color: UiTokens.primaryBlue,
          onRefresh: () async {
            await p.refreshKpi();
            if (p.tabIndex == 0) {
              await p.refreshQueue(status: p.queueStatus);
            } else if (p.tabIndex == 1) {
              await p.refreshMentees(onlyPending: p.onlyPendingMentees);
            } else {
              await p.refreshHistory();
            }
          },
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _ProfileHeader()),
              const SliverToBoxAdapter(child: _KpiHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              const SliverToBoxAdapter(child: _Tabs()),
              if (p.tabIndex == 0) const _QueueTab(),
              if (p.tabIndex == 1) const _MenteesTab(),
              if (p.tabIndex == 2) const _HistoryTab(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== 상단 프로필 카드 =====
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    final name = p.mentorName ?? '멘토';
    final photoUrl = p.mentorPhotoUrl;
    final hiredAtText = p.mentorHiredAt != null ? _fmtDate(p.mentorHiredAt!) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
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
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child:
              (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Color(0xFF8C96A1)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    hiredAtText != null ? '입사일: $hiredAtText' : '담당 멘티 현황을 확인하세요',
                    style: TextStyle(
                        color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== KPI 상단 그리드 =====
class _KpiHeader extends StatelessWidget {
  const _KpiHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1.0,
        ),
        children: [
          _KpiTile(icon: Icons.fact_check_outlined, title: '검수 대기', value: '${p.pendingTotal}', unit: '건'),
          _KpiTile(
            icon: Icons.hourglass_bottom_rounded,
            title: '평균 소요일',
            value: p.avgFeedbackDays == null ? '—' : p.avgFeedbackDays!.toStringAsFixed(1),
            unit: '일',
          ),
          _KpiTile(icon: Icons.done_all_rounded, title: '최근 7일 처리', value: '${p.handledLast7d}', unit: '건'),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  const _KpiTile({required this.icon, required this.title, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14), boxShadow: [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: UiTokens.actionIcon),
        const Spacer(),
        Text(title,
            style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(color: UiTokens.title, fontSize: 20, fontWeight: FontWeight.w900),
            children: [
              TextSpan(
                text: ' $unit',
                style: const TextStyle(color: UiTokens.primaryBlue, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// ===== 커스텀 세그먼트(대기 큐 / 내 멘티 / 히스토리) - 단일 인디케이터 =====
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    const labels = ['대기 큐', '내 멘티', '히스토리'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final totalW = c.maxWidth;
          final itemW = (totalW - 8) / labels.length; // 패딩 4+4
          final left = 4 + itemW * p.tabIndex;

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            height: 44,
            child: Stack(
              children: [
                // ✅ 하나의 하이라이트만 이동
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: left,
                  top: 4,
                  bottom: 4,
                  width: itemW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [UiTokens.cardShadow],
                    ),
                  ),
                ),
                // 라벨(정적) – 깜빡임 없음
                Row(
                  children: List.generate(labels.length, (i) {
                    final selected = p.tabIndex == i;
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => context.read<MentorProvider>().setTab(i),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color: selected ? UiTokens.title : const Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===== (A) 대기 큐 탭 =====
class _QueueTab extends StatelessWidget {
  const _QueueTab();

  Future<void> _openQueueFilter(BuildContext context) async {
    final p = context.read<MentorProvider>();
    final current = p.queueStatus == 'submitted' ? _QueueFilter.waiting : _QueueFilter.reviewed;

    final result = await showModalBottomSheet<_QueueFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<_QueueFilter>(
        current: current,
        title: '상태 필터',
        options: [
          SortOption(value: _QueueFilter.waiting, label: '대기', icon: Icons.hourglass_bottom_rounded),
          SortOption(value: _QueueFilter.reviewed, label: '완료', icon: Icons.done_all_rounded),
        ],
      ),
    );

    if (result != null) {
      final status = result == _QueueFilter.waiting ? 'submitted' : 'reviewed';
      await p.refreshQueue(status: status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    return SliverList.list(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Text('실습 대기/완료',
                style: TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openQueueFilter(context),
              icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
              label: Text(
                p.queueStatus == 'submitted' ? '대기' : '완료',
                style: const TextStyle(
                    color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (p.queueItems.isEmpty)
        _Empty(
          message: p.queueStatus == 'submitted' ? '리뷰할 과제가 없습니다.' : '완료된 리뷰가 없습니다.',
        ),
      if (p.queueItems.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (ctx, i) {
              final it = p.queueItems[i];
              final bool isWaiting = p.queueStatus == 'submitted';
              final dynamic date = isWaiting ? it['submitted_at'] : it['reviewed_at'];
              final String dateLabel = isWaiting ? '제출일' : '검토일';
              final String? rating = isWaiting ? null : (it['rating'] as String?);

              return _QueueItemCard(
                menteeName: '${it['mentee_name'] ?? ''}',
                setCode: '${it['set_code'] ?? ''}',
                attemptNo: (it['attempt_no'] as num?)?.toInt() ?? 0,
                date: date,
                dateLabel: dateLabel,
                waiting: isWaiting,
                rating: rating,
                onOpen: () async {
                  // 완료건도 열 수는 있게 두되, 서버에서 중복 리뷰 방지하도록(권장)
                  await Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (inner) => AttemptReviewPage(
                        mentorLoginKey: p.mentorLoginKey,
                        attemptId: '${it['id']}',
                      ),
                    ),
                  );
                  if (ctx.mounted) {
                    ctx.read<MentorProvider>().refreshQueue(status: p.queueStatus);
                    ctx.read<MentorProvider>().refreshKpi();
                  }
                },
              );
            },
            separatorBuilder: (ctx, __) => const SizedBox(height: 10),
            itemCount: p.queueItems.length,
          ),
        ),
    ]);
  }
}

enum _QueueFilter { waiting, reviewed }

/// ===== (B) 내 멘티 탭 =====
class _MenteesTab extends StatelessWidget {
  const _MenteesTab();

  Future<void> _openMenteeFilter(BuildContext context) async {
    final p = context.read<MentorProvider>();
    final result = await showModalBottomSheet<_MenteeFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<_MenteeFilter>(
        title: '필터',
        current: p.onlyPendingMentees ? _MenteeFilter.pending : _MenteeFilter.all,
        options: const [
          SortOption(value: _MenteeFilter.all, label: '전체', icon: Icons.list_alt),
          SortOption(value: _MenteeFilter.pending, label: '평가 대기 멘티', icon: Icons.hourglass_bottom_rounded),
        ],
      ),
    );
    if (result != null) {
      await p.refreshMentees(onlyPending: result == _MenteeFilter.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    return SliverList.list(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            const Text('담당 멘티',
                style: TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openMenteeFilter(context),
              icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
              label: Text(
                p.onlyPendingMentees ? '평가 대기 멘티' : '전체',
                style: const TextStyle(
                    color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
      if (p.mentees.isEmpty)
        const _Empty(message: '배정된 멘티가 없습니다.'),
      if (p.mentees.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.mentees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = p.mentees[i];
              final has = (m['pending_count'] ?? 0) > 0;
              final photoUrl = m['photo_url'] as String?;
              final joined = (m['joined_at'] ?? '').toString().split(' ').first;

              return InkWell(
                onTap: () {
                  // TODO: 멘티 드릴다운 페이지 연결(이전 시도 목록 등)
                },
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
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(Icons.person, color: Color(0xFF8C96A1))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m['nickname'] ?? ''}',
                              style: const TextStyle(
                                  color: UiTokens.title, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('가입일: $joined',
                              style: TextStyle(
                                  color: UiTokens.title.withOpacity(0.6),
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      _PendingBadge(count: (m['pending_count'] ?? 0) as int),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: UiTokens.actionIcon),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
    ]);
  }
}

enum _MenteeFilter { all, pending }

/// ===== (C) 히스토리 탭 =====
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  Future<void> _openHistoryFilter(BuildContext context) async {
    final p = context.read<MentorProvider>();
    final result = await showModalBottomSheet<HistoryFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<HistoryFilter>(
        title: '기간',
        current: p.historyRange,
        options: const [
          SortOption(value: HistoryFilter.d7, label: '최근 7일', icon: Icons.calendar_view_week),
          SortOption(value: HistoryFilter.d30, label: '최근 30일', icon: Icons.calendar_view_month),
          SortOption(value: HistoryFilter.d90, label: '최근 90일', icon: Icons.event_note_rounded),
        ],
      ),
    );
    if (result != null) {
      await p.setHistoryRange(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MentorProvider>();
    return SliverList.list(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            const Text('나의 리뷰 히스토리',
                style: TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openHistoryFilter(context),
              icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
              label: Text(
                p.historyRangeLabel,
                style: const TextStyle(
                    color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
      if (p.history.isEmpty)
        const _Empty(message: '최근 리뷰 내역이 없습니다.'),
      if (p.history.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = p.history[i];
              return _QueueItemCard(
                menteeName: '${it['mentee_name'] ?? ''}',
                setCode: '${it['set_code'] ?? ''}',
                attemptNo: it['attempt_no'] ?? 0,
                // 검토일 표시 + 등급 배지
                date: it['reviewed_at'],
                dateLabel: '검토일',
                waiting: false,
                rating: (it['rating'] as String?),
                onOpen: () {}, // 읽기 전용 상세 페이지(선택)
              );
            },
          ),
        ),
    ]);
  }
}

/// ===== 공통 카드 & 배지들 =====

/// 날짜 문자열만 추출 (dynamic 안전 파서)
String _fmtDateOnly(dynamic v) {
  if (v == null) return '';
  try {
    if (v is DateTime) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    final s = v.toString();
    // ISO8601 or "YYYY-MM-DD ..."
    final DateTime d = DateTime.tryParse(s) ??
        DateTime.tryParse(s.split(' ').first) ??
        DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return v.toString().split(' ').first;
  }
}

class _QueueItemCard extends StatelessWidget {
  final String menteeName;
  final String setCode;
  final int attemptNo;
  final dynamic date;     // 제출일/검토일(any)
  final String dateLabel; // '제출일' 또는 '검토일'
  final bool waiting;     // 큐: true → '대기' 배지
  final String? rating;   // 히스토리: 'high'|'mid'|'low'
  final VoidCallback onOpen;

  const _QueueItemCard({
    required this.menteeName,
    required this.setCode,
    required this.attemptNo,
    required this.date,
    required this.dateLabel,
    required this.waiting,
    required this.rating,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = _fmtDateOnly(date);

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UiTokens.cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [UiTokens.cardShadow],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined, color: UiTokens.actionIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$menteeName • $setCode • $attemptNo회차',
                  style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('$dateLabel: $dateText',
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ]),
          ),
          if (waiting) const _StatusBadgeWaiting(),
          if (!waiting && rating != null) _StatusBadgeRating(rating: rating!),
        ]),
      ),
    );
  }
}

class _StatusBadgeWaiting extends StatelessWidget {
  const _StatusBadgeWaiting();

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF7ED);
    const border = Color(0xFFFCCFB3);
    const fg = Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 14, color: fg),
          SizedBox(width: 4),
          Text('대기', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusBadgeRating extends StatelessWidget {
  final String rating; // 'high'|'mid'|'low'
  const _StatusBadgeRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    late Color bg, border, fg;
    late String label;
    late IconData icon;

    switch (rating) {
      case 'high':
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFB7F3DB);
        fg = const Color(0xFF059669);
        label = '상';
        icon = Icons.trending_up_rounded;
        break;
      case 'mid':
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFE2E8F0);
        fg = const Color(0xFF64748B);
        label = '중';
        icon = Icons.horizontal_rule_rounded;
        break;
      default: // 'low' or else
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = '하';
        icon = Icons.trending_down_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
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
    final String label = has ? '대기 $count건' : '대기 없음';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 20),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
              color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message,
              style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
            child: const Text('다시 시도'),
          ),
        ]));
  }
}
