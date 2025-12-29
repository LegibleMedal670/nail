// lib/Pages/Mentee/page/MenteeMainPage.dart
import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/model/CurriculumProgress.dart';
import 'package:nail/Pages/Common/page/CompletionPage.dart';
import 'package:nail/Pages/Common/page/CurriculumDetailPage.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Common/model/CurriculumItem.dart';
import 'package:nail/Pages/Common/widgets/CurriculumTile.dart';
import 'package:nail/Pages/Common/widgets/SortBottomSheet.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Services/CourseProgressService.dart';
import 'package:nail/Services/SignatureService.dart';
import 'package:provider/provider.dart';

enum LessonFilter { all, incomplete }
enum Progress { notStarted, inProgress, done }

class MenteeMainPage extends StatefulWidget {
  /// embedded=true 면 컨테이너(상위 Scaffold/AppBar/BottomNav)가 감싸는 모드
  final bool embedded;
  const MenteeMainPage({super.key, this.embedded = false});

  @override
  State<MenteeMainPage> createState() => _MenteeMainPageState();
}

class _MenteeMainPageState extends State<MenteeMainPage> {
  final _listController = ScrollController();
  LessonFilter _filter = LessonFilter.all;

  // ===== 진행도 상태 (RPC 연동) =====
  final Set<String> _completed = <String>{};         // 완료된 모듈 코드
  final Set<String> _partial = <String>{};           // 부분진척(영상 또는 시험만 완료)
  Map<String, CurriculumProgress> _progressById = {}; // 모듈코드 -> 진행객체
  bool _progLoading = false;
  bool _progError = false;

  // ✅ 서명 완료 상태 (프로토타입: 로컬 상태만)
  final Set<String> _signed = <String>{};

