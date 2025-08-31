import 'package:flutter/material.dart';
import 'package:nail/Common/ui_tokens.dart';
import 'package:nail/Manager/models/curriculum_item.dart';
import 'package:nail/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Manager/widgets/curriculum_tile.dart';
import 'package:nail/Manager/widgets/sort_bottom_sheet.dart';

/// 필터
enum LessonFilter { all, incomplete }

/// 강의 진행 상태
enum Progress { notStarted, inProgress, done }

/// 멘티 학습 홈
class MenteeMainPage extends StatefulWidget {
  final String name;
  final DateTime startedAt;
  final String? photoUrl;

  /// 커리큘럼 전체
  final List<CurriculumItem> curriculum;

  /// 수강 완료한 아이템 id 집합
  final Set<String> completedIds;

  /// 진행중 강의의 진행률(0.0~1.0). 키가 없으면 '시작 전'으로 간주.
  final Map<String, double> progressRatio;

  const MenteeMainPage({
    super.key,
    required this.name,
    required this.startedAt,
    required this.curriculum,
    this.photoUrl,
    this.completedIds = const {},
    this.progressRatio = const {},
  });

  /// 데모로 빠르게 확인하고 싶으면 이 팩토리로 띄워봐.
  factory MenteeMainPage.demo() {
    final demo = _demoCurriculum();
    return MenteeMainPage(
      name: '김민지',
      startedAt: DateTime.now().subtract(const Duration(days: 23)),
      curriculum: demo,
      completedIds: {'w01', 'w03', 'w05'},
      // 임의 완료
      progressRatio: {
        'w02': 0.2, // 20% 시청 중
        'w04': 0.6, // 60% 시청 중
      },
    );
  }

  @override
  State<MenteeMainPage> createState() => _MenteeMainPageState();
}

class _MenteeMainPageState extends State<MenteeMainPage> {
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
      appBar: AppBar(
        title: const Text(
          '학습',
          style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        iconTheme: const IconThemeData(color: UiTokens.title),
      ),
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
                    _nextIncomplete == null ? '복습하기' : '이어보기',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
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
                          Navigator.of(context).push<CurriculumDetailResult>(
                            MaterialPageRoute(
                              builder:
                                  (_) => CurriculumDetailPage(
                                    item: item,
                                    mode: CurriculumViewMode.mentee,
                                    progress: const CurriculumProgress(watchedRatio: 0.35, attempts: 2, bestScore: 72, passed: true),
                                    onPlay: () {},
                                    onContinueWatch: () {},
                                    onTakeExam: () {},
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

/// ——— 데모 커리큘럼 (14주) ———
/// 실제에선 EducationManageTab의 데이터와 동일한 걸 주입하면 됨.
List<CurriculumItem> _demoCurriculum() => [
  CurriculumItem(
    id: 'w01',
    week: 1,
    title: '네일아트 기초 교육',
    summary: '도구 소개, 위생, 손톱 구조 이해',
    durationMinutes: 60,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w02',
    week: 2,
    title: '케어 기본',
    summary: '큐티클 정리, 파일링, 샌딩',
    durationMinutes: 75,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w03',
    week: 3,
    title: '베이스 코트 & 컬러 올리기',
    summary: '균일한 도포, 번짐 방지 요령',
    durationMinutes: 90,
    hasVideo: true,
    requiresExam: true,
  ),
  CurriculumItem(
    id: 'w04',
    week: 4,
    title: '마감재 사용법',
    summary: '탑젤/매트탑, 경화 시간',
    durationMinutes: 60,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w05',
    week: 5,
    title: '간단 아트 1',
    summary: '도트, 스트라이프, 그라데이션',
    durationMinutes: 80,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w06',
    week: 6,
    title: '간단 아트 2',
    summary: '프렌치, 마블 기초',
    durationMinutes: 80,
    hasVideo: true,
    requiresExam: true,
  ),
  CurriculumItem(
    id: 'w07',
    week: 7,
    title: '젤 오프 & 재시술',
    summary: '안전한 오프, 손상 최소화',
    durationMinutes: 50,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w08',
    week: 8,
    title: '손 위생/살롱 위생 표준',
    summary: '소독 루틴, 위생 체크리스트',
    durationMinutes: 45,
    hasVideo: false,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w09',
    week: 9,
    title: '고객 응대 매뉴얼',
    summary: '예약/상담/클레임 응대',
    durationMinutes: 60,
    hasVideo: false,
    requiresExam: true,
  ),
  CurriculumItem(
    id: 'w10',
    week: 10,
    title: '트러블 케이스',
    summary: '리프트/파손/알러지 예방과 대응',
    durationMinutes: 70,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w11',
    week: 11,
    title: '젤 연장 기초',
    summary: '폼, 팁, 쉐입 만들기',
    durationMinutes: 90,
    hasVideo: true,
    requiresExam: true,
  ),
  CurriculumItem(
    id: 'w12',
    week: 12,
    title: '아트 심화',
    summary: '스톤, 파츠, 믹스미디어',
    durationMinutes: 95,
    hasVideo: true,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w13',
    week: 13,
    title: '시술 시간 단축 팁',
    summary: '동선/세팅 최적화, 체크리스트',
    durationMinutes: 40,
    hasVideo: false,
    requiresExam: false,
  ),
  CurriculumItem(
    id: 'w14',
    week: 14,
    title: '종합 점검 & 모의평가',
    summary: '전 과정 복습, 취약 파트 점검',
    durationMinutes: 120,
    hasVideo: true,
    requiresExam: true,
  ),
];
