import 'package:flutter/foundation.dart';
import 'package:nail/Pages/Manager/models/Mentee.dart';

@immutable
class MenteeEditResult {
  final Mentee? mentee;
  final bool deleted;
  const MenteeEditResult({this.mentee, this.deleted = false});
}
