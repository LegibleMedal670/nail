import 'package:flutter/material.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Providers/UserProvider.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Welcome/SelectRolePage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  UserProvider? _user;         // dispose에서 context 안 쓰려고 참조 저장
  bool _navigated = false;

  // ✅ 스플래시 최소 노출 시간 설정
  final Duration _minSplashDuration = const Duration(milliseconds: 1000);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 현재 트리에서 UserProvider를 한 번만 잡고 리스너 연결
    final next = context.read<UserProvider>();
    if (_user != next) {
      // 기존 리스너 정리
      _user?.removeListener(_onUserChanged);
      _user = next;
      _user!.addListener(_onUserChanged);

      // 이미 로딩이 끝난 상태라면 바로 라우팅 시도
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


    final goMenteeHome = _user!.isLoggedIn && !_user!.isAdmin;
    // final Widget dest = goMenteeHome ? const MenteeMainPage() : const SelectRolePage();

    goMenteeHome ? print('스플래시스크린:자동로그인') : print('자동로그인안댐');

    Navigator.pushReplacement(context, _buildPageRoute(SelectRolePage()));
  }

  /// 부드러운 전환을 위한 페이지 전환 애니메이션(없도록 설정)
  PageRouteBuilder _buildPageRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => screen,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  void dispose() {
    // ✅ context.read(...) 금지. 저장된 참조로 해제
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
