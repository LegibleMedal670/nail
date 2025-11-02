// lib/Pages/Manager/model/todo_types.dart
/// TODO 대상 범위(그룹 단위 공지)
enum TodoAudience { all, mentor, mentee }

/// 현황 페이지 필터
enum TodoViewFilter { active, completed, inactive, all }

extension TodoAudienceX on TodoAudience {
  String get dbValue {
    switch (this) {
      case TodoAudience.all: return 'all';
      case TodoAudience.mentor: return 'mentor';
      case TodoAudience.mentee: return 'mentee';
    }
  }
  static TodoAudience fromDb(String v) {
    switch (v) {
      case 'all': return TodoAudience.all;
      case 'mentor': return TodoAudience.mentor;
      case 'mentee': return TodoAudience.mentee;
    }
    // 기본값: 안전하게 mentee
    return TodoAudience.mentee;
  }
}
