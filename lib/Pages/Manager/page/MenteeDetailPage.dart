import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';
import 'package:nail/Pages/Manager/models/CurriculumItem.dart';
import 'package:nail/Pages/Manager/page/mentee_edit_page.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';
import 'package:nail/Pages/Manager/widgets/sort_bottom_sheet.dart';

/// 필터
enum DetailLessonFilter { all, incomplete }

/// 진행 상태
enum Progress { notStarted, inProgress, done }

/// 관리자용 멘티 상세 보기
class MenteeDetailPage extends StatefulWidget {
  final Mentee mentee;
  final List<CurriculumItem> curriculum;
  final Set<String> completedIds;
  final Map<String, double> progressRatio;
  final Set<String> existingCodes;

  const MenteeDetailPage({
    super.key,
    required this.mentee,
    required this.curriculum,
    this.completedIds = const {},
    this.progressRatio = const {},
    this.existingCodes = const {},
  });

  /// 데모용 팩토리
  factory MenteeDetailPage.demoFromEntry(Mentee entry) {
    final completed = <String>{'w01', 'w03'};
    final ratio = <String, double>{'w02': 0.35, 'w04': 0.6};
    return MenteeDetailPage(
      mentee: entry,
      curriculum: _demoCurriculum(),
      completedIds: completed,
      progressRatio: ratio,
    );
  }

  @override
  State<MenteeDetailPage> createState() => _MenteeDetailPageState();
}

