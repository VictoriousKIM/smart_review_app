import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/email_login_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isGoogleLoading = false;
  bool _isKakaoLoading = false;
  bool _showEmailForm = false;

  Future<void> _handleSocialSignIn(
    Future<void> Function() signInMethod,
    bool isGoogle,
  ) async {
    setState(() {
      if (isGoogle) {
        _isGoogleLoading = true;
      } else {
        _isKakaoLoading = true;
      }
    });

    try {
      await signInMethod();

      // 로그인 성공 시 GoRouter의 redirect가 자동으로 처리하므로
      // 여기서는 별도의 네비게이션 처리가 필요 없습니다.
      // AuthProvider의 상태가 변경되면 자동으로 리다이렉트됩니다.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isGoogle) {
            _isGoogleLoading = false;
          } else {
            _isKakaoLoading = false;
          }
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    await _handleSocialSignIn(
      () => ref.read(authProvider.notifier).signInWithGoogle(),
      true, // isGoogle = true
    );
  }

  Future<void> _signInWithKakao() async {
    await _handleSocialSignIn(
      () => ref.read(authProvider.notifier).signInWithKakao(),
      false, // isGoogle = false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // 로고 및 제목
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Smart Review',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '리뷰 캠페인 플랫폼에 오신 것을 환영합니다',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const Spacer(flex: 3),

              // 이메일 로그인 폼이 표시되는 경우
              if (_showEmailForm) ...[
                const EmailLoginForm(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showEmailForm = false;
                    });
                  },
                  child: const Text('소셜 로그인으로 돌아가기'),
                ),
              ] else ...[
                // 소셜 로그인 버튼들
                // Google 로그인
                CustomButton(
                  text: 'Google로 로그인',
                  onPressed: (_isGoogleLoading || _isKakaoLoading)
                      ? null
                      : _signInWithGoogle,
                  isLoading: _isGoogleLoading,
                  backgroundColor: Colors.white,
                  textColor: Colors.black87,
                  borderColor: Colors.grey[300],
                  icon: Icons.g_mobiledata,
                ),
                const SizedBox(height: 12),
                // Kakao 로그인
                CustomButton(
                  text: 'Kakao로 로그인',
                  onPressed: (_isGoogleLoading || _isKakaoLoading)
                      ? null
                      : _signInWithKakao,
                  isLoading: _isKakaoLoading,
                  backgroundColor: const Color(0xFFFEE500),
                  textColor: Colors.black87,
                  icon: Icons.chat,
                ),
                const SizedBox(height: 16),
                // 이메일 로그인 버튼
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showEmailForm = true;
                    });
                  },
                  child: const Text('이메일로 로그인'),
                ),
              ],
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
