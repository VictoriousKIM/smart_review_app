import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../services/company_service.dart';
import '../../../services/wallet_service.dart';
import '../../../models/user.dart' as app_user;
import '../../../models/wallet_models.dart';
import '../../../config/supabase_config.dart';
import '../../../utils/phone_formatter.dart';
import '../../../utils/error_message_utils.dart';
import '../../../widgets/address_form_field.dart';
import 'business_registration_form.dart';
import 'account_registration_form.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  app_user.User? _user;
  int _currentPoints = 0;
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _baseAddressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _existingCompanyData;
  bool _isLoadingCompanyData = false;
  Map<String, dynamic>? _pendingManagerRequest;
  bool _isLoadingPendingRequest = false;
  UserWallet? _userWallet;
  CompanyWallet? _companyWallet;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserProfile();
    _loadCompanyData();
    _loadPendingManagerRequest();
    _loadWalletData();

    // URL 파라미터로 광고주 탭을 요청한 경우 자동으로 광고주 탭으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.parse(GoRouterState.of(context).uri.toString());
      if (uri.queryParameters['tab'] == 'business') {
        _tabController.animateTo(1);
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _baseAddressController.dispose();
    _detailAddressController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // 탭 변경 시 처리 (필요시)
  }

  /// users 테이블에서 전화번호와 주소 정보 로드
  Future<void> _loadUserProfileDetails() async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;

      final response = await SupabaseConfig.client
          .from('users')
          .select('phone, address')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final phone = response['phone'] as String?;
        final address = response['address'] as String?;

        setState(() {
          _phoneController.text = phone ?? '';
          // 주소를 기본주소와 상세주소로 분리
          if (address != null && address.isNotEmpty) {
            final lastSpaceIndex = address.lastIndexOf(' ');
            if (lastSpaceIndex > 0 && lastSpaceIndex < address.length - 1) {
              _baseAddressController.text = address.substring(
                0,
                lastSpaceIndex,
              );
              _detailAddressController.text = address.substring(
                lastSpaceIndex + 1,
              );
            } else {
              _baseAddressController.text = address;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('프로필 상세 정보 로드 실패: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 사용자 정보 가져오기
      final user = await _authService.currentUser;

      if (user != null) {
        setState(() {
          _user = user;
          _displayNameController.text = user.displayName ?? '';
          _emailController.text = user.email;
        });

        // users 테이블에서 전화번호와 주소 정보 로드
        await _loadUserProfileDetails();

        // 포인트 정보는 _loadWalletData에서 로드하므로 여기서는 사용자 정보만 설정
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('사용자 정보를 불러올 수 없습니다')));
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('내 계정'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 공용 페이지에서는 무조건 리뷰어 마이페이지로 리다이렉트
            context.go('/mypage/reviewer');
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTabbedContent(),
    );
  }

  Widget _buildTabbedContent() {
    // 사용자가 null이 아닌 경우 항상 탭 표시 (유저타입 제약 없음)
    if (_user != null) {
      return Column(
        children: [
          // 탭 바
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF137fec),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF137fec),
              tabs: const [
                Tab(text: '리뷰어'),
                Tab(text: '광고주'),
              ],
            ),
          ),
          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileContent(), // 리뷰어 탭
                _buildBusinessTab(), // 광고주 탭
              ],
            ),
          ),
        ],
      );
    } else {
      // 사용자 정보가 없는 경우 기본 프로필만 표시
      return _buildProfileContent();
    }
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 프로필 정보 섹션
          _buildProfileInfoSection(),

          const SizedBox(height: 24),

          // 계좌정보 섹션
          AccountRegistrationForm(
            userWallet: _userWallet,
            onSaved: _loadWalletData,
          ),

          const SizedBox(height: 24),

          // 계정 정보 섹션
          _buildAccountManagementSection(),

          const SizedBox(height: 24),

          // 활동 통계 섹션
          _buildActivityStatsSection(),

          const SizedBox(height: 32),

          // 계정 관리 버튼들
          _buildAccountManagementButtons(),
        ],
      ),
    );
  }

  Widget _buildProfileInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기본 정보 타이틀과 편집 버튼을 한 줄에 배치
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '기본 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                // 편집 모드에 따라 버튼 표시
                if (!_isEditing)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('편집'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _cancelEdit,
                        child: const Text('취소'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('저장'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 이름
            _buildFormField(
              label: '이름',
              controller: _displayNameController,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '이름을 입력해주세요';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 이메일
            _buildFormField(
              label: '이메일',
              controller: _emailController,
              enabled: false, // 이메일은 변경 불가
              validator: null,
            ),

            const SizedBox(height: 16),

            // 전화번호
            _buildFormField(
              label: '전화번호',
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: null,
              inputFormatters: [PhoneNumberFormatter()],
            ),

            const SizedBox(height: 16),

            // 주소
            if (_isEditing) ...[
              // 편집 모드: AddressFormField 사용
              AddressFormField(
                deliveryBaseAddressController: _baseAddressController,
                deliveryDetailAddressController: _detailAddressController,
                isDeliveryAddressRequired: false,
                showReturnAddress: false,
              ),
              const SizedBox(height: 16),
            ] else ...[
              // 읽기 모드: 주소 항상 표시
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '주소',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _baseAddressController.text.isNotEmpty ||
                                    _detailAddressController.text.isNotEmpty
                                ? '${_baseAddressController.text} ${_detailAddressController.text}'
                                      .trim()
                                : '주소 없음',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _baseAddressController.text.isNotEmpty ||
                                      _detailAddressController.text.isNotEmpty
                                  ? const Color(0xFF333333)
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF137fec), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        ),
      ],
    );
  }

  Widget _buildAccountManagementSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계정 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            '가입일',
            _user?.createdAt != null
                ? '${_user!.createdAt.year}-${_user!.createdAt.month.toString().padLeft(2, '0')}-${_user!.createdAt.day.toString().padLeft(2, '0')}'
                : '알 수 없음',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('계정 상태', '활성'),
        ],
      ),
    );
  }

  Widget _buildActivityStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '활동 통계',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '리뷰 작성',
                  '${_user?.reviewCount ?? 0}개',
                  Icons.star_outline,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '보유 포인트',
                  '${_currentPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAccountManagementButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: '계정 삭제',
            onPressed: () {
              _showDeleteAccountDialog();
            },
            backgroundColor: Colors.red[50],
            textColor: Colors.red[700],
            borderColor: Colors.red[200],
          ),
        ),
      ],
    );
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _displayNameController.text = _user?.displayName ?? '';
      _emailController.text = _user?.email ?? '';
      // 프로필 상세 정보 다시 로드
      _loadUserProfileDetails();
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        // 사용자 ID 가져오기 (Custom JWT 세션 지원)
        final userId = await AuthService.getCurrentUserId();
        if (userId == null) {
          throw Exception('사용자 정보를 찾을 수 없습니다');
        }

        // 주소 합치기 (기본주소 + 상세주소)
        final baseAddress = _baseAddressController.text.trim();
        final detailAddress = _detailAddressController.text.trim();
        final fullAddress = baseAddress.isNotEmpty
            ? (detailAddress.isNotEmpty
                  ? '$baseAddress $detailAddress'
                  : baseAddress)
            : null;

        // users 테이블 업데이트
        await SupabaseConfig.client
            .from('users')
            .update({
              'display_name': _displayNameController.text.trim(),
              'phone': _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
              'address': fullAddress,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        // 프로필 다시 로드
        await _loadUserProfile();

        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('프로필이 저장되었습니다')));
        }
      } catch (e) {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
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
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text('계정 삭제 페이지로 이동하시겠습니까?\n\n계정 삭제는 신중하게 결정해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/account-deletion');
            },
            child: Text('이동', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // 광고주등록폼 통합
          _buildBusinessRegistrationForm(),
          const SizedBox(height: 24),
          // 계좌정보 섹션 (광고주 탭)
          AccountRegistrationForm(
            companyWallet: _companyWallet,
            onSaved: _loadWalletData,
            isBusinessTab: true,
          ),
          // 광고주 등록이 없으면 매니저 등록 요청 버튼 표시 (제일 밑)
          if (_existingCompanyData == null && !_isLoadingCompanyData) ...[
            const SizedBox(height: 24),
            _buildManagerRequestButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildBusinessRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BusinessRegistrationForm(
        hasPendingManagerRequest: _pendingManagerRequest != null,
        onVerificationComplete: () async {
          // 광고주 인증 완료 시 프로필 및 회사 데이터 다시 로드
          await _loadUserProfile();
          await _loadCompanyData();
          await _loadWalletData(); // 지갑 데이터 로드 (계좌정보 표시를 위해 필요)
          await _loadPendingManagerRequest();
          // 데이터 로드 완료 후 setState로 위젯 다시 빌드하여 계좌정보 표시
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  /// 회사 데이터 로드
  Future<void> _loadCompanyData() async {
    try {
      setState(() {
        _isLoadingCompanyData = true;
      });

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _isLoadingCompanyData = false;
        });
        return;
      }

      final companyData = await CompanyService.getCompanyByUserId(userId);
      setState(() {
        _existingCompanyData = companyData;
        _isLoadingCompanyData = false;
      });
    } catch (e) {
      print('❌ 회사 데이터 로드 실패: $e');
      setState(() {
        _isLoadingCompanyData = false;
      });
    }
  }

  /// 매니저 등록 요청 버튼
  Widget _buildManagerRequestButton() {
    // pending 또는 rejected 요청이 있으면 상태 표시
    if (_pendingManagerRequest != null && !_isLoadingPendingRequest) {
      final status = _pendingManagerRequest!['status'] ?? 'pending';
      final isRejected = status == 'rejected';

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '매니저 등록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRejected ? Colors.red[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRejected ? '거절됨' : '신청 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: isRejected ? Colors.red[700] : Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '사업자명',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        _pendingManagerRequest!['business_name'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.numbers, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '사업자등록번호',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        _pendingManagerRequest!['business_number'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  if (_pendingManagerRequest!['requested_at'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '신청일시',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Text(
                          _formatRequestDate(
                            _pendingManagerRequest!['requested_at'],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRejected
                  ? '매니저 등록 요청이 거절되었습니다.'
                  : '승인 대기 중입니다. 승인 완료 시 회사 매니저로 등록됩니다.',
              style: TextStyle(
                fontSize: 13,
                color: isRejected ? Colors.red[600] : Colors.grey[600],
                fontStyle: isRejected ? FontStyle.normal : FontStyle.italic,
                fontWeight: isRejected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (!isRejected) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelManagerRequestDialog(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    '신청 취소',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[600],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // pending 요청이 없으면 새로 신청하는 버튼
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매니저 등록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '광고주 등록이 완료된 회사의 매니저로 등록을 요청할 수 있습니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showManagerRequestDialog(),
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text(
                '매니저 등록 요청',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 신청일시 포맷팅
  String _formatRequestDate(dynamic dateValue) {
    try {
      if (dateValue == null) return '';

      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return '';
      }

      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  /// 매니저 등록 요청 취소 다이얼로그
  void _showCancelManagerRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신청 취소'),
        content: const Text('매니저 등록 요청을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelManagerRequest();
            },
            child: Text('예', style: TextStyle(color: Colors.red[600])),
          ),
        ],
      ),
    );
  }

  /// 매니저 등록 요청 취소
  Future<void> _cancelManagerRequest() async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return;
      }

      await CompanyService.cancelManagerRequest(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매니저 등록 요청이 취소되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 상태 새로고침
      await _loadPendingManagerRequest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// pending 매니저 요청 로드
  Future<void> _loadPendingManagerRequest() async {
    try {
      setState(() {
        _isLoadingPendingRequest = true;
      });

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _isLoadingPendingRequest = false;
        });
        return;
      }

      final pendingRequest = await CompanyService.getPendingManagerRequest(
        userId,
      );
      setState(() {
        _pendingManagerRequest = pendingRequest;
        _isLoadingPendingRequest = false;
      });
    } catch (e) {
      print('❌ pending 매니저 요청 로드 실패: $e');
      setState(() {
        _isLoadingPendingRequest = false;
      });
    }
  }

  /// 지갑 데이터 로드
  Future<void> _loadWalletData() async {
    try {
      final user = await _authService.currentUser;
      if (user == null) {
        return;
      }

      // 개인 지갑 로드
      final userWallet = await WalletService.getUserWallet();

      // 회사 지갑 로드 (company_users 테이블을 직접 조회하므로 user.companyId 체크 불필요)
      final companyWallets = await WalletService.getCompanyWallets();
      final companyWallet = companyWallets.isNotEmpty
          ? companyWallets.first
          : null;

      setState(() {
        _userWallet = userWallet;
        _companyWallet = companyWallet;
        _currentPoints = userWallet?.currentPoints ?? 0;
      });
    } catch (e) {
      print('❌ 지갑 데이터 로드 실패: $e');
    }
  }

  /// 매니저 등록 요청 다이얼로그
  void _showManagerRequestDialog() {
    final searchController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSearching = false;
    bool isSubmitting = false;
    List<Map<String, dynamic>> foundCompanies = [];
    String? errorMessage;
    Timer? countdownTimer;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 검색 실패 제한 관련
          const String searchFailureCountKey = 'manager_search_failure_count';
          const String searchFailureTimestampKey =
              'manager_search_failure_timestamp';
          const int maxFailureCount = 5;
          const Duration blockDuration = Duration(minutes: 5);

          // 실시간 카운트다운 시작
          void startCountdown() {
            countdownTimer?.cancel();
            countdownTimer = Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) async {
              try {
                final prefs = await SharedPreferences.getInstance();
                final failureTimestamp = prefs.getInt(
                  searchFailureTimestampKey,
                );

                if (failureTimestamp != null) {
                  final blockTime = DateTime.fromMillisecondsSinceEpoch(
                    failureTimestamp,
                  );
                  final now = DateTime.now();
                  final elapsed = now.difference(blockTime);

                  if (elapsed < blockDuration) {
                    final remainingSeconds =
                        blockDuration.inSeconds - elapsed.inSeconds;
                    final remainingMinutes = remainingSeconds ~/ 60;
                    final remainingSecs = remainingSeconds % 60;

                    setDialogState(() {
                      errorMessage =
                          '검색이 5번 연속 실패하여 5분간 차단되었습니다. ${remainingMinutes}분 ${remainingSecs}초 후에 다시 시도해주세요.';
                    });
                  } else {
                    // 차단 시간이 지났으면 리셋
                    timer.cancel();
                    countdownTimer?.cancel();
                    final prefs2 = await SharedPreferences.getInstance();
                    await prefs2.remove(searchFailureCountKey);
                    await prefs2.remove(searchFailureTimestampKey);
                    setDialogState(() {
                      errorMessage = null;
                    });
                  }
                } else {
                  timer.cancel();
                }
              } catch (e) {
                print('⚠️ 카운트다운 업데이트 실패: $e');
                timer.cancel();
              }
            });
          }

          // 검색 실패 횟수 리셋
          Future<void> resetSearchFailureCount() async {
            try {
              countdownTimer?.cancel();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(searchFailureCountKey);
              await prefs.remove(searchFailureTimestampKey);
            } catch (e) {
              print('⚠️ 검색 실패 횟수 리셋 실패: $e');
            }
          }

          // 검색 실패 횟수 증가
          Future<void> incrementSearchFailureCount() async {
            try {
              final prefs = await SharedPreferences.getInstance();
              final currentCount = prefs.getInt(searchFailureCountKey) ?? 0;
              final newCount = currentCount + 1;

              await prefs.setInt(searchFailureCountKey, newCount);

              if (newCount >= maxFailureCount) {
                // 5번 실패 시 타임스탬프 저장 및 카운트다운 시작
                await prefs.setInt(
                  searchFailureTimestampKey,
                  DateTime.now().millisecondsSinceEpoch,
                );
                startCountdown();
              }
            } catch (e) {
              print('⚠️ 검색 실패 횟수 증가 실패: $e');
            }
          }

          // 검색 차단 확인
          Future<bool> isSearchBlocked() async {
            try {
              final prefs = await SharedPreferences.getInstance();
              final failureCount = prefs.getInt(searchFailureCountKey) ?? 0;
              final failureTimestamp = prefs.getInt(searchFailureTimestampKey);

              if (failureCount >= maxFailureCount && failureTimestamp != null) {
                final blockTime = DateTime.fromMillisecondsSinceEpoch(
                  failureTimestamp,
                );
                final now = DateTime.now();
                final elapsed = now.difference(blockTime);

                if (elapsed < blockDuration) {
                  // 실시간 카운트다운 시작
                  startCountdown();
                  return true;
                } else {
                  // 차단 시간이 지났으면 리셋
                  await resetSearchFailureCount();
                }
              }
              return false;
            } catch (e) {
              print('⚠️ 검색 차단 확인 실패: $e');
              return false;
            }
          }

          // 검색 함수
          Future<void> searchCompany() async {
            final businessName = searchController.text.trim();

            if (businessName.isEmpty) {
              setDialogState(() {
                errorMessage = '사업자명을 입력해주세요.';
                foundCompanies = [];
              });
              return;
            }

            // 검색 차단 확인
            final blocked = await isSearchBlocked();
            if (blocked) {
              setDialogState(() {
                isSearching = false;
              });
              return;
            }

            setDialogState(() {
              isSearching = true;
              errorMessage = null;
              foundCompanies = [];
            });

            try {
              final supabase = SupabaseConfig.client;

              // 여러 결과 반환 (maybeSingle() 대신 select() 사용)
              final response = await supabase
                  .from('companies')
                  .select(
                    'id, business_name, business_number, representative_name, address',
                  )
                  .eq('business_name', businessName);

              if (response.isNotEmpty) {
                // 검색 성공 시 실패 횟수 리셋
                countdownTimer?.cancel();
                await resetSearchFailureCount();

                setDialogState(() {
                  foundCompanies = List<Map<String, dynamic>>.from(response);
                  isSearching = false;
                });
              } else {
                // 검색 실패 (결과 없음)
                await incrementSearchFailureCount();

                final prefs = await SharedPreferences.getInstance();
                final currentCount = prefs.getInt(searchFailureCountKey) ?? 0;

                setDialogState(() {
                  errorMessage =
                      '등록된 광고사를 찾을 수 없습니다. 사업자명을 정확히 입력해주세요. ($currentCount/$maxFailureCount)';
                  foundCompanies = [];
                  isSearching = false;
                });
              }
            } catch (e) {
              print('❌ 광고사 검색 실패: $e');

              // 검색 실패 (에러 발생)
              await incrementSearchFailureCount();

              final prefs = await SharedPreferences.getInstance();
              final currentCount = prefs.getInt(searchFailureCountKey) ?? 0;

              setDialogState(() {
                errorMessage =
                    '검색 중 오류가 발생했습니다: $e ($currentCount/$maxFailureCount)';
                foundCompanies = [];
                isSearching = false;
              });
            }
          }

          // 개별 회사에 대한 요청 함수
          Future<void> submitRequestForCompany(
            Map<String, dynamic> company,
          ) async {
            setDialogState(() {
              isSubmitting = true;
            });

            try {
              await CompanyService.requestManagerRole(
                businessName: company['business_name'],
                businessNumber: company['business_number'],
              );

              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${company['business_name']} 매니저 등록 요청이 완료되었습니다. 승인 대기 중입니다.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                // 회사 데이터 및 pending 요청 다시 로드
                await _loadCompanyData();
                await _loadPendingManagerRequest();
              }
            } catch (e) {
              setDialogState(() {
                isSubmitting = false;
              });

              String errorMsg = '등록 요청 실패: $e';
              if (e.toString().contains('1분 후에 다시 시도')) {
                errorMsg = '3번 틀리셨습니다. 1분 후에 다시 시도해주세요.';
              } else if (e.toString().contains('등록된 사업자정보가 없습니다')) {
                final match = RegExp(r'\((\d+)/3\)').firstMatch(e.toString());
                if (match != null) {
                  final count = match.group(1);
                  errorMsg = '등록된 광고주정보가 없습니다. ($count/3)';
                }
              }

              setDialogState(() {
                errorMessage = errorMsg;
              });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
                            const Text(
                              '광고주 - 매니저 요청',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 안내 메시지
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '광고사에 매니저로 등록을 요청할 수 있습니다.\n사업자명을 정확히 입력해주세요.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 검색 섹션
                            const Text(
                              '사업자명 검색',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: searchController,
                                    decoration: InputDecoration(
                                      labelText: '사업자명',
                                      hintText: '등록된 사업자명을 정확히 입력하세요',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: isSearching
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    onFieldSubmitted: (_) => searchCompany(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: isSearching ? null : searchCompany,
                                  icon: const Icon(Icons.search),
                                  label: const Text('검색'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 에러 메시지
                            if (errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 검색 결과 카드 리스트
                            if (foundCompanies.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                '검색 결과 (${foundCompanies.length}개)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...foundCompanies.map(
                                (company) => _buildCompanyCardInDialog(
                                  company,
                                  isSubmitting,
                                  () => submitRequestForCompany(company),
                                ),
                              ),
                            ],

                            if (isSubmitting) ...[
                              const SizedBox(height: 24),
                              const Center(child: CircularProgressIndicator()),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Actions 버튼
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                Navigator.pop(dialogContext);
                              },
                        child: const Text('취소'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      countdownTimer?.cancel();
      searchController.dispose();
    });
  }

  Widget _buildInfoRowInDialog(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
          ),
        ),
      ],
    );
  }

  // 매니저 신청 다이얼로그용 회사 카드 위젯
  Widget _buildCompanyCardInDialog(
    Map<String, dynamic> company,
    bool isSubmitting,
    VoidCallback onRequest,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company['business_name'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRowInDialog(
                    '사업자번호',
                    company['business_number'] ?? '',
                  ),
                  if (company['representative_name'] != null) ...[
                    const SizedBox(height: 4),
                    _buildInfoRowInDialog(
                      '대표자',
                      company['representative_name'] ?? '',
                    ),
                  ],
                  if (company['address'] != null) ...[
                    const SizedBox(height: 4),
                    _buildInfoRowInDialog('주소', company['address'] ?? ''),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: isSubmitting ? null : onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('신청'),
            ),
          ],
        ),
      ),
    );
  }
}
