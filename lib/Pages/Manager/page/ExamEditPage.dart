import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/model/ExamModel.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';

// /// =========================
// /// 모델
// /// =========================
//
// enum ExamQuestionType { mcq, shortAnswer, ordering }
//
// class ExamQuestion {
//   final String id;
//   ExamQuestionType type;
//   String prompt;
//
//   // 객관식
//   List<String>? choices;
//   int? correctIndex; // 단일정답(필요 시 확장 가능)
//
//   // 주관식
//   List<String>? answers; // 허용 답안들
//
//   // 순서 맞추기
//   List<String>? ordering; // 정답 순서
//
//   ExamQuestion._({
//     required this.id,
//     required this.type,
//     required this.prompt,
//     this.choices,
//     this.correctIndex,
//     this.answers,
//     this.ordering,
//   });
//
//   factory ExamQuestion.mcq({
//     required String prompt,
//     List<String>? choices,
//     int? correctIndex,
//   }) =>
//       ExamQuestion._(
//         id: DateTime.now().microsecondsSinceEpoch.toString(),
//         type: ExamQuestionType.mcq,
//         prompt: prompt,
//         choices: choices ?? ['보기 1', '보기 2', '보기 3', '보기 4'],
//         correctIndex: correctIndex ?? 0,
//       );
//
//   factory ExamQuestion.short({
//     required String prompt,
//     List<String>? answers,
//   }) =>
//       ExamQuestion._(
//         id: DateTime.now().microsecondsSinceEpoch.toString(),
//         type: ExamQuestionType.shortAnswer,
//         prompt: prompt,
//         answers: answers ?? ['예시 답안'],
//       );
//
//   factory ExamQuestion.ordering({
//     required String prompt,
//     List<String>? ordering,
//   }) =>
//       ExamQuestion._(
//         id: DateTime.now().microsecondsSinceEpoch.toString(),
//         type: ExamQuestionType.ordering,
//         prompt: prompt,
//         ordering: ordering ?? ['항목 A', '항목 B', '항목 C'],
//       );
//
//   ExamQuestion clone() => ExamQuestion._(
//     id: id,
//     type: type,
//     prompt: prompt,
//     choices: choices == null ? null : List<String>.from(choices!),
//     correctIndex: correctIndex,
//     answers: answers == null ? null : List<String>.from(answers!),
//     ordering: ordering == null ? null : List<String>.from(ordering!),
//   );
// }
//
// class ExamEditResult {
//   final List<ExamQuestion> questions;
//   final int passScore; // 0~100
//   const ExamEditResult({required this.questions, required this.passScore});
// }

/// =========================
/// 페이지
/// =========================

class ExamEditPage extends StatefulWidget {
  final List<ExamQuestion> initialQuestions;
  final int initialPassScore;

  const ExamEditPage({
    super.key,
    required this.initialQuestions,
    this.initialPassScore = 60,
  });

  /// 빠른 데모용
  factory ExamEditPage.demo() {
    return ExamEditPage(
      initialPassScore: 60,
      initialQuestions: [
        ExamQuestion.mcq(prompt: '기본 케어에서 먼저 해야 하는 단계는?'),
        ExamQuestion.short(prompt: '젤 제거 과정을 한 단어로? (영어)', answers: ['off', 'soakoff']),
        ExamQuestion.ordering(
          prompt: '올바른 순서로 배열하세요',
          ordering: ['손 소독', '큐티클 정리', '베이스 코트'],
        ),
      ],
    );
  }

  @override
  State<ExamEditPage> createState() => _ExamEditPageState();
}

class _ExamEditPageState extends State<ExamEditPage> {
  late List<ExamQuestion> _questions =
  widget.initialQuestions.map((e) => e.clone()).toList();
  late int _passScore = widget.initialPassScore;

  bool _dirty = false;

