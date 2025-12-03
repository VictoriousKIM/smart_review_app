import 'package:flutter/services.dart';

/// 전화번호 자동 포맷터
/// 숫자만 입력하면 자동으로 '-'를 추가
/// 예: 01012345678 -> 010-1234-5678
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // 숫자만 추출
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    // 숫자가 없으면 빈 문자열 반환
    if (digitsOnly.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    
    // 전화번호 포맷팅
    String formatted = '';
    
    if (digitsOnly.length <= 3) {
      // 010
      formatted = digitsOnly;
    } else if (digitsOnly.length <= 7) {
      // 010-1234
      formatted = '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3)}';
    } else if (digitsOnly.length <= 11) {
      // 010-1234-5678
      formatted =
          '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    } else {
      // 11자리 초과 시 이전 값 유지
      return oldValue;
    }
    
    // 커서 위치 계산
    final offset = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

