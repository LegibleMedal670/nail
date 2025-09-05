
enum MenteeSort { latest, name, progress }

class Mentee {
  final String name;
  final String mentor;
  final double progress; // 0.0 ~ 1.0
  final DateTime startedAt;
  final int? courseDone;
  final int? courseTotal;
  final int? examDone;
  final int? examTotal;
  final String? photoUrl;

  const Mentee({
    required this.name,
    required this.mentor,
    required this.progress,
    required this.startedAt,
    this.courseDone,
    this.courseTotal,
    this.examDone,
    this.examTotal,
    this.photoUrl,
  });
}
