import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloudflare_workers_service.dart';

/// R2 파일 조회 서비스
/// 
/// 로컬 개발 환경에서는 Supabase Edge Functions를 사용하고,
/// 프로덕션 환경에서는 Cloudflare Workers API를 사용합니다.
class R2UploadService {
  /// R2 파일 URL에서 파일 경로 추출
  static String _extractFilePathFromUrl(String fileUrl) {
    return CloudflareWorkersService.extractFilePathFromUrl(fileUrl);
  }

  /// R2 파일 조회용 Presigned URL 생성
  /// 
  /// 프로덕션 환경에서는 Cloudflare Workers API를 사용합니다.
  static Future<String> getPresignedUrlForViewing(
    String fileUrl, {
    bool? useWorkersApi,
  }) async {
    // 프로덕션에서는 Cloudflare Workers 사용
    final shouldUseWorkers = useWorkersApi ?? true;
    
    if (shouldUseWorkers) {
      try {
        print('🔧 Cloudflare Workers API 사용');
        return await CloudflareWorkersService.getPresignedUrlForViewing(fileUrl);
      } catch (e) {
        // Workers API 실패 시 Edge Function으로 fallback
        print('⚠️ Workers API 실패, Edge Function으로 fallback: $e');
        return _getPresignedUrlFromEdgeFunction(fileUrl);
      }
    }
    
    // 로컬 개발 환경에서는 Supabase Edge Function 사용
    return _getPresignedUrlFromEdgeFunction(fileUrl);
  }

  /// Supabase Edge Function을 사용한 Presigned URL 생성
  static Future<String> _getPresignedUrlFromEdgeFunction(String fileUrl) async {
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
