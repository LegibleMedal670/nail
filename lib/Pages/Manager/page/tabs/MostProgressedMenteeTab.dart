import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/CurriculumItem.dart';
import 'package:nail/Pages/Manager/widgets/curriculum_tile.dart';
import 'package:nail/Pages/Manager/widgets/sort_bottom_sheet.dart';

/// 필터
enum LessonFilter { all, incomplete }

/// 강의 진행 상태
enum Progress { notStarted, inProgress, done }

/// 멘티 학습 홈
class MostProgressedMenteeTab extends StatefulWidget {
  final String name;
  final DateTime startedAt;
  final String? photoUrl;

  /// 커리큘럼 전체
  final List<CurriculumItem> curriculum;

  /// 수강 완료한 아이템 id 집합
  final Set<String> completedIds;

  /// 진행중 강의의 진행률(0.0~1.0). 키가 없으면 '시작 전'으로 간주.
  final Map<String, double> progressRatio;

  const MostProgressedMenteeTab({
    super.key,
    required this.name,
    required this.startedAt,
    required this.curriculum,
    this.photoUrl,
    this.completedIds = const {},
    this.progressRatio = const {},
  });

  @override
  State<MostProgressedMenteeTab> createState() => _MostProgressedMenteeTabState();
}

class _MostProgressedMenteeTabState extends State<MostProgressedMenteeTab> {
  final _listController = ScrollController();
  LessonFilter _filter = LessonFilter.all;

  /// 전체 진행률: 완료=1, 진행중=ratio, 시작전=0 의 평균
  double get _progress {
    final items = widget.curriculum;
    if (items.isEmpty) return 0;

    double sum = 0;
    for (final it in items) {
      if (widget.completedIds.contains(it.id)) {
        sum += 1.0;
      } else {
        final r = widget.progressRatio[it.id];
        if (r != null && r > 0) {
          sum += r.clamp(0.0, 1.0);
        }
      }
    }
    return (sum / items.length).clamp(0.0, 1.0);
  }

  String get _filterLabel => _filter == LessonFilter.all ? '전체' : '미완료 강의';

  List<CurriculumItem> get _filtered {
    if (_filter == LessonFilter.all) return widget.curriculum;
    return widget.curriculum
        .where((e) => !widget.completedIds.contains(e.id))
        .toList();
  }

  /// 아이템별 상태 계산
  Progress _progressOf(String id) {
    if (widget.completedIds.contains(id)) return Progress.done;
    final r = widget.progressRatio[id];
    if (r != null && r > 0) return Progress.inProgress;
    return Progress.notStarted; // 서버에 기록이 전혀 없는 경우
  }

