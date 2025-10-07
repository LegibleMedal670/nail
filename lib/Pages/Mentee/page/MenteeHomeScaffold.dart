import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Mentee/page/MenteeMainPage.dart';
import 'package:nail/Pages/Mentee/page/MenteePracticePage.dart';
import 'package:nail/Pages/Welcome/SplashScreen.dart';
import 'package:nail/Providers/UserProvider.dart';

class MenteeHomeScaffold extends StatefulWidget {
  const MenteeHomeScaffold({super.key});

  @override
  State<MenteeHomeScaffold> createState() => _MenteeHomeScaffoldState();
}

class _MenteeHomeScaffoldState extends State<MenteeHomeScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const MenteeMainPage(embedded: true),     // ✅ 이론 탭(임베디드 모드)
      const MenteePracticePage(embedded: true), // ✅ 실습 탭(임베디드 모드)
    ];

    final titles = ['이론', '실습'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            color: UiTokens.title,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout_rounded, color: UiTokens.title),
            onPressed: () async {
              await context.read<UserProvider>().signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UiTokens.primaryBlue,
        unselectedItemColor: const Color(0xFFB0B9C1),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: '이론',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush_rounded),
            label: '실습',
          ),
        ],
      ),
    );
  }
}
