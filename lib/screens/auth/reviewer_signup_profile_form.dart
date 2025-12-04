import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/postcode_service.dart';
import '../../utils/phone_formatter.dart';

/// 리뷰어 회원가입 - 프로필 입력 폼
class ReviewerSignupProfileForm extends StatefulWidget {
  final String? initialDisplayName;
  final String? initialEmail;
  final String? initialPhone;
  final String? initialBaseAddress; // 기본 주소
  final String? initialDetailAddress; // 상세주소
  final String? initialBankName; // 은행명
  final String? initialAccountNumber; // 계좌번호
  final String? initialAccountHolder; // 예금주
  final Function({
    required String displayName,
    String? phone,
    String? address,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
  }) onComplete;

  const ReviewerSignupProfileForm({
    super.key,
    this.initialDisplayName,
    this.initialEmail,
    this.initialPhone,
    this.initialBaseAddress,
    this.initialDetailAddress,
    this.initialBankName,
    this.initialAccountNumber,
    this.initialAccountHolder,
    required this.onComplete,
  });

  @override
  State<ReviewerSignupProfileForm> createState() =>
      _ReviewerSignupProfileFormState();
}

class _ReviewerSignupProfileFormState
    extends State<ReviewerSignupProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(ReviewerSignupProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // initialEmail이나 initialDisplayName이 변경되면 컨트롤러 업데이트
    if (widget.initialEmail != oldWidget.initialEmail ||
        widget.initialDisplayName != oldWidget.initialDisplayName ||
        widget.initialPhone != oldWidget.initialPhone ||
        widget.initialBaseAddress != oldWidget.initialBaseAddress ||
        widget.initialDetailAddress != oldWidget.initialDetailAddress ||
        widget.initialBankName != oldWidget.initialBankName ||
        widget.initialAccountNumber != oldWidget.initialAccountNumber ||
        widget.initialAccountHolder != oldWidget.initialAccountHolder) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    bool needsUpdate = false;
    
    // 이메일 업데이트
    if (widget.initialEmail != null &&
        _emailController.text != widget.initialEmail) {
      _emailController.text = widget.initialEmail!;
      needsUpdate = true;
    }
    
    // 이름 업데이트
    if (widget.initialDisplayName != null &&
        _displayNameController.text != widget.initialDisplayName) {
      _displayNameController.text = widget.initialDisplayName!;
    }
    if (widget.initialPhone != null &&
        _phoneController.text != widget.initialPhone) {
      _phoneController.text = widget.initialPhone!;
    }
    if (widget.initialBaseAddress != null &&
        _addressController.text != widget.initialBaseAddress) {
      _addressController.text = widget.initialBaseAddress!;
    }
    if (widget.initialDetailAddress != null &&
        _detailAddressController.text != widget.initialDetailAddress) {
      _detailAddressController.text = widget.initialDetailAddress!;
    }
    if (widget.initialBankName != null &&
        _bankNameController.text != widget.initialBankName) {
      _bankNameController.text = widget.initialBankName!;
    }
    if (widget.initialAccountNumber != null &&
        _accountNumberController.text != widget.initialAccountNumber) {
      _accountNumberController.text = widget.initialAccountNumber!;
    }
    if (widget.initialAccountHolder != null &&
        _accountHolderController.text != widget.initialAccountHolder) {
      _accountHolderController.text = widget.initialAccountHolder!;
    }
    
    // 이메일이 업데이트되면 UI 재빌드 필요
    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      // 주소와 상세주소를 합쳐서 전달
      String? fullAddress;
      final baseAddress = _addressController.text.trim();
      final detailAddress = _detailAddressController.text.trim();
      
      if (baseAddress.isNotEmpty) {
        fullAddress = detailAddress.isNotEmpty 
            ? '$baseAddress $detailAddress'
            : baseAddress;
      }
      
      widget.onComplete(
        displayName: _displayNameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        address: fullAddress,
        bankName: _bankNameController.text.trim().isNotEmpty
            ? _bankNameController.text.trim()
            : null,
        accountNumber: _accountNumberController.text.trim().isNotEmpty
            ? _accountNumberController.text.trim()
            : null,
        accountHolder: _accountHolderController.text.trim().isNotEmpty
            ? _accountHolderController.text.trim()
            : null,
      );
    }
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
              '리뷰어 프로필에 필요한 기본 정보를 입력해주세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
            // 이메일 표시 (읽기 전용)
            if (widget.initialEmail != null || _emailController.text.isNotEmpty)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                enabled: false,
              ),
            if (widget.initialEmail != null || _emailController.text.isNotEmpty)
              const SizedBox(height: 16),
            // 이름 입력
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: '이름 *',
                hintText: '이름을 입력해주세요',
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
            // 전화번호 입력 (선택)
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '전화번호 (선택)',
                hintText: '010-1234-5678',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                PhoneNumberFormatter(),
              ],
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
            const SizedBox(height: 16),
            // 주소 입력 (선택)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '주소 (선택)',
                      hintText: '주소를 입력해주세요',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    PostcodeService.openPostcodeDialog(
                      context,
                      onComplete: (postalCode, address, extraAddress) {
                        setState(() {
                          // 기본 주소만 저장 (extraAddress는 참고용이므로 제외)
                          _addressController.text = address;
                        });
                      },
                    );
                  },
                  child: const Text('주소 찾기'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 상세주소 입력 (선택)
            TextFormField(
              controller: _detailAddressController,
              decoration: const InputDecoration(
                labelText: '상세주소',
                hintText: '상세주소를 입력해주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            // 계좌정보 섹션
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              '계좌정보 (선택)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 은행명 입력
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: '은행명',
                hintText: '은행명을 입력해주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 계좌번호 입력
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(
                labelText: '계좌번호',
                hintText: '계좌번호를 입력해주세요',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')), // 숫자와 하이픈만 허용
              ],
            ),
            const SizedBox(height: 16),
            // 예금주 입력
            TextFormField(
              controller: _accountHolderController,
              decoration: const InputDecoration(
                labelText: '예금주',
                hintText: '예금주명을 입력해주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            // 다음 버튼
            ElevatedButton(
              onPressed: _handleNext,
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
}

