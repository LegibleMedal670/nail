// lib/Pages/Manager/services/ChatService.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  SupabaseClient get _sb => Supabase.instance.client;

  // ============== 방/목록 ==============
  /// 내 방 목록: [{room_id,name,last_at,last_text,unread}, ...]
  Future<List<Map<String, dynamic>>> listRooms({
    required String loginKey,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _sb.rpc('rpc_list_rooms_for_user', params: {
      'p_login_key': loginKey,
      'p_limit': limit,
      'p_offset': offset,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 방 생성(관리자 전용). memberIds는 선택(없어도 됨).
  Future<String> createRoom({
    required String adminLoginKey,
    required String name,
    List<String> memberIds = const [],
  }) async {
    final res = await _sb.rpc('rpc_create_room', params: {
      'p_login_key': adminLoginKey,
      'p_name': name,
      'p_member_ids': memberIds,
    });
    return (res as String);
  }

  /// 방 삭제(관리자 전용). 소프트 삭제 처리.
  Future<bool> deleteRoom({
    required String adminLoginKey,
    required String roomId,
  }) async {
    final res = await _sb.rpc('rpc_delete_room', params: {
      'p_login_key': adminLoginKey,
      'p_room_id': roomId,
    });
    if (res is bool) return res;
    if (res is num) return res != 0;
    return true;
  }

  /// 멤버 초대(방 관리자 전용). 새로 추가된 수 반환.
  Future<int> inviteMembers({
    required String adminLoginKey,
    required String roomId,
    required List<String> memberIds,
  }) async {
    final res = await _sb.rpc('rpc_invite_members', params: {
      'p_login_key': adminLoginKey,
      'p_room_id': roomId,
      'p_member_ids': memberIds,
    });
    return (res as int);
  }

  /// 멤버 추방(방 관리자 전용). 성공 여부 반환.
  Future<bool> kickMember({
    required String adminLoginKey,
    required String roomId,
    required String memberId,
  }) async {
    final res = await _sb.rpc('rpc_kick_member', params: {
      'p_login_key': adminLoginKey,
      'p_room_id': roomId,
      'p_member_id': memberId,
    });
    if (res is bool) return res;
    if (res is num) return res != 0;
    return false;
  }

  // ============== 메시지 ==============
  /// 페이징: rpc_fetch_messages (서버에서 read_count/작성자 정보까지 계산해 내려옴)
  /// 반환은 최신부터 역순으로 내려오지만 화면에선 정렬해 쓰는 걸 권장.
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String loginKey,
    required String roomId,
    int? afterId,
    int? beforeId,
    int limit = 50,
  }) async {
    final res = await _sb.rpc('rpc_fetch_messages', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
      'p_after_id': afterId,
      'p_before_id': beforeId,
      'p_limit': limit,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 텍스트 전송 → message_id
  Future<int> sendText({
    required String loginKey,
    required String roomId,
    required String text,
    Map<String, dynamic>? meta,
  }) async {
    final res = await _sb.rpc('rpc_send_text', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
      'p_text': text,
      'p_meta': meta ?? <String, dynamic>{
        'client_ts': DateTime.now().toIso8601String(),
        'kind': 'text',
      },
    });
    return (res as num).toInt();
  }

  /// 파일/이미지 전송(스토리지 업로드 후) → message_id
  /// kind: 'file' | 'image'
  Future<int> sendFile({
    required String loginKey,
    required String roomId,
    required String fileName,
    required int sizeBytes,
    required String mime,
    required String storagePath,
    String kind = 'file',
    Map<String, dynamic>? meta,
  }) async {
    final res = await _sb.rpc('rpc_send_file', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
      'p_file_name': fileName,
      'p_size_bytes': sizeBytes,
      'p_mime': mime,
      'p_storage_path': storagePath,
      'p_kind': kind,
      'p_meta': meta ?? <String, dynamic>{},
    });
    return (res as num).toInt();
  }

  /// 삭제(관리자만) – soft delete
  Future<void> deleteMessage({
    required String adminLoginKey,
    required int messageId,
  }) async {
    await _sb.rpc('rpc_delete_message', params: {
      'p_login_key': adminLoginKey,
      'p_message_id': messageId,
    });
  }

  /// 읽음 커서(방 단위)
  Future<void> markRead({
    required String loginKey,
    required String roomId,
  }) async {
    await _sb.rpc('rpc_mark_read', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
    });
  }

  // ============== 공지(핀) ==============
  Future<void> pinNotice({
    required String adminLoginKey,
    required String roomId,
    required int messageId,
  }) async {
    await _sb.rpc('rpc_pin_notice', params: {
      'p_login_key': adminLoginKey,
      'p_room_id': roomId,
      'p_message_id': messageId,
    });
  }

  Future<void> unpinNotice({
    required String adminLoginKey,
    required String roomId,
  }) async {
    await _sb.rpc('rpc_unpin_notice', params: {
      'p_login_key': adminLoginKey,
      'p_room_id': roomId,
    });
  }

  /// 현재 공지 1건: {message_id,title,body,created_at,author_id} or {}
  Future<Map<String, dynamic>> getNotice({
    required String loginKey,
    required String roomId,
  }) async {
    final res = await _sb.rpc('rpc_get_notice', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
    });
    if (res == null) return <String, dynamic>{};
    if (res is List && res.isNotEmpty) return Map<String, dynamic>.from(res.first as Map);
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{};
  }

  /// 과거 공지 목록 (is_notice=true) → chat_messages rows
  Future<List<Map<String, dynamic>>> listNotices({
    required String loginKey,
    required String roomId,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _sb.rpc('rpc_list_notices', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
      'p_limit': limit,
      'p_offset': offset,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  // ============== 멤버/미디어/검색 ==============
  /// 방 멤버 상세 (역할/라스트리드 포함)
  Future<List<Map<String, dynamic>>> listRoomMembers({
    required String loginKey,
    required String roomId,
  }) async {
    final res = await _sb.rpc('rpc_list_room_members', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 방 비구성원(초대 가능 후보) 목록
  Future<List<Map<String, dynamic>>> listRoomNonMembers({
    required String adminLoginKey,
    required String roomId,
    int limit = 200,
    int offset = 0,
  }) async {
    final res = await _sb.rpc('rpc_list_room_non_members', params: {
      'p_login_key': adminLoginKey,
      'p_room_id': roomId,
      'p_limit': limit,
      'p_offset': offset,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  /// 갤러리/파일 탭
  /// returns: [{message_id,storage_path,mime,created_at,sender_id}, ...]
  Future<List<Map<String, dynamic>>> listMedia({
    required String loginKey,
    required String roomId,
    List<String> kinds = const ['image', 'file'],
    int limit = 60,
    int offset = 0,
  }) async {
    final res = await _sb.rpc('rpc_list_media', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
      'p_kind': kinds,
      'p_limit': limit,
      'p_offset': offset,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchMessages({
    required String loginKey,
    required String roomId,
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _sb.rpc('rpc_search_messages', params: {
      'p_login_key': loginKey,
      'p_room_id': roomId,
      'p_q': query,
      'p_limit': limit,
      'p_offset': offset,
    });
    final rows = (res is List) ? res : [res];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  // ============== Realtime ==============
  /// 목록 화면 전체 갱신용(내가 볼 수 있는 모든 방의 변화 수신)
  /// 필터 없이 테이블 단위로 구독하면 RLS로 걸러져 내가 볼 수 있는 것만 온다.
  RealtimeChannel subscribeListRefresh({
    void Function()? onChanged,
  }) {
    final ch = _sb.channel('chat_list_refresh');

    // 새 메시지 / 삭제 토글
    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      callback: (_) => onChanged?.call(),
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'chat_messages',
      callback: (_) => onChanged?.call(),
    );

    // 공지 핀 변경
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'chat_rooms',
      callback: (_) => onChanged?.call(),
    );

    ch.subscribe();
    return ch;
  }

  /// 방 내부용: 특정 roomId에 대한 메시지/핀/읽음변경 구독
  /// onMemberUpdate는 chat_room_members(last_read_at 등) 업데이트에 반응.
  RealtimeChannel subscribeRoomChanges({
    required String roomId,
    void Function(PostgresChangePayload payload)? onInsert,
    void Function(PostgresChangePayload payload)? onUpdate,
    void Function(PostgresChangePayload payload)? onPinUpdate,
    void Function(PostgresChangePayload payload)? onMemberUpdate,
  }) {
    final ch = _sb.channel('room_changes_$roomId');

    if (onInsert != null) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: onInsert,
      );
    }

    if (onUpdate != null) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: onUpdate,
      );
    }

    if (onPinUpdate != null) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chat_rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: roomId,
        ),
        callback: onPinUpdate,
      );
    }

    if (onMemberUpdate != null) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chat_room_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: onMemberUpdate,
      );
    }

    ch.subscribe();
    return ch;
  }
}
