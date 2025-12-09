import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      debugPrint('🔍 이미지 분석 시작...');

      // ✅ Phase 2.2: 분석용 저해상도 이미지 사용 (1024px 이하)
      // 큰 이미지는 분석에 불필요하고 디코딩 시간만 늘림
      final analysisBytes = await _prepareForAnalysis(
        imageBytes,
        maxSize: 1024,
      );
      debugPrint('📏 분석용 이미지 크기: ${analysisBytes.lengthInBytes} bytes');

      // ✅ 웹에서는 직접 디코딩, 네이티브에서는 isolate 사용
      Map<String, int>? imageInfo;
      if (kIsWeb) {
        // ✅ Future.microtask로 분리하여 메인 스레드 블로킹 최소화
        final image = await Future.microtask(
          () => img.decodeImage(analysisBytes),
        );
        if (image != null) {
          imageInfo = {'width': image.width, 'height': image.height};
        }
      } else {
        imageInfo = await compute(_decodeImageInIsolate, analysisBytes);
      }

      if (imageInfo == null) {
        debugPrint('❌ 이미지 디코딩 실패');
        return null;
      }

      final imageWidth = imageInfo['width'] as int;
      final imageHeight = imageInfo['height'] as int;
      debugPrint('📏 분석용 이미지 크기: ${imageWidth}x$imageHeight');

      debugPrint('📤 Workers API 호출 중 (multipart/form-data)...');

      // multipart/form-data로 분석용 이미지 파일 전송 (원본 대신 저해상도 이미지)
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

      // ✅ 분석용 저해상도 이미지 파일 추가 (원본 대신)
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          analysisBytes, // 원본 대신 저해상도 이미지 사용
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

      debugPrint('📥 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final model = result['model'] ?? 'unknown';
          debugPrint('✅ 이미지 분석 성공 (모델: $model)');
          debugPrint('📋 추출된 데이터: ${result['data']}');
          return result['data'];
        } else {
          debugPrint('❌ 이미지 분석 실패: ${result['error']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP 에러: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 이미지 분석 실패: $e');
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

  /// ✅ Phase 2.2: 분석용 이미지 준비 (저해상도)
  /// AI 분석에는 고해상도가 불필요하므로 작은 이미지로 리사이징
  /// 웹에서는 여러 프레임에 걸쳐 처리하여 UI 블로킹 최소화
  Future<Uint8List> _prepareForAnalysis(
    Uint8List bytes, {
    int maxSize = 1024,
  }) async {
    try {
      // ✅ Step 1: 이미지 디코딩 (프레임 분리)
      img.Image? image;
      if (kIsWeb) {
        // ✅ 웹: 여러 프레임에 걸쳐 처리
        await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
        image = await Future.microtask(() => img.decodeImage(bytes));
      } else {
        // ✅ 네이티브: isolate에서 디코딩
        image = await compute(_decodeImageInIsolateForResize, bytes);
      }

      if (image == null) {
        debugPrint('⚠️ 이미지 디코딩 실패, 원본 반환');
        return bytes;
      }

      // 이미지가 null이 아니므로 non-null 타입으로 변환
      final decodedImage = image;

      // 이미 작은 이미지면 그대로 반환
      if (decodedImage.width <= maxSize && decodedImage.height <= maxSize) {
        return bytes;
      }

      // ✅ Step 2: 리사이징 계산 (프레임 분리)
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      }

      // 비율 유지하며 리사이징
      double scale = 1.0;
      if (decodedImage.width > maxSize) {
        scale = maxSize / decodedImage.width;
      }
      if (decodedImage.height > maxSize) {
        final heightScale = maxSize / decodedImage.height;
        if (heightScale < scale) {
          scale = heightScale;
        }
      }

      final newWidth = (decodedImage.width * scale).round();
      final newHeight = (decodedImage.height * scale).round();

      // ✅ Step 3: 리사이징 실행 (프레임 분리)
      img.Image resizedImage;
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
        resizedImage = await Future.microtask(
          () => img.copyResize(
            decodedImage,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.linear,
          ),
        );
      } else {
        resizedImage = await compute(
          _resizeImageInIsolate,
          _ResizeParams(imageBytes: bytes, width: newWidth, height: newHeight),
        );
      }

      // ✅ Step 4: 인코딩 (프레임 분리)
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      }

      final resizedBytes = await Future.microtask(
        () => Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85)),
      );

      debugPrint(
        '✅ 분석용 이미지 준비: ${decodedImage.width}x${decodedImage.height} -> ${newWidth}x$newHeight',
      );
      return resizedBytes;
    } catch (e) {
      debugPrint('⚠️ 분석용 이미지 준비 실패: $e, 원본 반환');
      return bytes;
    }
  }

  /// Isolate에서 실행할 이미지 디코딩 함수 (크기 정보용)
  static Map<String, int>? _decodeImageInIsolate(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return null;
      }
      return {'width': image.width, 'height': image.height};
    } catch (e) {
      debugPrint('❌ Isolate에서 이미지 디코딩 실패: $e');
      return null;
    }
  }

  /// Isolate에서 실행할 이미지 디코딩 함수 (리사이징용)
  static img.Image? _decodeImageInIsolateForResize(Uint8List imageBytes) {
    try {
      return img.decodeImage(imageBytes);
    } catch (e) {
      debugPrint('❌ Isolate에서 이미지 디코딩 실패: $e');
      return null;
    }
  }

  /// Isolate에서 실행할 이미지 리사이징 함수
  static img.Image _resizeImageInIsolate(_ResizeParams params) {
    final image = img.decodeImage(params.imageBytes);
    if (image == null) {
      throw Exception('이미지 디코딩 실패');
    }
    return img.copyResize(
      image,
      width: params.width,
      height: params.height,
      interpolation: img.Interpolation.linear,
    );
  }
}

/// 리사이징 파라미터
class _ResizeParams {
  final Uint8List imageBytes;
  final int width;
  final int height;

  _ResizeParams({
    required this.imageBytes,
    required this.width,
    required this.height,
  });
}
