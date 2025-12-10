import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_message_utils.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/email_login_form.dart';
import 'package:responsive_builder/responsive_builder.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isGoogleLoading = false;
  bool _isKakaoLoading = false;
  bool _isNaverLoading = false;
  bool _showEmailForm = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleSocialSignIn(
    Future<void> Function() signInMethod,
    String provider, // 'google', 'kakao', 'naver'
  ) async {
    setState(() {
      if (provider == 'google') {
        _isGoogleLoading = true;
      } else if (provider == 'kakao') {
        _isKakaoLoading = true;
      } else if (provider == 'naver') {
        _isNaverLoading = true;
      }
    });

    try {
      await signInMethod();

      // OAuth 로그인의 경우 외부 브라우저로 이동하므로
      // 여기서는 로딩 상태를 유지하고, authStateChanges에서 로그인 완료를 감지합니다.
      // 모바일에서는 딥링크로 돌아올 때까지 로딩 상태가 유지됩니다.

      // 웹의 경우 즉시 완료되므로 짧은 대기 후 상태 확인
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
        // 웹에서는 signInWithOAuth가 완료되면 바로 세션이 생성됨
        // authStateChanges에서 자동으로 처리됨
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _isKakaoLoading = false;
          _isNaverLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    // finally 블록 제거: authStateChanges에서 로그인 완료 시 로딩 상태 해제
  }

  Future<void> _signInWithGoogle() async {
    await _handleSocialSignIn(
      () => ref.read(authProvider.notifier).signInWithGoogle(),
      'google',
    );
  }

  Future<void> _signInWithKakao() async {
    await _handleSocialSignIn(
      () => ref.read(authProvider.notifier).signInWithKakao(),
      'kakao',
    );
  }

  Future<void> _signInWithNaver() async {
    await _handleSocialSignIn(
      () => ref.read(authProvider.notifier).signInWithNaver(),
      'naver',
    );
  }

  @override
  Widget build(BuildContext context) {
    // authStateChanges를 감지하여 로그인 완료 시 로딩 상태 해제
    // ref.listen은 build 메서드 내에서만 사용 가능
    ref.listen<AsyncValue>(authProvider, (previous, next) {
      if (previous?.value == null && next.value != null) {
        // 로그인 성공: 로딩 상태 해제
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _isKakaoLoading = false;
            _isNaverLoading = false;
          });
        }
      } else if (previous?.value != null && next.value == null) {
        // 로그아웃: 로딩 상태 해제
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _isKakaoLoading = false;
            _isNaverLoading = false;
          });
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: ResponsiveBuilder(
          builder: (context, sizingInformation) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: getValueForScreenType<double>(
                    context: context,
                    mobile: double.infinity,
                    tablet: 500,
                    desktop: 600,
                  ),
                ),
                child: Padding(
                  padding: getValueForScreenType<EdgeInsets>(
                    context: context,
                    mobile: const EdgeInsets.all(24.0),
                    tablet: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    desktop: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
                  ),
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
                  onPressed:
                      (_isGoogleLoading || _isKakaoLoading || _isNaverLoading)
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
                  onPressed:
                      (_isGoogleLoading || _isKakaoLoading || _isNaverLoading)
                      ? null
                      : _signInWithKakao,
                  isLoading: _isKakaoLoading,
                  backgroundColor: const Color(0xFFFEE500),
                  textColor: Colors.black87,
                  icon: Icons.chat,
                ),
                const SizedBox(height: 12),
                // Naver 로그인
                CustomButton(
                  text: 'Naver로 로그인',
                  onPressed:
                      (_isGoogleLoading || _isKakaoLoading || _isNaverLoading)
                      ? null
                      : _signInWithNaver,
                  isLoading: _isNaverLoading,
                  backgroundColor: const Color(0xFF03C75A),
                  textColor: Colors.white,
                  icon: Icons.account_circle,
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
          },
        ),
      ),
    );
  }
}
