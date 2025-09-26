import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import 'signup_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isGoogleLoading = false;
  bool _isKakaoLoading = false;

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

      if (mounted) {
        // 잠시 기다린 후 사용자 데이터를 확인
        await Future.delayed(const Duration(milliseconds: 500));

        final authState = ref.read(authProvider);
        authState.when(
          data: (user) {
            if (user != null) {
              // 사용자 프로필이 완전하지 않으면 추가 정보 입력 화면으로 이동
              if (user.displayName == null || user.displayName!.isEmpty) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        const SignupScreen(isSocialLogin: true),
                  ),
                );
              } else {
                // 프로필이 완전하면 홈 화면으로 이동
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            }
          },
          loading: () {
            // 로딩 중이면 잠시 더 기다린 후 다시 확인
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                final authState = ref.read(authProvider);
                authState.when(
                  data: (user) {
                    if (user != null) {
                      if (user.displayName == null ||
                          user.displayName!.isEmpty) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) =>
                                const SignupScreen(isSocialLogin: true),
                          ),
                        );
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      }
                    }
                  },
                  loading: () {},
                  error: (error, _) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('로그인 실패: $error')));
                  },
                );
              }
            });
          },
          error: (error, _) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('로그인 실패: $error')));
          },
        );
      }
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
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
