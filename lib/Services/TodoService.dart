// lib/Pages/Manager/services/TodoService.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class TodoService {
  TodoService._();
  static final TodoService instance = TodoService._();

  SupabaseClient get _sb => Supabase.instance.client;

  /// 관리자 전용 멘토 선택 목록
  /// 서버에서 p_login_key로 관리자 여부 검증
  /// 반환 컬럼: id (uuid), nickname->name (string), joined_at (iso string), photo_url (string)
  Future<List<Map<String, String>>> listMentorsForSelect({
    required String adminLoginKey,
  }) async {
    final res = await _sb.rpc('list_mentors_for_select', params: {
      'p_login_key': adminLoginKey,
    });

    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map<Map<String, String>>((m) {
      return {
        'id': (m['id'] ?? '').toString(),
        'name': (m['nickname'] ?? '').toString(),
        'joined_at': (m['joined_at'] ?? '').toString(),
        'photo_url': (m['photo_url'] ?? '').toString(),
      };
    }).toList(growable: false);
  }

  /// 멘티 선택 목록 (공용 RPC)
  /// list_mentees → { id, nickname, mentor, mentor_name, photo_url }
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

  /// TODO 배치/단일 생성 (rpc_create_todo_groups)
  /// items: [{title, description?, audience('all'|'mentor'|'mentee'), assignee_ids: uuid[]}, ...]
  /// returns: [{group_id,title,inserted_count}, ...]
  Future<List<Map<String, dynamic>>> createTodoGroups({
    required String loginKey,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _sb.rpc('rpc_create_todo_groups', params: {
      'p_login_key': loginKey,
      'p_items': items,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// TODO 그룹 목록 (본인이 생성한 그룹만 반환)
  /// filter: 'active' | 'completed' | 'inactive' | 'all'
  /// returns: [{group_id,title,audience,is_archived,created_by,created_at,updated_at,total_count,done_count,ack_count}, ...]
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

  /// 상세 요약 1row (rpc_get_todo_group_summary)
  /// returns: {group_id,title,audience,is_archived,created_by,created_at,updated_at,total_count,done_count,ack_count,done_rate,ack_rate,description}
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
  /// returns: [{user_id,nickname,is_mentor,ack_at,done_at}, ...]
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
  /// returns: {group_id,is_archived,updated_at}
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

  /// 삭제 (rpc_delete_todo_group) – FK CASCADE로 관련 배정/이벤트 제거
  /// returns: {group_id, deleted} 이지만 여기선 사용처가 void
  Future<void> deleteTodoGroup({
    required String loginKey,
    required String groupId,
  }) async {
    await _sb.rpc('rpc_delete_todo_group', params: {
      'p_login_key': loginKey,
      'p_group_id': groupId,
    });
  }

  /// 읽지 않은 활성 TODO (모달용) (rpc_list_my_unread_active_todos)
  /// returns: [{group_id,title,description,audience,created_by_role,created_at,ack_at,done_at}, ...]
  Future<List<Map<String, dynamic>>> listMyUnreadActiveTodos({
    required String loginKey,
  }) async {
    final res = await _sb.rpc('rpc_list_my_unread_active_todos', params: {
      'p_login_key': loginKey,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 내 TODO 목록 (페이지용) (rpc_list_my_todos)
  /// filter: 'active'|'not_done'|'done'|'all'
  /// returns: [{group_id,title,description,audience,is_archived,created_by_role,created_at,updated_at,ack_at,done_at}, ...]
  Future<List<Map<String, dynamic>>> listMyTodos({
    required String loginKey,
    String filter = 'active',
  }) async {
    final res = await _sb.rpc('rpc_list_my_todos', params: {
      'p_login_key': loginKey,
      'p_filter': filter,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 확인(ACK) (rpc_acknowledge_todo)
  /// returns: {group_id,user_id,ack_at}
  Future<Map<String, dynamic>> acknowledgeTodo({
    required String loginKey,
    required String groupId,
  }) async {
    final res = await _sb.rpc('rpc_acknowledge_todo', params: {
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

  /// 완료/해제 (rpc_set_my_todo_done)
  /// returns: {group_id,user_id,done_at}
  Future<Map<String, dynamic>> setMyTodoDone({
    required String loginKey,
    required String groupId,
    required bool done,
  }) async {
    final res = await _sb.rpc('rpc_set_my_todo_done', params: {
      'p_login_key': loginKey,
      'p_group_id': groupId,
      'p_done': done,
    });
    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    } else if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return <String, dynamic>{};
  }

  /// 멘토 전용: 멘티들에게 단건 생성 편의 함수
  Future<List<Map<String, dynamic>>> createTodoForMentees({
    required String mentorLoginKey,
    required String title,
    String? description,
    required List<String> menteeIds,
  }) {
    final items = <Map<String, dynamic>>[
      {
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'audience': 'mentee',
        'assignee_ids': menteeIds,
      }
    ];
    return createTodoGroups(loginKey: mentorLoginKey, items: items);
  }
}