class _MenteeDetailPageState extends State<MenteeDetailPage> {
  final _listController = ScrollController();
  DetailLessonFilter _filter = DetailLessonFilter.all;
  late Mentee _mentee = widget.mentee;

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
        if (r != null && r > 0) sum += r.clamp(0.0, 1.0);
      }
    }
    return (sum / items.length).clamp(0.0, 1.0);
  }

  String get _filterLabel =>
      _filter == DetailLessonFilter.all ? '전체' : '미완료 강의';

  List<CurriculumItem> get _filtered {
    if (_filter == DetailLessonFilter.all) return widget.curriculum;
    return widget.curriculum
        .where((e) => !widget.completedIds.contains(e.id))
        .toList();
  }

  CurriculumItem? get _nextIncomplete {
    for (final it in widget.curriculum) {
      if (!widget.completedIds.contains(it.id)) return it;
    }
    return null;
  }

  Progress _progressOf(String id) {
    if (widget.completedIds.contains(id)) return Progress.done;
    final r = widget.progressRatio[id] ?? 0.0;
    if (r > 0) return Progress.inProgress;
    return Progress.notStarted;
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<DetailLessonFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<DetailLessonFilter>(
        title: '필터',
        current: _filter,
        options: const [
          SortOption(
              value: DetailLessonFilter.all,
              label: '전체',
              icon: Icons.list_alt_outlined),
          SortOption(
              value: DetailLessonFilter.incomplete,
              label: '미완료 강의만',
              icon: Icons.remove_done_outlined),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  /// 가운데 액션: '레포트 생성하기'
  Future<void> _generateReport() async {
    final target = _nextIncomplete;
    final msg = target == null
        ? '${_mentee.name}님의 학습 레포트를 생성했어요. (데모)'
        : '${_mentee.name}님의 학습 레포트를 생성했어요. (다음 학습: W${target.week} ${target.title})';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 편집 → (삭제 시) 결과를 상위로 전달하여 리스트 탭이 재조회할 수 있게 함
  Future<void> _editMentee() async {
    final result = await Navigator.of(context).push<MenteeEditResult>(
      MaterialPageRoute(
        builder: (_) => MenteeEditPage(
          initial: _mentee,
          existingCodes: widget.existingCodes,
        ),
      ),
    );

    if (result == null) return;

    if (result.deleted) {
      if (!mounted) return;
      // 삭제는 상세를 닫으면서 결과를 상위에 전달
      Navigator.of(context).pop(result);
      return;
    }

    if (result.mentee != null) {
      setState(() => _mentee = result.mentee!); // 페이지 내 즉시 반영
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멘티 정보가 저장되었습니다')),
      );
      // 수정은 상세 유지. (원하면 Navigator.pop(context, result) 로 상위에도 즉시 전달 가능)
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final gaugeColor = UiTokens.primaryBlue;
    final started = _fmtDate(_mentee.startedAt);
    final progressPercentText = '${(_progress * 100).round()}%';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
        Text(_mentee.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: UiTokens.title,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '멘티 정보 수정',
            icon: const Icon(Icons.edit_rounded),
            onPressed: _editMentee,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _listController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 프로필 + 게이지
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: UiTokens.cardBorder, width: 1),
                  boxShadow: [UiTokens.cardShadow],
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[400],
                            backgroundImage: _mentee.photoUrl != null
                                ? NetworkImage(_mentee.photoUrl!)
                                : null,
                            child: _mentee.photoUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _mentee.name,
                                style: const TextStyle(
                                  color: UiTokens.title,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '멘토 : ${_mentee.mentor}',
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

              // 주요 액션: 레포트 생성하기
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _generateReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: UiTokens.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    '레포트 생성하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 헤더
              Row(
                children: [
                  const Text('커리큘럼',
                      style: TextStyle(
                          color: UiTokens.title,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.filter_list_rounded,
                        size: 18, color: UiTokens.actionIcon),
                    label: Text(
                      _filterLabel,
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.7),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      foregroundColor: UiTokens.actionIcon,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              // 커리큘럼 목록
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CurriculumDetailPage(
                                item: item,
                                mode: CurriculumViewMode.adminReview,
                                progress: const CurriculumProgress(
                                  watchedRatio: 0.35,
                                  attempts: 2,
                                  bestScore: 72,
                                  passed: true,
                                ),
                                menteeName: _mentee.name,
                                onOpenExamReport: () {},
                                onImpersonate: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CurriculumDetailPage(
                                        item: item,
                                        mode: CurriculumViewMode.mentee,
                                        progress: const CurriculumProgress(
                                          watchedRatio: 0.35,
                                          attempts: 2,
                                          bestScore: 72,
                                          passed: true,
                                        ),
                                        onPlay: () {},
                                        onContinueWatch: () {},
                                        onTakeExam: () {},
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),

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

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ===== 데모 커리큘럼 ===== TODO 커리큘럼
List<CurriculumItem> _demoCurriculum() => const [
  CurriculumItem(
    id: 'w01',
    week: 1,
    title: '기초 위생 및 도구 소개',
    summary: '필수 위생, 도구 종류, 기본 사용법',
    hasVideo: true,
    requiresExam: false,videoUrl: '', resources: [], goals: []
  ),
  CurriculumItem(
    id: 'w02',
    week: 2,
    title: '파일링과 큐티클 케어',
    summary: '안전한 큐티클 정리와 파일링 각도',
    hasVideo: true,
    requiresExam: true,videoUrl: '', resources: [], goals: []
  ),
  CurriculumItem(
    id: 'w03',
    week: 3,
    title: '베이스·컬러·탑 코트',
    summary: '도포 순서, 경화 시간, 흔한 실수',
    hasVideo: true,
    requiresExam: true,videoUrl: '', resources: [], goals: []
  ),
  CurriculumItem(
    id: 'w04',
    week: 4,
    title: '마감재 사용법',
    summary: '탑젤/매트탑, 경화 시간',
    hasVideo: true,
    requiresExam: false,videoUrl: '', resources: [], goals: []
  ),
  CurriculumItem(
    id: 'w05',
    week: 5,
    title: '간단 아트 1',
    summary: '도트, 스트라이프, 그라데이션',
    hasVideo: true,
    requiresExam: false,videoUrl: '', resources: [], goals: []
  ),
];
