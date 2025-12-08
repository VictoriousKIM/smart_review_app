import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/supabase_config.dart';
import '../../services/wallet_service.dart';
import '../../services/auth_service.dart';
import '../../utils/error_message_utils.dart';
import 'reviewer_signup_profile_form.dart';
import 'reviewer_signup_sns_form.dart';
import 'reviewer_signup_company_form.dart';

/// 리뷰어 회원가입 화면
/// 단계별로 프로필 입력 → SNS 연결 → 회사 선택 → 완료
class ReviewerSignupScreen extends ConsumerStatefulWidget {
  final String? companyId; // URL 파라미터 또는 쿠키에서 가져온 값
  final String? provider; // OAuth 제공자

  const ReviewerSignupScreen({super.key, this.companyId, this.provider});

  @override
  ConsumerState<ReviewerSignupScreen> createState() =>
      _ReviewerSignupScreenState();
}

class _ReviewerSignupScreenState extends ConsumerState<ReviewerSignupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // 회원가입 데이터
  String? _displayName;
  String? _email;
  String? _phone = '';
  String? _baseAddress; // 기본 주소 (주소 찾기로 선택한 주소)
  String? _detailAddress; // 상세주소 (사용자가 직접 입력)
  String? _bankName; // 은행명
  String? _accountNumber; // 계좌번호
  String? _accountHolder; // 예금주
  List<Map<String, dynamic>> _snsConnections = [];
  String? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    // OAuth 데이터를 먼저 로드한 후 저장된 데이터 로드
    _loadOAuthUserData().then((_) => _loadSavedData());
  }

  /// 저장된 회원가입 데이터 로드
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();

      if (userId == null) return;

      final savedData = prefs.getString('reviewer_signup_data_$userId');
      if (savedData != null) {
        final data = jsonDecode(savedData) as Map<String, dynamic>;
        setState(() {
          _displayName = data['displayName'] as String?;
          _email =
              data['email'] as String? ??
              _email; // 저장된 이메일이 없으면 OAuth에서 가져온 값 유지
          _phone = data['phone'] as String? ?? '';
          _baseAddress = data['baseAddress'] as String?;
          _detailAddress = data['detailAddress'] as String?;
          _bankName = data['bankName'] as String?;
          _accountNumber = data['accountNumber'] as String?;
          _accountHolder = data['accountHolder'] as String?;
          _snsConnections =
              (data['snsConnections'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          _selectedCompanyId = data['selectedCompanyId'] as String?;
          _currentStep = data['currentStep'] as int? ?? 0;
        });
        debugPrint('✅ 저장된 회원가입 데이터 복원 완료');
      }
    } catch (e) {
      debugPrint('⚠️ 저장된 데이터 로드 실패: $e');
    }
  }

  /// 회원가입 데이터 저장
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();

      if (userId == null) return;

      final data = {
        'displayName': _displayName,
        'email': _email,
        'phone': _phone,
        'baseAddress': _baseAddress,
        'detailAddress': _detailAddress,
        'bankName': _bankName,
        'accountNumber': _accountNumber,
        'accountHolder': _accountHolder,
        'snsConnections': _snsConnections,
        'selectedCompanyId': _selectedCompanyId,
        'currentStep': _currentStep,
      };
      await prefs.setString('reviewer_signup_data_$userId', jsonEncode(data));
      debugPrint('✅ 회원가입 데이터 저장 완료');
    } catch (e) {
      debugPrint('⚠️ 데이터 저장 실패: $e');
    }
  }

  /// 저장된 회원가입 데이터 삭제
  Future<void> _clearSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();

      if (userId == null) return;

      await prefs.remove('reviewer_signup_data_$userId');
      debugPrint('✅ 저장된 회원가입 데이터 삭제 완료');
    } catch (e) {
      debugPrint('⚠️ 데이터 삭제 실패: $e');
    }
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

          if (customJwtEmail != null && customJwtEmail.isNotEmpty) {
            setState(() {
              _email = customJwtEmail;
              if (_displayName == null &&
                  customJwtName != null &&
                  customJwtName.isNotEmpty) {
                _displayName = customJwtName;
              }
            });
            debugPrint(
              '✅ 네이버 로그인 정보 로드: email=$customJwtEmail, name=$customJwtName',
            );
            return;
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
        });
      }
    } catch (e) {
      debugPrint('OAuth 사용자 정보 로드 실패: $e');
    }
  }

  /// 프로필 입력 완료
  void _onProfileComplete({
    required String displayName,
    String? phone,
    String? address,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
  }) {
    setState(() {
      _displayName = displayName;
      _phone = phone ?? '';
      // 주소를 기본 주소와 상세주소로 분리하여 저장
      // 주소 형식: "기본주소 상세주소" (공백으로 구분)
      if (address != null && address.isNotEmpty) {
        final trimmedAddress = address.trim();
        // 주소에서 마지막 공백 이후를 상세주소로 간주
        final lastSpaceIndex = trimmedAddress.lastIndexOf(' ');
        if (lastSpaceIndex > 0 && lastSpaceIndex < trimmedAddress.length - 1) {
          // 공백이 있고, 그 이후에 문자가 있으면 분리
          _baseAddress = trimmedAddress.substring(0, lastSpaceIndex);
          _detailAddress = trimmedAddress.substring(lastSpaceIndex + 1);
        } else {
          // 공백이 없거나 마지막에 공백만 있으면 전체를 기본 주소로
          _baseAddress = trimmedAddress;
          _detailAddress = null;
        }
      } else {
        _baseAddress = null;
        _detailAddress = null;
      }
      // 계좌정보 저장
      _bankName = bankName;
      _accountNumber = accountNumber;
      _accountHolder = accountHolder;
      _currentStep = 1; // SNS 연결 단계로 이동
    });
    _saveData(); // 데이터 저장
  }

  /// SNS 연결 완료
  void _onSNSComplete(List<Map<String, dynamic>> snsConnections) {
    setState(() {
      _snsConnections = snsConnections;
      _currentStep = 2; // 회사 선택 단계로 이동
    });
    _saveData(); // 데이터 저장
  }

  /// 회사 선택 완료
  void _onCompanyComplete(String? companyId) {
    setState(() {
      _selectedCompanyId = companyId;
    });
    _saveData(); // 데이터 저장
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

      // 주소 합치기 (기본 주소 + 상세주소)
      String? fullAddress;
      if (_baseAddress != null && _baseAddress!.isNotEmpty) {
        fullAddress = _detailAddress != null && _detailAddress!.isNotEmpty
            ? '$_baseAddress $_detailAddress'
            : _baseAddress;
      }

      // SNS 연결 데이터 디버그 출력
      if (_snsConnections.isNotEmpty) {
        debugPrint('📤 SNS 연결 데이터 전송:');
        for (var conn in _snsConnections) {
          debugPrint('  - 플랫폼: ${conn['platform']}');
          debugPrint('    계정 ID: ${conn['platform_account_id']}');
          debugPrint('    계정 이름: ${conn['platform_account_name']}');
          debugPrint('    전화번호: ${conn['phone']}');
          debugPrint('    주소: ${conn['address']}');
          debugPrint('    반품주소: ${conn['return_address']}');
        }
      }

      // RPC 함수 호출
      Map<String, dynamic>? result;

      if (customJwtToken != null) {
        // Custom JWT를 사용하여 직접 HTTP 요청 (웹/모바일 공통)
        final supabaseUrl = SupabaseConfig.supabaseUrl;
        final url = Uri.parse(
          '$supabaseUrl/rest/v1/rpc/create_reviewer_profile_with_company',
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
            'p_address': fullAddress,
            'p_company_id': _selectedCompanyId,
            'p_sns_connections': _snsConnections.isNotEmpty
                ? _snsConnections
                : null,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data != null && data is Map<String, dynamic>) {
            result = data;
            debugPrint('✅ Custom JWT로 회원가입 RPC 호출 성공');
          } else {
            throw Exception('회원가입 응답 형식이 올바르지 않습니다');
          }
        } else {
          throw Exception('회원가입 실패: ${response.statusCode} - ${response.body}');
        }
      } else {
        // 일반 RPC 함수 호출
        result = await SupabaseConfig.client.rpc(
          'create_reviewer_profile_with_company',
          params: {
            'p_user_id': userId,
            'p_display_name': _displayName!,
            'p_phone': _phone ?? '',
            'p_address': fullAddress,
            'p_company_id': _selectedCompanyId,
            'p_sns_connections': _snsConnections.isNotEmpty
                ? _snsConnections
                : null,
          },
        );
      }

      debugPrint('✅ 회원가입 RPC 결과: $result');

      // SNS 연결 결과 확인
      if (result != null && result['sns_connections'] != null) {
        final snsResult = result['sns_connections'] as Map<String, dynamic>;
        final success = snsResult['success'] as int? ?? 0;
        final failed = snsResult['failed'] as int? ?? 0;
        final errors = snsResult['errors'] as List<dynamic>? ?? [];

        if (failed > 0) {
          debugPrint('⚠️ SNS 연결 일부 실패: 성공 $success개, 실패 $failed개');
          for (var error in errors) {
            final errorMap = error as Map<String, dynamic>;
            debugPrint(
              '  - 플랫폼: ${errorMap['platform']}, 계정: ${errorMap['account_id']}',
            );
            debugPrint('    에러: ${errorMap['error']}');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'SNS 연결 일부 실패: $failed개 연결이 등록되지 않았습니다. 마이페이지에서 다시 등록해주세요.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (success > 0) {
          debugPrint('✅ SNS 연결 모두 성공: $success개');
        } else if (_snsConnections.isNotEmpty) {
          // SNS 연결을 입력했는데 성공/실패 모두 0인 경우 (예상치 못한 상황)
          debugPrint('⚠️ SNS 연결 결과가 없습니다. 입력한 연결 수: ${_snsConnections.length}');
        }
      } else if (_snsConnections.isNotEmpty) {
        // SNS 연결을 입력했는데 결과가 없는 경우
        debugPrint(
          '⚠️ SNS 연결 결과가 반환되지 않았습니다. 입력한 연결 수: ${_snsConnections.length}',
        );
      }

      // 계좌정보가 있으면 지갑에 업데이트
      if (_bankName != null &&
          _bankName!.isNotEmpty &&
          _accountNumber != null &&
          _accountNumber!.isNotEmpty &&
          _accountHolder != null &&
          _accountHolder!.isNotEmpty) {
        try {
          await WalletService.updateUserWalletAccount(
            bankName: _bankName!,
            accountNumber: _accountNumber!,
            accountHolder: _accountHolder!,
          );
          debugPrint('✅ 계좌정보 업데이트 완료');
        } catch (e) {
          debugPrint('⚠️ 계좌정보 업데이트 실패: $e');
          // 계좌정보 업데이트 실패해도 회원가입은 성공으로 처리
        }
      }

      // 회원가입 성공 시 저장된 데이터 삭제
      await _clearSavedData();

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
      debugPrint('❌ 회원가입 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
              await _saveData(); // 단계 변경 시 데이터 저장
            } else {
              await _saveData(); // 뒤로가기 전 데이터 저장
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

  Widget _buildProgressIndicator() {
    // 전체 4단계: 타입 선택(1) → 프로필(2) → SNS(3) → 회사(4)
    // reviewer_signup_screen은 타입 선택 이후이므로:
    // _currentStep 0 = 프로필 입력 (전체 2단계)
    // _currentStep 1 = SNS 연결 (전체 3단계)
    // _currentStep 2 = 회사 선택 (전체 4단계)
    final totalSteps = 4;
    final currentStep = _currentStep + 2; // 타입 선택(1단계) 이후이므로 +2

    final stepLabels = [
      '프로필 입력', // _currentStep = 0 (전체 2단계)
      'SNS 연결', // _currentStep = 1 (전체 3단계)
      '회사 선택', // _currentStep = 2 (전체 4단계)
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

  Widget _buildStepContent() {
    Widget formWidget;
    switch (_currentStep) {
      case 0:
        // ReviewerSignupProfileForm이 회원가입 모드일 때는 자체적으로 하단 버튼을 포함하므로
        // SingleChildScrollView로 감싸지 않음
        formWidget = ReviewerSignupProfileForm(
          key: ValueKey(
            'profile_${_email}_${_displayName}',
          ), // email이나 displayName이 변경되면 위젯 재생성
          initialDisplayName: _displayName,
          initialEmail: _email,
          initialPhone: _phone?.isNotEmpty == true ? _phone : null,
          initialBaseAddress: _baseAddress,
          initialDetailAddress: _detailAddress,
          initialBankName: _bankName,
          initialAccountNumber: _accountNumber,
          initialAccountHolder: _accountHolder,
          onComplete: _onProfileComplete,
        );
        break;
      case 1:
        // 프로필 주소 전체주소 생성
        String? profileAddress;
        if (_baseAddress != null && _baseAddress!.isNotEmpty) {
          profileAddress = _detailAddress != null && _detailAddress!.isNotEmpty
              ? '$_baseAddress $_detailAddress'
              : _baseAddress;
        }

        // ReviewerSignupSNSForm이 회원가입 모드일 때는 자체적으로 하단 버튼을 포함하므로
        // SingleChildScrollView로 감싸지 않음
        formWidget = ReviewerSignupSNSForm(
          initialSnsConnections: _snsConnections,
          profileName: _displayName,
          profilePhone: _phone?.isNotEmpty == true ? _phone : null,
          profileAddress: profileAddress,
          onComplete: _onSNSComplete,
        );
        break;
      case 2:
        // ReviewerSignupCompanyForm이 회원가입 모드일 때는 자체적으로 하단 버튼을 포함하므로
        // SingleChildScrollView로 감싸지 않음
        formWidget = ReviewerSignupCompanyForm(
          initialCompanyId: widget.companyId ?? _selectedCompanyId,
          onComplete: _onCompanyComplete,
        );
        break;
      default:
        return const Center(child: Text('알 수 없는 단계입니다'));
    }

    return formWidget;
  }
}
