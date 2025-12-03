import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 광고주 회원가입 - 입출금통장 입력 폼
class AdvertiserSignupAccountForm extends StatefulWidget {
  final Function({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  })
  onComplete;

  const AdvertiserSignupAccountForm({super.key, required this.onComplete});

  @override
  State<AdvertiserSignupAccountForm> createState() =>
      _AdvertiserSignupAccountFormState();
}

class _AdvertiserSignupAccountFormState
    extends State<AdvertiserSignupAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  void _handleComplete() {
    if (_formKey.currentState!.validate()) {
      widget.onComplete(
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountHolder: _accountHolderController.text.trim(),
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
              '입출금통장 정보',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              '포인트 출금에 사용할 계좌 정보를 입력해주세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
              // 은행명 입력
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: '은행명 *',
                  hintText: '예: 국민은행, 신한은행',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '은행명을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 계좌번호 입력
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: '계좌번호 *',
                  hintText: '계좌번호를 입력해주세요',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')), // 숫자와 하이픈만 허용
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '계좌번호를 입력해주세요';
                  }
                  // 하이픈 제거 후 길이 검증
                  final digitsOnly = value.replaceAll('-', '');
                  if (digitsOnly.length < 10) {
                    return '올바른 계좌번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 예금주명 입력
              TextFormField(
                controller: _accountHolderController,
                decoration: const InputDecoration(
                  labelText: '예금주명 *',
                  hintText: '예금주명을 입력해주세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '예금주명을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // 완료 버튼
              ElevatedButton(
                onPressed: _handleComplete,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
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
            ],
          ),
        ),
    );
  }
}
