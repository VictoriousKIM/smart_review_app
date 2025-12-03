import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../config/supabase_config.dart';

/// 광고주 회원가입 - 사업자 인증 폼
class AdvertiserSignupBusinessForm extends StatefulWidget {
  final String? initialDisplayName;
  final Function({required Map<String, dynamic> businessData, String? phone})
  onComplete;

  const AdvertiserSignupBusinessForm({
    super.key,
    this.initialDisplayName,
    required this.onComplete,
  });

  @override
  State<AdvertiserSignupBusinessForm> createState() =>
      _AdvertiserSignupBusinessFormState();
}

class _AdvertiserSignupBusinessFormState
    extends State<AdvertiserSignupBusinessForm> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _representativeNameController = TextEditingController();
  final _businessTypeController = TextEditingController();

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _isProcessing = false;
  Map<String, dynamic>? _extractedData;
  bool _isBusinessNumberValid = false;
  String? _registrationFileUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialDisplayName != null) {
      _displayNameController.text = widget.initialDisplayName!;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessNumberController.dispose();
    _addressController.dispose();
    _representativeNameController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  /// 파일 선택
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedFileBytes = result.files.single.bytes;
          _selectedFileName = result.files.single.name;
          _extractedData = null;
          _isBusinessNumberValid = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일 선택 실패: $e')));
      }
    }
  }

  /// AI로 사업자 정보 추출 및 검증
  Future<void> _processWithAI() async {
    if (_selectedFileBytes == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 이미지를 base64로 인코딩
      final base64Image = base64Encode(_selectedFileBytes!);

      // Workers API 호출
      final workersApiUrl = SupabaseConfig.workersApiUrl;
      final response = await http.post(
        Uri.parse('$workersApiUrl/api/verify-and-register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': base64Image,
          'fileName': _selectedFileName ?? 'business_registration.png',
          'userId': userId,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? '처리 실패';
        throw Exception(errorMessage);
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception(responseData['error'] ?? '검증 실패');
      }

      // AI 추출 데이터 설정
      final extractedData =
          responseData['extractedData'] as Map<String, dynamic>?;
      if (extractedData != null) {
        setState(() {
          _extractedData = extractedData;
          _isBusinessNumberValid = true;
          _registrationFileUrl = responseData['publicUrl'] as String?;

          // 추출된 데이터로 폼 채우기
          _businessNameController.text = extractedData['business_name'] ?? '';
          _businessNumberController.text =
              extractedData['business_number'] ?? '';
          _addressController.text = extractedData['address'] ?? '';
          _representativeNameController.text =
              extractedData['representative_name'] ?? '';
          _businessTypeController.text = extractedData['business_type'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// 다음 단계로 이동
  void _handleNext() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isBusinessNumberValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사업자등록증을 검증해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onComplete(
      businessData: {
        'business_name': _businessNameController.text.trim(),
        'business_number': _businessNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'representative_name': _representativeNameController.text.trim(),
        'business_type': _businessTypeController.text.trim(),
        'registration_file_url': _registrationFileUrl,
      },
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Text(
              '사업자 인증',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              '사업자등록증을 업로드하여 인증해주세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
              // 파일 업로드
              _buildFileUploadSection(),
              const SizedBox(height: 24),
              // 기본 정보 입력
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              // 사업자 정보 입력
              if (_isBusinessNumberValid) _buildBusinessInfoSection(),
              const SizedBox(height: 32),
              // 다음 버튼
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleNext,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '다음',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '사업자등록증 업로드 *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_selectedFileBytes == null)
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('파일 선택'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFileName ?? '파일',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedFileBytes = null;
                        _selectedFileName = null;
                        _extractedData = null;
                        _isBusinessNumberValid = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processWithAI,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(_isProcessing ? '처리 중...' : '검증하기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '기본 정보',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            labelText: '이름 *',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '이름을 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: '전화번호 (선택)',
            hintText: '010-1234-5678',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildBusinessInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Text(
                '사업자등록증 검증 완료',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '사업자 정보',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _businessNameController,
          decoration: const InputDecoration(
            labelText: '상호명 *',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '상호명을 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessNumberController,
          decoration: const InputDecoration(
            labelText: '사업자등록번호 *',
            border: OutlineInputBorder(),
          ),
          enabled: false, // AI 추출된 값이므로 수정 불가
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: '사업장 주소 *',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '사업장 주소를 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _representativeNameController,
          decoration: const InputDecoration(
            labelText: '대표자명 *',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '대표자명을 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessTypeController,
          decoration: const InputDecoration(
            labelText: '업종',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
