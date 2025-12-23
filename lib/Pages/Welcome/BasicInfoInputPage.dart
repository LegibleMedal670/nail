import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nail/Pages/Common/ui_tokens.dart';
import 'package:nail/Pages/Welcome/PendingRolePage.dart';
import 'package:nail/Providers/UserProvider.dart';

/// 신규 가입자 이름 입력 페이지
class BasicInfoInputPage extends StatefulWidget {
  const BasicInfoInputPage({super.key});

  @override
  State<BasicInfoInputPage> createState() => _BasicInfoInputPageState();
}

class _BasicInfoInputPageState extends State<BasicInfoInputPage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isNameValid {
    final name = _nameController.text.trim();
    return name.length >= 2 && name.length <= 20;
  }

  Future<void> _submit() async {
    if (!_isNameValid) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.updateNickname(_nameController.text.trim());

      if (!mounted) return;

      // 가입 완료 → 대기 페이지로
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PendingRolePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),

                // 타이틀
                const Text(
                  '반갑습니다!',
                  style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const Text(
                  '이름을 입력해주세요.',
                  style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 40),

                // 라벨
                const Text(
                  '이름',
                  style: TextStyle(
                    color: UiTokens.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // 이름 입력 필드
                TextField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '홍길동',
                    hintStyle: TextStyle(
                      color: UiTokens.title.withOpacity(0.3),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: UiTokens.primaryBlue,
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    color: UiTokens.title,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),

                const Spacer(),

                // 가입 완료 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isNameValid) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTokens.primaryBlue,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            '가입 완료',
                            style: TextStyle(
                              color: _isNameValid
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
