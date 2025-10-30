import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../services/point_service.dart';
import '../../../models/user.dart' as app_user;
import 'business_registration_form.dart';

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
  final AuthService _authService = AuthService();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();

    // URL 파라미터로 사업자 탭을 요청한 경우 자동으로 사업자 탭으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.parse(GoRouterState.of(context).uri.toString());
      if (uri.queryParameters['tab'] == 'business') {
        _tabController.animateTo(1);
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
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

        // 포인트 정보 로드
        try {
          final wallets = await PointService.getUserWallets(user.uid);
          final personalWallet = wallets.isNotEmpty
              ? wallets.firstWhere(
                  (w) => w.walletType == 'PERSONAL',
                  orElse: () => wallets.first,
                )
              : null;

          setState(() {
            _currentPoints = personalWallet?.points ?? 0;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _currentPoints = 0;
            _isLoading = false;
          });
        }
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
        ).showSnackBar(SnackBar(content: Text('프로필 로드 실패: $e')));
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
          onPressed: () => context.go('/mypage'),
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: const Text('편집'),
            )
          else
            Row(
              children: [
                TextButton(onPressed: _cancelEdit, child: const Text('취소')),
                TextButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTabbedContent(),
    );
  }

  Widget _buildTabbedContent() {
    // 사용자가 리뷰어인 경우에만 탭 표시
    if (_user?.userType == app_user.UserType.user) {
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
                Tab(text: '사업자'),
              ],
            ),
          ),
          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileContent(), // 리뷰어 탭
                _buildBusinessTab(), // 사업자 탭
              ],
            ),
          ),
        ],
      );
    } else {
      // 광고주인 경우 탭 없이 기본 프로필만 표시
      return _buildProfileContent();
    }
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 프로필 이미지 섹션
          _buildProfileImageSection(),

          const SizedBox(height: 24),

          // 프로필 정보 섹션
          _buildProfileInfoSection(),

          const SizedBox(height: 24),

          // 계정 정보 섹션
          _buildAccountInfoSection(),

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

  Widget _buildProfileImageSection() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF137fec),
            child: Text(
              (_user?.displayName?.isNotEmpty == true)
                  ? _user!.displayName!.substring(0, 1)
                  : (_user?.email.isNotEmpty == true)
                  ? _user!.email.substring(0, 1).toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isEditing)
            CustomButton(
              text: '프로필 이미지 변경',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 이미지 변경 기능은 준비 중입니다')),
                );
              },
              backgroundColor: Colors.grey[100],
              textColor: Colors.grey[700],
            ),
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
            const Text(
              '기본 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
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

            // 사용자 타입
            _buildInfoRow('사용자 타입', _getUserTypeText()),

            const SizedBox(height: 8),

            // 광고주 인증 상태
            if (_user?.companyId != null) _buildInfoRow('광고주 인증', '인증 완료'),
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

  Widget _buildAccountInfoSection() {
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

  String _getUserTypeText() {
    if (_user?.companyId != null) {
      return '광고주';
    } else {
      return '리뷰어';
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _displayNameController.text = _user?.displayName ?? '';
      _emailController.text = _user?.email ?? '';
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        // 사용자 프로필 업데이트
        await _authService.updateUserProfile({
          'display_name': _displayNameController.text.trim(),
        });

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
          ).showSnackBar(SnackBar(content: Text('프로필 저장 실패: $e')));
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
          // 사업자등록폼 통합
          _buildBusinessRegistrationForm(),
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
      child: const BusinessRegistrationForm(),
    );
  }
}
