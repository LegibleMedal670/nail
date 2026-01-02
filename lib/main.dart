import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nail/Providers/AdminProgressProvider.dart';
import 'package:nail/Providers/PracticeProvider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'env/env.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Providers/CurriculumProvider.dart';
import 'package:nail/Services/FCMService.dart';

/// FCM 백그라운드 메시지 핸들러
/// 앱이 백그라운드 또는 종료 상태일 때 알림을 수신하면 호출됨
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화 (백그라운드 컨텍스트)
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // FCM 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: Env.supabaseURL,
    anonKey: Env.supabaseAnonKey,
    // 안전하게 명시(기본값도 true지만 확실히 해둠)
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUri: true,
      autoRefreshToken: true,
    ),
  );

  await initializeDateFormatting('ko');
  await initializeDateFormatting('ko_KR');


  // ✅ 세션이 없을 때만 익명 로그인 (핵심 수정)
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    try {
      await auth.signInAnonymously();
    } catch (e) {
      debugPrint('anonymous sign-in failed: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..hydrate()),
        ChangeNotifierProvider(create: (_) => CurriculumProvider()),
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
        ChangeNotifierProvider(create: (_) => AdminProgressProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// GlobalKey for navigation from FCM notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 앱 라이프사이클 관찰자 등록
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 앱이 포그라운드로 돌아올 때마다 배지 초기화
    if (state == AppLifecycleState.resumed) {
      FCMService.instance.clearBadge();
      debugPrint('[App] Resumed - Badge cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EDU',
      theme: ThemeData(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        primaryColor: Colors.black,
        bottomSheetTheme: BottomSheetThemeData(
          dragHandleColor: Colors.grey[400],
          dragHandleSize: const Size(50, 5),
        ),
        useMaterial3: false,
        fontFamily: "Pretendard",
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}
