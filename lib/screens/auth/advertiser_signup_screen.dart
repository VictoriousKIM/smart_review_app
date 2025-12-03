import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/supabase_config.dart';
import 'advertiser_signup_business_form.dart';
import 'advertiser_signup_account_form.dart';

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
  int _currentStep = 0;
  bool _isLoading = false;

  // 회원가입 데이터
  String? _displayName;
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
      final session = SupabaseConfig.client.auth.currentSession;
      if (session?.user != null) {
        final user = session!.user;
        final metadata = user.userMetadata ?? {};

        // OAuth에서 가져온 이름 설정
        if (_displayName == null) {
          setState(() {
            _displayName =
                metadata['full_name'] ??
                metadata['name'] ??
                metadata['display_name'] ??
                (user.email != null ? user.email!.split('@')[0] : null);
          });
        }
      }
    } catch (e) {
      debugPrint('OAuth 사용자 정보 로드 실패: $e');
    }
  }

  /// 사업자 인증 완료
  void _onBusinessComplete({
    required Map<String, dynamic> businessData,
    String? phone,
  }) {
    setState(() {
      _businessData = businessData;
      _phone = phone;
      _currentStep = 1; // 입출금통장 입력 단계로 이동
    });
  }

  /// 입출금통장 입력 완료
  void _onAccountComplete({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    setState(() {
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
      final session = SupabaseConfig.client.auth.currentSession;
      if (session?.user == null) {
        throw Exception('세션이 없습니다. 다시 로그인해주세요.');
      }

      final userId = session!.user.id;

      // RPC 함수 호출
      final result = await SupabaseConfig.client.rpc(
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
          'p_bank_name': _bankName!,
          'p_account_number': _accountNumber!,
          'p_account_holder': _accountHolder!,
        },
      );

      if (mounted) {
        // 성공 시 홈 화면으로 이동
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: $e'), backgroundColor: Colors.red),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStepContent(),
      bottomNavigationBar: _isLoading ? null : _buildProgressIndicator(),
    );
  }

  Widget _buildStepContent() {
    Widget formWidget;
    switch (_currentStep) {
      case 0:
        formWidget = AdvertiserSignupBusinessForm(
          initialDisplayName: _displayName,
          onComplete: _onBusinessComplete,
        );
        break;
      case 1:
        formWidget = AdvertiserSignupAccountForm(onComplete: _onAccountComplete);
        break;
      default:
        return const Center(child: Text('알 수 없는 단계입니다'));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: formWidget,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // 전체 2단계: 사업자 인증(1) → 입출금통장(2)
    final totalSteps = 2;
    final currentStep = _currentStep + 1; // 0-based → 1-based

    final stepLabels = [
      '사업자 인증',
      '입출금통장',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              final isActive = stepNumber < currentStep;
              final isCurrent = stepNumber == currentStep;

              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < totalSteps - 1 ? 4 : 0),
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
            stepLabels[_currentStep],
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
