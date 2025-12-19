import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/supabase_config.dart';
import '../../utils/error_message_utils.dart';
import '../../services/auth_service.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../mypage/common/business_registration_form.dart';
import '../../providers/auth_provider.dart';

/// 광고주 회원가입 화면
/// 단계별로 사업자 인증 → 입출금통장 입력 → 완료
class AdvertiserSignupScreen extends ConsumerStatefulWidget {
  final String? provider; // OAuth 제공자

  const AdvertiserSignupScreen({super.key, this.provider});

  @override
  ConsumerState<AdvertiserSignupScreen> createState() =>
      _AdvertiserSignupScreenState();
}

class _AdvertiserSignupScreenState
    extends ConsumerState<AdvertiserSignupScreen> {
  bool _isLoading = false;
  bool _isLoadingUserData = true; // 사용자 정보 로딩 상태

  // 회원가입 데이터
  String? _displayName;
  String? _email;
  String? _phone;
  Map<String, dynamic>? _businessData; // 사업자 정보
  String? _bankName;
  String? _accountNumber;
  String? _accountHolder;

  @override
  void initState() {
    super.initState();
    _checkUserState();
    _loadOAuthUserData();
  }

  /// 사용자 상태 확인 (이미 프로필이 있으면 리다이렉트)
  Future<void> _checkUserState() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authService = ref.read(authServiceProvider);
      final userState = await authService.getUserState();

      // 이미 프로필이 있는 사용자는 signup 페이지 접근 불가
      if (userState == UserState.loggedIn) {
        debugPrint('🔄 [AdvertiserSignupScreen] 이미 프로필이 있는 사용자: 홈으로 리다이렉트');
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      // 비로그인 상태도 signup 페이지 접근 불가
      if (userState == UserState.notLoggedIn) {
        debugPrint('🔄 [AdvertiserSignupScreen] 비로그인 상태: 로그인으로 리다이렉트');
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // tempSession 상태만 signup 페이지 허용
      debugPrint('✅ [AdvertiserSignupScreen] 임시 세션 상태: signup 페이지 허용');
    });
  }

  /// OAuth에서 가져온 사용자 정보 로드
  Future<void> _loadOAuthUserData() async {
    try {
      // 네이버 로그인 (Custom JWT)인 경우 Secure Storage에서 정보 가져오기
      if (widget.provider == 'naver') {
        try {
          const storage = FlutterSecureStorage();
          final customJwtEmail = await storage.read(
            key: 'custom_jwt_user_email',
          );
          final customJwtName = await storage.read(key: 'custom_jwt_user_name');

          debugPrint('🔍 네이버 로그인 정보 확인:');
          debugPrint('   - provider: ${widget.provider}');
          debugPrint('   - email: $customJwtEmail');
          debugPrint('   - name: $customJwtName');

          if (customJwtEmail != null && customJwtEmail.isNotEmpty) {
            setState(() {
              _email = customJwtEmail;
              if (_displayName == null &&
                  customJwtName != null &&
                  customJwtName.isNotEmpty) {
                _displayName = customJwtName;
              }
              _isLoadingUserData = false;
            });
            debugPrint(
              '✅ 네이버 로그인 정보 로드: email=$customJwtEmail, name=$customJwtName',
            );
            return;
          } else {
            debugPrint('⚠️ 네이버 로그인 정보가 없습니다.');
          }
        } catch (e) {
          debugPrint('⚠️ 네이버 로그인 정보 로드 실패: $e');
        }
      }

      // 일반 OAuth 로그인 (Google, Kakao 등)
      final session = SupabaseConfig.client.auth.currentSession;
      if (session?.user != null) {
        final user = session!.user;
        final metadata = user.userMetadata ?? {};

        setState(() {
          // OAuth에서 가져온 이메일 설정
          _email = user.email;

          // OAuth에서 가져온 이름 설정
          _displayName ??=
              metadata['full_name'] ??
              metadata['name'] ??
              metadata['display_name'] ??
              (user.email != null ? user.email!.split('@')[0] : null);
          _isLoadingUserData = false;
        });
      } else {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      debugPrint('OAuth 사용자 정보 로드 실패: $e');
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  /// 사업자 인증 완료 (단계 통합으로 인해 바로 회원가입 완료)
  void _onBusinessComplete({
    required Map<String, dynamic> businessData,
    String? phone,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
  }) {
    setState(() {
      _businessData = businessData;
      _phone = phone;
      _bankName = bankName;
      _accountNumber = accountNumber;
      _accountHolder = accountHolder;
    });
    _completeSignup();
  }

  /// 회원가입 완료
  Future<void> _completeSignup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // AuthService를 통해 일관된 방식으로 사용자 ID 가져오기
      // (Custom JWT와 일반 세션 모두 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('세션이 없습니다. 다시 로그인해주세요.');
      }

      // 디버그: 회원가입 RPC 호출 전 사업자등록번호 확인
      final businessNumber = _businessData!['business_number'];
      debugPrint('📤 회원가입 RPC 호출 전 사업자등록번호: $businessNumber');

      // RPC 함수 호출 (p_user_id 전달 - Custom JWT와 일반 세션 둘 다 지원)
      await SupabaseConfig.client.rpc(
        'create_advertiser_profile_with_company',
        params: {
          'p_user_id': userId,
          'p_display_name': _displayName!,
          'p_phone': _phone ?? '',
          'p_business_name': _businessData!['business_name'],
          'p_business_number': businessNumber,
          'p_address': _businessData!['address'],
          'p_representative_name': _businessData!['representative_name'],
          'p_business_type': _businessData!['business_type'],
          'p_registration_file_url': _businessData!['registration_file_url'],
          'p_bank_name': _bankName ?? '',
          'p_account_number': _accountNumber ?? '',
          'p_account_holder': _accountHolder ?? '',
          'p_auto_approve_reviewers':
              _businessData!['auto_approve_reviewers'] ?? true,
        },
      );

      if (mounted) {
        // 성공 시 홈 화면으로 이동
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        // Exception 객체인 경우 메시지만 추출
        if (e is Exception) {
          final exceptionString = e.toString();
          if (exceptionString.startsWith('Exception: ')) {
            errorMessage = exceptionString.substring(11).trim();
          } else {
            errorMessage = ErrorMessageUtils.getUserFriendlyMessage(e);
          }
        } else {
          errorMessage = ErrorMessageUtils.getUserFriendlyMessage(e);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: (_isLoading || _isLoadingUserData)
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBuilder(
              builder: (context, sizingInformation) {
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: getValueForScreenType<double>(
                        context: context,
                        mobile: double.infinity,
                        tablet: 700,
                        desktop: 900,
                      ),
                    ),
                    child: _buildStepContent(),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStepContent() {
    // BusinessRegistrationForm이 회원가입 모드일 때는 자체적으로 하단 버튼을 포함하므로
    // Padding은 내부에서 처리하고 버튼은 전체 너비를 사용하도록 함
    return BusinessRegistrationForm(
      isSignupMode: true,
      initialDisplayName: _displayName,
      initialEmail: _email,
      onComplete: _onBusinessComplete,
    );
  }
}
