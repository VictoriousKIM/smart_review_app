import 'package:http/http.dart' as http;
import 'dart:convert';

/// 행정안전부 도로명주소 API 서비스
/// 
/// API 키 발급: https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do
/// 
/// 사용 방법:
/// 1. https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do 에서 회원가입
/// 2. 개발자 센터에서 API 키 신청
/// 3. 승인 후 아래 _apiKey 값을 실제 API 키로 교체
class JusoApiService {
  /// Juso API 키
  /// 
  /// 발급 방법:
  /// 1. https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do 접속
  /// 2. 회원가입 및 로그인
  /// 3. "도로명주소 API" 메뉴에서 신청
  /// 4. 승인 후 발급받은 API 키를 아래에 입력
  /// 
  /// 주의: API 키가 없으면 주소 검색이 작동하지 않습니다.
  static const String _apiKey = 'U01TX0FVVEgyMDI1MTEyMjExMzc0NDExNjQ4MjQ=';
  static const String _baseUrl = 'https://www.juso.go.kr/addrlink/addrLinkApi.do';

  /// 주소 검색
  /// 
  /// [keyword] 검색할 주소 키워드 (도로명, 지번, 건물명 등)
  /// [currentPage] 현재 페이지 (기본값: 1)
  /// [countPerPage] 페이지당 결과 수 (기본값: 20, 최대: 100)
  /// 
  /// 반환: 검색 결과 리스트
  static Future<List<Map<String, String>>> searchAddress(
    String keyword, {
    int currentPage = 1,
    int countPerPage = 20,
  }) async {
    if (keyword.trim().isEmpty) {
      return [];
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'confmKey': _apiKey,
          'keyword': keyword,
          'resultType': 'json',
          'currentPage': currentPage.toString(),
          'countPerPage': countPerPage.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        
        if (data['results']['common']['errorCode'] == '0') {
          final jusoList = data['results']['juso'] as List?;
          if (jusoList != null && jusoList.isNotEmpty) {
            return jusoList.map((juso) => {
              'postalCode': juso['zipNo'] as String? ?? '',
              'roadAddress': juso['roadAddr'] as String? ?? '',
              'jibunAddress': juso['jibunAddr'] as String? ?? '',
              'sido': juso['siNm'] as String? ?? '',
              'sigungu': juso['sggNm'] as String? ?? '',
              'dong': juso['emdNm'] as String? ?? '',
              'buildingName': juso['bdNm'] as String? ?? '',
            }).toList();
          }
        } else {
          final errorMessage = data['results']['common']['errorMessage'] as String?;
          throw Exception(errorMessage ?? '주소 검색 중 오류가 발생했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      // 네트워크 오류 또는 파싱 오류
      throw Exception('주소 검색 실패: ${e.toString()}');
    }

    return [];
  }
}

