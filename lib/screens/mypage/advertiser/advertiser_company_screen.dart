import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserCompanyScreen extends ConsumerStatefulWidget {
  const AdvertiserCompanyScreen({super.key});

  @override
  ConsumerState<AdvertiserCompanyScreen> createState() =>
      _AdvertiserCompanyScreenState();
}

class _AdvertiserCompanyScreenState
    extends ConsumerState<AdvertiserCompanyScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic> _companyInfo = {};
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _businessNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _businessNumberController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyInfo() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _companyInfo = {
        'companyName': '스마트테크 주식회사',
        'businessNumber': '123-45-67890',
        'address': '서울특별시 강남구 테헤란로 123',
        'phone': '02-1234-5678',
        'email': 'contact@smarttech.com',
        'role': 'owner',
        'roleText': '회사 소유자',
        'joinDate': '2023-01-15',
        'status': 'verified',
        'statusText': '인증 완료',
      };
      _companyNameController.text = _companyInfo['companyName'];
      _businessNumberController.text = _companyInfo['businessNumber'];
      _addressController.text = _companyInfo['address'];
      _phoneController.text = _companyInfo['phone'];
      _emailController.text = _companyInfo['email'];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('회사 정보'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/advertiser'),
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
                  onPressed: _saveCompanyInfo,
                  child: const Text('저장'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCompanyContent(),
    );
  }

  Widget _buildCompanyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 회사 상태 카드
          _buildStatusCard(),

          const SizedBox(height: 24),

          // 회사 정보 섹션
          _buildCompanyInfoSection(),

          const SizedBox(height: 24),

          // 계정 정보 섹션
          _buildAccountInfoSection(),

          const SizedBox(height: 32),

          // 관리 기능 버튼들
          _buildManagementButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    switch (_companyInfo['status']) {
      case 'verified':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

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
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(Icons.business, color: statusColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyInfo['companyName'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _companyInfo['statusText'],
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoSection() {
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
              '회사 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),

            // 회사명
            _buildFormField(
              label: '회사명',
              controller: _companyNameController,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '회사명을 입력해주세요';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 사업자등록번호
            _buildFormField(
              label: '사업자등록번호',
              controller: _businessNumberController,
              enabled: false, // 사업자등록번호는 변경 불가
              validator: null,
            ),

            const SizedBox(height: 16),

            // 주소
            _buildFormField(
              label: '주소',
              controller: _addressController,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '주소를 입력해주세요';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 전화번호
            _buildFormField(
              label: '전화번호',
              controller: _phoneController,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '전화번호를 입력해주세요';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 이메일
            _buildFormField(
              label: '회사 이메일',
              controller: _emailController,
              enabled: _isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '이메일을 입력해주세요';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return '올바른 이메일 형식을 입력해주세요';
                }
                return null;
              },
            ),
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
          _buildInfoRow('역할', _companyInfo['roleText']),
          const SizedBox(height: 8),
          _buildInfoRow('가입일', _companyInfo['joinDate']),
        ],
      ),
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

  Widget _buildManagementButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: '회사 정보 재인증',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회사 정보 재인증 기능은 준비 중입니다')),
              );
            },
            backgroundColor: Colors.white,
            textColor: const Color(0xFF137fec),
            borderColor: const Color(0xFF137fec),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: '회사 탈퇴',
            onPressed: () {
              _showLeaveCompanyDialog();
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
      _companyNameController.text = _companyInfo['companyName'];
      _addressController.text = _companyInfo['address'];
      _phoneController.text = _companyInfo['phone'];
      _emailController.text = _companyInfo['email'];
    });
  }

  void _saveCompanyInfo() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _companyInfo['companyName'] = _companyNameController.text.trim();
        _companyInfo['address'] = _addressController.text.trim();
        _companyInfo['phone'] = _phoneController.text.trim();
        _companyInfo['email'] = _emailController.text.trim();
        _isEditing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회사 정보가 저장되었습니다')));
    }
  }

  void _showLeaveCompanyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회사 탈퇴'),
        content: const Text('정말로 회사에서 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회사 탈퇴 기능은 준비 중입니다')),
              );
            },
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
