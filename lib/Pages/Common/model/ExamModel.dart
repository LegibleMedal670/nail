// lib/Pages/Common/model/ExamModel.dart

/// 문제 유형
enum ExamQuestionType { mcq, shortAnswer, ordering }

/// 시험 문항 모델
class ExamQuestion {
  final String id;                 // 고정 ID (서버 jsonb에도 저장)
  ExamQuestionType type;           // 문제 유형
  String prompt;                   // 문제 텍스트

  // 객관식
  List<String>? choices;           // 보기 목록
  int? correctIndex;               // 정답 인덱스(0-base)

  // 주관식
  List<String>? answers;           // 허용 답안들 (소문자/트림 비교는 화면단에서 처리)

  // 순서 맞추기
  List<String>? ordering;          // 정답 순서

  ExamQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.choices,
    this.correctIndex,
    this.answers,
    this.ordering,
  });

  /// 내부: 새 id 생성기
  static String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  // -------------------------
  // 팩토리(신규 생성; 외부에서 id 주입 가능)
  // -------------------------
  factory ExamQuestion.mcq({
    String? id,
    required String prompt,
    List<String>? choices,
    int? correctIndex,
  }) =>
      ExamQuestion(
        id: id ?? _genId(),
        type: ExamQuestionType.mcq,
        prompt: prompt,
        choices: (choices == null || choices.isEmpty)
            ? ['보기 1', '보기 2', '보기 3', '보기 4']
            : List<String>.from(choices),
        correctIndex: correctIndex ?? 0,
      );

  factory ExamQuestion.short({
    String? id,
    required String prompt,
    List<String>? answers,
  }) =>
      ExamQuestion(
        id: id ?? _genId(),
        type: ExamQuestionType.shortAnswer,
        prompt: prompt,
        answers: (answers == null || answers.isEmpty)
            ? ['예시 답안']
            : List<String>.from(answers),
      );

  factory ExamQuestion.ordering({
    String? id,
    required String prompt,
    List<String>? ordering,
  }) =>
      ExamQuestion(
        id: id ?? _genId(),
        type: ExamQuestionType.ordering,
        prompt: prompt,
        ordering: (ordering == null || ordering.isEmpty)
            ? ['항목 A', '항목 B', '항목 C']
            : List<String>.from(ordering),
      );

  /// 깊은 복제 (같은 id 유지)
  ExamQuestion clone() => ExamQuestion(
    id: id,
    type: type,
    prompt: prompt,
    choices: choices == null ? null : List<String>.from(choices!),
    correctIndex: correctIndex,
    answers: answers == null ? null : List<String>.from(answers!),
    ordering: ordering == null ? null : List<String>.from(ordering!),
  );

  // -------------------------
  // 직렬화 / 역직렬화
  // -------------------------

  /// 서버 jsonb -> 모델 (키 유연 처리: snake_case/camelCase 혼용 허용)
  factory ExamQuestion.fromJson(Map<String, dynamic> j) {
    ExamQuestionType _parseType(dynamic t) {
      if (t is String) {
        // byName과 대소문자/스네이크 변형 모두 수용
        final s = t.trim();
        for (final v in ExamQuestionType.values) {
          if (v.name == s ||
              v.name.toLowerCase() == s.toLowerCase() ||
              s.toLowerCase().replaceAll('_', '') ==
                  v.name.toLowerCase().replaceAll('_', '')) {
            return v;
          }
        }
      } else if (t is int) {
        if (t >= 0 && t < ExamQuestionType.values.length) {
          return ExamQuestionType.values[t];
        }
      }
      return ExamQuestionType.mcq;
    }

    List<String>? _toStrList(dynamic x) {
      if (x == null) return null;
      if (x is List) return x.map((e) => e.toString()).toList();
      return null;
    }

    int? _toInt(dynamic x) {
      if (x == null) return null;
      if (x is int) return x;
      if (x is num) return x.toInt();
      if (x is String) {
        final v = int.tryParse(x);
        return v;
      }
      return null;
    }

    // 유연 키 매핑
    String id = (j['id'] ?? j['question_id'] ?? _genId()).toString();
    final type = _parseType(j['type'] ?? j['question_type'] ?? 'mcq');
    final prompt = (j['prompt'] ?? j['question'] ?? '').toString();

    final choices =
    _toStrList(j['choices'] ?? j['options'] ?? j['mcq_choices']);
    final correctIndex = _toInt(j['correctIndex'] ?? j['correct_index']);
    final answers = _toStrList(j['answers'] ?? j['accepted_answers']);
    final ordering = _toStrList(j['ordering'] ?? j['order']);

    return ExamQuestion(
      id: id,
      type: type,
      prompt: prompt,
      choices: choices,
      correctIndex: correctIndex,
      answers: answers,
      ordering: ordering,
    );
  }

  /// 모델 -> 서버 jsonb (camelCase 고정; 서버는 그대로 보관 후 재반환)
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name, // e.g. "mcq" | "shortAnswer" | "ordering"
    'prompt': prompt,
    'choices': choices,
    'correctIndex': correctIndex,
    'answers': answers,
    'ordering': ordering,
  };

  /// 가벼운 유효성 점검(편집기에서 저장 전 체크용)
  bool get isValid {
    switch (type) {
      case ExamQuestionType.mcq:
        return (choices?.length ?? 0) >= 2 &&
            correctIndex != null &&
            correctIndex! >= 0 &&
            correctIndex! < (choices?.length ?? 0) &&
            prompt.trim().isNotEmpty;
      case ExamQuestionType.shortAnswer:
        return (answers?.isNotEmpty ?? false) && prompt.trim().isNotEmpty;
      case ExamQuestionType.ordering:
        return (ordering?.length ?? 0) >= 2 && prompt.trim().isNotEmpty;
    }
  }

  /// copyWith(필요 시 화면단에서 사용)
  ExamQuestion copyWith({
    ExamQuestionType? type,
    String? prompt,
    List<String>? choices,
    int? correctIndex,
    List<String>? answers,
    List<String>? ordering,
  }) {
    return ExamQuestion(
      id: id,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      choices: choices ?? (this.choices == null ? null : List<String>.from(this.choices!)),
      correctIndex: correctIndex ?? this.correctIndex,
      answers: answers ?? (this.answers == null ? null : List<String>.from(this.answers!)),
      ordering: ordering ?? (this.ordering == null ? null : List<String>.from(this.ordering!)),
    );
  }
}

/// 편집 결과(편집 페이지 -> 호출자)
class ExamEditResult {
  final List<ExamQuestion> questions;
  final int passScore; // 0~100
  const ExamEditResult({required this.questions, required this.passScore});
}
