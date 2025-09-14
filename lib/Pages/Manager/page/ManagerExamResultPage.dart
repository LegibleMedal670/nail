// lib/Pages/Manager/page/ManagerExamResultPage.dart

import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Services/ExamService.dart';

/// ===== 로컬(뷰 표현) 데이터 모델 =====

class ExamAttemptResult {
  final String id;                 // 시도 ID(서버 미제공 시 생성)
  final DateTime takenAt;          // 응시 일시
  final int score;                 // 0~100
  final bool passed;               // 통과 여부
  final Duration duration;         // 풀이 시간 (서버 미제공 시 Duration.zero)
  final List<QuestionResult> items; // 문항 상세(현재 서버 미제공 → 빈 리스트)

  const ExamAttemptResult({
    required this.id,
    required this.takenAt,
    required this.score,
    required this.passed,
    required this.duration,
    required this.items,
  });
}

enum QuestionType { mcq, short, ordering }

class QuestionResult {
  final String id;
  final QuestionType type;
  final String prompt;

  // 객관식
  final List<String>? choices;
  final int? selectedIndex;
  final int? correctIndex;

  // 단답
  final String? answerText;       // 사용자가 입력
  final List<String>? accepteds;  // 정답 허용값

  // 순서
  final List<String>? selectedOrdering;
  final List<String>? correctOrdering;

  // 공통
  final bool isCorrect;
  final String? explanation;

  const QuestionResult({
    required this.id,
    required this.type,
    required this.prompt,
    this.choices,
    this.selectedIndex,
    this.correctIndex,
    this.answerText,
    this.accepteds,
    this.selectedOrdering,
    this.correctOrdering,
    required this.isCorrect,
    this.explanation,
  });
}

/// ===== 페이지 =====
///
/// 사용 방법:
/// - (추천) 서버 연동용
///   ExamResultPage(
///     menteeName: '홍길동',
///     curriculumTitle: 'W1. ...',
///     moduleCode: 'MOD-001',
///     loginKey: 'login-xxxx',
///     // passScore 를 안 넘기면 서버(get_exam_set)에서 가져옵니다.
///   )
///

class ExamResultPage extends StatefulWidget {
  final String menteeName;              // 예: 한지민
  final String curriculumTitle;         // 예: W1. 기초 위생 및 도구 소개

  /// 서버 연동 파라미터 (둘 다 주어지면 자동 로드)
  final String? moduleCode;             // 과정 코드
  final String? loginKey;               // 멘티 로그인 키

  /// 통과 기준(옵션). 전달 안 하면 서버에서 exam_set pass_score를 읽습니다.
  final int? passScore;

  /// 수동 주입 시도 목록(옵션). 이 값이 있으면 우선 렌더링하고, 서버 파라미터가 있다면 백그라운드로 새로 고쳐 반영합니다.
  final List<ExamAttemptResult>? attempts;

  const ExamResultPage({
    super.key,
    required this.menteeName,
    required this.curriculumTitle,
    this.moduleCode,
    this.loginKey,
    this.passScore,
    this.attempts,
  });

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  bool _loading = false;
  String? _error;

  /// 서버/입력으로 수집된 최종 시도 목록(최신 우선 정렬)
  List<ExamAttemptResult> _attempts = [];

  /// 헤더에 표시할 통과 기준
  int? _passScore;

  /// 선택된 시도 인덱스(0=최신)
  int _selected = 0;

  ExamAttemptResult get _attempt => _attempts[_selected];

  @override
  void initState() {
    super.initState();

    // 초기 값 반영
    _attempts = List<ExamAttemptResult>.from(widget.attempts ?? const []);
    _attempts.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    _passScore = widget.passScore;

    // 서버 파라미터가 주어졌다면 새로고침
    if ((widget.moduleCode ?? '').isNotEmpty && (widget.loginKey ?? '').isNotEmpty) {
      _loadRemote();
    } else if (_attempts.isEmpty && _passScore == null && (widget.moduleCode ?? '').isNotEmpty) {
      // attempts 없이 passScore만 필요할 때
      _loadPassScoreOnly();
    }
  }

