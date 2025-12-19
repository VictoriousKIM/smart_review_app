import 'dart:convert';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/company_service.dart';
import '../../../services/cloudflare_workers_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/error_message_utils.dart';
import '../../../utils/phone_formatter.dart';
import '../../../config/supabase_config.dart';

class BusinessRegistrationForm extends ConsumerStatefulWidget {
  final bool hasPendingManagerRequest;
  final Future<void> Function()? onVerificationComplete;
  // 회원가입 모드 지원
  final bool isSignupMode; // true: 회원가입 모드, false: 프로필 모드
  final String? initialDisplayName; // 회원가입 모드에서 사용
  final String? initialEmail; // 회원가입 모드에서 사용
  final Function({
    required Map<String, dynamic> businessData,
    String? phone,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
  })?
  onComplete; // 회원가입 모드에서 사용

  const BusinessRegistrationForm({
    super.key,
    this.hasPendingManagerRequest = false,
    this.onVerificationComplete,
    this.isSignupMode = false,
    this.initialDisplayName,
    this.initialEmail,
    this.onComplete,
  });

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
  bool _autoApproveReviewers = true; // 리뷰어 자동승인 여부 (기본값: true)

  // 회원가입 모드용 컨트롤러
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.isSignupMode) {
      // 회원가입 모드: 기존 데이터 로드 안 함
      if (widget.initialEmail != null) {
        _emailController.text = widget.initialEmail!;
      }
      if (widget.initialDisplayName != null) {
        _displayNameController.text = widget.initialDisplayName!;
      }
      // 이름 입력 변경 시 버튼 상태 업데이트를 위한 리스너 추가
      _displayNameController.addListener(_onFormChanged);
    } else {
      // 프로필 모드: 기존 데이터 로드
      _loadExistingCompanyData();
    }
  }

  /// 폼 변경 시 버튼 상태 업데이트
  void _onFormChanged() {
    if (widget.isSignupMode) {
      setState(() {
        // 버튼 상태 업데이트를 위한 setState
      });
    }
  }

  @override
  void dispose() {
    if (widget.isSignupMode) {
      _displayNameController.removeListener(_onFormChanged);
      _emailController.dispose();
      _displayNameController.dispose();
      _phoneController.dispose();
      _bankNameController.dispose();
      _accountNumberController.dispose();
      _accountHolderController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSignupMode) {
      // 회원가입 모드: 전체 폼 래핑 (다음 버튼은 하단 고정)
      return Container(
        color: Colors.white,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),
                        const Text(
                          '기본 정보 입력',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '광고주 프로필에 필요한 정보를 입력해주세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.4,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 64),

                        // 기본 정보 입력 (회원가입 모드에서만)
                        _buildBasicInfoSection(),

                        const SizedBox(height: 32),

                        // 파일 업로드 섹션
                        _buildFileUploadSection(),

                        const SizedBox(height: 24),

                        // 광고주 정보 입력 폼
                        _buildBusinessInfoForm(),

                        const SizedBox(height: 32),

                        // 계좌정보 섹션 (제일 밑)
                        const Divider(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: const Text(
                            '계좌정보 (선택)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAccountSection(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              // 다음 버튼 (하단 고정, 너비 최대)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isProcessing || !_canCompleteSignup)
                            ? null
                            : _handleNext,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '회원가입 완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // 프로필 모드: 기존 동작
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 파일 업로드 섹션
          _buildFileUploadSection(),

          const SizedBox(height: 24),

          // 광고주 정보 입력 폼
          _buildBusinessInfoForm(),

          const SizedBox(height: 24),
        ],
      );
    }
  }

  Widget _buildFileUploadSection() {
    return Container(
      padding: widget.isSignupMode ? const EdgeInsets.all(20) : EdgeInsets.zero,
      color: widget.isSignupMode ? Colors.white : Colors.transparent,
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
          // 매니저 등록 신청 중일 때 업로드 차단
          if (widget.hasPendingManagerRequest &&
              _selectedFileBytes == null &&
              _existingImageUrl == null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange[200]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 32, color: Colors.orange[700]),
                  const SizedBox(height: 12),
                  Text(
                    '매니저 등록 신청 중',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매니저 등록 신청이 진행 중인 경우 광고주 등록을 할 수 없습니다.\n매니저 등록 신청이 완료되거나 취소된 후 다시 시도해주세요.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else if (_selectedFileBytes == null &&
              _existingImageUrl == null &&
              !widget.hasPendingManagerRequest) ...[
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
                      'JPG, PNG (최대 1MB)',
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
                // 검증하기 버튼 (파일 선택되었고 아직 처리되지 않았을 때만 표시, 매니저 신청 중이 아닐 때만)
                if (!_isProcessing &&
                    !_isDataSaved &&
                    !widget.hasPendingManagerRequest)
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
                      future:
                          CloudflareWorkersService.getPresignedUrlForViewing(
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
                          debugPrint(
                            '❌ Presigned URL 생성 실패: ${snapshot.error}',
                          );
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
                            debugPrint('❌ 이미지 로드 오류: $error');
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
        padding: widget.isSignupMode
            ? const EdgeInsets.all(20)
            : EdgeInsets.zero,
        color: widget.isSignupMode ? Colors.white : Colors.transparent,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: widget.isSignupMode ? const EdgeInsets.all(20) : EdgeInsets.zero,
      color: widget.isSignupMode ? Colors.white : Colors.transparent,
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
          // 회원가입 모드에서만 리뷰어 자동승인 체크박스 표시
          if (widget.isSignupMode) ...[
            const SizedBox(height: 24),
            _buildAutoApproveReviewersCheckbox(),
          ],
        ],
      ),
    );
  }

  /// 리뷰어 자동승인 체크박스
  Widget _buildAutoApproveReviewersCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _autoApproveReviewers,
            onChanged: (value) {
              setState(() {
                _autoApproveReviewers = value ?? true;
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '리뷰어 자동승인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '체크 시 리뷰어 신청이 자동으로 승인됩니다. 체크 해제 시 승인이 필요합니다.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessNumberCard() {
    final businessNumber = _extractedData?['business_number'] ?? '';
    final isEmpty = businessNumber.isEmpty;

    // 디버그: 화면에 표시되는 사업자등록번호 확인
    if (!isEmpty) {
      debugPrint('🖥️ 화면에 표시되는 사업자등록번호: $businessNumber');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
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
                      '광고주 상태: $_businessStatus',
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
      color: Colors.white,
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
    // 매니저 등록 신청 중일 때 파일 선택 차단
    if (widget.hasPendingManagerRequest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매니저 등록 신청 중에는 광고주 등록을 할 수 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // 웹 환경에서 파일 선택이 제대로 작동하지 않는 경우를 위한 디버그 로그
      debugPrint('🔍 파일 선택 시작 - 플랫폼: ${Theme.of(context).platform}');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      debugPrint('🔍 파일 선택 결과: ${result?.files.length ?? 0}개 파일');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('🔍 선택된 파일: ${file.name}, 크기: ${file.size} bytes');

        // 파일 확장자 검증 (이미지 파일만 허용)
        final fileName = file.name.toLowerCase();
        final isValidImage =
            fileName.endsWith('.jpg') ||
            fileName.endsWith('.jpeg') ||
            fileName.endsWith('.png');

        if (!isValidImage) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('이미지 파일만 업로드 가능합니다. (JPG, PNG)'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // 파일 크기 체크 (1MB 제한)
        if (file.size > 1 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('파일 크기는 1MB 이하여야 합니다'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // 파일을 바이트로 읽기
        Uint8List? bytes = file.bytes;
        debugPrint('🔍 파일 바이트 (file.bytes): ${bytes?.length ?? 0} bytes');

        // Android/iOS에서 file.bytes가 null인 경우 file.path를 사용하여 파일 읽기
        if (bytes == null || bytes.isEmpty) {
          if (!kIsWeb && file.path != null) {
            debugPrint('🔍 file.path를 사용하여 파일 읽기: ${file.path}');
            try {
              final fileData = File(file.path!);
              bytes = await fileData.readAsBytes();
              debugPrint('✅ 파일 경로에서 읽기 성공: ${bytes.length} bytes');
            } catch (e) {
              debugPrint('❌ 파일 경로에서 읽기 실패: $e');
              bytes = null;
            }
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            _selectedFileBytes = bytes;
            _selectedFileName = file.name;
            _extractedData = null; // 새 파일 선택 시 이전 데이터 초기화
          });

          debugPrint('✅ 파일 선택 완료 - 검증하기 버튼 표시');
        } else {
          // 파일을 읽을 수 없는 경우
          debugPrint('❌ 파일 바이트가 null이거나 비어있습니다');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('파일을 읽을 수 없습니다. 다시 시도해주세요.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        debugPrint('❌ 파일이 선택되지 않았습니다');
      }
    } catch (e) {
      debugPrint('❌ 파일 선택 중 오류 발생: $e');
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
  /// reviewer 역할인 경우 회사 정보를 로드하지 않음 (owner/manager만 조회)
  Future<void> _loadExistingCompanyData() async {
    try {
      setState(() {
        _isLoadingExistingData = true;
      });

      // 현재 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ 사용자가 로그인되지 않았습니다.');
        return;
      }

      // reviewer 역할인 경우 회사 정보를 로드하지 않음
      // owner/manager 역할만 회사 정보 조회
      final companyData = await CompanyService.getAdvertiserCompanyByUserId(
        userId,
      );

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
            debugPrint('📸 등록된 이미지 URL: $_existingImageUrl');
          }
        });

        debugPrint('✅ 기존 회사 정보 로드 완료: ${companyData['business_name']}');
      } else {
        debugPrint('ℹ️ 등록된 회사 정보가 없습니다.');
      }
    } catch (e) {
      debugPrint('❌ 기존 회사 정보 로드 실패: $e');
    } finally {
      setState(() {
        _isLoadingExistingData = false;
      });
    }
  }

  /// 에러 메시지를 유저 친화적인 메시지로 변환
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // 네트워크 관련 에러
    if (errorString.contains('socketexception') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network')) {
      return '네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인하고 다시 시도해주세요.';
    }

    // 로그인 관련 에러
    if (errorString.contains('로그인이 필요') ||
        errorString.contains('login') ||
        errorString.contains('unauthorized')) {
      return '로그인이 필요합니다. 다시 로그인해주세요.';
    }

    // DB 저장 관련 에러
    if (errorString.contains('db 저장') ||
        errorString.contains('database') ||
        errorString.contains('중복')) {
      return '이미 등록된 사업자등록번호입니다.';
    }

    // 파일 업로드 관련 에러
    if (errorString.contains('파일 업로드') ||
        errorString.contains('upload') ||
        errorString.contains('파일')) {
      return '파일 업로드에 실패했습니다. 다시 시도해주세요.';
    }

    // AI 추출 관련 에러
    if (errorString.contains('ai 추출') ||
        errorString.contains('extraction') ||
        errorString.contains('추출')) {
      return '사업자등록증 정보를 읽을 수 없습니다. 이미지가 선명한지 확인하고 다시 시도해주세요.';
    }

    // 검증 관련 에러
    if (errorString.contains('검증') ||
        errorString.contains('validation') ||
        errorString.contains('유효하지')) {
      return '사업자등록번호가 유효하지 않습니다. 다시 확인해주세요.';
    }

    // 이미지 검증 관련 에러
    if (errorString.contains('이미지 검증') ||
        errorString.contains('image_verification') ||
        errorString.contains('사업자등록증이 아닙니다')) {
      return '업로드된 이미지가 사업자등록증이 아닙니다. 사업자등록증 이미지를 업로드해주세요.';
    }

    // 일반적인 에러
    return '처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }

  Future<void> _processWithAI() async {
    if (_selectedFileBytes == null) return;

    // 매니저 등록 신청 중일 때 처리 차단
    if (widget.hasPendingManagerRequest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매니저 등록 신청 중에는 광고주 등록을 할 수 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _isValidatingBusinessNumber = true;
    });

    try {
      // 통합 Workers API 호출 (AI 추출 + 검증 + 등록)
      debugPrint('🔄 통합 검증 및 등록 프로세스 시작');

      // 이미지를 base64로 인코딩
      final base64Image = base64Encode(_selectedFileBytes!);

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
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
        // 디버그: Workers에서 받은 사업자등록번호 확인
        debugPrint('📥 Workers에서 받은 extractedData: $extractedData');
        debugPrint(
          '📥 사업자등록번호 (Workers 응답): ${extractedData['business_number']}',
        );
        setState(() {
          _extractedData = extractedData;
        });
        // 디버그: 상태에 저장된 사업자등록번호 확인
        debugPrint('💾 상태에 저장된 사업자등록번호: ${_extractedData?['business_number']}');
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
            if (widget.isSignupMode) {
              // 회원가입 모드: Workers API를 통해 파일 업로드 (CORS 문제 없음)
              // DB 저장은 나중에 create_advertiser_profile_with_company에서 처리
              debugPrint('📤 회원가입 모드: Workers API를 통해 파일 업로드 시작');

              String? uploadedFileUrl;
              try {
                final uploadResult = await CloudflareWorkersService.uploadFile(
                  fileBytes: _selectedFileBytes!,
                  fileName: _selectedFileName ?? 'business_registration.png',
                  userId: userId,
                  fileType: 'business-registration',
                  contentType:
                      _selectedFileName?.toLowerCase().endsWith('.jpg') ==
                              true ||
                          _selectedFileName?.toLowerCase().endsWith('.jpeg') ==
                              true
                      ? 'image/jpeg'
                      : 'image/png',
                );

                if (!uploadResult.success || uploadResult.url.isEmpty) {
                  throw Exception('파일 업로드 실패');
                }

                uploadedFileUrl = uploadResult.url;
                debugPrint('✅ 파일 업로드 완료: $uploadedFileUrl');
              } catch (uploadError) {
                throw Exception('파일 업로드 실패: $uploadError');
              }

              // 성공: 검증 완료 상태로 설정 (DB 저장은 하지 않음)
              // uploadedFileUrl을 상태에 저장하여 _handleNext에서 사용
              setState(() {
                _isProcessing = false;
                _isValidatingBusinessNumber = false;
                // uploadedFileUrl을 _extractedData에 저장
                if (_extractedData != null) {
                  _extractedData!['registration_file_url'] = uploadedFileUrl;
                }
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('검증이 완료되었습니다. 다음 단계로 진행하세요.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              // 프로필 모드: 파일 업로드 먼저 → DB 저장 (트랜잭션 보장)
              // 1단계: Workers API를 통해 파일 업로드 (CORS 문제 없음)
              debugPrint('📤 Workers API를 통해 파일 업로드 시작');

              String? uploadedFileUrl;
              try {
                final uploadResult = await CloudflareWorkersService.uploadFile(
                  fileBytes: _selectedFileBytes!,
                  fileName: _selectedFileName ?? 'business_registration.png',
                  userId: userId,
                  fileType: 'business-registration',
                  contentType:
                      _selectedFileName?.toLowerCase().endsWith('.jpg') ==
                              true ||
                          _selectedFileName?.toLowerCase().endsWith('.jpeg') ==
                              true
                      ? 'image/jpeg'
                      : 'image/png',
                );

                if (!uploadResult.success || uploadResult.url.isEmpty) {
                  throw Exception('파일 업로드 실패');
                }

                uploadedFileUrl = uploadResult.url;
                debugPrint('✅ 파일 업로드 완료: $uploadedFileUrl');
              } catch (uploadError) {
                // 파일 업로드 실패 시 DB 저장하지 않음
                throw Exception('파일 업로드 실패: $uploadError');
              }

              // 2단계: 파일 업로드 성공 후 DB 저장 시도
              debugPrint('💾 DB 저장 시작 (파일 업로드 성공 후)');
              String? savedCompanyId;

              try {
                savedCompanyId = await _saveCompanyToDatabase(
                  extractedData: extractedData,
                  validationResult: validationResult,
                  fileUrl: uploadedFileUrl,
                );
                debugPrint('✅ DB 저장 완료: $savedCompanyId');
              } catch (dbError) {
                // DB 저장 실패 → 업로드된 파일 삭제 (롤백)
                debugPrint('❌ DB 저장 실패, 파일 삭제 시작');
                try {
                  await CloudflareWorkersService.deleteFile(uploadedFileUrl);
                  debugPrint('✅ 파일 롤백 완료');
                } catch (rollbackError) {
                  debugPrint('⚠️ 파일 롤백 실패: $rollbackError');
                }
                throw Exception('DB 저장 실패: $dbError');
              }

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

              // 부모 스크린에 알림 (사업자 인증 완료)
              debugPrint('🔄 검증 완료 - onVerificationComplete 콜백 호출 시작');
              if (widget.onVerificationComplete != null) {
                await widget.onVerificationComplete!();
                debugPrint('✅ 검증 완료 - onVerificationComplete 콜백 호출 완료');
              } else {
                debugPrint('⚠️ 검증 완료 - onVerificationComplete 콜백이 null입니다');
              }
            }
          } catch (error) {
            // 에러 발생 시 처리
            debugPrint('❌ 처리 실패: $error');
            final userFriendlyMessage = _getUserFriendlyErrorMessage(error);

            setState(() {
              _isProcessing = false;
              _isValidatingBusinessNumber = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userFriendlyMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
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
          String userFriendlyMessage = errorMessage;

          // step에 따라 유저 친화적인 메시지로 변환
          if (step == 'duplicate') {
            backgroundColor = Colors.orange;
            userFriendlyMessage = '이미 등록된 사업자등록번호입니다.';
          } else if (step == 'image_verification') {
            backgroundColor = Colors.orange;
            userFriendlyMessage =
                '업로드된 이미지가 사업자등록증이 아닙니다. 사업자등록증 이미지를 업로드해주세요.';
          } else if (step == 'extraction') {
            userFriendlyMessage =
                '사업자등록증 정보를 읽을 수 없습니다. 이미지가 선명한지 확인하고 다시 시도해주세요.';
          } else {
            // 서버에서 온 에러 메시지도 유저 친화적으로 변환
            userFriendlyMessage = _getUserFriendlyErrorMessage(errorMessage);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFriendlyMessage),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ 검증 및 등록 실패: $e');
      final userFriendlyMessage = _getUserFriendlyErrorMessage(e);

      setState(() {
        _isProcessing = false;
        _isValidatingBusinessNumber = false;
        _isBusinessNumberValid = false;
        _businessNumberValidationMessage = userFriendlyMessage;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
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
    // 사용자 ID 가져오기 (Custom JWT 세션 지원)
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final supabase = Supabase.instance.client;

    // 디버그: DB 저장 전 사업자등록번호 확인
    final businessNumber = extractedData['business_number'] ?? '';
    debugPrint('💾 DB 저장 전 사업자등록번호: $businessNumber');
    debugPrint('💾 DB 저장 전 extractedData: $extractedData');

    // RPC 함수 호출 (중복 체크 및 트랜잭션 포함)
    final result = await supabase.rpc(
      'register_company',
      params: {
        'p_user_id': userId,
        'p_business_name': extractedData['business_name'] ?? '',
        'p_business_number': businessNumber,
        'p_address': extractedData['business_address'] ?? '',
        'p_representative_name': extractedData['representative_name'] ?? '',
        'p_business_type': extractedData['business_type'] ?? '',
        'p_registration_file_url': fileUrl,
        'p_auto_approve_reviewers': _autoApproveReviewers,
      },
    );

    // 디버그: DB 저장 후 반환된 사업자등록번호 확인
    debugPrint('✅ DB 저장 후 반환된 사업자등록번호: ${result['business_number']}');

    if (result == null) {
      throw Exception('회사 등록 실패: 응답이 없습니다.');
    }

    final companyId = result['company_id'] as String?;
    if (companyId == null) {
      throw Exception('회사 등록 실패: company_id가 없습니다.');
    }

    debugPrint('✅ 회사 정보 저장 완료: $companyId');
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

      debugPrint('✅ 회사 정보 삭제 완료: $companyId');
    } catch (e) {
      debugPrint('❌ 회사 삭제 중 오류: $e');
      rethrow;
    }
  }

  /// 기본 정보 입력 섹션 (회원가입 모드에서만 사용)
  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 이메일 표시 (읽기 전용)
          if (widget.initialEmail != null ||
              _emailController.text.isNotEmpty) ...[
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: '이름 *',
              hintText: '이름을 입력해주세요',
              border: OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
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
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneNumberFormatter()],
            validator: (value) {
              // 빈 값은 허용 (선택 항목)
              if (value == null || value.trim().isEmpty) {
                return null;
              }
              // 값이 있으면 형식 검증
              final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
              if (digitsOnly.length < 10 || digitsOnly.length > 11) {
                return '올바른 전화번호를 입력해주세요';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// 회원가입 완료 가능 여부 확인 (필수 항목 체크)
  bool get _canCompleteSignup {
    // 이름이 입력되어 있는지 확인
    if (_displayNameController.text.trim().isEmpty) {
      return false;
    }

    // 사업자등록증이 검증되었는지 확인
    if (!_isBusinessNumberValid) {
      return false;
    }

    // 사업자 정보가 추출되었는지 확인
    if (_extractedData == null) {
      return false;
    }

    return true;
  }

  /// 다음 단계로 이동 (회원가입 모드에서만 사용)
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

    if (_extractedData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사업자 정보를 추출해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 디버그: 회원가입 완료 시 전달되는 사업자등록번호 확인
    final businessNumberForSignup = _extractedData!['business_number'] ?? '';
    debugPrint('📤 회원가입 완료 시 전달되는 사업자등록번호: $businessNumberForSignup');

    // onComplete 콜백 호출
    if (widget.onComplete != null) {
      widget.onComplete!(
        businessData: {
          'business_name': _extractedData!['business_name'] ?? '',
          'business_number': businessNumberForSignup,
          'address':
              _extractedData!['business_address'] ??
              _extractedData!['address'] ??
              '',
          'representative_name': _extractedData!['representative_name'] ?? '',
          'business_type': _extractedData!['business_type'] ?? '',
          'registration_file_url':
              _extractedData!['registration_file_url'], // 파일 업로드 후 URL
          'auto_approve_reviewers': _autoApproveReviewers,
        },
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        accountHolder: _accountHolderController.text.trim().isEmpty
            ? null
            : _accountHolderController.text.trim(),
      );
    }
  }

  /// 계좌정보 섹션 (회원가입 모드에서만 사용)
  Widget _buildAccountSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _bankNameController,
            decoration: const InputDecoration(
              labelText: '은행명',
              hintText: '은행명을 입력해주세요',
              border: OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNumberController,
            decoration: const InputDecoration(
              labelText: '계좌번호',
              hintText: '계좌번호를 입력해주세요 (예: 123-456-789012)',
              border: OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[0-9\-]'),
              ), // 숫자와 하이픈만 허용
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountHolderController,
            decoration: const InputDecoration(
              labelText: '예금주',
              hintText: '예금주명을 입력해주세요',
              border: OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
        ],
      ),
    );
  }
}
