import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/curriculum_item.dart';
import 'package:nail/Pages/Manager/widgets/curriculum_tile.dart';
import 'package:nail/Pages/Manager/widgets/sort_bottom_sheet.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:provider/provider.dart';

/// 필터
enum LessonFilter { all, incomplete }

/// 강의 진행 상태
enum Progress { notStarted, inProgress, done }

/// 멘티 학습 홈 (Provider에서 유저/커리큘럼을 읽음)
class MenteeMainPage extends StatefulWidget {
  // 선택 주입(없으면 Provider에서/기본값으로 채움)
  final String? name;
  final DateTime? startedAt;
  final String? photoUrl;

  const MenteeMainPage({
    super.key,
    this.name,
    this.startedAt,
    this.photoUrl,
  });

  @override
  State<MenteeMainPage> createState() => _MenteeMainPageState();
}

class _MenteeMainPageState extends State<MenteeMainPage> {
  final _listController = ScrollController();
  LessonFilter _filter = LessonFilter.all;

  @override
  void initState() {
    super.initState();
    // 스플래시에서 안 불러왔어도 이 화면 진입 시 1회 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CurriculumProvider>().ensureLoaded();
    });
  }

  // ---- 진행도/필터 계산 유틸 (서버 연동되면 completedIds/progressRatio 치환) ----
  double _calcTotalProgress(
      List<CurriculumItem> items,
      Set<String> completedIds,
      Map<String, double> progressRatio,
      ) {
    if (items.isEmpty) return 0;
    double sum = 0;
    for (final it in items) {
      if (completedIds.contains(it.id)) {
        sum += 1.0;
      } else {
        final r = progressRatio[it.id];
        if (r != null && r > 0) sum += r.clamp(0.0, 1.0);
      }
    }
    return (sum / items.length).clamp(0.0, 1.0);
  }

  List<CurriculumItem> _applyFilter(
      LessonFilter filter,
      List<CurriculumItem> items,
      Set<String> completedIds,
      ) {
    if (filter == LessonFilter.all) return items;
    return items.where((e) => !completedIds.contains(e.id)).toList();
  }

  Progress _progressOf(
      String id,
      Set<String> completedIds,
      Map<String, double> progressRatio,
      ) {
    if (completedIds.contains(id)) return Progress.done;
    final r = progressRatio[id];
    if (r != null && r > 0) return Progress.inProgress;
    return Progress.notStarted;
  }

  CurriculumItem? _nextIncomplete(
      List<CurriculumItem> items,
      Set<String> completedIds,
      Map<String, double> progressRatio,
      ) {
    for (final e in items) {
      if (_progressOf(e.id, completedIds, progressRatio) == Progress.inProgress) {
        return e;
      }
    }
    for (final e in items) {
      if (_progressOf(e.id, completedIds, progressRatio) == Progress.notStarted) {
        return e;
      }
    }
    return null;
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<LessonFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet<LessonFilter>(
        title: '필터',
        current: _filter,
        options: const [
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

  void _scrollToItem(int index) {
    _listController.animateTo(
      (index * 120).toDouble(), // 카드 높이 대략치
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _continueLearning(List<CurriculumItem> items, Set<String> completedIds, Map<String, double> progressRatio) {
    final target = _nextIncomplete(items, completedIds, progressRatio);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 강의를 완료했어요!')),
      );
      return;
    }
    final idx = items.indexOf(target);
    _scrollToItem(idx);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('이어 학습: W${target.week}. ${target.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final cur = context.watch<CurriculumProvider>();

    // ---- 유저 표시용(이름/시작일/사진). 실제 필드명에 맞춰 교체 가능 ----
    final String displayName = widget.name ?? '멘티';
    final DateTime startedAt = widget.startedAt ?? DateTime.now();
    final String? photoUrl = widget.photoUrl;

    // ---- 커리큘럼(서버 동기화) ----
    final List<CurriculumItem> curriculum = cur.items;

    // 진행/완료는 아직 서버X → 임시 빈값 (추후 서버 연동 시 주입)
    final Set<String> completedIds = const <String>{};
    final Map<String, double> progressRatio = const <String, double>{};

    final double totalProgress = _calcTotalProgress(curriculum, completedIds, progressRatio);
    final String progressPercentText = '${(totalProgress * 100).round()}%';
    final filtered = _applyFilter(_filter, curriculum, completedIds);
    final gaugeColor = UiTokens.primaryBlue;

    // 로딩/에러 상태 처리
    if (cur.loading && curriculum.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (cur.error != null && curriculum.isEmpty) {



      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cur.error!, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => cur.refresh(force: true),
                style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
                child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
            onPressed: () => context.read<CurriculumProvider>().refresh(force: true),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await context.read<UserProvider>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
              );
            },
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
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person, color: Color(0xFF8C96A1))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: UiTokens.title,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '멘토 : 김선생', // TODO: UserProvider에서 멘토명 오면 교체
                                style: TextStyle(
                                  color: UiTokens.title.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '시작일 : ${_fmtDate(startedAt)}',
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
                              value: totalProgress,
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
                  onPressed: () => _continueLearning(curriculum, completedIds, progressRatio),
                  style: FilledButton.styleFrom(
                    backgroundColor: UiTokens.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _nextIncomplete(curriculum, completedIds, progressRatio) == null ? '복습하기' : '이어보기',
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
                        _filter == LessonFilter.all ? '전체' : '미완료 강의',
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

              // ===== 커리큘럼 목록 =====
              ListView.separated(
                itemCount: filtered.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  final state = _progressOf(item.id, completedIds, progressRatio);

                  return Stack(
                    children: [
                      CurriculumTile(
                        item: item,
                        onTap: () {
                          Navigator.of(context).push<CurriculumDetailResult>(
                            MaterialPageRoute(
                              builder: (_) => CurriculumDetailPage(
                                item: item,
                                mode: CurriculumViewMode.mentee,
                                // TODO: 여기도 실제 진행/시험 데이터 연동되면 교체
                                progress: const CurriculumProgress(
                                  watchedRatio: 0.0,
                                  attempts: 0,
                                  bestScore: 0,
                                  passed: false,
                                ),
                                onPlay: () {},
                                onContinueWatch: () {},
                                onTakeExam: () {},
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

  /// 상태 뱃지 (완료/수강중). '시작 전' 상태는 호출하지 않음.
  Widget _progressBadge(Progress state) {
    final bool done = (state == Progress.done);
    final Color bg = done ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);
    final Color border = done ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE);
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
          Icon(done ? Icons.check_circle_rounded : Icons.timelapse, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(done ? '완료' : '수강중',
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
