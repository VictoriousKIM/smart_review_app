import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

/// Cloudflare Workers API를 사용한 파일 업로드 서비스
class CloudflareWorkersService {
  /// Workers API 기본 URL
  static String get _baseUrl => SupabaseConfig.workersApiUrl;

  /// URL 변환 결과 캐시 (반복 호출 방지)
  static final Map<String, String> _urlCache = {};

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
    String? companyId, // 캠페인 이미지용
    String? productName, // 캠페인 이미지용
    String? companyName, // 사업자등록증용
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
          if (companyId != null) 'companyId': companyId,
          if (productName != null) 'productName': productName,
          if (companyName != null) 'companyName': companyName,
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
    String? companyId, // 캠페인 이미지용
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
      if (companyId != null) {
        request.fields['companyId'] = companyId;
      }

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
      var pathSegments = uri.pathSegments;

      // Workers API URL 형식인 경우 (/api/files/ 제거)
      if (pathSegments.isNotEmpty &&
          pathSegments.length >= 2 &&
          pathSegments[0] == 'api' &&
          pathSegments[1] == 'files') {
        // 'api', 'files' 제거
        pathSegments = pathSegments.sublist(2);
        // URL 디코딩 후 반환
        if (pathSegments.isNotEmpty) {
          final path = pathSegments.join('/');
          try {
            return Uri.decodeComponent(path);
          } catch (e) {
            debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
            return path;
          }
        }
      }

      // R2 직접 URL인 경우: smart-review-files/ 제거
      if (pathSegments.isNotEmpty && pathSegments[0] == 'smart-review-files') {
        // 'smart-review-files' 제거
        pathSegments = pathSegments.sublist(1);
        if (pathSegments.isNotEmpty) {
          final path = pathSegments.join('/');
          // URL 디코딩 (한글/특수문자 처리)
          try {
            return Uri.decodeComponent(path);
          } catch (e) {
            debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
            return path;
          }
        }
      }

      // 전체 경로 반환 (첫 번째 세그먼트도 포함)
      if (pathSegments.isNotEmpty) {
        final path = pathSegments.join('/');
        // URL 디코딩 (한글/특수문자 처리)
        try {
          return Uri.decodeComponent(path);
        } catch (e) {
          debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
          return path;
        }
      }

      // 만약 경로가 없으면 전체 경로에서 bucketName 제거
      final fullPath = uri.path;
      const bucketName = 'smart-review-files/';
      if (fullPath.startsWith('/$bucketName')) {
        final path = fullPath.substring(bucketName.length + 1);
        // URL 디코딩
        try {
          return Uri.decodeComponent(path);
        } catch (e) {
          debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
          return path;
        }
      }

