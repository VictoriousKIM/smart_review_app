import 'package:supabase_flutter/supabase_flutter.dart';

/// R2 파일 조회 서비스
class R2UploadService {
  /// R2 파일 URL에서 파일 경로 추출
  static String _extractFilePathFromUrl(String fileUrl) {
    // URL 형식: https://accountId.r2.cloudflarestorage.com/bucketName/filePath
    // 예: https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/smart-review-files/business-registration/2025/10/30/...
    try {
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;

      // bucketName을 제거하고 나머지 경로 조합
      if (pathSegments.length > 1) {
        return pathSegments.sublist(1).join('/');
      }

      // 만약 경로가 없으면 전체 경로에서 bucketName 제거
      final fullPath = uri.path;
      const bucketName = 'smart-review-files/';
      if (fullPath.startsWith('/$bucketName')) {
        return fullPath.substring(bucketName.length + 1);
      }

      return fullPath;
    } catch (e) {
      print('❌ 파일 경로 추출 실패: $e');
      // 폴백: URL에서 직접 경로 추출 시도
      final parts = fileUrl.split('/smart-review-files/');
      if (parts.length > 1) {
        return parts[1].split('?')[0]; // 쿼리 파라미터 제거
      }
      return '';
    }
  }

  /// R2 파일 조회용 Presigned URL 생성
  static Future<String> getPresignedUrlForViewing(String fileUrl) async {
    try {
      final filePath = _extractFilePathFromUrl(fileUrl);
      if (filePath.isEmpty) {
        throw Exception('파일 경로를 추출할 수 없습니다: $fileUrl');
      }

      print('🔍 파일 URL에서 경로 추출: $filePath');

      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'get-presigned-url',
        body: {'filePath': filePath, 'method': 'GET'},
      );

      if (response.status != 200) {
        throw Exception('Presigned URL 요청 실패: ${response.status}');
      }

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] != true ||
          responseData['presignedUrl'] == null) {
        throw Exception(
          'Presigned URL 생성 실패: ${responseData['error'] ?? '알 수 없는 오류'}',
        );
      }

      return responseData['presignedUrl'] as String;
    } catch (e) {
      print('❌ Presigned URL 생성 실패: $e');
      rethrow;
    }
  }
}
