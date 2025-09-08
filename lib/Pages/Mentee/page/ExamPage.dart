// MenteeExamPage.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/model/ExamModel.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

/// =========================
/// 멘티 시험 페이지
/// =========================
class ExamPage extends StatefulWidget {
  final List<ExamQuestion> questions;
  final int passScore; // 0~100
  final Map<String, String> explanations; // questionId -> text
  final int? initialAttempts; // 누적 응시 횟수(이 페이지 들어오면 +1)
  final int? initialBestScore; // 기존 최고점

  // ▼ 서버 제출을 위한 정보/콜백
  final String? moduleCode;               // 서버 저장용(옵션)
  final String? loginKey;                 // 서버 저장용(옵션)
  final Future<void> Function(int score, Map<String, dynamic> answers)? onSubmitted;

  const ExamPage({
    super.key,
    required this.questions,
    required this.passScore,
    this.explanations = const {},
    this.initialAttempts,
    this.initialBestScore,
    this.moduleCode,
    this.loginKey,
    this.onSubmitted,
  });

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late final PageController _pager = PageController();
  late int _page = 0;

  // 응답: MCQ=int(index), SA=String, ORDER=List<String>
  late List<dynamic> _answers;

  // 진행 통계
  late int _attempts;
  late int _bestScore;

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void initState() {
    super.initState();
    _answers = widget.questions.map((q) {
      switch (q.type) {
        case ExamQuestionType.mcq:
          return null; // 아직 선택 안함
        case ExamQuestionType.shortAnswer:
          return ''; // 아직 입력 없음
        case ExamQuestionType.ordering:
          final items = List<String>.from(q.ordering ?? const []);
          final seed = DateTime.now().millisecondsSinceEpoch ^ q.id.hashCode;
          items.shuffle(Random(seed));
          return items;
      }
    }).toList();

    // 들어오자마자 응시 횟수 +1
    _attempts = (widget.initialAttempts ?? 0) + 1;
    _bestScore = widget.initialBestScore ?? 0;
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  // 뒤로가기/스와이프 차단 + 컨펌
  Future<bool> _confirmLeave() async {
    return (await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE6ECF3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text('시험을 종료할까요?',
                  style: TextStyle(
                      color: UiTokens.title,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '진행 중인 응시는 무효 처리됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: UiTokens.title.withOpacity(0.7),
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('계속 응시',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: UiTokens.title,
                          )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: UiTokens.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('나가기',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )) ==
        true;
  }

  // 현재 문제 답변 여부 (MCQ/SA인 경우만 체크)
  bool _answeredCurrent() {
    final q = widget.questions[_page];
    final a = _answers[_page];
    switch (q.type) {
      case ExamQuestionType.mcq:
        return a is int;
      case ExamQuestionType.shortAnswer:
        return (a is String) && a.trim().isNotEmpty;
      case ExamQuestionType.ordering:
        return true; // 순서는 기본 순서도 응답으로 간주
    }
  }

  void _goNext() {
    _unfocus();
    if (_page < widget.questions.length - 1) {
      setState(() => _page++);
      _pager.animateToPage(_page,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _goPrev() {
    _unfocus();
    if (_page > 0) {
      setState(() => _page--);
      _pager.animateToPage(_page,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  int _calcScore() {
    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final a = _answers[i];
      switch (q.type) {
        case ExamQuestionType.mcq:
          if (a is int && a == q.correctIndex) correct++;
          break;
        case ExamQuestionType.shortAnswer:
          final user = (a is String) ? a.trim().toLowerCase() : '';
          final ok = (q.answers ?? const [])
              .map((e) => e.trim().toLowerCase())
              .any((x) => x == user);
          if (ok) correct++;
          break;
        case ExamQuestionType.ordering:
          final user = (a as List<String>).map((e) => e.trim()).toList();
          final ans = (q.ordering ?? const []).map((e) => e.trim()).toList();
          if (user.length == ans.length) {
            bool same = true;
            for (int k = 0; k < user.length; k++) {
              if (user[k] != ans[k]) {
                same = false;
                break;
              }
            }
            if (same) correct++;
          }
          break;
      }
    }
    final pct = (correct * 100 / widget.questions.length).round();
    return pct;
  }

  void _submit() async {
    _unfocus();
    final score = _calcScore();
    final newBest = (score > _bestScore) ? score : _bestScore;

    // 질문 id -> 사용자 응답 맵 구성(서버 저장용)
    final Map<String, dynamic> answerMap = {};
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      answerMap[q.id] = _answers[i];
    }

    // 옵션: 제출 콜백이 주어졌고, moduleCode/loginKey가 있으면 서버에 기록
    try {
      if (widget.onSubmitted != null &&
          (widget.moduleCode?.isNotEmpty ?? false) &&
          (widget.loginKey?.isNotEmpty ?? false)) {
        await widget.onSubmitted!(score, answerMap);
      }
    } catch (e) {
      // 서버 오류가 나더라도 UX 흐름은 유지(결과 페이지로 이동)
      // ignore: avoid_print
      print('시험제출 :$e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _ExamResultPage(
          questions: widget.questions,
          answers: _answers,
          explanations: widget.explanations,
          score: score,
          passScore: widget.passScore,
          attempts: _attempts,
          bestScore: newBest,
          // ▼ 재시험 시에도 서버 저장이 되도록 전달
          moduleCode: widget.moduleCode,
          loginKey: widget.loginKey,
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == widget.questions.length - 1;
    final canProceed = _answeredCurrent();

    return GestureDetector(
      onTap: _unfocus,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final leave = await _confirmLeave();
          if (leave && mounted) Navigator.pop(context);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              tooltip: '나가기',
              icon: const Icon(Icons.close, color: UiTokens.title),
              onPressed: () async {
                final ok = await _confirmLeave();
                if (ok && mounted) Navigator.pop(context);
              },
            ),
            title: const Text('시험',
                style: TextStyle(
                    color: UiTokens.title, fontWeight: FontWeight.w700)),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // 상단 진행 바
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Text('문항 ${_page + 1} / ${widget.questions.length}',
                          style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(8),
                    value: (_page + 1) / widget.questions.length,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE6ECF3),
                    valueColor:
                    const AlwaysStoppedAnimation(UiTokens.primaryBlue),
                  ),
                ),
                const SizedBox(height: 12),

                // 문제 페이지
                Expanded(
                  child: PageView.builder(
                    controller: _pager,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.questions.length,
                    itemBuilder: (_, i) {
                      final q = widget.questions[i];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _QuestionCard(
                          child: _buildQuestion(q, i),
                        ),
                      );
                    },
                  ),
                ),

                // 하단 네비게이션
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: UiTokens.primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _page == 0 ? null : _goPrev,
                          child: const Text('이전'),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: UiTokens.primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed:
                          canProceed ? (isLast ? _submit : _goNext) : null,
                          child: Text(isLast ? '제출하기' : '다음'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(ExamQuestion q, int i) {
    switch (q.type) {
      case ExamQuestionType.mcq:
        return _McqView(
          prompt: q.prompt,
          choices: q.choices ?? const [],
          value: _answers[i] as int?,
          onChanged: (v) => setState(() => _answers[i] = v),
        );
      case ExamQuestionType.shortAnswer:
        return _ShortView(
          prompt: q.prompt,
          value: _answers[i] as String,
          onChanged: (v) => setState(() => _answers[i] = v),
        );
      case ExamQuestionType.ordering:
        return _OrderingView(
          prompt: q.prompt,
          items: List<String>.from(_answers[i] as List<String>),
          onChanged: (v) => setState(() => _answers[i] = v),
        );
    }
  }
}

/// =========================
/// 결과 페이지
/// =========================
class _ExamResultPage extends StatelessWidget {
  final List<ExamQuestion> questions;
  final List<dynamic> answers;
  final Map<String, String> explanations;
  final int score;
  final int passScore;
  final int attempts;
  final int bestScore;

  // ▼ 재시험 시 서버 저장을 위해 전달 유지
  final String? moduleCode;
  final String? loginKey;
  final Future<void> Function(int score, Map<String, dynamic> answers)? onSubmitted;

  const _ExamResultPage({
    super.key,
    required this.questions,
    required this.answers,
    required this.explanations,
    required this.score,
    required this.passScore,
    required this.attempts,
    required this.bestScore,
    this.moduleCode,
    this.loginKey,
    this.onSubmitted,
  });

  bool _isCorrect(int i) {
    final q = questions[i];
    final a = answers[i];
    switch (q.type) {
      case ExamQuestionType.mcq:
        return a is int && a == q.correctIndex;
      case ExamQuestionType.shortAnswer:
        final user = (a is String) ? a.trim().toLowerCase() : '';
        return (q.answers ?? const [])
            .map((e) => e.trim().toLowerCase())
            .any((x) => x == user);
      case ExamQuestionType.ordering:
        final user = (a as List<String>).map((e) => e.trim()).toList();
        final ans = (q.ordering ?? const []).map((e) => e.trim()).toList();
        if (user.length != ans.length) return false;
        for (int k = 0; k < user.length; k++) {
          if (user[k] != ans[k]) return false;
        }
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = score >= passScore;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: const SizedBox.shrink(), // 스와이프/뒤로막기 + 닫기는 오른쪽
          title: const Text('결과',
              style:
              TextStyle(color: UiTokens.title, fontWeight: FontWeight.w700)),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                OutlinedButton(
                  // 부모가 await하는 경우를 위해 true 반환(응시 완료)
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '닫기',
                    style: TextStyle(color: UiTokens.title),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: UiTokens.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // 재시험은 현재 결과 페이지를 교체(pushReplacement)
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ExamPage(
                          questions: questions,
                          passScore: passScore,
                          explanations: explanations,
                          initialAttempts: attempts, // 새 페이지에서 +1
                          initialBestScore:
                          (score > bestScore) ? score : bestScore,
                          // ▼ 전달 유지(이게 핵심!)
                          moduleCode: moduleCode,
                          loginKey: loginKey,
                          onSubmitted: onSubmitted,
                        ),
                      ),
                    );
                  },
                  child: const Text('재시험'),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultSummaryCard(
                    score: score,
                    passScore: passScore,
                    attempts: attempts,
                    bestScore: bestScore),
                const SizedBox(height: 12),
                _QuestionList(
                  questions: questions,
                  answers: answers,
                  isCorrect: _isCorrect,
                  onTap: (i) {
                    _showExplanationSheet(context, questions[i], answers[i],
                        explanations[questions[i].id]);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExplanationSheet(
      BuildContext context, ExamQuestion q, dynamic a, String? exp) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE6EAF0),
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 10),
                Text('해설',
                    style: TextStyle(
                        color: UiTokens.title.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _QuestionCard(
                  // 읽기 전용 문제 UI (사용자 답/정답 하이라이트)
                  child: _ReviewQuestion(q: q, answer: a),
                ),
                const SizedBox(height: 12),
                if ((exp ?? '').trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6ECF3)),
                    ),
                    child: Text(
                      exp!,
                      style: TextStyle(
                        color: UiTokens.title.withOpacity(0.85),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  Text('등록된 해설이 없습니다.',
                      style: TextStyle(
                          color: UiTokens.title.withOpacity(0.6),
                          fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =========================
/// 문제 뷰 (응시용)
/// =========================

// 카드 공통
class _QuestionCard extends StatelessWidget {
  final Widget child;
  const _QuestionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [UiTokens.cardShadow],
      ),
      child: child,
    );
  }
}

// 객관식
class _McqView extends StatelessWidget {
  final String prompt;
  final List<String> choices;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _McqView({
    required this.prompt,
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt,
            style: const TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 12),
        ...List.generate(choices.length, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              border: Border.all(color: const Color(0xFFE6ECF3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RadioListTile<int>(
              activeColor: UiTokens.primaryBlue,
              value: i,
              groupValue: value,
              onChanged: onChanged,
              title: Text(choices[i]),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          );
        }),
      ],
    );
  }
}

// 주관식
class _ShortView extends StatelessWidget {
  final String prompt;
  final String value;
  final ValueChanged<String> onChanged;

  const _ShortView({
    required this.prompt,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctl = TextEditingController(text: value);
    ctl.selection =
        TextSelection.fromPosition(TextPosition(offset: ctl.text.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt,
            style: const TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          controller: ctl,
          onChanged: onChanged,
          decoration: const InputDecoration(
            labelText: '답변을 입력하세요',
            isDense: true,
            filled: true,
            fillColor: Color(0xFFF7F9FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE6ECF3)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: UiTokens.primaryBlue, width: 2),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// 순서 맞추기 (드래그)
class _OrderingView extends StatefulWidget {
  final String prompt;
  final List<String> items; // 현재 사용자 순서
  final ValueChanged<List<String>> onChanged;

  const _OrderingView({
    required this.prompt,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_OrderingView> createState() => _OrderingViewState();
}

class _OrderingViewState extends State<_OrderingView> {
  late List<String> _items = List<String>.from(widget.items);

  @override
  void didUpdateWidget(covariant _OrderingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = List<String>.from(widget.items);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 항목 수에 따른 적당한 영역 확보(드래그 제스처 충돌 방지)
    final double h = (56.0 * _items.length + 16).clamp(200.0, 360.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.prompt,
            style: const TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: h,
          child: ReorderableListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: _items.length,
            proxyDecorator: (child, index, animation) {
              const radius = 12.0;
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 8 * animation.value, // 드래그 중 살짝 뜨는 느낌
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius), // 둥근 그림자
                    ),
                    shadowColor: Colors.black26,
                    child: ClipRRect(
                      // 내용도 둥글게 클립
                      borderRadius: BorderRadius.circular(radius),
                      child: child,
                    ),
                  );
                },
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > _items.length) newIndex = _items.length;
                if (oldIndex < newIndex) newIndex--;
                final it = _items.removeAt(oldIndex);
                _items.insert(newIndex, it);
                widget.onChanged(_items);
              });
            },
            itemBuilder: (_, i) {
              return Container(
                key: ValueKey('ord_${i}_${_items[i]}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  border: Border.all(color: const Color(0xFFE6ECF3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _items[i],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle_rounded),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// =========================
/// 결과 요약/리스트/리뷰 UI
/// =========================

class _ResultSummaryCard extends StatelessWidget {
  final int score;
  final int passScore;
  final int attempts;
  final int bestScore;

  const _ResultSummaryCard({
    required this.score,
    required this.passScore,
    required this.attempts,
    required this.bestScore,
  });

  @override
  Widget build(BuildContext context) {
    final passed = score >= passScore;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [UiTokens.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('점수',
              style:
              TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('$score / 100',
                  style: const TextStyle(
                      color: UiTokens.title,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: passed
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: passed
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF87171),
                  ),
                ),
                child: Text(
                  passed ? '통과' : '미통과',
                  style: TextStyle(
                    color: passed
                        ? const Color(0xFF065F46)
                        : const Color(0xFF7F1D1D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('응시 ${attempts}회',
                      style: TextStyle(
                          color: UiTokens.title.withOpacity(0.7),
                          fontWeight: FontWeight.w700)),
                  Text('최고 $bestScore점',
                      style: TextStyle(
                          color: UiTokens.title.withOpacity(0.7),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionList extends StatelessWidget {
  final List<ExamQuestion> questions;
  final List<dynamic> answers;
  final bool Function(int idx) isCorrect;
  final ValueChanged<int> onTap;

  const _QuestionList({
    required this.questions,
    required this.answers,
    required this.isCorrect,
    required this.onTap,
  });

  IconData _iconOf(ExamQuestionType t) {
    switch (t) {
      case ExamQuestionType.mcq:
        return Icons.radio_button_checked;
      case ExamQuestionType.shortAnswer:
        return Icons.short_text;
      case ExamQuestionType.ordering:
        return Icons.swap_vert;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('문항별 결과',
              style:
              TextStyle(color: UiTokens.title, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...List.generate(questions.length, (i) {
            final q = questions[i];
            final ok = isCorrect(i);
            return InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: UiTokens.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                      ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      child: Icon(
                        ok ? Icons.check_rounded : Icons.close_rounded,
                        size: 18,
                        color:
                        ok ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Q${i + 1}. ${q.prompt}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: UiTokens.title,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(_iconOf(q.type), color: UiTokens.actionIcon, size: 18),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: UiTokens.actionIcon),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 읽기 전용 리뷰 문제 UI(선택/정답 하이라이트)
class _ReviewQuestion extends StatelessWidget {
  final ExamQuestion q;
  final dynamic answer;
  const _ReviewQuestion({required this.q, required this.answer});

  Widget _statusChip(String text, Color bg, Color border, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (q.type) {
      case ExamQuestionType.mcq:
        final sel = answer is int ? answer as int : null;
        final correctIdx = q.correctIndex ?? -1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.prompt,
                style: const TextStyle(
                    color: UiTokens.title,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 12),
            ...List.generate(q.choices?.length ?? 0, (i) {
              final isCorrect = i == correctIdx;
              final isSelected = sel == i;

              final Color bg = isCorrect
                  ? const Color(0xFFDCFCE7) // 정답: 연녹
                  : (isSelected
                  ? const Color(0xFFFEE2E2) // 내 선택 오답: 연빨
                  : const Color(0xFFF7F9FC)); // 기타: 중립

              final Color border = isCorrect
                  ? const Color(0xFF34D399)
                  : (isSelected
                  ? const Color(0xFFF87171)
                  : const Color(0xFFE6ECF3));

              final Widget trailingBadges = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCorrect)
                    _statusChip('정답', const Color(0xFFDCFCE7),
                        const Color(0xFF34D399), const Color(0xFF065F46)),
                  if (isSelected && !isCorrect) ...[
                    const SizedBox(width: 6),
                    _statusChip(
                        '내 선택',
                        const Color(0xFFFEE2E2),
                        const Color(0xFFF87171),
                        const Color(0xFF7F1D1D)),
                  ],
                ],
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 1.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (isSelected
                        ? Icons.cancel_rounded
                        : Icons.circle_outlined),
                    color: isCorrect
                        ? const Color(0xFF059669)
                        : (isSelected
                        ? const Color(0xFFDC2626)
                        : UiTokens.actionIcon),
                  ),
                  title: Text(
                    q.choices![i],
                    style: const TextStyle(
                      color: UiTokens.title,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: trailingBadges,
                  dense: true,
                ),
              );
            }),
          ],
        );

      case ExamQuestionType.shortAnswer:
        final user = (answer is String) ? answer : '';
        final ok = (q.answers ?? const [])
            .map((e) => e.trim().toLowerCase())
            .contains(user.trim().toLowerCase());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.prompt,
                style: const TextStyle(
                    color: UiTokens.title,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                  ok ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내 답: ${user.isEmpty ? '(빈 답변)' : user}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: UiTokens.title)),
                  const SizedBox(height: 6),
                  if (!ok)
                    Text('정답 예시: ${(q.answers ?? const []).join(', ')}',
                        style: TextStyle(
                          color: UiTokens.title.withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                        )),
                ],
              ),
            ),
          ],
        );

      case ExamQuestionType.ordering:
        final user = (answer as List<String>);
        final ans = (q.ordering ?? const []);
        final bool anyWrong = user.length != ans.length ||
            List.generate(user.length,
                    (i) => i < ans.length && user[i] == ans[i])
                .contains(false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.prompt,
                style: const TextStyle(
                    color: UiTokens.title,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 12),

            // 내 순서: 위치별 정오 표시 (맞으면 초록, 틀리면 빨강)
            Text('내 순서',
                style: const TextStyle(
                    color: UiTokens.title, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...List.generate(user.length, (i) {
              final bool correctPos =
                  (i < ans.length) && (user[i].trim() == ans[i].trim());
              final Color bg =
              correctPos ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
              final Color border = correctPos
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171);
              final IconData icon =
              correctPos ? Icons.check_rounded : Icons.close_rounded;
              final Color iconColor =
              correctPos ? const Color(0xFF065F46) : const Color(0xFF7F1D1D);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 1.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: UiTokens.title,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user[i],
                        style: const TextStyle(
                          color: UiTokens.title,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(icon, color: iconColor),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // 틀린게 있으면 정답 순서도 표시
            if (anyWrong) ...[
              Text('정답 순서',
                  style: const TextStyle(
                      color: UiTokens.title, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...List.generate(ans.length, (i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    border: Border.all(color: const Color(0xFFE6ECF3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: UiTokens.title,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ans[i],
                          style: const TextStyle(
                            color: UiTokens.title,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
    }
  }
}
