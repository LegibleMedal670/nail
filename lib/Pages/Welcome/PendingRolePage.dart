import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Manager/page/ManagerMainPage.dart';
import 'package:nail/Pages/Mentor/page/MentorHomeScaffold.dart';
import 'package:nail/Pages/Mentee/page/MenteeHomeScaffold.dart';
import 'package:nail/Pages/Welcome/PhoneLoginPage.dart';
import 'package:nail/Providers/UserProvider.dart';

/// 가입 신청 완료 대기 페이지 (WaitingPage)
/// - 관리자가 역할을 배정하기 전까지 대기
class PendingRolePage extends StatefulWidget {
  const PendingRolePage({super.key});

  @override
  State<PendingRolePage> createState() => _PendingRolePageState();
}

class _PendingRolePageState extends State<PendingRolePage> {
  bool _isRefreshing = false;

  Future<void> _checkRoleAssigned() async {
    setState(() => _isRefreshing = true);

    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.refreshProfile();

      if (!mounted) return;

      final role = userProvider.role;
      if (role != 'pending') {
        _navigateByRole(role);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('아직 역할이 배정되지 않았습니다.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('확인 실패: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _navigateByRole(String role) {
    Widget destination;

    switch (role) {
      case 'admin':
        destination = const ManagerMainPage();
        break;
      case 'mentor':
        destination = const MentorHomeScaffold();
        break;
      case 'mentee':
        destination = const MenteeHomeScaffold();
        break;
      default:
        return; // pending이면 이동하지 않음
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 시계 아이콘 (체크 포함)
              _buildClockIcon(),
              const SizedBox(height: 32),

              // 타이틀
              const Text(
                '가입 신청 완료',
                style: TextStyle(
                  color: UiTokens.title,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              // 설명
              Text(
                '관리자 확인 후 서비스 이용이 가능합니다.\n잠시만 기다려주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: UiTokens.title.withOpacity(0.5),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // 로그아웃 버튼 (outlined 스타일)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isRefreshing ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: UiTokens.primaryBlue,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(
                      color: UiTokens.primaryBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 역할 배정 확인 (숨겨진 새로고침)
              TextButton(
                onPressed: _isRefreshing ? null : _checkRoleAssigned,
                child: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '역할이 배정되었나요?',
                        style: TextStyle(
                          color: UiTokens.title.withOpacity(0.4),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 체크 표시가 있는 시계 아이콘
  Widget _buildClockIcon() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          // 시계 아이콘
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: UiTokens.title,
                width: 3,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.access_time,
                size: 40,
                color: UiTokens.title,
              ),
            ),
          ),
          // 체크 표시
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: UiTokens.title,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
