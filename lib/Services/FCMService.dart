import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM (Firebase Cloud Messaging) 서비스
/// - 푸시 알림 토큰 관리
/// - 포그라운드/백그라운드 알림 수신
class FCMService {
  FCMService._();
  static final instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _sb = Supabase.instance.client;

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// FCM 초기화
  /// - 권한 요청
  /// - 토큰 가져오기
  /// - 토큰 갱신 리스너 등록
  Future<void> initialize({required String firebaseUid}) async {
    try {
      // 1. 권한 요청
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('[FCM] Notification permission denied');
        return;
      }

      debugPrint('[FCM] Notification permission granted');

      // 2. FCM 토큰 가져오기
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        debugPrint('[FCM] Token: ${_currentToken!.substring(0, 20)}...');
        await _updateTokenInServer(firebaseUid, _currentToken!);
      }

      // 3. 토큰 갱신 리스너
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed');
        _currentToken = newToken;
        _updateTokenInServer(firebaseUid, newToken);
      });

      // 4. 포그라운드 알림 처리
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. 백그라운드 알림 클릭 처리
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 6. 앱이 종료된 상태에서 알림으로 열린 경우
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('[FCM] Initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Initialization failed: $e');
    }
  }

  /// 서버에 FCM 토큰 업데이트
  Future<void> _updateTokenInServer(String firebaseUid, String token) async {
    try {
      await _sb.rpc('update_fcm_token', params: {
        'p_firebase_uid': firebaseUid,
        'p_fcm_token': token,
      });
      debugPrint('[FCM] Token updated in server');
    } catch (e) {
      debugPrint('[FCM] Failed to update token: $e');
    }
  }

  /// 로그아웃 시 FCM 토큰 삭제
  Future<void> removeToken({required String firebaseUid}) async {
    try {
      await _messaging.deleteToken();
      await _sb.rpc('remove_fcm_token', params: {
        'p_firebase_uid': firebaseUid,
      });
      _currentToken = null;
      debugPrint('[FCM] Token removed');
    } catch (e) {
      debugPrint('[FCM] Failed to remove token: $e');
    }
  }

  /// 포그라운드 알림 처리 (앱이 열려있을 때)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message received');
    debugPrint('[FCM] Title: ${message.notification?.title}');
    debugPrint('[FCM] Body: ${message.notification?.body}');
    debugPrint('[FCM] Data: ${message.data}');

    // TODO: 인앱 알림 표시 또는 상태 업데이트
    // 예: 채팅방 목록 새로고침, 배지 카운트 업데이트 등
  }

  /// 알림 클릭 처리 (백그라운드 또는 종료 상태에서)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped');
    debugPrint('[FCM] Data: ${message.data}');

    // TODO: 알림 타입에 따라 적절한 페이지로 이동
    // 예: 
    // - type: 'chat' → ChatRoomPage
    // - type: 'practice' → AttemptReviewPage
    // - type: 'journal' → JournalDetailPage
    // - type: 'todo' → TodoDetailPage
    final type = message.data['type'] as String?;
    final targetId = message.data['targetId'] as String?;
    
    if (type != null && targetId != null) {
      _navigateToPage(type, targetId);
    }
  }

  /// 알림 타입에 따라 페이지 이동
  void _navigateToPage(String type, String targetId) {
    debugPrint('[FCM] Navigate to: $type -> $targetId');
    
    // TODO: GlobalKey<NavigatorState>를 사용한 네비게이션 구현
    // 
    // 알림 타입별 페이지:
    // - chat: ChatRoomPage(roomId: targetId)
    // - practice_submitted: AttemptReviewPage(attemptId: targetId)
    // - practice_reviewed: 실습 상세 페이지
    // - journal_submitted: MentorJournalDetail(journalId: targetId)
    // - journal_replied: MenteeJournalPage()
    // - completion_pending: CompletionApprovalPage(menteeId: targetId)
    // - new_user: PendingUsersPage()
    // - role_approved: 홈 화면
    // - todo_assigned: TodoDetailPage(groupId: targetId)
    //
    // 구현 예시:
    // final context = navigatorKey.currentContext;
    // if (context != null) {
    //   switch (type) {
    //     case 'chat':
    //       Navigator.push(context, MaterialPageRoute(
    //         builder: (_) => ChatRoomPage(roomId: targetId)
    //       ));
    //       break;
    //     // ... 나머지 케이스
    //   }
    // }
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received');
  debugPrint('[FCM] Title: ${message.notification?.title}');
  debugPrint('[FCM] Body: ${message.notification?.body}');
  debugPrint('[FCM] Data: ${message.data}');
  
  // 백그라운드에서는 UI 업데이트 불가
  // 필요시 로컬 DB 업데이트 또는 로그 저장
}

