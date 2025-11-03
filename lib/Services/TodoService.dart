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

  /// TODO 그룹 목록
  /// filter: 'active' | 'completed' | 'inactive' | 'all'
  Future<List<Map<String, dynamic>>> listTodoGroups({
    required String loginKey,
    required String filter,
  }) async {
    final res = await _sb.rpc('rpc_list_todo_groups', params: {
      'p_login_key': loginKey,
      'p_filter': filter,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 상세: 요약 1row (rpc_get_todo_group_summary)
  Future<Map<String, dynamic>> getTodoGroupSummary({
    required String loginKey,
    required String groupId,
  }) async {
    final res = await _sb.rpc('rpc_get_todo_group_summary', params: {
      'p_login_key': loginKey,
      'p_group_id': groupId,
    });
    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    } else if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return <String, dynamic>{};
  }

  /// 상세: 멤버 리스트 (rpc_get_todo_group_members)
  /// tab: 'done' | 'not_done' | 'not_ack'
  Future<List<Map<String, dynamic>>> getTodoGroupMembers({
    required String loginKey,
    required String groupId,
    required String tab,
  }) async {
    final res = await _sb.rpc('rpc_get_todo_group_members', params: {
      'p_login_key': loginKey,
      'p_group_id': groupId,
      'p_tab': tab,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 보관/해제 (rpc_toggle_group_archive)
  Future<Map<String, dynamic>> toggleGroupArchive({
    required String loginKey,
    required String groupId,
    required bool toArchived,
  }) async {
    final res = await _sb.rpc('rpc_toggle_group_archive', params: {
      'p_login_key': loginKey,
      'p_group_id': groupId,
      'p_to_archived': toArchived,
    });
    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    } else if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return <String, dynamic>{};
  }

  /// 삭제 (rpc_delete_todo_group)
  Future<void> deleteTodoGroup({
    required String loginKey,
    required String groupId,
  }) async {
    await _sb.rpc('rpc_delete_todo_group', params: {
      'p_login_key': loginKey,
      'p_group_id': groupId,
    });
  }
}