  /// 이어 학습 대상: 우선 '진행중' 중 첫 번째, 없으면 '시작전' 중 첫 번째
  CurriculumItem? get _nextIncomplete {
    for (final e in widget.curriculum) {
      if (_progressOf(e.id) == Progress.inProgress) return e;
    }
    for (final e in widget.curriculum) {
      if (_progressOf(e.id) == Progress.notStarted) return e;
    }
    return null; // 전부 완료
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<LessonFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => SortBottomSheet<LessonFilter>(
        title: '필터',
        current: _filter,
        options: [
          SortOption(
            value: LessonFilter.all,
            label: '전체',
            icon: Icons.list_alt,
          ),
          SortOption(
            value: LessonFilter.incomplete,
            label: '미완료 강의',
            icon: Icons.hourglass_bottom_rounded,
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  void _continueLearning() {
    final target = _nextIncomplete;
    if (target == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 강의를 완료했어요!')));
      return;
    }
    final idx = widget.curriculum.indexOf(target);
    // 대충 해당 카드 위치로 스크롤
    _listController.animateTo(
      (idx * 120).toDouble(), // 카드 높이 대략치
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    // 상세 열기 대신 스낵바
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('이어 학습: W${target.week}. ${target.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gaugeColor = UiTokens.primaryBlue;
    final started = _fmtDate(widget.startedAt);
    final progressPercentText = '${(_progress * 100).round()}%';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _listController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== 상단 프로필 + 게이지 =====
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: UiTokens.cardBorder),
                  boxShadow: [UiTokens.cardShadow],
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Row(
                  children: [
                    // 왼쪽: 사진, 이름, 시작일
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                            widget.photoUrl != null
                                ? NetworkImage(widget.photoUrl!)
                                : null,
                            child:
                            widget.photoUrl == null
                                ? const Icon(
                              Icons.person,
                              color: Color(0xFF8C96A1),
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: const TextStyle(
                                  color: UiTokens.title,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '멘토 : 김선생',
                                style: TextStyle(
                                  color: UiTokens.title.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '시작일 : $started',
                                style: TextStyle(
                                  color: UiTokens.title.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 오른쪽: 원형 게이지
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 10,
                              backgroundColor: const Color(0xFFE9EEF6),
                              valueColor: AlwaysStoppedAnimation(gaugeColor),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            progressPercentText,
                            style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 이어하기 버튼 =====
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _continueLearning,
                  style: FilledButton.styleFrom(
                    backgroundColor: UiTokens.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '레포트 생성하기',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===== 목록 헤더 + 필터 =====
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  children: [
                    const Text(
                      '내 학습',
                      style: TextStyle(
                        color: UiTokens.title,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showFilterSheet,
                      icon: const Icon(
                        Icons.filter_list_rounded,
                        color: UiTokens.actionIcon,
                        size: 18,
                      ),
                      label: Text(
                        _filterLabel,
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

              // ===== 커리큘럼 목록 (기존 CurriculumTile 재사용) =====
              ListView.separated(
                itemCount: _filtered.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = _filtered[i];
                  final state = _progressOf(item.id);

                  return Stack(
                    children: [
                      CurriculumTile(
                        item: item,
                        onTap: () {
                          final pr = _progressFor(item); // ⬇︎ 2번에서 추가할 헬퍼
                          Navigator.of(context).push<CurriculumDetailResult>(
                            MaterialPageRoute(
                              builder: (_) => CurriculumDetailPage(
                                item: item,
                                mode: CurriculumViewMode.adminReview,   // ✅ 멘토(검토) 모드로
                                menteeName: widget.name,                // ✅ 상단 '검토 대상'에 표시
                                progress: pr,                           // ✅ 시청률/합격 여부 전달
                                // onOpenExamReport: () { ... }          // (선택) 리포트 화면 연결 시
                              ),
                            ),
                          );
                        },
                        // (멘티 뷰) onEdit 미전달 → 편집 아이콘 비표시
                      ),

                      // 상태 뱃지: notStarted면 아예 표시하지 않음
                      if (state != Progress.notStarted)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _progressBadge(state),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MostProgressedMenteeTab의 State 클래스 내부에 추가
  CurriculumProgress _progressFor(CurriculumItem item) {
    // 완료로 표시된 항목이면 시청률=1로 간주
    final passed = widget.completedIds.contains(item.id);
    final watched = passed ? 1.0 : (widget.progressRatio[item.id] ?? 0.0);

    return CurriculumProgress(
      watchedRatio: watched.clamp(0.0, 1.0),
      attempts: passed ? 1 : 0,  // 점수 데이터가 없으니 '1회 응시'로 표기해 통과/미응시 모순 방지
      bestScore: null,           // (있다면 채워 넣으세요)
      passed: passed,
    );
  }


  /// 상태 뱃지 (완료/수강중). '시작 전' 상태는 이 위젯을 호출하지 마세요.
  Widget _progressBadge(Progress state) {
    final bool done = (state == Progress.done);

    final Color bg = done ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);
    final Color border =
    done ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE);
    final Color fg = done ? const Color(0xFF059669) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.timelapse,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            done ? '완료' : '수강중',
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}