  @override
  void initState() {
    super.initState();
    // 첫 렌더 뒤 진행도 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgress();
    });
  }

  // 진행도 불러오기 (게이지/뱃지용 스냅샷 + 상세 맵)
  // retryOnEmpty: true일 경우, 데이터 반영 대기 후 재시도 (시험 제출 직후 등)
  Future<void> _loadProgress({bool retryOnEmpty = false}) async {
    final user = context.read<UserProvider>();
    // UserProvider에 노출된 loginKey 사용 (프로젝트 구조에 맞춰 노출되어 있음)
    final String loginKey = (user.current?.loginKey ?? '').toString();
    if (loginKey.isEmpty) return;

    setState(() {
      _progLoading = true;
      _progError = false;
    });

    try {
      // 재시도 시에는 약간의 지연을 두고 호출 (DB 커밋 대기)
      if (retryOnEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      final snap = await CourseProgressService.getCompletionSnapshot(loginKey: loginKey);
      final map = await CourseProgressService.listCurriculumProgress(loginKey: loginKey);
      
      // 서명 완료된 이론 모듈 조회
      final signedModules = await SignatureService.instance.getSignedTheoryModules(
        loginKey: loginKey,
      );

      setState(() {
        _completed
          ..clear()
          ..addAll(snap.completed);
        _partial
          ..clear()
          ..addAll(snap.partial);
        _progressById = map;
        _signed
          ..clear()
          ..addAll(signedModules);
        _progLoading = false;
      });
      
      debugPrint('[MenteeMainPage] Progress loaded: ${_completed.length} completed, ${_signed.length} signed');
    } catch (e) {
      debugPrint('[MenteeMainPage] Failed to load progress: $e');
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _progError = true;
        _progLoading = false;
      });
    }
  }

  // 커리큘럼 새로고침(목록 새로고침 후 진행도도 재조회)
  // retryOnEmpty: 시험/영상 완료 직후에는 재시도 모드 활성화
  Future<void> _refreshAll({bool retryOnEmpty = false}) async {
    final curri = context.read<CurriculumProvider>();
    await curri.refresh(force: true);
    await _loadProgress(retryOnEmpty: retryOnEmpty);
  }

  // ======= 수료 가능 여부 체크 =======
  bool _canCompleteEducation(List<CurriculumItem> items) {
    if (items.isEmpty) return false;

    // 프로토타입: 모든 이론 교육이 서명 완료되었는지 확인
    for (final item in items) {
      // 시험이 필요한 모듈만 체크 (이론 교육)
      if (item.requiresExam) {
        if (!_signed.contains(item.id)) {
          return false; // 하나라도 서명되지 않았으면 불가
        }
      }
    }

    // TODO: 실습 교육 완료 여부도 체크 필요
    return true;
  }

  // ======= 진행률 계산 유틸 (게이지/뱃지) =======
  double _progressForAll(List<CurriculumItem> items) {
    if (items.isEmpty) return 0.0;
    double sum = 0.0;
    for (final it in items) {
      if (_completed.contains(it.id)) {
        sum += 1.0;
      } else {
        final watched = _progressById[it.id]?.watchedRatio ?? 0.0;
        sum += watched.clamp(0.0, 1.0);
      }
    }
    return (sum / items.length).clamp(0.0, 1.0);
  }

  Progress _progressOf(String id) {
    if (_completed.contains(id)) return Progress.done;
    if (_partial.contains(id)) return Progress.inProgress;
    return Progress.notStarted;
  }

  CurriculumItem? _nextIncomplete(List<CurriculumItem> items) {
    // ‘진행중’ 우선, 없으면 ‘시작 전’
    for (final e in items) {
      if (_progressOf(e.id) == Progress.inProgress) return e;
    }
    for (final e in items) {
      if (_progressOf(e.id) == Progress.notStarted) return e;
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
          SortOption(value: LessonFilter.all, label: '전체', icon: Icons.list_alt),
          SortOption(value: LessonFilter.incomplete, label: '미완료 강의', icon: Icons.hourglass_bottom_rounded),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  void _continueLearning(List<CurriculumItem> items) {
    final target = _nextIncomplete(items);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 강의를 완료했어요!')));
      return;
    }
    final idx = items.indexOf(target);
    _listController.animateTo(
      (idx * 120).toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('이어 학습: W${target.week}. ${target.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final curri = context.watch<CurriculumProvider>();

    // 사용자 표시 정보 (UserProvider가 보관)
    final String displayName = user.nickname.isNotEmpty ? user.nickname : '사용자';
    final DateTime startedAt = user.joinedAt; // getter가 non-null 반환
    final String? photoUrl = user.photoUrl;
    final String mentorName = user.mentorName ?? '미배정';

    // 커리큘럼 상태
    final bool loading = curri.loading;
    final String? error = curri.error;
    final List<CurriculumItem> items = curri.items;

    // 필터 적용
    final List<CurriculumItem> list =
    _filter == LessonFilter.all ? items : items.where((e) => _progressOf(e.id) != Progress.done).toList();

    final progress = _progressForAll(items);
    final progressPercentText = '${(progress * 100).round()}%';
    final started = _fmtDate(startedAt);

    // ===== 로딩/에러: embedded 모드 고려 =====
    if (loading && items.isEmpty) {
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && items.isEmpty) {
      final errorChild = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('서버에서 커리큘럼을 찾을 수 없어요',
                style: TextStyle(color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _refreshAll,
              style: FilledButton.styleFrom(backgroundColor: UiTokens.primaryBlue),
              child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (widget.embedded) {
        return errorChild;
      }
      return Scaffold(backgroundColor: Colors.white, body: errorChild);
    }

    // ===== 공통 본문 =====
    final content = SafeArea(
      top: !widget.embedded, // 상위 AppBar가 있을 땐 false (embedded=true면 상단패딩 제거)
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
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person, color: Color(0xFF8C96A1)) : null,
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
                              '멘토 : $mentorName',
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
                            valueColor: const AlwaysStoppedAnimation(UiTokens.primaryBlue),
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
                onPressed: () => _continueLearning(items),
                style: FilledButton.styleFrom(
                  backgroundColor: UiTokens.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _nextIncomplete(items) == null ? '복습하기' : '이어보기',
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
                  const Text('내 학습',
                      style: TextStyle(color: UiTokens.title, fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_progLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_progError)
                    TextButton(
                      onPressed: _loadProgress,
                      child: const Text('진행도 재시도'),
                    ),
                  TextButton.icon(
                    onPressed: _showFilterSheet,
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
            ),

            // ===== 커리큘럼 목록 =====
            ListView.separated(
              itemCount: list.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = list[i];
                final state = _progressOf(item.id);
                final prog = _progressById[item.id] ??
                    const CurriculumProgress(
                      watchedRatio: 0.0,
                      attempts: 0,
                      bestScore: null,
                      passed: false,
                    );

                // 잠금 체크: 이전 모듈이 서명되지 않았으면 잠금
                final bool isLocked = i > 0 && !_signed.contains(list[i - 1].id);
                final bool isSigned = _signed.contains(item.id);

                return Stack(
                  children: [
                    Opacity(
                      opacity: isLocked ? 0.5 : 1.0,
                      child: CurriculumTile(
                        item: item,
                        onTap: isLocked
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('이전 교육의 서명을 완료해주세요.'),
                                  ),
                                );
                              }
                            : () async {
                                final changed =
                                    await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => CurriculumDetailPage(
                                      item: item,
                                      mode: CurriculumViewMode.mentee,
                                      progress: prog, // 실제 진행 객체 전달
                                    ),
                                  ),
                                );

                                // 디테일에서 진행도 변화가 있었다면(true), 즉시 최신화
                                if (changed == true) {
                                  // 시험/영상 완료 직후이므로 재시도 모드 활성화
                                  await _refreshAll(retryOnEmpty: true);
                                }
                              },
                      ),
                    ),

                    // 잠금 아이콘 (오른쪽 중앙)
                    if (isLocked)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Icon(
                            Icons.lock,
                            color: Colors.grey[600],
                            size: 26,
                          ),
                        ),
                      ),

                    // 진행 뱃지 (오른쪽 상단)
                    if (state != Progress.notStarted && !isLocked)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _progressBadge(state),
                      ),

                    // 서명 완료 펜 아이콘 (오른쪽 상단, 진행 뱃지 옆)
                    if (isSigned && !isLocked)
                      Positioned(
                        top: 10,
                        right: state != Progress.notStarted ? 50 : 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green[500],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // ===== 교육 수료하기 버튼 =====
            if (_canCompleteEducation(items))
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final user = context.read<UserProvider>().current;
                      if (user == null) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompletionPage(
                            menteeId: user.id,
                            menteeName: user.nickname,
                            theoryCount: items.where((i) => i.requiresExam).length,
                            practiceCount: 0, // TODO: 실습 개수 가져오기
                            totalHours: 0, // TODO: 총 교육 시간 계산
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.school, size: 24),
                    label: const Text(
                      '교육 수료하기',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // ===== embedded 모드면 본문만 반환 =====
    if (widget.embedded) {
      return content;
    }

    // ===== 단독 페이지 모드면 기존처럼 AppBar 포함 =====
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('학습', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        iconTheme: const IconThemeData(color: UiTokens.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAll,
            tooltip: '진행도 새로고침',
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
      body: content,
    );
  }

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
          Text(done ? '완료' : '수강중', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
