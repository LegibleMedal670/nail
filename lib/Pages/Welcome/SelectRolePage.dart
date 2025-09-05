import 'package:flutter/material.dart';
import 'package:nail/Pages/Common/page/CheckPasswordPage.dart';

class SelectRolePage extends StatefulWidget {
  const SelectRolePage({super.key});

  @override
  State<SelectRolePage> createState() => _SelectRolePageState();
}

class _SelectRolePageState extends State<SelectRolePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // ✅ 멘토 제거: 관리자/멘티만
  late final Animation<Offset> _slideAdmin;
  late final Animation<Offset> _slideMentee;

  late final Animation<double> _fadeAdmin;
  late final Animation<double> _fadeMentee;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 스태거(순차): 관리자 -> 멘티
    _slideAdmin = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.60, curve: Curves.easeOutCubic),
    ));
    _fadeAdmin = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.60, curve: Curves.easeOut),
    ));

    _slideMentee = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 1.00, curve: Curves.easeOutCubic),
    ));
    _fadeMentee = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 1.00, curve: Curves.easeOut),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 위에 const 때문에 분리한 버전
  Widget _roleTileBuilt({
    required IconData icon,
    required String label,
    required Animation<Offset> slide,
    required Animation<double> fade,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: GestureDetector(
          onTap: () {
            switch (label) {
              case '관리자':
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => const CheckPasswordPage(mode: EntryMode.manager,)),
                );
                break;
              case '멘티':
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const  CheckPasswordPage(mode: EntryMode.mentee,)
                  ),
                );
                break;
              default:
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const  CheckPasswordPage(mode: EntryMode.mentee,)
                  ),
                );
            }
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: 65,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color.fromRGBO(47, 130, 246, 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 42),
                Icon(icon, color: const Color.fromRGBO(253, 253, 255, 1), size: 32),
                const SizedBox(width: 24),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color.fromRGBO(253, 253, 255, 1),
                    fontWeight: FontWeight.w600,
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 가운데 정렬은 유지, 타일 간격만 살짝 조정
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '역할을 선택해주세요',
              style: TextStyle(
                color: Color.fromRGBO(34, 38, 49, 1),
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 45),

            // 관리자
            _roleTileBuilt(
              icon: Icons.supervisor_account_outlined,
              label: '관리자',
              slide: _slideAdmin,
              fade: _fadeAdmin,
            ),
            const SizedBox(height: 30),

            // 멘티
            _roleTileBuilt(
              icon: Icons.child_care,
              label: '멘티',
              slide: _slideMentee,
              fade: _fadeMentee,
            ),
          ],
        ),
      ),
    );
  }
}
