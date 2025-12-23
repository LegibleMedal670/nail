import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Manager/page/ManagerMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteeHomeScaffold.dart';
import 'package:nail/Pages/Mentor/page/MentorHomeScaffold.dart';
import 'package:nail/Pages/Welcome/PendingRolePage.dart';
import 'package:nail/Pages/Welcome/PhoneLoginPage.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Services/FirebaseAuthService.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _firebaseAuth = FirebaseAuthService();
  bool _navigated = false;

  // 스플래시 최소 노출 시간
  final Duration _minSplashDuration = const Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final startTime = DateTime.now();

    try {
      // 1. UserProvider hydrate (Firebase 세션 확인 + Supabase 프로필 복원)
      final userProvider = context.read<UserProvider>();
      await userProvider.hydrate();

      // 최소 스플래시 시간 보장
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < _minSplashDuration) {
        await Future.delayed(_minSplashDuration - elapsed);
      }

      if (!mounted || _navigated) return;
      _navigated = true;

      // 2. 라우팅 결정
      _route(userProvider);
    } catch (e) {
      debugPrint('[SplashScreen] init error: $e');
      if (mounted && !_navigated) {
        _navigated = true;
        _navigateTo(const PhoneLoginPage());
      }
    }
  }

  void _route(UserProvider userProvider) {
    // Firebase 로그인 안됨 → 로그인 페이지
    if (_firebaseAuth.currentUid == null) {
      _navigateTo(const PhoneLoginPage());
      return;
    }

    // Supabase 프로필 없음 → 로그인 페이지 (재연동 필요)
    if (!userProvider.isLoggedIn) {
      _navigateTo(const PhoneLoginPage());
      return;
    }

    // 역할에 따라 분기
    final role = userProvider.role;
    switch (role) {
      case 'admin':
        _navigateTo(const ManagerMainPage());
        break;
      case 'mentor':
        _navigateTo(const MentorHomeScaffold());
        break;
      case 'mentee':
        _navigateTo(const MenteeHomeScaffold());
        break;
      case 'pending':
      default:
        _navigateTo(const PendingRolePage());
        break;
    }
  }

  void _navigateTo(Widget destination) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => destination,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          child: Image.asset('images/logo.png'),
        ),
      ),
    );
  }
}
