

import 'package:flutter/material.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // if (Platform.isIOS) {
  //   final status = await AppTrackingTransparency
  //       .requestTrackingAuthorization();
  // }

  await Supabase.initialize(
    url: Env.supabaseURL,
    anonKey: Env.supabaseAnonKey,
  );

  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );


  /// Supabase 초기화 후 현재 로그인 상태 확인
  // final currentUser = Supabase.instance.client.auth.currentUser;
  // final userDataProvider = UserDataProvider();
  // final bookmarkProvider = BookmarkProvider();

  // if (currentUser != null) {
  //   // 로그인 상태이면 UID, email, provider를 provider에 설정
  //   userDataProvider.login(currentUser.id, currentUser.email!, currentUser.appMetadata['provider']!);
  //   bookmarkProvider.updateLoginStatus(true, currentUser.id);
  // }

  // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // FlutterError.onError = (errorDetails) {
  //   FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  // };
  // // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  //   return true;
  // };

  runApp(MyApp());
}

class MyApp extends StatefulWidget {

  /// main에서 초기화한 프로바이더를 그대로 이용하기 위해
  // final UserDataProvider userDataProvider;
  //
  // final BookmarkProvider bookmarkProvider;

  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  // final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorObservers: [
          // FirebaseAnalyticsObserver(analytics: analytics),
        ],
        debugShowCheckedModeBanner: false,
        title: 'EDU',
        theme: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          primaryColor: Colors.black,
          bottomSheetTheme: BottomSheetThemeData(
              dragHandleColor: Colors.grey[400],
              dragHandleSize: const Size(50, 5)),
          useMaterial3: false,
          fontFamily: "Pretendard",
        ),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: child!),
        home: const SplashScreen(),
      );
  }
}
