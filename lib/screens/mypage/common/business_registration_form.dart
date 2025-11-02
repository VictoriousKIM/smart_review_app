import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/company_service.dart';
import '../../../services/r2_upload_service.dart';
import '../../../config/supabase_config.dart';

class BusinessRegistrationForm extends ConsumerStatefulWidget {
  const BusinessRegistrationForm({super.key});

  @override
  ConsumerState<BusinessRegistrationForm> createState() =>
      _BusinessRegistrationFormState();
}

class _BusinessRegistrationFormState
    extends ConsumerState<BusinessRegistrationForm> {
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _isProcessing = false;
  Map<String, dynamic>? _extractedData;
  bool _isValidatingBusinessNumber = false;
  bool _isBusinessNumberValid = false;
  String? _businessNumberValidationMessage;
  String? _businessStatus;
  Map<String, dynamic>? _existingCompanyData;
  bool _isLoadingExistingData = false;
  bool _isDataSaved = false;
  String? _existingImageUrl; // 기존 등록된 이미지 URL

  @override
  void initState() {
    super.initState();
    _loadExistingCompanyData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 파일 업로드 섹션
        _buildFileUploadSection(),

        const SizedBox(height: 24),

        // 사업자 정보 입력 폼
        _buildBusinessInfoForm(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFileUploadSection() {
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
            '사업자등록증 업로드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '사업자등록증 이미지를 업로드하면 AI가 자동으로 정보를 추출하고 검증합니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (_selectedFileBytes == null && _existingImageUrl == null) ...[
            GestureDetector(
              onTap: _selectFile,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '파일을 선택하세요',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    Text(
                      'JPG, PNG, PDF (최대 1MB)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_selectedFileBytes != null) ...[
            Column(
              children: [
                // 이미지 미리보기
                Container(
                  width: double.infinity,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _selectedFileBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 파일 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName ?? '파일',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              '${(_selectedFileBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _removeFile,
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 검증하기 버튼 (파일 선택되었고 아직 처리되지 않았을 때만 표시)
                if (!_isProcessing && !_isDataSaved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _processWithAI,
                      icon: const Icon(Icons.verified_user, size: 20),
                      label: const Text(
                        '검증하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                // 처리 중 표시
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI가 정보를 추출하고 검증 중입니다...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ] else if (_existingImageUrl != null &&
              _selectedFileBytes == null) ...[
            // 기존 등록된 이미지 표시
            Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<String>(
                      future: R2UploadService.getPresignedUrlForViewing(
                        _existingImageUrl!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green[600]!,
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          print('❌ Presigned URL 생성 실패: ${snapshot.error}');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[400],
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '이미지를 불러올 수 없습니다',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }

                        return CachedNetworkImage(
                          imageUrl: snapshot.data!,
                          cacheKey: _existingImageUrl, // 원본 URL을 캐시 키로 사용
                          fit: BoxFit.contain,
                          maxWidthDiskCache: 1000, // 디스크 캐시 최대 너비
                          maxHeightDiskCache: 1000, // 디스크 캐시 최대 높이
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green[600]!,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            print('❌ 이미지 로드 오류: $error');
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '이미지를 불러올 수 없습니다',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '등록된 사업자등록증 이미지',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              '이미 업로드된 이미지입니다',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _selectFile,
                        icon: Icon(Icons.edit, color: Colors.blue[600]),
                        tooltip: '새 이미지로 교체',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBusinessInfoForm() {
    if (_isLoadingExistingData) {
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
        child: const Center(child: CircularProgressIndicator()),
      );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '회사 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              if (_existingCompanyData != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '등록됨',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _buildBusinessNumberCard(),
          const SizedBox(height: 16),
          _buildInfoCard('상호명', _extractedData?['business_name'] ?? ''),
          const SizedBox(height: 16),
          _buildInfoCard('대표자명', _extractedData?['representative_name'] ?? ''),
          const SizedBox(height: 16),
          _buildInfoCard('사업장 주소', _extractedData?['business_address'] ?? ''),
          const SizedBox(height: 16),
          _buildInfoCard('업태/종목', _extractedData?['business_type'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildBusinessNumberCard() {
    final businessNumber = _extractedData?['business_number'] ?? '';
    final isEmpty = businessNumber.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty ? Colors.grey[300]! : Colors.blue[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '사업자등록번호',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isEmpty ? Colors.grey[600] : Colors.blue[700],
                ),
              ),
              const Spacer(),
              if (!isEmpty) ...[
                if (_isValidatingBusinessNumber)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isBusinessNumberValid
                          ? Colors.green
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBusinessNumberValid
                              ? Icons.check_circle
                              : Icons.verified_user,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isBusinessNumberValid ? '검증완료' : '검증중',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEmpty ? '' : businessNumber,
            style: TextStyle(
              fontSize: 16,
              color: isEmpty ? Colors.grey[400] : Colors.grey[800],
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (!isEmpty && _businessNumberValidationMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isBusinessNumberValid
                    ? Colors.green[50]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBusinessNumberValid
                      ? Colors.green[200]!
                      : Colors.red[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isBusinessNumberValid
                            ? Icons.check_circle
                            : Icons.error,
                        color: _isBusinessNumberValid
                            ? Colors.green[700]
                            : Colors.red[700],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _businessNumberValidationMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isBusinessNumberValid
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_businessStatus != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '사업자 상태: $_businessStatus',
                      style: TextStyle(
                        fontSize: 11,
                        color: _businessStatus == '계속사업자'
                            ? Colors.green[600]
                            : Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    final isEmpty = value.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty ? Colors.grey[300]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isEmpty ? Colors.grey[600] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmpty ? '' : value,
            style: TextStyle(
              fontSize: 16,
              color: isEmpty ? Colors.grey[400] : Colors.grey[800],
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      // 웹 환경에서 파일 선택이 제대로 작동하지 않는 경우를 위한 디버그 로그
      print('🔍 파일 선택 시작 - 플랫폼: ${Theme.of(context).platform}');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      print('🔍 파일 선택 결과: ${result?.files.length ?? 0}개 파일');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('🔍 선택된 파일: ${file.name}, 크기: ${file.size} bytes');

        // 파일 크기 체크 (10MB 제한)
        if (file.size > 1 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일 크기는 1MB 이하여야 합니다')),
            );
          }
          return;
        }

        // 파일을 바이트로 읽기
        final bytes = file.bytes;
        print('🔍 파일 바이트: ${bytes?.length ?? 0} bytes');

        if (bytes != null) {
          setState(() {
            _selectedFileBytes = bytes;
            _selectedFileName = file.name;
            _extractedData = null; // 새 파일 선택 시 이전 데이터 초기화
          });

          print('✅ 파일 선택 완료 - 검증하기 버튼 표시');
        } else {
          // 웹에서 bytes가 null인 경우 파일을 다시 읽기 시도
          print('❌ 파일 바이트가 null입니다');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일을 읽을 수 없습니다. 다시 시도해주세요.')),
            );
          }
        }
      } else {
        print('❌ 파일이 선택되지 않았습니다');
      }
    } catch (e) {
      print('❌ 파일 선택 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일 선택 실패: $e')));
      }
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _extractedData = null;
      _isBusinessNumberValid = false;
      _businessNumberValidationMessage = null;
      _businessStatus = null;
      _isValidatingBusinessNumber = false;
      _isDataSaved = false;
    });
  }

  /// 기존 회사 정보 로드
  Future<void> _loadExistingCompanyData() async {
    try {
      setState(() {
        _isLoadingExistingData = true;
      });

      // 현재 사용자 ID 가져오기
      SupabaseClient supabase;
      try {
        supabase = Supabase.instance.client;
      } catch (e) {
        supabase = SupabaseClient(
          SupabaseConfig.supabaseUrl,
          SupabaseConfig.supabaseAnonKey,
        );
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        print('❌ 사용자가 로그인되지 않았습니다.');
        return;
      }

      // 사용자의 회사 정보 조회
      final companyData = await CompanyService.getCompanyByUserId(user.id);

      if (companyData != null) {
        setState(() {
          _existingCompanyData = companyData;
          _extractedData = {
            'business_name': companyData['business_name'] ?? '',
            'business_number': companyData['business_number'] ?? '',
            'business_address': companyData['address'] ?? '',
            'representative_name': companyData['representative_name'] ?? '',
            'business_type': companyData['business_type'] ?? '',
          };
          _isBusinessNumberValid = true;
          _businessNumberValidationMessage = '이미 등록된 검증된 회사입니다.';
          _businessStatus = '계속사업자'; // 기존 등록된 회사는 유효한 것으로 간주
          _isDataSaved = true; // 이미 저장된 상태

          // 이미지 URL이 있으면 표시
          if (companyData['registration_file_url'] != null &&
              companyData['registration_file_url'].toString().isNotEmpty) {
            // 이미지 URL을 로드하여 표시할 수 있도록 처리
            _existingImageUrl = companyData['registration_file_url'].toString();
            print('📸 등록된 이미지 URL: $_existingImageUrl');
          }
        });

        print('✅ 기존 회사 정보 로드 완료: ${companyData['business_name']}');
      } else {
        print('ℹ️ 등록된 회사 정보가 없습니다.');
      }
    } catch (e) {
      print('❌ 기존 회사 정보 로드 실패: $e');
    } finally {
      setState(() {
        _isLoadingExistingData = false;
      });
    }
  }

  Future<void> _processWithAI() async {
    if (_selectedFileBytes == null) return;

    setState(() {
      _isProcessing = true;
      _isValidatingBusinessNumber = true;
    });

    try {
      // 통합 Workers API 호출 (AI 추출 + 검증 + 등록)
      print('🔄 통합 검증 및 등록 프로세스 시작');

      // 이미지를 base64로 인코딩
      final base64Image = base64Encode(_selectedFileBytes!);

      // 사용자 ID 가져오기
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }

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

      // AI 추출 데이터 설정
      final extractedData =
          responseData['extractedData'] as Map<String, dynamic>?;
      if (extractedData != null) {
        setState(() {
          _extractedData = extractedData;
        });
      }

      // 검증 결과 설정
      final validationResult =
          responseData['validationResult'] as Map<String, dynamic>?;
      if (validationResult != null) {
        setState(() {
          _isBusinessNumberValid = validationResult['isValid'] ?? false;
          _businessStatus = validationResult['businessStatus'];
          _businessNumberValidationMessage = _isBusinessNumberValid
              ? '유효한 사업자등록번호입니다.'
              : validationResult['errorMessage'] ?? '유효하지 않은 사업자등록번호입니다.';
        });
      }

      // 성공 여부 확인
      if (responseData['success'] == true) {
        // Workers에서 검증과 Presigned URL 생성 성공
        final presignedUrl = responseData['presignedUrl'] as String?;
        final filePath = responseData['filePath'] as String?;
        final publicUrl = responseData['publicUrl'] as String?;

        if (extractedData != null &&
            validationResult != null &&
            presignedUrl != null &&
            filePath != null &&
            publicUrl != null) {
          try {
            // 1단계: DB 저장 먼저 시도 (중복 체크 포함)
            print('💾 DB 저장 시작 (파일 업로드 전)');
            String? savedCompanyId;

            try {
              savedCompanyId = await _saveCompanyToDatabase(
                extractedData: extractedData,
                validationResult: validationResult,
                fileUrl: publicUrl,
              );
              print('✅ DB 저장 완료: $savedCompanyId');
            } catch (dbError) {
              // DB 저장 실패 시 파일 업로드하지 않음
              throw Exception('DB 저장 실패: $dbError');
            }

            // 2단계: DB 저장 성공 후 파일 업로드
            print('📤 Presigned URL로 파일 업로드 시작');
            final uploadResponse = await http.put(
              Uri.parse(presignedUrl),
              headers: {
                'Content-Type':
                    _selectedFileName?.toLowerCase().endsWith('.pdf') == true
                    ? 'application/pdf'
                    : 'image/png',
              },
              body: _selectedFileBytes!,
            );

            if (uploadResponse.statusCode != 200) {
              // 파일 업로드 실패 → DB 롤백
              print('❌ 파일 업로드 실패, DB 롤백 시작');
              try {
                await _deleteCompanyFromDatabase(savedCompanyId);
                print('✅ DB 롤백 완료');
              } catch (rollbackError) {
                print('⚠️ DB 롤백 실패: $rollbackError');
              }
              throw Exception('파일 업로드 실패: ${uploadResponse.statusCode}');
            }

            print('✅ 파일 업로드 완료: $publicUrl');

            // 성공: 회사 등록 완료
            setState(() {
              _isDataSaved = true;
              _isProcessing = false;
              _isValidatingBusinessNumber = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('인증되었습니다'),
                  backgroundColor: Colors.green,
                ),
              );
            }

            // 기존 회사 데이터 다시 로드
            await _loadExistingCompanyData();
          } catch (error) {
            // 에러 발생 시 처리
            print('❌ 처리 실패: $error');

            setState(() {
              _isProcessing = false;
              _isValidatingBusinessNumber = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('처리 실패: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // 필수 데이터 누락
          setState(() {
            _isProcessing = false;
            _isValidatingBusinessNumber = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('데이터가 누락되었습니다. 다시 시도해주세요.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // 검증 실패 또는 중복 등록 (정상 응답이지만 처리 실패)
        setState(() {
          _isProcessing = false;
          _isValidatingBusinessNumber = false;
        });

        // 중복 등록 또는 이미지 검증 실패인 경우 특별 처리
        final errorMessage = responseData['error'] ?? '처리 실패';
        final step = responseData['step'] as String?;

        if (mounted) {
          Color backgroundColor = Colors.red;
          if (step == 'duplicate') {
            backgroundColor = Colors.orange;
          } else if (step == 'image_verification') {
            backgroundColor = Colors.orange; // 이미지 검증 실패는 주황색으로 표시
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ 검증 및 등록 실패: $e');

      setState(() {
        _isProcessing = false;
        _isValidatingBusinessNumber = false;
        _isBusinessNumberValid = false;
        _businessNumberValidationMessage = '처리 중 오류 발생: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Workers에서 받은 데이터를 Supabase에 저장 (RPC 사용)
  Future<String> _saveCompanyToDatabase({
    required Map<String, dynamic> extractedData,
    required Map<String, dynamic> validationResult,
    required String fileUrl,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // RPC 함수 호출 (중복 체크 및 트랜잭션 포함)
    final result = await supabase.rpc(
      'register_company',
      params: {
        'p_user_id': user.id,
        'p_business_name': extractedData['business_name'] ?? '',
        'p_business_number': extractedData['business_number'] ?? '',
        'p_address': extractedData['business_address'] ?? '',
        'p_representative_name': extractedData['representative_name'] ?? '',
        'p_business_type': extractedData['business_type'] ?? '',
        'p_registration_file_url': fileUrl,
      },
    );

    if (result == null) {
      throw Exception('회사 등록 실패: 응답이 없습니다.');
    }

    final companyId = result['company_id'] as String?;
    if (companyId == null) {
      throw Exception('회사 등록 실패: company_id가 없습니다.');
    }

    print('✅ 회사 정보 저장 완료: $companyId');
    return companyId;
  }

  /// 회사 정보 삭제 (롤백용, RPC 사용)
  Future<void> _deleteCompanyFromDatabase(String companyId) async {
    final supabase = Supabase.instance.client;

    try {
      final result = await supabase.rpc(
        'delete_company',
        params: {'p_company_id': companyId},
      );

      if (result == null || result['success'] != true) {
        throw Exception('회사 삭제 실패');
      }

      print('✅ 회사 정보 삭제 완료: $companyId');
    } catch (e) {
      print('❌ 회사 삭제 중 오류: $e');
      rethrow;
    }
  }
}
