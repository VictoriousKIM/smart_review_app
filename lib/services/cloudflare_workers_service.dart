import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

/// Cloudflare Workers API를 사용한 파일 업로드 서비스
class CloudflareWorkersService {
  /// Workers API 기본 URL
  static String get _baseUrl => SupabaseConfig.workersApiUrl;

  /// Health check
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Health check 실패: $e');
      rethrow;
    }
  }

  /// Presigned URL 생성 요청
  static Future<PresignedUrlResponse> getPresignedUrl({
    required String fileName,
    required String userId,
    required String contentType,
    required String fileType,
    String method = 'PUT',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/presigned-url'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fileName': fileName,
          'userId': userId,
          'contentType': contentType,
          'fileType': fileType,
          'method': method,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PresignedUrlResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['error'] ?? 'Presigned URL 생성 실패');
      }
    } catch (e) {
      debugPrint('❌ Presigned URL 생성 실패: $e');
      rethrow;
    }
  }

  /// 파일 직접 업로드 (Workers API 사용)
  static Future<UploadResponse> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String userId,
    required String fileType,
    required String contentType,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/upload'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      request.fields['userId'] = userId;
      request.fields['fileType'] = fileType;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return UploadResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['error'] ?? '파일 업로드 실패');
      }
    } catch (e) {
      debugPrint('❌ 파일 업로드 실패: $e');
      rethrow;
    }
  }

  /// 파일 다운로드 (Workers API 사용)
  static Future<Uint8List> getFile(String filePath) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/files/$filePath'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('파일 다운로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 파일 다운로드 실패: $e');
      rethrow;
    }
  }

  /// Presigned URL을 사용한 파일 업로드 (클라이언트에서 직접 R2에 업로드)
  static Future<void> uploadToPresignedUrl({
    required String presignedUrl,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {'Content-Type': contentType},
        body: fileBytes,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Presigned URL 업로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Presigned URL 업로드 실패: $e');
      rethrow;
    }
  }

  /// R2 파일 URL에서 파일 경로 추출
  static String extractFilePathFromUrl(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;

      // 전체 경로 반환 (첫 번째 세그먼트도 포함)
      if (pathSegments.isNotEmpty) {
        return pathSegments.join('/');
      }

      // 만약 경로가 없으면 전체 경로에서 bucketName 제거
      final fullPath = uri.path;
      const bucketName = 'smart-review-files/';
      if (fullPath.startsWith('/$bucketName')) {
        return fullPath.substring(bucketName.length + 1);
      }

      // 앞의 슬래시 제거
      return fullPath.startsWith('/') ? fullPath.substring(1) : fullPath;
    } catch (e) {
      debugPrint('❌ 파일 경로 추출 실패: $e');
      // 폴백: URL에서 직접 경로 추출 시도
      final parts = fileUrl.split('.r2.cloudflarestorage.com/');
      if (parts.length > 1) {
        final pathWithQuery = parts[1];
        return pathWithQuery.split('?')[0]; // 쿼리 파라미터 제거
      }
      return '';
    }
  }

  /// R2 파일 조회용 Presigned URL 생성 (Workers API 사용)
  static Future<String> getPresignedUrlForViewing(String fileUrl) async {
    try {
      final filePath = extractFilePathFromUrl(fileUrl);
      if (filePath.isEmpty) {
        throw Exception('파일 경로를 추출할 수 없습니다: $fileUrl');
      }

      debugPrint('🔍 파일 URL에서 경로 추출: $filePath');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/presigned-url-view'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'filePath': filePath,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          return data['url'] as String;
        } else {
          throw Exception(data['error'] ?? 'Presigned URL 생성 실패');
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['error'] ?? 'Presigned URL 생성 실패');
      }
    } catch (e) {
      debugPrint('❌ Presigned URL 생성 실패: $e');
      rethrow;
    }
  }
}

/// Presigned URL 응답 모델
class PresignedUrlResponse {
  final bool success;
  final String url;
  final String filePath;
  final int expiresIn;
  final int? expiresAt;
  final String method;
  final String? error;

  PresignedUrlResponse({
    required this.success,
    required this.url,
    required this.filePath,
    required this.expiresIn,
    this.expiresAt,
    required this.method,
    this.error,
  });

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      success: json['success'] ?? false,
      url: json['url'] ?? '',
      filePath: json['filePath'] ?? '',
      expiresIn: json['expiresIn'] ?? 0,
      expiresAt: json['expiresAt'] as int?,
      method: json['method'] ?? 'PUT',
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'url': url,
      'filePath': filePath,
      'expiresIn': expiresIn,
      'expiresAt': expiresAt,
      'method': method,
      if (error != null) 'error': error,
    };
  }
}

/// 파일 업로드 응답 모델
class UploadResponse {
  final bool success;
  final String url;
  final String key;
  final String? error;

  UploadResponse({
    required this.success,
    required this.url,
    required this.key,
    this.error,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      success: json['success'] ?? false,
      url: json['url'] ?? '',
      key: json['key'] ?? '',
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'url': url,
      'key': key,
      if (error != null) 'error': error,
    };
  }
}
