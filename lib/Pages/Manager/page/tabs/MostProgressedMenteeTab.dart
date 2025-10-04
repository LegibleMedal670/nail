// lib/Pages/Manager/page/tabs/MostProgressedMenteeTab.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';

import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Providers/AdminProgressProvider.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';

/// 필터
enum LessonFilter { all, incomplete }

/// 강의 진행 상태
enum Progress { notStarted, inProgress, done }

/// 관리자 홈의 “진도 1등 멘티” 섹션
/// - 별도 props 없이 Provider에서 직접 읽는다.
class MostProgressedMenteeTab extends StatefulWidget {
  const MostProgressedMenteeTab({super.key});

  @override
  State<MostProgressedMenteeTab> createState() => _MostProgressedMenteeTabState();
}

class _MostProgressedMenteeTabState extends State<MostProgressedMenteeTab> {
  final _listController = ScrollController();
  LessonFilter _filter = LessonFilter.all;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 후 안전한 로드 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CurriculumProvider>().ensureLoaded();
      context.read<AdminProgressProvider>().ensureLoaded();
    });
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AdminProgressProvider>().refreshAll();
      // (선택) 커리큘럼 변경 가능성이 있으면 동기화
      await context.read<CurriculumProvider>().refresh(force: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProgressProvider>();
    final curri = context.watch<CurriculumProvider>();

    // 로딩/에러/데이터 확보
    if (admin.loading && admin.mentees.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (admin.error != null && admin.mentees.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(admin.error!, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _onRefresh,
                style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
                child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }
    if (admin.mentees.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('표시할 멘티가 없어요')),
      );
    }

    // 1) Top mentee 선정 (provider의 퍼센트 기준으로 정렬)
    final List<Mentee> mentees = [...admin.mentees];
    mentees.sort((a, b) =>
        admin.progressOfUser(b.id).compareTo(admin.progressOfUser(a.id)));
    final top = mentees.first;

    // 2) 동일 데이터 소스: 커리큘럼/모듈별 진행 맵
    final List<CurriculumItem> items = curri.items;
    final Map<String, CurriculumProgress> pm =
        admin.progressMapFor(top.id) ?? const <String, CurriculumProgress>{};

    // 3) 게이지 퍼센트(단일 공식)
    final double progress = admin.progressOfUser(top.id).clamp(0.0, 1.0);
    final String progressPercentText = '${(progress * 100).round()}%';

    // 4) 상태(완료/진행/미시작) 계산을 모듈별 맵으로 통일
    bool _isDone(String id) => (pm[id]?.moduleCompleted ?? false);
    bool _isInProgress(String id) {
      final p = pm[id];
      if (p == null) return false;
      final vc = ((p.hasVideo ?? false) && (p.videoCompleted ?? false));
      final ep = ((p.hasExam ?? false) && (p.examPassed ?? false));
      final someWatch = (p.watchedRatio > 0);
      return (!p.moduleCompleted) && (vc || ep || someWatch);
    }

    Progress _progressOf(String id) {
      if (_isDone(id)) return Progress.done;
      if (_isInProgress(id)) return Progress.inProgress;
      return Progress.notStarted;
    }

    // 5) 필터 목록
    final List<CurriculumItem> list = (_filter == LessonFilter.all)
        ? items
        : items.where((e) => !_isDone(e.id)).toList();

    final gaugeColor = UiTokens.primaryBlue;
    final started = _fmtDate(top.startedAt);
    final mentorName = top.mentorName ?? '미배정'; // ✅ 멘토명 표시(B안)

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
                            top.photoUrl != null ? NetworkImage(top.photoUrl!) : null,
                            child: top.photoUrl == null
                                ? const Icon(Icons.person, color: Color(0xFF8C96A1))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ “김멘티 · 멘토 : 김멘토” 형식
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: top.name,
                                      style: const TextStyle(
                                        color: UiTokens.title,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '  ·  멘토 : ',
                                      style: TextStyle(
                                        color: UiTokens.title.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: mentorName,
                                      style: TextStyle(
                                        color: UiTokens.title.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                    // 오른쪽: 원형 게이지 (provider 값 그대로)
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
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: const Color(0xFFE9EEF6),
                              valueColor: AlwaysStoppedAnimation(gaugeColor),
                              // strokeCap: StrokeCap.round, // 사용 중인 Flutter 버전에 따라 미지원일 수 있음
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

              // ===== 새로고침 / 필터 =====
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '새로고침',
                    iconSize: 20,
                    onPressed: _refreshing ? null : _onRefresh,
                    icon: _refreshing
                        ? const SizedBox(
                      width: 18, height: 18,
                      child: CupertinoActivityIndicator(),
                    )
                        : const Icon(Icons.refresh_rounded, color: UiTokens.actionIcon),
                  ),
                  TextButton.icon(
                    onPressed: () async {
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
                            SortOption(value: LessonFilter.all, label: '전체', icon: Icons.list_alt),
                            SortOption(value: LessonFilter.incomplete, label: '미완료 강의', icon: Icons.hourglass_bottom_rounded),
                          ],
                        ),
                      );
                      if (result != null && mounted) setState(() => _filter = result);
                    },
                    icon: const Icon(Icons.filter_list_rounded, color: UiTokens.actionIcon, size: 18),
                    label: Text(
                      _filter == LessonFilter.all ? '전체' : '미완료 강의',
                      style: const TextStyle(color: UiTokens.actionIcon, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ===== 커리큘럼 목록 =====
              ListView.separated(
                itemCount: list.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = list[i];
                  final state = _progressOf(item.id);

                  CurriculumProgress _progressForItem() {
                    final p = pm[item.id];
                    if (p != null) {
                      // ⛑️ 125% 같은 오버슈팅 방지: 항상 0..1로 클램프
                      return CurriculumProgress(
                        watchedRatio: p.watchedRatio.clamp(0.0, 1.0),
                        attempts: p.attempts,
                        bestScore: p.bestScore,
                        passed: p.examPassed ?? p.passed,
                        hasVideo: p.hasVideo,
                        hasExam: p.hasExam,
                        videoCompleted: p.videoCompleted,
                        examPassed: p.examPassed,
                        moduleCompleted: p.moduleCompleted,
                      );
                    }
                    // 맵이 아직 없으면 완전 미시작으로 간주
                    return const CurriculumProgress(
                      watchedRatio: 0.0,
                      attempts: 0,
                      bestScore: null,
                      passed: false,
                    );
                  }

                  return Stack(
                    children: [
                      CurriculumTile(
                        item: item,
                        onTap: () {
                          final pr = _progressForItem();
                          Navigator.of(context).push<CurriculumDetailResult>(
                            MaterialPageRoute(
                              builder: (_) => CurriculumDetailPage(
                                item: item,
                                mode: CurriculumViewMode.adminReview,
                                menteeName: top.name,
                                menteeUserId: top.id,
                                progress: pr,
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

  /// 상태 뱃지 (완료/수강중). '시작 전' 상태는 호출 안 함.
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
}