  Future<void> _loadRemote() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) 시도 목록
      final list = await ExamService.instance.menteeListAttempts(
        loginKey: widget.loginKey!,
        moduleCode: widget.moduleCode!,
      );

      final mapped = list.map((m) {
        final id = 'attempt_${m.createdAt.millisecondsSinceEpoch}';
        return ExamAttemptResult(
          id: id,
          takenAt: m.createdAt,
          score: m.score,
          passed: m.passed,
          duration: Duration.zero, // 현재 RPC에 풀이시간/문항 상세 없음
          items: const <QuestionResult>[],
        );
      }).toList();

      // 2) 통과 기준 (없다면)
      int? pass = _passScore;
      if (pass == null) {
        final set = await ExamService.instance.getExamSet(widget.moduleCode!);
        pass = set?.passScore;
      }

      if (!mounted) return;
      setState(() {
        _attempts = mapped..sort((a, b) => b.takenAt.compareTo(a.takenAt));
        _selected = 0;
        _passScore = pass ?? _passScore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '결과를 불러오지 못했어요: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadPassScoreOnly() async {
    try {
      final set = await ExamService.instance.getExamSet(widget.moduleCode!);
      if (!mounted) return;
      setState(() {
        _passScore = set?.passScore ?? _passScore;
      });
    } catch (_) {
      // 무시 (헤더에만 영향)
    }
  }

  @override
  Widget build(BuildContext context) {
    final best = _attempts.fold<int>(0, (m, e) => e.score > m ? e.score : m);
    final anyPassed = _attempts.any((e) => e.passed);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: UiTokens.title),
        title: const Text('시험 결과', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: '요약 보기',
            onPressed: () => _showSummarySheet(context, best, anyPassed),
            icon: const Icon(Icons.assessment_outlined, color: UiTokens.actionIcon),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _loadRemote)
            : _attempts.isEmpty
            ? _EmptyState(
          menteeName: widget.menteeName,
          curriculumTitle: widget.curriculumTitle,
          passScore: _passScore,
        )
            : SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(
                menteeName: widget.menteeName,
                curriculumTitle: widget.curriculumTitle,
                attempts: _attempts.length,
                bestScore: best,
                passScore: _passScore ?? 60,
                anyPassed: anyPassed,
              ),
              const SizedBox(height: 12),

              // 시도 선택 바
              _AttemptPicker(
                attempts: _attempts,
                selected: _selected,
                onSelected: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: 12),

              // 시도 요약
              _AttemptSummary(attempt: _attempt),
              const SizedBox(height: 12),

              // 문항별 결과(현재 RPC 미지원: 데모/향후 확장을 위해 조건부 표시)
              if (_attempt.items.isNotEmpty)
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('문항별 결과'),
                      const SizedBox(height: 8),
                      ListView.separated(
                        itemCount: _attempt.items.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _QuestionBlock(q: _attempt.items[i]),
                      ),
                    ],
                  ),
                )
              else
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('문항별 결과'),
                      const SizedBox(height: 8),
                      Text(
                        '문항 상세 데이터가 아직 제공되지 않습니다.',
                        style: TextStyle(
                          color: UiTokens.title.withOpacity(0.65),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSummarySheet(BuildContext context, int best, bool anyPassed) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetGrabber(),
            const SizedBox(height: 8),
            const Text('시험 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiTokens.title)),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniStat('응시 횟수', '${_attempts.length}회'),
                const SizedBox(width: 10),
                _miniStat('최고 점수', '$best점'),
                const SizedBox(width: 10),
                _miniStat('통과 여부', anyPassed ? '통과' : '미통과',
                    fg: anyPassed ? const Color(0xFF059669) : UiTokens.title.withOpacity(0.7)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: UiTokens.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sheetGrabber() => Container(
    width: 44,
    height: 4,
    decoration: BoxDecoration(color: const Color(0xFFE6EAF0), borderRadius: BorderRadius.circular(3)),
  );

  static Widget _miniStat(String label, String value, {Color? fg}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: UiTokens.title.withOpacity(0.6), fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(color: fg ?? UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// ===== 빈 상태 / 에러 상태 =====

class _EmptyState extends StatelessWidget {
  final String menteeName;
  final String curriculumTitle;
  final int? passScore;

  const _EmptyState({
    required this.menteeName,
    required this.curriculumTitle,
    required this.passScore,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(menteeName,
                    style: const TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(curriculumTitle,
                    style: TextStyle(color: UiTokens.title.withOpacity(0.8), fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _HeaderCard._pill('통과기준 ${passScore ?? 60}점',
                        const Color(0xFFFEF3C7), const Color(0xFFFDE68A), const Color(0xFF92400E)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: UiTokens.actionIcon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '응시 내역이 없습니다.',
                    style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SectionCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: UiTokens.title.withOpacity(0.8), fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

/// ===== 헤더 카드 =====

class _HeaderCard extends StatelessWidget {
  final String menteeName;
  final String curriculumTitle;
  final int attempts;
  final int bestScore;
  final int passScore;
  final bool anyPassed;

  const _HeaderCard({
    required this.menteeName,
    required this.curriculumTitle,
    required this.attempts,
    required this.bestScore,
    required this.passScore,
    required this.anyPassed,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(menteeName, style: const TextStyle(color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(curriculumTitle,
              style: TextStyle(color: UiTokens.title.withOpacity(0.8), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _pill('응시 ${attempts}회', const Color(0xFFF5F3FF), const Color(0xFFE9D5FF), const Color(0xFF6D28D9)),
              const SizedBox(width: 8),
              _pill('최고 $bestScore점', const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              _pill('통과기준 $passScore점', const Color(0xFFFEF3C7), const Color(0xFFFDE68A), const Color(0xFF92400E)),
              const Spacer(),
              _pill(anyPassed ? '통과' : '미통과',
                  anyPassed ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                  anyPassed ? const Color(0xFFA7F3D0) : const Color(0xFFE9D5FF),
                  anyPassed ? const Color(0xFF059669) : const Color(0xFF6D28D9)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _pill(String text, Color bg, Color border, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

/// ===== 시도 선택 바 =====

class _AttemptPicker extends StatelessWidget {
  final List<ExamAttemptResult> attempts;
  final int selected;
  final ValueChanged<int> onSelected;

  const _AttemptPicker({
    required this.attempts,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('시도 선택'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(attempts.length, (i) {
                final a = attempts[i];
                final isSel = selected == i;
                return Padding(
                  padding: EdgeInsets.only(right: i == attempts.length - 1 ? 0 : 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelected(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: isSel ? const Color(0xFF93C5FD) : UiTokens.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            a.passed ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
                            size: 16,
                            color: a.passed ? const Color(0xFF059669) : UiTokens.actionIcon,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${attempts.length - i}회차 · ${_fmtDate(a.takenAt)} · ${a.score}점',
                            style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }
}

/// ===== 시도 요약 카드 =====

class _AttemptSummary extends StatelessWidget {
  final ExamAttemptResult attempt;
  const _AttemptSummary({required this.attempt});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          // 점수 원형
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE6ECF3)),
            ),
            child: Text(
              '${attempt.score}점',
              style: const TextStyle(
                color: UiTokens.title,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(attempt.passed ? '통과' : '미통과',
                    attempt.passed ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                    attempt.passed ? const Color(0xFFA7F3D0) : const Color(0xFFE9D5FF),
                    attempt.passed ? const Color(0xFF059669) : const Color(0xFF6D28D9)),
                const SizedBox(height: 12),
                _iconText(Icons.event_rounded, _fmtDateTime(attempt.takenAt)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _iconText(IconData ic, String text) {
    return Row(
      children: [
        Icon(ic, size: 18, color: UiTokens.actionIcon),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: UiTokens.title.withOpacity(0.85), fontWeight: FontWeight.w700)),
      ],
    );
  }

  static String _fmtDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}분 ${s}초';
  }

  static Widget _pill(String text, Color bg, Color border, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

/// ===== 문항 카드 =====
/// 현재 RPC로 문항 상세를 받지 못하므로, 데모/향후 확장 대비 코드는 유지합니다.

class _QuestionBlock extends StatefulWidget {
  final QuestionResult q;
  const _QuestionBlock({required this.q});

  @override
  State<_QuestionBlock> createState() => _QuestionBlockState();
}

class _QuestionBlockState extends State<_QuestionBlock> {
  bool _showExp = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.q;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [UiTokens.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                q.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 20,
                color: q.isCorrect ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.prompt,
                  style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _typeChip(q.type),
            ],
          ),
          const SizedBox(height: 10),

          // 본문
          if (q.type == QuestionType.mcq)
            _mcqView(q)
          else if (q.type == QuestionType.short)
            _shortView(q)
          else
            _orderingView(q),

          // 해설 토글
          if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showExp = !_showExp),
                icon: Icon(_showExp ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: UiTokens.actionIcon),
                label: Text(_showExp ? '해설 숨기기' : '해설 보기',
                    style: const TextStyle(color: UiTokens.actionIcon, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6ECF3)),
                ),
                child: Text(q.explanation!,
                    style: TextStyle(color: UiTokens.title.withOpacity(0.9), fontWeight: FontWeight.w700)),
              ),
              crossFadeState: _showExp ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
            )
          ],
        ],
      ),
    );
  }

  static Widget _typeChip(QuestionType t) {
    String label;
    switch (t) {
      case QuestionType.mcq:
        label = '객관식';
        break;
      case QuestionType.short:
        label = '단답';
        break;
      case QuestionType.ordering:
        label = '순서';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  Widget _mcqView(QuestionResult q) {
    final choices = q.choices ?? const <String>[];
    return Column(
      children: List.generate(choices.length, (i) {
        final isSel = q.selectedIndex == i;
        final isCor = q.correctIndex == i;
        final bg = isSel
            ? (isCor ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2))
            : Colors.white;
        final border = isSel
            ? (isCor ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA))
            : (isCor ? const Color(0xFFA7F3D0) : UiTokens.cardBorder);
        final icon = isCor
            ? Icons.check_rounded
            : (isSel ? Icons.close_rounded : Icons.radio_button_unchecked);
        final fg = isCor
            ? const Color(0xFF059669)
            : (isSel ? const Color(0xFFDC2626) : UiTokens.actionIcon);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  choices[i],
                  style: TextStyle(
                    color: UiTokens.title.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _shortView(QuestionResult q) {
    final ok = q.isCorrect;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('응답', q.answerText ?? '-', ok ? const Color(0xFF059669) : UiTokens.title),
        const SizedBox(height: 6),
        _kv('허용 정답', (q.accepteds ?? const <String>[]).join(', '),
            UiTokens.title.withOpacity(0.8)),
      ],
    );
  }

  Widget _orderingView(QuestionResult q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('선택한 순서',
            style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _orderList(q.selectedOrdering ?? const <String>[],
            border: q.isCorrect ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
            bg: q.isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2)),
        const SizedBox(height: 10),
        Text('정답 순서',
            style: TextStyle(color: UiTokens.title.withOpacity(0.7), fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _orderList(q.correctOrdering ?? const <String>[],
            border: const Color(0xFFA7F3D0), bg: const Color(0xFFECFDF5)),
      ],
    );
  }

  static Widget _kv(String k, String v, Color vColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 74, child: Text(k, style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: TextStyle(color: vColor, fontWeight: FontWeight.w700))),
      ],
    );
  }

  static Widget _orderList(List<String> items, {required Color border, required Color bg}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Column(
        children: List.generate(items.length, (i) {
          return Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: UiTokens.cardBorder),
                ),
                child: Text('${i + 1}',
                    style: const TextStyle(color: UiTokens.title, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(items[i],
                    style: TextStyle(color: UiTokens.title.withOpacity(0.95), fontWeight: FontWeight.w700)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// ===== 공용 섹션 카드 / 타이틀 =====

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [UiTokens.cardShadow],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: UiTokens.title, fontSize: 16, fontWeight: FontWeight.w800));
  }
}
