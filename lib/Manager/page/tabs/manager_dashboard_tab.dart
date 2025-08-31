import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/mentee.dart';
import 'package:nail/Manager/widgets/MetricCard.dart';
import 'package:nail/Manager/widgets/mentee_expandable_tile.dart';
import 'package:nail/Manager/widgets/sort_bottom_sheet.dart';

class ManagerDashboardTab extends StatefulWidget {
  final double completionRate;   // %
  final double avgScore;         // 점
  final int waitingFinalReview;  // 명
  final double menteesPerMentor; // 명

  final List<Mentee> mentees;

  const ManagerDashboardTab({
    super.key,
    required this.completionRate,
    required this.avgScore,
    required this.waitingFinalReview,
    required this.menteesPerMentor,
    required this.mentees,
  });

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  MenteeSort _sort = MenteeSort.latest;
  Mentee? _expanded;

  List<Mentee> get _sorted {
    final list = List<Mentee>.from(widget.mentees);
    switch (_sort) {
      case MenteeSort.latest:
        list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        break;
      case MenteeSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case MenteeSort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
    }
    return list;
  }

  String _sortLabel(MenteeSort s) => switch (s) {
    MenteeSort.latest => '최신순',
    MenteeSort.name => '가나다순',
    MenteeSort.progress => '진척도순',
  };

// 호출부
  Future<void> _showMenteeSortSheet() async {
    final result = await showModalBottomSheet<MenteeSort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SortBottomSheet<MenteeSort>(
        title: '정렬 선택',
        current: _sort, // 현재 선택
        options: const [
          SortOption(value: MenteeSort.latest, label: '최신순', icon: Icons.new_releases_outlined),
          SortOption(value: MenteeSort.name, label: '가나다순', icon: Icons.sort_by_alpha),
          SortOption(value: MenteeSort.progress, label: '진척도순', icon: Icons.trending_up_outlined),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _sort = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        children: [
          // 4 카드
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.33,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.35,
              children: [
                MetricCard.simple(
                  icon: Icons.school_outlined,
                  iconColor: UiTokens.primaryBlue,
                  title: '교육 완료율',
                  value: widget.completionRate.toStringAsFixed(0),
                  unit: '%',
                ),
                MetricCard.simple(
                  icon: Icons.star_rate_rounded,
                  iconColor: UiTokens.primaryBlue,
                  title: '평가 평균 점수',
                  value: widget.avgScore.toStringAsFixed(0),
                  unit: '점',
                ),
                MetricCard.simple(
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: UiTokens.primaryBlue,
                  title: '최종 평가를 기다리는 멘티',
                  value: '${widget.waitingFinalReview}',
                  unit: '명',
                ),
                MetricCard.simple(
                  icon: Icons.group_outlined,
                  iconColor: UiTokens.primaryBlue,
                  title: '멘토 당 평균 멘티 수',
                  value: widget.menteesPerMentor.toStringAsFixed(1),
                  unit: '명',
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 헤더 + 정렬
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                const Text(
                  '멘티 현황',
                  style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showMenteeSortSheet,
                  icon: const Icon(Icons.keyboard_arrow_down_outlined, color: UiTokens.actionIcon, size: 18),
                  label: Text(
                    _sortLabel(_sort),
                    style: const TextStyle(
                      color: UiTokens.actionIcon,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    foregroundColor: UiTokens.actionIcon,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // 리스트
          ListView.separated(
            itemCount: _sorted.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = _sorted[i];
              final expanded = identical(_expanded, m);
              return MenteeExpandableTile(
                mentee: m,
                expanded: expanded,
                onToggle: () {
                  setState(() => _expanded = expanded ? null : m);
                },
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
