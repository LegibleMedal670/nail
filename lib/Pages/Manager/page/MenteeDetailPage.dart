// lib/Pages/Manager/page/MenteeDetailPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Manager/widgets/sort_bottom_sheet.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';
import 'package:nail/Pages/Manager/page/mentee_edit_page.dart';

import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';

import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Services/CourseProgressService.dart';

/// 필터
enum DetailLessonFilter { all, incomplete }

/// 진행 상태
enum _RowState { notStarted, inProgress, done }

/// 관리자용 멘티 상세 보기 (실데이터 연동)
class MenteeDetailPage extends StatefulWidget {
  final Mentee mentee;
  final Set<String> existingCodes; // 멘티 코드 중복검사용(편집 페이지에서 사용)

  const MenteeDetailPage({
    super.key,
    required this.mentee,
    this.existingCodes = const {},
  });

  @override
  State<MenteeDetailPage> createState() => _MenteeDetailPageState();
}

class _MenteeDetailPageState extends State<MenteeDetailPage> {
  final _listController = ScrollController();
  DetailLessonFilter _filter = DetailLessonFilter.all;

  // 상단 표시용 멘티 스냅샷(편집 후 갱신)
  late Mentee _mentee = widget.mentee;

  // 진행/시험 맵: 모듈코드 -> CurriculumProgress
  Map<String, CurriculumProgress> _byId = {};
  // 게이지 값(= 완료 모듈 / 전체 모듈; 서버 계산치)
  double _ratio = 0.0;

  // 로딩/에러
  bool _loadingProg = false;
  bool _errorProg = false;