  void _markDirty() => setState(() => _dirty = true);
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  // 나가기 확인(중앙 다이얼로그)
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DiscardConfirmDialog(
        title: '작성을 종료할까요?',
        message: '저장하지 않은 내용은 사라집니다.',
        keepEditingText: '계속 작성',
        leaveText: '나가기',
      ),
    );
    return ok == true;
  }

  // 저장
  void _save() {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문항을 1개 이상 추가해주세요')),
      );
      return;
    }
    Navigator.pop(
      context,
      ExamEditResult(questions: _questions, passScore: _passScore),
    );
  }

  // 문항 추가
  Future<void> _addQuestionSheet() async {
    final type = await showModalBottomSheet<ExamQuestionType>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddQuestionSheet(),
    );
    if (type == null) return;

    late ExamQuestion q;
    switch (type) {
      case ExamQuestionType.mcq:
        q = ExamQuestion.mcq(prompt: '질문을 입력하세요');
        break;
      case ExamQuestionType.shortAnswer:
        q = ExamQuestion.short(prompt: '질문을 입력하세요');
        break;
      case ExamQuestionType.ordering:
        q = ExamQuestion.ordering(prompt: '질문을 입력하세요');
        break;
    }
    setState(() {
      _questions.add(q);
      _dirty = true;
    });
    // 생성 직후 편집 열기
    _editQuestion(q);
  }

  // 문항 편집
  Future<void> _editQuestion(ExamQuestion q) async {
    Widget sheet;
    switch (q.type) {
      case ExamQuestionType.mcq:
        sheet = _McqEditorSheet(question: q.clone());
        break;
      case ExamQuestionType.shortAnswer:
        sheet = _ShortEditorSheet(question: q.clone());
        break;
      case ExamQuestionType.ordering:
        sheet = _OrderingEditorSheet(question: q.clone());
        break;
    }

    final updated = await showModalBottomSheet<ExamQuestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => sheet,
    );

    if (updated != null) {
      setState(() {
        final idx = _questions.indexWhere((e) => e.id == q.id);
        if (idx != -1) _questions[idx] = updated;
        _dirty = true;
      });
    }
  }

  void _removeQuestion(String id) {
    setState(() {
      _questions.removeWhere((e) => e.id == id);
      _dirty = true;
    });
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    setState(() {
      final item = _questions.removeAt(i);
      _questions.insert(i - 1, item);
      _dirty = true;
    });
  }

  void _moveDown(int i) {
    if (i >= _questions.length - 1) return;
    setState(() {
      final item = _questions.removeAt(i);
      _questions.insert(i + 1, item);
      _dirty = true;
    });
  }

  // 타입별 카운트
  int _count(ExamQuestionType t) =>
      _questions.where((e) => e.type == t).length;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocus,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final leave = await _confirmDiscard();
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
                final ok = await _confirmDiscard();
                if (ok && mounted) Navigator.pop(context);
              },
            ),
            title: const Text(
              '시험 편집',
              style: TextStyle(
                color: UiTokens.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _save,
                child:
                const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addQuestionSheet,
            backgroundColor: UiTokens.primaryBlue,
            label: const Text('문항 추가'),
            icon: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 KPI(문항 수/타입 분포)
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('구성 요약'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _kpiChip(Icons.list_alt, '전체', _questions.length.toString()),
                            _kpiChip(Icons.radio_button_checked, '객관식',
                                _count(ExamQuestionType.mcq).toString()),
                            _kpiChip(Icons.short_text, '주관식',
                                _count(ExamQuestionType.shortAnswer).toString()),
                            _kpiChip(Icons.swap_vert, '순서 맞추기',
                                _count(ExamQuestionType.ordering).toString()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text(
                              '통과 기준',
                              style: TextStyle(
                                  color: UiTokens.title,
                                  fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F2FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_passScore점 / 100',
                                style: const TextStyle(
                                    color: UiTokens.primaryBlue,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _passScore.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '$_passScore',
                          activeColor: UiTokens.primaryBlue,
                          onChanged: (v) {
                            setState(() {
                              _passScore = v.round();
                              _dirty = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 문항 리스트
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('문항'),
                        const SizedBox(height: 8),
                        if (_questions.isEmpty)
                          Text(
                            '아직 문항이 없습니다. 우측 하단의 ‘문항 추가’ 버튼을 눌러 시작하세요.',
                            style: TextStyle(
                              color: UiTokens.title.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          ListView.separated(
                            itemCount: _questions.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final q = _questions[i];
                              return _QuestionTile(
                                index: i,
                                question: q,
                                onEdit: () => _editQuestion(q),
                                onRemove: () => _removeQuestion(q.id),
                                onMoveUp: () => _moveUp(i),
                                onMoveDown: () => _moveDown(i),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 작은 UI들
  Widget _kpiChip(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8FF),
      border: Border.all(color: UiTokens.cardBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: UiTokens.actionIcon),
      const SizedBox(width: 6),
      Text('$label $value',
          style: const TextStyle(
              color: UiTokens.title, fontWeight: FontWeight.w800)),
    ]),
  );
}

/// =========================
/// 타일
/// =========================
class _QuestionTile extends StatelessWidget {
  final int index;
  final ExamQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _QuestionTile({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  IconData get _icon {
    switch (question.type) {
      case ExamQuestionType.mcq:
        return Icons.radio_button_checked;
      case ExamQuestionType.shortAnswer:
        return Icons.short_text;
      case ExamQuestionType.ordering:
        return Icons.swap_vert;
    }
  }

  String get _meta {
    switch (question.type) {
      case ExamQuestionType.mcq:
        final n = question.choices?.length ?? 0;
        return '보기 $n개 · 정답 ${((question.correctIndex ?? 0) + 1)}';
      case ExamQuestionType.shortAnswer:
        final n = question.answers?.length ?? 0;
        return '허용 답안 $n개';
      case ExamQuestionType.ordering:
        final n = question.ordering?.length ?? 0;
        return '항목 $n개';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UiTokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [UiTokens.cardShadow],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE9F2FF),
            child: Icon(_icon, color: UiTokens.primaryBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Q${index + 1}. ${question.prompt}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: UiTokens.title, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_meta,
                    style: TextStyle(
                      color: UiTokens.title.withOpacity(0.6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 순서 이동
          IconButton(
            tooltip: '위로',
            onPressed: onMoveUp,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
          IconButton(
            tooltip: '아래로',
            onPressed: onMoveDown,
            icon: const Icon(Icons.arrow_downward_rounded),
          ),
          // 편집/삭제
          IconButton(
            tooltip: '편집',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '삭제',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// =========================
/// 시트: 문항 타입 선택
/// =========================
class _AddQuestionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String subtitle, ExamQuestionType t) {
      return ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE9F2FF),
          child: Icon(icon, color: UiTokens.primaryBlue, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        onTap: () => Navigator.pop(context, t),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetGrabber(),
          const SizedBox(height: 8),
          const Text('새 문항 추가',
              style: TextStyle(
                  color: UiTokens.title, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          item(Icons.radio_button_checked, '객관식', '보기 중 하나를 고르는 문제', ExamQuestionType.mcq),
          item(Icons.short_text, '주관식', '텍스트를 직접 작성하여 답하는 문제', ExamQuestionType.shortAnswer),
          item(Icons.swap_vert, '순서 맞추기', '항목을 올바른 순서로 정렬', ExamQuestionType.ordering),
        ],
      ),
    );
  }
}

/// =========================
/// 시트: 객관식 에디터
/// =========================
class _McqEditorSheet extends StatefulWidget {
  final ExamQuestion question;
  const _McqEditorSheet({required this.question});

  @override
  State<_McqEditorSheet> createState() => _McqEditorSheetState();
}

class _McqEditorSheetState extends State<_McqEditorSheet> {
  late TextEditingController _promptCtl =
  TextEditingController(text: widget.question.prompt);
  late List<String> _choices = List<String>.from(widget.question.choices!);
  late int _correct = widget.question.correctIndex ?? 0;

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocus,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            _sheetGrabber(),
            const SizedBox(height: 8),
            const Text('객관식 편집',
                style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            // 질문
            TextField(
              controller: _promptCtl,
              decoration: _inputDeco('질문'),
            ),
            const SizedBox(height: 20),

            // 보기들
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _choices.length,
                physics: const ClampingScrollPhysics(),
                itemBuilder: (_, i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: _correct,
                          onChanged: (v) => setState(() => _correct = v ?? 0),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller:
                            TextEditingController(text: _choices[i]),
                            onChanged: (v) => _choices[i] = v,
                            decoration: _inputDeco('보기 ${i + 1}').copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          onPressed: () => setState(() {
                            _choices.removeAt(i);
                            if (_choices.isEmpty) {
                              _correct = 0;
                            } else if (_correct >= _choices.length) {
                              _correct = _choices.length - 1;
                            }
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _choices.add('새 보기')),
                  icon: const Icon(Icons.add),
                  label: const Text('보기 추가'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (_choices.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('보기는 2개 이상이어야 합니다')));
                      return;
                    }
                    Navigator.pop(
                      context,
                      widget.question
                        ..prompt = _promptCtl.text.trim()
                        ..choices = _choices
                        ..correctIndex = _correct,
                    );
                  },
                  child:
                  const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// 시트: 주관식 에디터
/// =========================
class _ShortEditorSheet extends StatefulWidget {
  final ExamQuestion question;
  const _ShortEditorSheet({required this.question});

  @override
  State<_ShortEditorSheet> createState() => _ShortEditorSheetState();
}

class _ShortEditorSheetState extends State<_ShortEditorSheet> {
  late TextEditingController _promptCtl =
  TextEditingController(text: widget.question.prompt);
  late List<String> _answers = List<String>.from(widget.question.answers!);

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocus,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            _sheetGrabber(),
            const SizedBox(height: 8),
            const Text('주관식 편집',
                style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: _promptCtl, decoration: _inputDeco('질문')),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: _answers.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded,
                          color: UiTokens.actionIcon, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller:
                          TextEditingController(text: _answers[i]),
                          onChanged: (v) => _answers[i] = v,
                          decoration: _inputDeco('허용 답안 ${i + 1}').copyWith(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10)),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _answers.removeAt(i)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _answers.add('')),
                  icon: const Icon(Icons.add),
                  label: const Text('답안 추가'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final kept = _answers
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    if (kept.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('답안을 1개 이상 입력하세요')));
                      return;
                    }
                    Navigator.pop(
                      context,
                      widget.question
                        ..prompt = _promptCtl.text.trim()
                        ..answers = kept,
                    );
                  },
                  child:
                  const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// 시트: 순서 맞추기 에디터
/// =========================
class _OrderingEditorSheet extends StatefulWidget {
  final ExamQuestion question;
  const _OrderingEditorSheet({required this.question});

  @override
  State<_OrderingEditorSheet> createState() => _OrderingEditorSheetState();
}

class _OrderingEditorSheetState extends State<_OrderingEditorSheet> {
  late TextEditingController _promptCtl =
  TextEditingController(text: widget.question.prompt);
  late List<String> _items = List<String>.from(widget.question.ordering!);

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _moveUp(int i) {
    if (i <= 0) return;
    setState(() {
      final x = _items.removeAt(i);
      _items.insert(i - 1, x);
    });
  }

  void _moveDown(int i) {
    if (i >= _items.length - 1) return;
    setState(() {
      final x = _items.removeAt(i);
      _items.insert(i + 1, x);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocus,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            _sheetGrabber(),
            const SizedBox(height: 8),
            const Text('순서 맞추기 편집',
                style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: _promptCtl, decoration: _inputDeco('질문')),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (_, i) => Container(
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
                        child: TextField(
                          controller:
                          TextEditingController(text: _items[i]),
                          onChanged: (v) => _items[i] = v,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '항목',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _moveUp(i),
                        icon:
                        const Icon(Icons.arrow_upward_rounded, size: 18),
                      ),
                      IconButton(
                        onPressed: () => _moveDown(i),
                        icon:
                        const Icon(Icons.arrow_downward_rounded, size: 18),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _items.removeAt(i)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _items.add('')),
                  icon: const Icon(Icons.add),
                  label: const Text('항목 추가'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final kept = _items
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    if (kept.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('항목을 2개 이상 입력하세요')));
                      return;
                    }
                    Navigator.pop(
                      context,
                      widget.question
                        ..prompt = _promptCtl.text.trim()
                        ..ordering = kept,
                    );
                  },
                  child:
                  const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// 공용 뷰 위젯들
/// =========================

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 16),
      width: double.infinity,
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: UiTokens.title, fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}

Widget _sheetGrabber() => Container(
  width: 44,
  height: 4,
  decoration: BoxDecoration(
    color: const Color(0xFFE6EAF0),
    borderRadius: BorderRadius.circular(3),
  ),
);

InputDecoration _inputDeco(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  filled: true,
  fillColor: const Color(0xFFF7F9FC),
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xFFE6ECF3)),
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
  focusedBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: UiTokens.primaryBlue, width: 2),
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
);

/// 중앙 컨펌 다이얼로그 (수정/생성 페이지 공용으로 재사용 가능)
class _DiscardConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String keepEditingText;
  final String leaveText;

  const _DiscardConfirmDialog({
    required this.title,
    required this.message,
    this.keepEditingText = '계속 작성',
    this.leaveText = '나가기',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE6EAF0),
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                  color: UiTokens.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: UiTokens.title.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
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
                    child: Text(keepEditingText,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
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
                    child: Text(leaveText,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
