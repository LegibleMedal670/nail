// lib/Pages/Manager/services/TodoService.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class TodoService {
  TodoService._();
  static final TodoService instance = TodoService._();

  SupabaseClient get _sb => Supabase.instance.client;

  /// 관리자 전용 멘토 선택 목록
  /// - 서버에서 p_login_key로 관리자 여부 검증
  /// - 반환 컬럼: id, nickname, joined_at, photo_url
  Future<List<Map<String, String>>> listMentorsForSelect({
    required String adminLoginKey, // 현재 로그인(관리자) 사용자의 login_key
  }) async {
    final res = await _sb.rpc('list_mentors_for_select', params: {
      'p_login_key': adminLoginKey,
    });

    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map<Map<String, String>>((m) {
      return {
        'id': (m['id'] ?? '').toString(),
        'name': (m['nickname'] ?? '').toString(),
        'photo_url': (m['photo_url'] ?? '').toString(),
      };
    }).toList(growable: false);
  }

  /// 멘티 선택 목록 (공용 RPC)
  /// - list_mentees: id, nickname, mentor, mentor_name, photo_url ...
  Future<List<Map<String, String>>> listMenteesForSelect() async {
    final res = await _sb.rpc('list_mentees');
    final rows = (res is List) ? res : [res];

    return rows.whereType<Map>().map<Map<String, String>>((m) {
      return {
        'id': (m['id'] ?? '').toString(),
        'name': (m['nickname'] ?? '').toString(),
        'mentor_id': (m['mentor'] ?? '').toString(),
        'mentor_name': (m['mentor_name'] ?? '').toString(),
        'photo_url': (m['photo_url'] ?? '').toString(),
      };
    }).toList(growable: false);
  }

  /// TODO 배치/단일 생성
  Future<List<Map<String, dynamic>>> createTodoGroups({
    required String loginKey, // 현재 로그인 사용자의 login_key (관리자/멘토/멘티 모두 가능: 서버에서 권한 판단)
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _sb.rpc('rpc_create_todo_groups', params: {
      'p_login_key': loginKey,
      'p_items': items,
    });

    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }
}
