/// 리뷰 키워드 관련 유틸리티 함수
class KeywordUtils {
  /// 키워드 문자열을 정규화 (공백 제거, 빈 키워드 제거)
  /// 입력: "키워드1, 키워드2, , 키워드3 "
  /// 출력: "키워드1,키워드2,키워드3"
  static String normalizeKeywords(String input) {
    if (input.trim().isEmpty) return '';
    
    final keywords = input
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    
    return keywords.join(',');
  }

  /// 키워드 문자열을 파싱하여 리스트로 변환
  /// 입력: "키워드1,키워드2,키워드3"
  /// 출력: ["키워드1", "키워드2", "키워드3"]
  static List<String> parseKeywords(String input) {
    if (input.trim().isEmpty) return [];
    
    return input
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
  }

  /// 키워드 개수 카운트
  static int countKeywords(String input) {
    return parseKeywords(input).length;
  }

  /// 전체 텍스트 길이 계산 (콤마 포함)
  /// 예: "키워드1,키워드2" → 11 (콤마 포함)
  static int getKeywordTextLength(String input) {
    return normalizeKeywords(input).length;
  }

  /// 키워드 검증 (최대 3개, 전체 20자 이내)
  /// 반환: (isValid, errorMessage)
  static (bool, String?) validateKeywords(String input) {
    if (input.trim().isEmpty) {
      return (true, null); // 빈 값은 허용
    }

    final normalized = normalizeKeywords(input);
    final keywords = parseKeywords(normalized);
    final textLength = normalized.length;

    // 최대 3개 검증
    if (keywords.length > 3) {
      return (false, '키워드는 최대 3개까지 입력 가능합니다 (현재: ${keywords.length}개)');
    }

    // 전체 텍스트 길이 검증 (콤마 포함)
    if (textLength > 20) {
      return (false, '전체 텍스트 길이는 20자 이내여야 합니다 (현재: $textLength자)');
    }

    return (true, null);
  }
}

