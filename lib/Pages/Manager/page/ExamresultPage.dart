import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// ===== 데이터 모델 =====

class ExamAttemptResult {
  final String id;                 // 시도 ID
  final DateTime takenAt;          // 응시 일시
  final int score;                 // 0~100
  final bool passed;               // 통과 여부
  final Duration duration;         // 풀이 시간
  final List<QuestionResult> items;

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
  final String? answerText;     // 사용자가 입력
  final List<String>? accepteds; // 정답 허용값(소문자 트림 일치 등 전처리 가정)

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

class ExamResultPage extends StatefulWidget {
  final String menteeName;          // 예: 한지민
  final String curriculumTitle;     // 예: W1. 기초 위생 및 도구 소개
  final int passScore;              // 예: 60
  final List<ExamAttemptResult> attempts;

  const ExamResultPage({
    super.key,
    required this.menteeName,
    required this.curriculumTitle,
    required this.passScore,
    required this.attempts,
  });

  /// 데모 데이터로 바로 띄우는 팩토리
  factory ExamResultPage.demo() {
    final itemsA = <QuestionResult>[
      QuestionResult(
        id: 'q1',
        type: QuestionType.mcq,
        prompt: '기본 케어에서 가장 먼저 해야 하는 단계는?',
        choices: const ['베이스 코트', '손 소독', '탑 코트', '컬러 도포'],
        selectedIndex: 1,
        correctIndex: 1,
        isCorrect: true,
        explanation: '위생이 최우선 → 손 소독 후 케어/도포 진행.',
      ),
      QuestionResult(
        id: 'q2',
        type: QuestionType.short,
        prompt: '젤 제거를 한 단어로 (영문) 쓰세요.',
        answerText: 'soakoff',
        accepteds: const ['soakoff', 'soak-off', 'soak off'],
        isCorrect: true,
        explanation: 'Soak-off가 통용. 하이픈/띄어쓰기 허용.',
      ),
      QuestionResult(
        id: 'q3',
        type: QuestionType.ordering,
        prompt: '올바른 순서를 고르세요.',
        selectedOrdering: const ['손 소독', '큐티클 정리', '베이스 코트'],
        correctOrdering: const ['손 소독', '큐티클 정리', '베이스 코트'],
        isCorrect: true,
        explanation: '위생 → 케어 → 도포.',
      ),
      QuestionResult(
        id: 'q4',
        type: QuestionType.mcq,
        prompt: '피부 손상이 의심될 때 가장 먼저 할 행동은?',
        choices: const ['계속 진행', '즉시 중단 후 상태 확인', '탑 코트 도포', '도구 소독'],
        selectedIndex: 0,
        correctIndex: 1,
        isCorrect: false,
        explanation: '안전이 최우선. 즉시 중단하고 상태를 확인해야 함.',
      ),
    ];

    final itemsB = <QuestionResult>[
      ...itemsA.sublist(0, 3),
      QuestionResult(
        id: 'q4',
        type: QuestionType.mcq,
        prompt: '피부 손상이 의심될 때 가장 먼저 할 행동은?',
        choices: const ['계속 진행', '즉시 중단 후 상태 확인', '탑 코트 도포', '도구 소독'],
        selectedIndex: 1,
        correctIndex: 1,
        isCorrect: true,
        explanation: '안전이 최우선. 즉시 중단하고 상태를 확인해야 함.',
      ),
    ];

    final attempts = <ExamAttemptResult>[
      ExamAttemptResult(
        id: 'try02',
        takenAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        score: 92,
        passed: true,
        duration: const Duration(minutes: 7, seconds: 11),
        items: itemsB,
      ),
      ExamAttemptResult(
        id: 'try01',
        takenAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
        score: 58,
        passed: false,
        duration: const Duration(minutes: 10, seconds: 3),
        items: itemsA,
      ),
    ];

    return ExamResultPage(
      menteeName: '한지민',
      curriculumTitle: 'W1. 기초 위생 및 도구 소개',
      passScore: 60,
      attempts: attempts,
    );
  }

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  int _selected = 0; // 기본: 0번(보통 최신 시도)

  ExamAttemptResult get _attempt => widget.attempts[_selected];

  @override
  Widget build(BuildContext context) {
    widget.attempts.sort((a, b) => b.takenAt.compareTo(a.takenAt)); // 최신 우선

    final best = widget.attempts.fold<int>(0, (m, e) => e.score > m ? e.score : m);
    final anyPassed = widget.attempts.any((e) => e.passed);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: UiTokens.title),
        title: const Text('시험 결과', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        actions: [
          // 향후 PDF 내보내기/공유 아이콘 자리
          IconButton(
            tooltip: '요약 보기',
            onPressed: () => _showSummarySheet(context, best, anyPassed),
            icon: const Icon(Icons.assessment_outlined, color: UiTokens.actionIcon),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(
                menteeName: widget.menteeName,
                curriculumTitle: widget.curriculumTitle,
                attempts: widget.attempts.length,
                bestScore: best,
                passScore: widget.passScore,
                anyPassed: anyPassed,
              ),
              const SizedBox(height: 12),

              // 시도 선택 바
              _AttemptPicker(
                attempts: widget.attempts,
                selected: _selected,
                onSelected: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: 12),

              // 시도 요약
              _AttemptSummary(attempt: _attempt),
              const SizedBox(height: 12),

              // 문항별 결과
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
                _miniStat('응시 횟수', '${widget.attempts.length}회'),
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
                            '${attempts.length - i}회차 · ${_fmtDateTime(a.takenAt)} · ${a.score}점',
                            style: TextStyle(
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

  static String _fmtDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
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
          // 점수 원형 게이지 느낌(라벨만)
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
              '${attempt.score}',
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
                Row(
                  children: [
                    const Text('점수', style: TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    _pill(attempt.passed ? '통과' : '미통과',
                        attempt.passed ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                        attempt.passed ? const Color(0xFFA7F3D0) : const Color(0xFFE9D5FF),
                        attempt.passed ? const Color(0xFF059669) : const Color(0xFF6D28D9)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _iconText(Icons.access_time_rounded, _fmtDuration(attempt.duration)),
                    const SizedBox(width: 10),
                    _iconText(Icons.event_rounded, _AttemptPicker._fmtDateTime(attempt.takenAt)),
                  ],
                ),
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
          if (q.type == QuestionType.mcq) _mcqView(q) else
            if (q.type == QuestionType.short) _shortView(q) else
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
      case QuestionType.mcq: label = '객관식'; break;
      case QuestionType.short: label = '단답'; break;
      case QuestionType.ordering: label = '순서'; break;
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
