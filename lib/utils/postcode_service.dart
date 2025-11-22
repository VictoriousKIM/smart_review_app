import 'package:flutter/material.dart';
import '../widgets/postcode_search_dialog.dart';

/// 우편번호 찾기 서비스
/// 
/// 행정안전부 Juso API를 사용하여 모든 플랫폼(웹, Android, iOS)에서 작동합니다.
class PostcodeService {
  /// 우편번호 찾기 다이얼로그를 표시하고 결과를 콜백으로 반환
  /// 
  /// [context] BuildContext (다이얼로그 표시에 필요)
  /// [onComplete] 콜백은 다음 파라미터를 받습니다:
  /// - postalCode: 우편번호 (5자리)
  /// - address: 기본주소 (도로명주소)
  /// - extraAddress: 참고항목 (지번주소 또는 건물명)
  static Future<void> openPostcodeDialog(
    BuildContext context, {
    required Function(String postalCode, String address, String? extraAddress) onComplete,
  }) async {
    final result = await PostcodeSearchDialog.show(context);
    if (result != null) {
      onComplete(
        result.postalCode,
        result.address,
        result.extraAddress,
      );
    }
  }
}
