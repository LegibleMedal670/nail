import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:nail/main.dart' show navigatorKey;
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Pages/Chat/page/ChatRoomPage.dart';
import 'package:nail/Pages/Manager/page/PendingUsersPage.dart';
import 'package:nail/Pages/Manager/page/ManagerMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteeHomeScaffold.dart';
import 'package:nail/Pages/Mentor/page/MentorHomeScaffold.dart';

/// FCM (Firebase Cloud Messaging) 서비스
/// - 푸시 알림 토큰 관리
/// - 포그라운드/백그라운드 알림 수신
/// - 앱 아이콘 배지 관리
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
  /// - 앱 배지 초기화
  Future<void> initialize({required String firebaseUid}) async {
    try {
      // 0. 앱 배지 초기화 (앱 열릴 때마다 0으로)
      await clearBadge();

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
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        clearBadge(); // 알림 클릭 시 배지 제거
        _handleNotificationTap(message);
      });

      // 6. 앱이 종료된 상태에서 알림으로 열린 경우
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        clearBadge(); // 알림으로 앱 시작 시 배지 제거
        _handleNotificationTap(initialMessage);
      }

      debugPrint('[FCM] Initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Initialization failed: $e');
    }
  }

  /// 앱 아이콘 배지 제거
  Future<void> clearBadge() async {
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (supported) {
        await FlutterAppBadger.removeBadge();
        debugPrint('[FCM] Badge cleared');
      }
    } catch (e) {
      debugPrint('[FCM] Failed to clear badge: $e');
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

    final type = message.data['type'] as String?;
    final targetId = message.data['targetId'] as String?;
    
    if (type != null && targetId != null) {
      _navigateToPage(type, targetId, message.data);
    }
  }

  /// 알림 타입에 따라 페이지 이동
  void _navigateToPage(String type, String targetId, Map<String, dynamic> allData) {
    debugPrint('[FCM] Navigate to: $type -> $targetId');
    
    // GlobalKey로 context 가져오기
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[FCM] Navigator context is null, cannot navigate');
      return;
    }

    // UserProvider로 로그인 확인 및 역할 확인
    final userProvider = context.read<UserProvider>();
    if (!userProvider.isLoggedIn) {
      debugPrint('[FCM] User not logged in, ignoring navigation');
      return;
    }

    final role = userProvider.role;
    debugPrint('[FCM] User role: $role');

    try {
      switch (type) {
        // ===== 채팅: 채팅 목록 탭 → 채팅방 (2단계 네비게이션) =====
        
        case 'chat':
          final roomName = allData['roomName'] as String? ?? '채팅';
          
          // 1단계: 역할별 채팅 목록 탭으로 이동
          Widget homeWithChatTab;
          switch (role) {
            case 'admin':
              homeWithChatTab = const ManagerMainPage(initialIndex: 3); // 채팅 탭
              break;
            case 'mentor':
              homeWithChatTab = const MentorHomeScaffold(initialIndex: 3); // 채팅 탭
              break;
            case 'mentee':
              homeWithChatTab = const MenteeHomeScaffold(initialIndex: 2); // 채팅 탭
              break;
            default:
              debugPrint('[FCM] Unknown role for chat navigation: $role');
              return;
          }
          
          // 백 스택 초기화하고 채팅 탭으로 이동
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => homeWithChatTab),
            (route) => false,
          );
          
          // 2단계: 잠시 후 채팅방 열기 (채팅 목록이 렌더링된 후)
          Future.delayed(const Duration(milliseconds: 300), () {
            final newContext = navigatorKey.currentContext;
            if (newContext != null) {
              Navigator.push(
                newContext,
                MaterialPageRoute(
                  builder: (_) => ChatRoomPage(
                    roomId: targetId,
                    roomName: roomName,
                  ),
                ),
              );
            }
          });
          break;

        // ===== 별도 페이지 열기 (관리자 전용) =====

        case 'new_user_signup':
        case 'role_approval_request':
          // 관리자 → 가입 대기 페이지
          if (role == 'admin') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PendingUsersPage()),
            );
          }
          break;

        // ===== 탭으로 이동 + 새로고침 (7개) =====

        case 'practice_submitted':
        case 'completion_mentee_signed':
          // 멘토 → 대시보드 탭(4) + 대기 큐 새로고침
          if (role == 'mentor') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const MentorHomeScaffold(initialIndex: 4),
              ),
              (route) => false,
            );
          }
          break;

        case 'practice_reviewed':
          // 멘티 → 학습 탭(3) + 실습으로 전환
          if (role == 'mentee') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const MenteeHomeScaffold(
                  initialIndex: 3,
                  showPractice: true,
                ),
              ),
              (route) => false,
            );
          }
          break;

        case 'journal_submitted':
          // 멘토 → 일일 일지 탭(2)
          if (role == 'mentor') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const MentorHomeScaffold(initialIndex: 2),
              ),
              (route) => false,
            );
          }
          break;

        case 'journal_replied':
          // 멘티 → 일일 일지 탭(1)
          if (role == 'mentee') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const MenteeHomeScaffold(initialIndex: 1),
              ),
              (route) => false,
            );
          }
          break;

        case 'user_approved':
          // 사용자 승인 완료 → 역할별 홈 화면
          switch (role) {
            case 'admin':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ManagerMainPage()),
                (route) => false,
              );
              break;
            case 'mentor':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MentorHomeScaffold()),
                (route) => false,
              );
              break;
            case 'mentee':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MenteeHomeScaffold()),
                (route) => false,
              );
              break;
          }
          break;

        case 'todo_assigned':
          // TODO 배정 → 역할별 투두 탭(0)
          switch (role) {
            case 'admin':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ManagerMainPage(initialIndex: 0)),
                (route) => false,
              );
              break;
            case 'mentor':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MentorHomeScaffold(initialIndex: 0)),
                (route) => false,
              );
              break;
            case 'mentee':
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MenteeHomeScaffold(initialIndex: 0)),
                (route) => false,
              );
              break;
          }
          break;

        default:
          debugPrint('[FCM] Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('[FCM] Navigation error: $e');
    }
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

