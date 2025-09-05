// ExamModel.dart

enum ExamQuestionType { mcq, shortAnswer, ordering }

class ExamQuestion {
  final String id;
  ExamQuestionType type;
  String prompt;

  List<String>? choices;
  int? correctIndex;
  List<String>? answers;
  List<String>? ordering;

  ExamQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.choices,
    this.correctIndex,
    this.answers,
    this.ordering,
  });

  static String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ✅ id를 외부에서 주입할 수 있게 하고, 없으면 '신규 생성 시'에만 한 번 생성
  factory ExamQuestion.mcq({
    String? id,
    required String prompt,
    List<String>? choices,
    int? correctIndex,
  }) => ExamQuestion(
    id: id ?? _genId(),
    type: ExamQuestionType.mcq,
    prompt: prompt,
    choices: choices ?? ['보기 1', '보기 2', '보기 3', '보기 4'],
    correctIndex: correctIndex ?? 0,
  );

  factory ExamQuestion.short({
    String? id,
    required String prompt,
    List<String>? answers,
  }) => ExamQuestion(
    id: id ?? _genId(),
    type: ExamQuestionType.shortAnswer,
    prompt: prompt,
    answers: answers ?? ['예시 답안'],
  );

  factory ExamQuestion.ordering({
    String? id,
    required String prompt,
    List<String>? ordering,
  }) => ExamQuestion(
    id: id ?? _genId(),
    type: ExamQuestionType.ordering,
    prompt: prompt,
    ordering: ordering ?? ['항목 A', '항목 B', '항목 C'],
  );

  // ✅ clone은 같은 id를 유지
  ExamQuestion clone() => ExamQuestion(
    id: id,
    type: type,
    prompt: prompt,
    choices: choices == null ? null : List<String>.from(choices!),
    correctIndex: correctIndex,
    answers: answers == null ? null : List<String>.from(answers!),
    ordering: ordering == null ? null : List<String>.from(ordering!),
  );

  // (선택) 직렬화/역직렬화 시에도 id를 그대로 유지
  factory ExamQuestion.fromJson(Map<String, dynamic> j) => ExamQuestion(
    id: j['id'] as String,
    type: ExamQuestionType.values.byName(j['type'] as String),
    prompt: j['prompt'] as String,
    choices: (j['choices'] as List?)?.cast<String>(),
    correctIndex: j['correctIndex'] as int?,
    answers: (j['answers'] as List?)?.cast<String>(),
    ordering: (j['ordering'] as List?)?.cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'prompt': prompt,
    'choices': choices,
    'correctIndex': correctIndex,
    'answers': answers,
    'ordering': ordering,
  };
}


class ExamEditResult {
  final List<ExamQuestion> questions;
  final int passScore; // 0~100
  const ExamEditResult({required this.questions, required this.passScore});
}