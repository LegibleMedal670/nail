// lib/Services/UserService.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// 사용자 관련 서비스 (회원 탈퇴 등)
class UserService {
  UserService._();
  static final instance = UserService._();

  final _supabase = Supabase.instance.client;

  /// 회원 탈퇴 (Soft Delete)
  /// 
  /// - 채팅방에서 자동으로 나가집니다.
  /// - 서명 정보 등 법적 보관이 필요한 데이터는 유지됩니다.
  /// - 학습 이력 및 활동 기록은 보존됩니다.
  /// 
  /// [userId]: 탈퇴할 사용자의 UUID
  /// [reason]: 탈퇴 사유 (선택)
  /// 
  /// Returns: 탈퇴 처리 결과 정보
  /// - success: 성공 여부
  /// - role: 사용자 역할
  /// - affectedMentees: 영향받은 후임 수 (선임인 경우)
  /// - removedChatRooms: 나간 채팅방 수
  Future<Map<String, dynamic>> withdrawUser({
    required String userId,
    String? reason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'rpc_withdraw_user',
        params: {
          'p_user_id': userId,
          'p_reason': reason,
        },
      );

      if (response == null) {
        throw Exception('회원 탈퇴 처리 실패: 응답이 없습니다.');
      }

      // JSONB 응답 파싱
      final result = response as Map<String, dynamic>;
      
      if (result['success'] != true) {
        throw Exception('회원 탈퇴 처리 실패');
      }

      return {
        'success': true,
        'role': result['role'] as String?,
        'affectedMentees': result['affected_mentees'] as int? ?? 0,
        'removedChatRooms': result['removed_chat_rooms'] as int? ?? 0,
      };
    } on PostgrestException catch (e) {
      throw Exception('회원 탈퇴 처리 중 오류가 발생했습니다: ${e.message}');
    } catch (e) {
      throw Exception('회원 탈퇴 처리 중 오류가 발생했습니다: $e');
    }
  }
}

