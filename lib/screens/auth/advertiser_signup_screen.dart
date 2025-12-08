import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../config/supabase_config.dart';
import '../../utils/error_message_utils.dart';
import '../mypage/common/business_registration_form.dart';

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
    _loadOAuthUserData();
  }

  /// OAuth에서 가져온 사용자 정보 로드
  Future<void> _loadOAuthUserData() async {
    try {
      // 네이버 로그인 (Custom JWT)인 경우 SharedPreferences에서 정보 가져오기
      if (widget.provider == 'naver') {
        try {
          final prefs = await SharedPreferences.getInstance();
          final customJwtEmail = prefs.getString('custom_jwt_user_email');
          final customJwtName = prefs.getString('custom_jwt_user_name');

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
          if (_displayName == null) {
            _displayName =
                metadata['full_name'] ??
                metadata['name'] ??
                metadata['display_name'] ??
                (user.email != null ? user.email!.split('@')[0] : null);
          }
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
      String userId;
      String? customJwtToken;

      // 네이버 로그인 (Custom JWT)인 경우 SharedPreferences에서 정보 가져오기
      if (widget.provider == 'naver') {
        try {
          final prefs = await SharedPreferences.getInstance();
          final customJwtUserId = prefs.getString('custom_jwt_user_id');
          customJwtToken = prefs.getString('custom_jwt_token');

          if (customJwtUserId == null || customJwtUserId.isEmpty) {
            throw Exception('세션이 없습니다. 다시 로그인해주세요.');
          }

          userId = customJwtUserId;
          debugPrint('✅ 네이버 로그인: Custom JWT로 회원가입 진행 (userId: $userId)');
        } catch (e) {
          debugPrint('⚠️ 네이버 로그인 정보 로드 실패: $e');
          throw Exception('세션이 없습니다. 다시 로그인해주세요.');
        }
      } else {
        // 일반 OAuth 로그인 (Google, Kakao 등)
        final session = SupabaseConfig.client.auth.currentSession;
        if (session?.user == null) {
          throw Exception('세션이 없습니다. 다시 로그인해주세요.');
        }
        userId = session!.user.id;
      }

      // RPC 함수 호출
      if (customJwtToken != null) {
        // Custom JWT를 사용하여 직접 HTTP 요청 (웹/모바일 공통)
        final supabaseUrl = SupabaseConfig.supabaseUrl;
        final url = Uri.parse(
          '$supabaseUrl/rest/v1/rpc/create_advertiser_profile_with_company',
        );

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $customJwtToken',
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'p_user_id': userId,
            'p_display_name': _displayName!,
            'p_phone': _phone ?? '',
            'p_business_name': _businessData!['business_name'],
            'p_business_number': _businessData!['business_number'],
            'p_address': _businessData!['address'],
            'p_representative_name': _businessData!['representative_name'],
            'p_business_type': _businessData!['business_type'],
            'p_registration_file_url': _businessData!['registration_file_url'],
            'p_bank_name': _bankName ?? '',
            'p_account_number': _accountNumber ?? '',
            'p_account_holder': _accountHolder ?? '',
          }),
        );

        if (response.statusCode != 200) {
          debugPrint('❌ Custom JWT로 회원가입 RPC 호출 실패: ${response.statusCode}');
          debugPrint('❌ 응답 본문: ${response.body}');

          // JSON 응답에서 메시지 추출 및 사용자 친화적 메시지로 변환
          String errorMessage = '회원가입에 실패했습니다. 입력한 정보를 확인하고 다시 시도해주세요.';
          try {
            final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
            if (errorJson.containsKey('message')) {
              final rawMessage = errorJson['message'] as String;
              // 사용자 친화적 메시지로 변환
              errorMessage = ErrorMessageUtils.getUserFriendlyMessage(
                rawMessage,
              );
            }
          } catch (e) {
            // JSON 파싱 실패 시 기본 메시지 사용
            debugPrint('⚠️ JSON 파싱 실패: $e');
          }

          throw Exception(errorMessage);
        }
        debugPrint('✅ Custom JWT로 회원가입 RPC 호출 성공');
      } else {
        // 일반 RPC 함수 호출
        await SupabaseConfig.client.rpc(
          'create_advertiser_profile_with_company',
          params: {
            'p_user_id': userId,
            'p_display_name': _displayName!,
            'p_phone': _phone ?? '',
            'p_business_name': _businessData!['business_name'],
            'p_business_number': _businessData!['business_number'],
            'p_address': _businessData!['address'],
            'p_representative_name': _businessData!['representative_name'],
            'p_business_type': _businessData!['business_type'],
            'p_registration_file_url': _businessData!['registration_file_url'],
            'p_bank_name': _bankName ?? '',
            'p_account_number': _accountNumber ?? '',
            'p_account_holder': _accountHolder ?? '',
          },
        );
      }

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
          : _buildStepContent(),
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