  @override
  void initState() {
    super.initState();
    // 커리큘럼은 Provider가 관리 → ensureLoaded 후 진행도 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CurriculumProvider>().ensureLoaded();
      await _loadProgress();
    });
  }

  Future<void> _loadProgress() async {
    final loginKey = _mentee.accessCode.trim();
    if (loginKey.isEmpty) return;

    setState(() {
      _loadingProg = true;
      _errorProg = false;
    });

    try {
      final ov = await CourseProgressService.getCourseOverview(loginKey: loginKey);
      final map = await CourseProgressService.listCurriculumProgress(loginKey: loginKey);

      if (!mounted) return;
      setState(() {
        _ratio = ov.moduleCompletionRatio;
        _byId = map;
        _loadingProg = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorProg = true;
        _loadingProg = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    final curri = context.read<CurriculumProvider>();
    await curri.refresh(force: true);
    await _loadProgress();
  }

  // ===== 행 상태 계산 =====
  _RowState _stateOf(CurriculumItem it) {
    final pr = _byId[it.id];
    if (pr == null) return _RowState.notStarted;

    if (pr.moduleCompleted == true) return _RowState.done;

    final partial = (pr.hasVideo && pr.videoCompleted) ||
        (pr.hasExam && pr.examPassed) ||
        (pr.watchedRatio > 0);

    return partial ? _RowState.inProgress : _RowState.notStarted;
  }

  String get _filterLabel =>
      _filter == DetailLessonFilter.all ? '전체' : '미완료 강의';

  List<CurriculumItem> _applyFilter(List<CurriculumItem> items) {
    if (_filter == DetailLessonFilter.all) return items;
    return items.where((e) => _stateOf(e) != _RowState.done).toList();
  }

  CurriculumItem? _nextIncomplete(List<CurriculumItem> items) {
    for (final e in items) {
      if (_stateOf(e) == _RowState.inProgress) return e;
    }
    for (final e in items) {
      if (_stateOf(e) == _RowState.notStarted) return e;
    }
    return null;
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
            icon: Icons.list_alt_outlined,
          ),
          SortOption(
            value: DetailLessonFilter.incomplete,
            label: '미완료 강의만',
            icon: Icons.remove_done_outlined,
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  Future<void> _editMentee() async {
    final res = await Navigator.of(context).push<MenteeEditResult>(
      MaterialPageRoute(
        builder: (_) => MenteeEditPage(
          initial: _mentee,
          existingCodes: widget.existingCodes,
        ),
      ),
    );

    if (res == null) return;

    if (res.deleted) {
      if (!mounted) return;
      Navigator.of(context).pop(res); // 상위로 삭제 결과 전달
      return;
    }

    if (res.mentee != null) {
      setState(() => _mentee = res.mentee!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멘티 정보가 저장되었습니다')),
      );
    }
  }

  // ---- UI helpers ----
  Widget _badge(_RowState s) {
    final done = s == _RowState.done;
    final bg = done ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);
    final border = done ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE);
    final fg = done ? const Color(0xFF059669) : const Color(0xFF2563EB);

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

  @override
  Widget build(BuildContext context) {
    final curri = context.watch<CurriculumProvider>();
    final items = curri.items;
    final filtered = _applyFilter(items);

    final gaugeColor = UiTokens.primaryBlue;
    final started = _fmtDate(_mentee.startedAt);
    final progressPercentText = '${(_ratio * 100).round()}%';

    // 커리큘럼 로딩/에러 기준 화면
    if (curri.loading && items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (curri.error != null && items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(curri.error!,
                  style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refreshAll,
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
        title: Text(_mentee.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: UiTokens.title,
        elevation: 0,
        actions: [
          if (_loadingProg)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_errorProg)
            IconButton(
              icon: const Icon(Icons.error_outline, color: Colors.redAccent),
              onPressed: _loadProgress,
              tooltip: '진행도 재시도',
            ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAll,
          ),
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
              // ===== 상단 프로필 + 게이지 =====
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
                            backgroundImage: _mentee.photoUrl != null ? NetworkImage(_mentee.photoUrl!) : null,
                            child: _mentee.photoUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_mentee.name,
                                  style: const TextStyle(
                                      color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w900)),
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
                              value: _ratio,
                              strokeWidth: 10,
                              backgroundColor: const Color(0xFFE9EEF6),
                              valueColor: AlwaysStoppedAnimation(gaugeColor),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            progressPercentText,
                            style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 이어하기 버튼 ===== (관리자 검토에서도 멘티 현재 위치로 스크롤만)
              // SizedBox(
              //   width: double.infinity,
              //   height: 48,
              //   child: FilledButton(
              //     onPressed: () {
              //       final t = _nextIncomplete(items);
              //       if (t == null) {
              //         ScaffoldMessenger.of(context)
              //             .showSnackBar(const SnackBar(content: Text('모든 강의를 완료했어요!')));
              //         return;
              //       }
              //       final idx = items.indexOf(t);
              //       _listController.animateTo(
              //         (idx * 120).toDouble(),
              //         duration: const Duration(milliseconds: 300),
              //         curve: Curves.easeOut,
              //       );
              //       ScaffoldMessenger.of(context)
              //           .showSnackBar(SnackBar(content: Text('이어 학습: W${t.week}. ${t.title}')));
              //     },
              //     style: FilledButton.styleFrom(
              //       backgroundColor: UiTokens.primaryBlue,
              //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              //     ),
              //     child: const Text('이어보기', style: TextStyle(fontWeight: FontWeight.w800)),
              //   ),
              // ),

              const SizedBox(height: 8),

              // ===== 목록 헤더 + 필터 =====
              Row(
                children: [
                  const Text('커리큘럼',
                      style: TextStyle(color: UiTokens.title, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.filter_list_rounded, size: 18, color: UiTokens.actionIcon),
                    label: Text(
                      _filterLabel,
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

              // ===== 커리큘럼 목록 =====
              ListView.separated(
                itemCount: filtered.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  final state = _stateOf(item);
                  final prog = _byId[item.id] ??
                      const CurriculumProgress(
                        watchedRatio: 0,
                        attempts: 0,
                        bestScore: null,
                        passed: false,
                        hasVideo: false,
                        hasExam: false,
                        videoCompleted: false,
                        examPassed: false,
                        moduleCompleted: false,
                      );

                  return Stack(
                    children: [
                      CurriculumTile(
                        item: item,
                        onTap: () async {
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => CurriculumDetailPage(
                                item: item,
                                mode: CurriculumViewMode.adminReview,
                                menteeName: _mentee.name,
                                menteeUserId: _mentee.id,
                                progress: prog,
                              ),
                            ),
                          );
                          if (changed == true) {
                            await _refreshAll();
                          }
                        },
                      ),
                      if (state != _RowState.notStarted)
                        Positioned(top: 10, right: 10, child: _badge(state)),
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
}
