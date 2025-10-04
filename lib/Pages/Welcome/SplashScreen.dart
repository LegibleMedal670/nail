import 'package:flutter/material.dart';
import 'package:nail/Pages/Mentor/page/MentorMainPage.dart';
import 'package:provider/provider.dart';

import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Welcome/SelectRolePage.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:nail/Providers/CurriculumProvider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  UserProvider? _user; // dispose에서 context 안 쓰려고 참조 저장
  bool _navigated = false;

  // 스플래시 최소 노출 시간
  final Duration _minSplashDuration = const Duration(milliseconds: 1000);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 커리큘럼은 SWR 방식: 캐시 즉시 반영, 서버는 백그라운드로 재검증
    // (idempotent 하므로 여러 번 호출돼도 안전)
    // context.read<CurriculumProvider>().ensureLoaded();

    // UserProvider 구독 셋업
    final next = context.read<UserProvider>();
    if (_user != next) {
      _user?.removeListener(_onUserChanged);
      _user = next;
      _user!.addListener(_onUserChanged);

      if (!_user!.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _route());
      }
    }
  }

  void _onUserChanged() {
    if (!mounted || _user == null) return;
    if (!_user!.isLoading) {
      _route();
    }
  }

  Future<void> _route() async {
    if (_navigated || !mounted || _user == null) return;
    _navigated = true;

    await Future.delayed(_minSplashDuration);
    if (!mounted) return;

    final u = _user!;
    Widget dest;

    if (!u.isLoggedIn) {
      dest = const SelectRolePage();
    } else if (u.isAdmin) {
      // 기존 정책대로 관리자 진입점은 SelectRolePage에서 선택하도록 유지
      dest = const SelectRolePage();
    } else if (u.isMentor) {
      // ✅ 멘토 세션이면 멘토 메인으로
      dest = MentorMainPage(
        mentorLoginKey: u.current!.loginKey,
        mentorName: u.nickname,
        mentorPhotoUrl: u.photoUrl,
        mentorHiredAt: u.joinedAt,
      );
    } else {
      // 멘티
      dest = const MenteeMainPage();
    }

    Navigator.pushReplacement(context, _buildPageRoute(dest));
  }


  PageRouteBuilder _buildPageRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => screen,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _user?.removeListener(_onUserChanged);
    super.dispose();
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
