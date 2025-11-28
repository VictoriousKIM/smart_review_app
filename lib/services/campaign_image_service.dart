import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

/// 캠페인 이미지에서 정보를 추출하는 서비스
class CampaignImageService {
  // Workers URL (api_config_info.md 참조)
  static const String workersUrl =
      'https://smart-review-api.nightkille.workers.dev';

  /// 이미지에서 캠페인 정보 추출
  ///
  /// [imageBytes]: 이미지 바이트 데이터
  ///
  /// Returns: 추출된 캠페인 정보 또는 null
  Future<Map<String, dynamic>?> extractFromImage(Uint8List imageBytes) async {
    try {
      print('🔍 이미지 분석 시작...');

      // ✅ 웹에서는 직접 디코딩, 네이티브에서는 isolate 사용
      Map<String, int>? imageInfo;
      if (kIsWeb) {
        final image = img.decodeImage(imageBytes);
        if (image != null) {
          imageInfo = {'width': image.width, 'height': image.height};
        }
      } else {
        imageInfo = await compute(_decodeImageInIsolate, imageBytes);
      }

      if (imageInfo == null) {
        print('❌ 이미지 디코딩 실패');
        return null;
      }

      final imageWidth = imageInfo['width'] as int;
      final imageHeight = imageInfo['height'] as int;
      print('📏 실제 이미지 크기: ${imageWidth}x${imageHeight}');

      print('📤 Workers API 호출 중 (multipart/form-data)...');

      // multipart/form-data로 실제 이미지 파일 전송
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$workersUrl/api/analyze-campaign-image'),
      );

      // 이미지 타입 감지 (PNG 또는 JPEG)
      String contentType = 'image/png';
      String filename = 'campaign_image.png';

      // 이미지 시그니처 확인 (PNG: 89 50 4E 47, JPEG: FF D8 FF)
      if (imageBytes.length >= 4) {
        if (imageBytes[0] == 0xFF &&
            imageBytes[1] == 0xD8 &&
            imageBytes[2] == 0xFF) {
          contentType = 'image/jpeg';
          filename = 'campaign_image.jpg';
        } else if (imageBytes[0] == 0x89 &&
            imageBytes[1] == 0x50 &&
            imageBytes[2] == 0x4E &&
            imageBytes[3] == 0x47) {
          contentType = 'image/png';
          filename = 'campaign_image.png';
        }
      }

      // 이미지 파일 추가 (MIME 타입 명시)
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );

      // 이미지 크기 정보 추가
      request.fields['imageWidth'] = imageWidth.toString();
      request.fields['imageHeight'] = imageHeight.toString();

      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final model = result['model'] ?? 'unknown';
          print('✅ 이미지 분석 성공 (모델: $model)');
          print('📋 추출된 데이터: ${result['data']}');
          return result['data'];
        } else {
          print('❌ 이미지 분석 실패: ${result['error']}');
          return null;
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 이미지 분석 실패: $e');
      return null;
    }
  }

  /// 추출된 데이터의 유효성 검증
  ///
  /// [data]: 추출된 데이터
  ///
  /// Returns: 유효성 검증 결과 메시지
  String? validateExtractedData(Map<String, dynamic>? data) {
    if (data == null) {
      return '데이터를 추출할 수 없습니다.';
    }

    // 필수 필드 검증
    if (data['title'] == null || data['title'].toString().isEmpty) {
      return '제품명을 찾을 수 없습니다.';
    }

    if (data['productPrice'] == null || data['productPrice'] <= 0) {
      return '결제금액을 찾을 수 없습니다.';
    }

    return null; // 유효함
  }

  /// Isolate에서 실행할 이미지 디코딩 함수
  static Map<String, int>? _decodeImageInIsolate(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return null;
      }
      return {'width': image.width, 'height': image.height};
    } catch (e) {
      print('❌ Isolate에서 이미지 디코딩 실패: $e');
      return null;
    }
  }
}
