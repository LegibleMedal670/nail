import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env/env.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Providers/CurriculumProvider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseURL,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        // 사용자 상태
        ChangeNotifierProvider(create: (_) => UserProvider()..hydrate()),
        // 커리큘럼: 캐시 즉시 반영 + 서버 재검증(SWR) 백그라운드 수행
        ChangeNotifierProvider(create: (_) => CurriculumProvider()..ensureLoaded()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
