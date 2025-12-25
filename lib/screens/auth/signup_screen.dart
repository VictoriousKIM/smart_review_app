import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 회원가입 화면
/// OAuth 로그인 후 프로필이 없을 때 표시됨
class SignupScreen extends ConsumerStatefulWidget {
  final String? type; // 'oauth'
  final String? provider; // 'google', 'kakao'
  final String? companyId; // URL 파라미터 또는 쿠키에서 가져온 값

  const SignupScreen({super.key, this.type, this.provider, this.companyId});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUserState();
    // companyId가 있으면 회사 정보 미리 로드
    if (widget.companyId != null) {
      _loadCompanyInfo(widget.companyId!);
    }
  }

  /// 사용자 상태 확인 (이미 프로필이 있으면 리다이렉트)
  Future<void> _checkUserState() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      final authService = ref.read(authServiceProvider);
      final userState = await authService.getUserState();
      
      // 이미 프로필이 있는 사용자는 signup 페이지 접근 불가
      if (userState == UserState.loggedIn) {
        debugPrint('🔄 [SignupScreen] 이미 프로필이 있는 사용자: 홈으로 리다이렉트');
        if (mounted) {
          context.go('/home');
        }
        return;
      }
      
      // 비로그인 상태도 signup 페이지 접근 불가 (OAuth 로그인 필요)
      if (userState == UserState.notLoggedIn) {
        debugPrint('🔄 [SignupScreen] 비로그인 상태: 로그인으로 리다이렉트');
        if (mounted) {
          context.go('/login');
        }
        return;
      }
      
      // tempSession 상태만 signup 페이지 허용
      debugPrint('✅ [SignupScreen] 임시 세션 상태: signup 페이지 허용');
    });
  }

  Future<void> _loadCompanyInfo(String companyId) async {
    // TODO: 회사 정보 로드
    debugPrint('회사 정보 로드: $companyId');
  }

  void _onUserTypeSelected(app_user.UserType userType) {
    // 선택한 타입에 따라 다음 화면으로 이동
    if (userType == app_user.UserType.user) {
      // 리뷰어 플로우
      context.go(
        '/signup/reviewer',
        extra: {'companyId': widget.companyId, 'provider': widget.provider},
      );
    } else {
      // 광고주 플로우
      final providerParam = widget.provider != null
          ? '?provider=${widget.provider}'
          : '';
      context.go('/signup/advertiser$providerParam');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // 토큰 정보 삭제 (로그아웃) - Custom JWT 포함
            try {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            } catch (e) {
              debugPrint('로그아웃 중 에러 발생: $e');
            }
            // 로그인 화면으로 이동
            if (!mounted) return;
            context.go('/login');
          },
        ),
      ),
      body: _buildUserTypeSelection(),
      bottomNavigationBar: _buildProgressIndicator(
        currentStep: 0,
        totalSteps: 4,
      ),
    );
  }

  Widget _buildUserTypeSelection() {
    return SafeArea(
      child: ResponsiveBuilder(
        builder: (context, sizingInformation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: getValueForScreenType<double>(
                      context: context,
                      mobile: double.infinity,
                      tablet: 500,
                      desktop: 600,
                    ),
                    minHeight: constraints.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: getValueForScreenType<EdgeInsets>(
                          context: context,
                          mobile: const EdgeInsets.symmetric(horizontal: 24.0),
                          tablet: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 32,
                          ),
                          desktop: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 40,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 상단 섹션
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 32),
                                // 제목
                                const Text(
                                  '회원가입',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                // 질문
                                Text(
                                  '어떤 용도로 사용하시나요?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                    letterSpacing: -0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 64),
                                // 리뷰어 버튼
                                ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _onUserTypeSelected(
                                          app_user.UserType.user,
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFFEDE7F6,
                                    ), // 연한 보라색
                                    foregroundColor: const Color(
                                      0xFF512DA8,
                                    ), // 진한 보라색
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    '리뷰어로 시작하기',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                      color: Color(0xFF512DA8), // 진한 보라색
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 광고주 버튼
                                OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          // 광고주 플로우
                                          context.go(
                                            '/signup/advertiser',
                                            extra: {
                                              'provider': widget.provider,
                                            },
                                          );
                                        },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(
                                      0xFF512DA8,
                                    ), // 진한 보라색
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF512DA8), // 진한 보라색
                                      width: 2.0, // 2px 테두리
                                    ),
                                  ),
                                  child: const Text(
                                    '광고주로 시작하기',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                      color: Color(0xFF512DA8), // 진한 보라색
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator({
    required int currentStep,
    required int totalSteps,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              final stepNumber = index + 1;
              final isActive = stepNumber < currentStep + 1;
              final isCurrent = stepNumber == currentStep + 1;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < totalSteps - 1 ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isActive || isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '1단계: 사용자 타입 선택',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