      // 앞의 슬래시 제거
      final path = fullPath.startsWith('/') ? fullPath.substring(1) : fullPath;
      // URL 디코딩
      try {
        return Uri.decodeComponent(path);
      } catch (e) {
        debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
        return path;
      }
    } catch (e) {
      debugPrint('❌ 파일 경로 추출 실패: $e');
      // 폴백: URL에서 직접 경로 추출 시도 (R2 URL)
      if (fileUrl.contains('.r2.cloudflarestorage.com/')) {
        final parts = fileUrl.split('.r2.cloudflarestorage.com/');
        if (parts.length > 1) {
          final pathWithQuery = parts[1];
          final path = pathWithQuery.split('?')[0]; // 쿼리 파라미터 제거
          
          debugPrint('🔍 폴백 경로 추출 (R2 URL 직접 파싱): $path');
          
          // smart-review-files/ 제거
          if (path.startsWith('smart-review-files/')) {
            final cleanPath = path.substring('smart-review-files/'.length);
            debugPrint('🔍 폴백 경로 추출 (smart-review-files 제거): $cleanPath');
            // URL 디코딩
            try {
              final decoded = Uri.decodeComponent(cleanPath);
              debugPrint('✅ 폴백 경로 추출 성공: $decoded');
              return decoded;
            } catch (e) {
              debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
              return cleanPath;
            }
          }
          
          // URL 디코딩
          try {
            final decoded = Uri.decodeComponent(path);
            debugPrint('✅ 폴백 경로 추출 성공 (smart-review-files 없음): $decoded');
            return decoded;
          } catch (e) {
            debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
            return path;
          }
        }
      }
      // Workers API URL 형식인 경우
      if (fileUrl.contains('/api/files/')) {
        final parts = fileUrl.split('/api/files/');
        if (parts.length > 1) {
          final pathWithQuery = parts[1];
          final path = pathWithQuery.split('?')[0]; // 쿼리 파라미터 제거
          // URL 디코딩
          try {
            return Uri.decodeComponent(path);
          } catch (e) {
            debugPrint('⚠️ URL 디코딩 실패 (원본 사용): $e');
            return path;
          }
        }
      }
      return '';
    }
  }

  /// R2 파일 삭제 (Workers API 사용)
  static Future<void> deleteFile(String fileUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/delete-file'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fileUrl': fileUrl}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          debugPrint('✅ 파일 삭제 성공: $fileUrl');
          return;
        } else {
          throw Exception(data['error'] ?? '파일 삭제 실패');
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorData['error'] ?? '파일 삭제 실패: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ 파일 삭제 실패: $e');
      rethrow;
    }
  }

  /// R2 파일 조회용 URL 생성 (Workers 프록시 사용 - CORS 문제 해결)
  static Future<String> getPresignedUrlForViewing(String fileUrl) async {
    try {
      final filePath = extractFilePathFromUrl(fileUrl);
      if (filePath.isEmpty) {
        throw Exception('파일 경로를 추출할 수 없습니다: $fileUrl');
      }

      debugPrint('🔍 파일 URL에서 경로 추출: $filePath');

      // Workers 프록시 URL 사용 (CORS 문제 해결)
      // URL 인코딩하여 한글/특수문자 처리
      final encodedPath = Uri.encodeComponent(filePath);
      final proxyUrl = '$_baseUrl/api/files/$encodedPath';

      debugPrint('✅ Workers 프록시 URL 생성: $proxyUrl');

      return proxyUrl;
    } catch (e) {
      debugPrint('❌ URL 생성 실패: $e');
      rethrow;
    }
  }

  /// R2 URL을 Workers 프록시 URL로 동기 변환 (위젯에서 사용)
  /// R2 직접 URL이면 Workers 프록시 URL로 변환, 이미 Workers URL이면 그대로 반환
  /// 캐싱을 통해 반복 호출 방지
  static String convertToProxyUrl(String fileUrl) {
    try {
      // 빈 URL 체크
      if (fileUrl.isEmpty) {
        return fileUrl;
      }

      // 캐시 확인
      if (_urlCache.containsKey(fileUrl)) {
        return _urlCache[fileUrl]!;
      }

      // 이미 Workers 프록시 URL인 경우 그대로 반환
      if (fileUrl.contains('/api/files/') || 
          fileUrl.contains('localhost:8787') || 
          fileUrl.contains('smart-review-api.nightkille.workers.dev')) {
        _urlCache[fileUrl] = fileUrl;
        return fileUrl;
      }

      // R2 직접 URL인지 확인
      if (!fileUrl.contains('.r2.cloudflarestorage.com')) {
        _urlCache[fileUrl] = fileUrl;
        return fileUrl;
      }

      // R2 직접 URL인 경우 경로 추출 후 Workers 프록시 URL로 변환
      final filePath = extractFilePathFromUrl(fileUrl);
      if (filePath.isEmpty) {
        _urlCache[fileUrl] = fileUrl;
        return fileUrl;
      }

      // Workers 프록시 URL 생성
      // 경로를 세그먼트별로 나누어 각각 인코딩 (슬래시 보존)
      final pathSegments = filePath.split('/');
      final encodedSegments = pathSegments.map((segment) => Uri.encodeComponent(segment)).toList();
      final encodedPath = encodedSegments.join('/');
      final proxyUrl = '$_baseUrl/api/files/$encodedPath';

      // 캐시에 저장
      _urlCache[fileUrl] = proxyUrl;

      return proxyUrl;
    } catch (e) {
      // 에러 발생 시 원본 URL 반환 및 캐싱
      _urlCache[fileUrl] = fileUrl;
      return fileUrl;
    }
  }

  /// URL 캐시 초기화 (필요 시 사용)
  static void clearUrlCache() {
    _urlCache.clear();
  }

  /// Workers API 기본 URL (외부 접근용)
  static String get workersApiUrl => SupabaseConfig.workersApiUrl;
}

/// Presigned URL 응답 모델
class PresignedUrlResponse {
  final bool success;
  final String url;
  final String filePath;
  final String? publicUrl; // Public URL 추가
  final int expiresIn;
  final int? expiresAt;
  final String method;
  final String? error;

  PresignedUrlResponse({
    required this.success,
    required this.url,
    required this.filePath,
    this.publicUrl,
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
      publicUrl: json['publicUrl'] as String?,
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
      if (publicUrl != null) 'publicUrl': publicUrl,
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
