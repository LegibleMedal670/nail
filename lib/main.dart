import 'package:flutter/material.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env/env.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseURL,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider()..hydrate(),
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
