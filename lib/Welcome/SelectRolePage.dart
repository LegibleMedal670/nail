import 'package:flutter/material.dart';
import 'package:nail/Common/page/SelectUserPage.dart';
import 'package:nail/Manager/page/CheckPasswordPage.dart';
import 'package:nail/Manager/page/ManagerMainPage.dart';
import 'package:nail/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Mentor/page/MentorMainPage.dart';

class SelectRolePage extends StatefulWidget {
  const SelectRolePage({super.key});

  @override
  State<SelectRolePage> createState() => _SelectRolePageState();
}

class _SelectRolePageState extends State<SelectRolePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<Offset> _slideAdmin;
  late final Animation<Offset> _slideMentor;
  late final Animation<Offset> _slideMentee;

  late final Animation<double> _fadeAdmin;
  late final Animation<double> _fadeMentor;
  late final Animation<double> _fadeMentee;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 스태거(순차) 인터벌: 관리자 -> 멘토 -> 멘티
    _slideAdmin = Tween<Offset>(
      begin: const Offset(0, 0.25), // 아래에서 시작
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.60, curve: Curves.easeOutCubic),
    ));

    _fadeAdmin = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.60, curve: Curves.easeOut),
    ));

    _slideMentor = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
    ));

    _fadeMentor = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.75, curve: Curves.easeOut),
    ));

    _slideMentee = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.90, curve: Curves.easeOutCubic),
    ));

    _fadeMentee = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.90, curve: Curves.easeOut),
    ));

    // 페이지가 뜨면 자동 재생
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _roleTile({
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
          onTap: (){
            switch (label) {
              case '관리자' :
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => CheckPasswordPage()),
                );
              break;
              case '멘토' :
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => SelectUserPage(
                    mode: 'Mentor',
                    users: [],
                    title: '사용자 선택 (멘토)',
                    hintText: '이름으로 검색',
                    subtitleBuilder: (u) => '팀: ${u.meta}',
                    onStart: (mentor) {
                      // TODO: 저장/이동
                      // Navigator.pushReplacement(context, MaterialPageRoute(
                      //   builder: (_) => MentorMainPage(mentor: mentor),
                      // ));
                    },
                  )),
                );
              break;
              case '멘티' :
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => SelectUserPage(
                    mode: 'Mentee',
                    title: '사용자 선택 (멘티)',
                  )),
                );
              break;
              default :
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => MenteeMainPage()),
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
                Icon(icon, color: Color.fromRGBO(253, 253, 255, 1), size: 32),
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
            _roleTile(
              icon: Icons.supervisor_account_outlined,
              label: '관리자',
              slide: _slideAdmin,
              fade: _fadeAdmin,
            ),
            const SizedBox(height: 30),

            // 멘토
            _roleTile(
              icon: Icons.school_outlined,
              label: '멘토',
              slide: _slideMentor,
              fade: _fadeMentor,
            ),
            const SizedBox(height: 30),

            // 멘티
            _roleTile(
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
