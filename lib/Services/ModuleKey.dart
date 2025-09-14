// lib/Services/ModuleKey.dart
class ModuleKey {
  /// 서버와 완전 일치하도록 모듈키를 정규화한다.
  static String norm(String raw) => raw.trim().toLowerCase();
}
