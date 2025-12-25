import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// SNS 플랫폼 연결 서비스
class SNSPlatformConnectionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // 캐시 키
  static const String _cacheKeyPrefix = 'sns_connections_';
  static const String _cacheTimestampKeyPrefix = 'sns_connections_timestamp_';

  // 캐시 만료 시간 (24시간)
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// 스토어 플랫폼 목록 (한글)
  static const List<String> storePlatforms = [
    '쿠팡',
    'N스토어',
    '카카오',
    '11번가',
    '지마켓',
    '옥션',
    '위메프',
  ];

  /// SNS 플랫폼 목록 (한글)
  static const List<String> snsPlatforms = [
    '네이버 블로그',
    '인스타그램',
    '유튜브',
    '틱톡',
    '네이버',
  ];

  /// 플랫폼이 스토어 플랫폼인지 확인
  static bool isStorePlatform(String platform) {
    return storePlatforms.contains(platform);
  }

  /// SNS 플랫폼 연결 생성
  static Future<Map<String, dynamic>> createConnection({
    required String platform,
    required String platformAccountId,
    required String platformAccountName,
    required String phone,
    String? address,
    String? returnAddress,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 애플리케이션 레벨 검증 (사용자 친화적 에러 메시지)
      if (isStorePlatform(platform) && (address == null || address.isEmpty)) {
        throw Exception('$platform 플랫폼은 주소 입력이 필수입니다');
      }

      // 프론트엔드 사전 검증: 계정 ID 중복 확인
      final existingConnections = await getConnections();
      final duplicateAccount = existingConnections.any(
        (conn) =>
            conn['platform'] == platform &&
            conn['platform_account_id'] == platformAccountId,
      );

      if (duplicateAccount) {
        throw Exception('이미 등록된 계정입니다');
      }

      // 프론트엔드 사전 검증: 배송주소 중복 확인 (스토어 플랫폼만)
      if (isStorePlatform(platform) && address != null && address.isNotEmpty) {
        final duplicateAddress = existingConnections.any(
          (conn) => conn['platform'] == platform && conn['address'] == address,
        );

        if (duplicateAddress) {
          throw Exception('같은 플랫폼에 동일한 배송주소가 이미 등록되어 있습니다');
        }
      }

      // RPC 함수 호출 (트랜잭션 포함)
      final result = await _supabase.rpc(
        'create_sns_connection',
        params: {
          'p_user_id': userId,
          'p_platform': platform,
          'p_platform_account_id': platformAccountId,
          'p_platform_account_name': platformAccountName,
          'p_phone': phone,
          'p_address': isStorePlatform(platform) ? address : null,
          'p_return_address': returnAddress,
        },
      );

      // 캐시 무효화
      await _invalidateCache(userId);

      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ SNS 연결 생성 실패: $e');
      rethrow;
    }
  }

  /// SNS 플랫폼 연결 수정
  static Future<Map<String, dynamic>> updateConnection({
    required String id,
    String? platformAccountName,
    String? phone,
    String? address,
    String? returnAddress,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 기존 연결 정보 조회
      final existingConnections = await getConnections();
      final currentConnection = existingConnections.firstWhere(
        (conn) => conn['id'] == id,
        orElse: () => {},
      );

      if (currentConnection.isEmpty) {
        throw Exception('SNS 연결을 찾을 수 없습니다');
      }

      final platform = currentConnection['platform'] as String;
      final currentAddress = currentConnection['address'] as String?;

      // 프론트엔드 사전 검증: 배송주소 중복 확인 (스토어 플랫폼만, 주소가 변경된 경우만)
      if (isStorePlatform(platform) &&
          address != null &&
          address.isNotEmpty &&
          address != currentAddress) {
        final duplicateAddress = existingConnections.any(
          (conn) =>
              conn['id'] != id && // 자기 자신 제외
              conn['platform'] == platform &&
              conn['address'] == address,
        );

        if (duplicateAddress) {
          throw Exception('같은 플랫폼에 동일한 배송주소가 이미 등록되어 있습니다');
        }
      }

      // RPC 함수 호출 (트랜잭션 포함)
      final result = await _supabase.rpc(
        'update_sns_connection',
        params: {
          'p_id': id,
          'p_user_id': userId,
          'p_platform_account_name': platformAccountName,
          'p_phone': phone,
          'p_address': address,
          'p_return_address': returnAddress,
        },
      );

      // 캐시 무효화
      await _invalidateCache(userId);

      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ SNS 연결 수정 실패: $e');
      rethrow;
    }
  }

  /// SNS 플랫폼 연결 삭제
  static Future<void> deleteConnection(String id) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // RPC 함수 호출 (트랜잭션 포함)
      await _supabase.rpc(
        'delete_sns_connection',
        params: {'p_id': id, 'p_user_id': userId},
      );

      // 캐시 무효화
      await _invalidateCache(userId);
    } catch (e) {
      debugPrint('❌ SNS 연결 삭제 실패: $e');
      rethrow;
    }
  }

  /// 사용자의 모든 SNS 플랫폼 연결 조회 (캐싱 적용)
  static Future<List<Map<String, dynamic>>> getConnections({
    bool forceRefresh = false,
  }) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 캐시 확인 (강제 새로고침이 아닌 경우)
      if (!forceRefresh) {
        final cachedData = await _getCachedConnections(userId);
        if (cachedData != null) {
          debugPrint('✅ 캐시에서 SNS 연결 정보 로드');
          return cachedData;
        }
      }

      // 서버에서 데이터 조회 (RPC 함수 사용, Custom JWT 세션 지원)
      debugPrint('🔄 서버에서 SNS 연결 정보 조회');
      final response =
          await _supabase.rpc(
                'get_user_sns_connections_safe',
                params: {'p_user_id': userId},
              )
              as List;

      final connections = List<Map<String, dynamic>>.from(response);

      // 캐시에 저장
      await _saveCachedConnections(userId, connections);

      return connections;
    } catch (e) {
      debugPrint('❌ SNS 연결 조회 실패: $e');

      // 에러 발생 시 캐시에서 가져오기 시도
      try {
        final userId = await AuthService.getCurrentUserId();
        if (userId != null) {
          final cachedData = await _getCachedConnections(userId);
          if (cachedData != null) {
            debugPrint('⚠️ 에러 발생으로 캐시 데이터 사용');
            return cachedData;
          }
        }
      } catch (_) {
        // 캐시 조회 실패는 무시
      }

      rethrow;
    }
  }

  /// 특정 플랫폼의 연결 조회
  static Future<List<Map<String, dynamic>>> getConnectionsByPlatform(
    String platform,
  ) async {
    try {
      // Custom JWT 세션 또는 Supabase 세션에서 사용자 ID 가져오기
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }

      // RPC 함수 호출 (Custom JWT 세션 지원)
      final response =
          await _supabase.rpc(
                'get_user_sns_connections_safe',
                params: {'p_user_id': userId, 'p_platform': platform},
              )
              as List;

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ SNS 연결 조회 실패: $e');
      rethrow;
    }
  }

  /// 플랫폼 표시 이름 반환 (한글로 직접 저장하므로 그대로 반환)
  static String getPlatformDisplayName(String platform) {
    return platform;
  }

  /// 플랫폼 아이콘 반환
  static IconData getPlatformIcon(String platform) {
    final iconMap = {
      '쿠팡': Icons.shopping_cart,
      'N스토어': Icons.store,
      '카카오': Icons.chat,
      '네이버 블로그': Icons.article,
      '인스타그램': Icons.camera_alt,
      '유튜브': Icons.play_circle_filled,
      '틱톡': Icons.music_note,
      '네이버': Icons.search,
      '11번가': Icons.shopping_bag,
      '지마켓': Icons.store_mall_directory,
      '옥션': Icons.gavel,
      '위메프': Icons.local_offer,
    };
    return iconMap[platform] ?? Icons.link;
  }

  /// 플랫폼 색상 반환
  static Color getPlatformColor(String platform) {
    final colorMap = {
      '쿠팡': const Color(0xFFFF6B00),
      'N스토어': const Color(0xFF137fec),
      '카카오': const Color(0xFFFEE500),
      '네이버 블로그': const Color(0xFF03C75A),
      '인스타그램': const Color(0xFFE4405F),
      '유튜브': const Color(0xFFFF0000),
      '틱톡': const Color(0xFF000000),
      '네이버': const Color(0xFF03C75A),
      '11번가': const Color(0xFFE60012),
      '지마켓': const Color(0xFF1A237E),
      '옥션': const Color(0xFF1976D2),
      '위메프': const Color(0xFFFF6B00),
    };
    return colorMap[platform] ?? Colors.grey;
  }

  /// 캐시에서 연결 정보 조회
  static Future<List<Map<String, dynamic>>?> _getCachedConnections(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$userId';
      final timestampKey = '$_cacheTimestampKeyPrefix$userId';

      // 캐시 존재 확인
      final cachedJson = prefs.getString(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cachedJson == null || timestamp == null) {
        return null;
      }

      // 캐시 만료 확인
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(cacheTime) > _cacheExpiration) {
        // 캐시 만료됨
        await _invalidateCache(userId);
        return null;
      }

      // JSON 파싱
      final List<dynamic> decoded = json.decode(cachedJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ 캐시 조회 실패: $e');
      return null;
    }
  }

  /// 캐시에 연결 정보 저장
  static Future<void> _saveCachedConnections(
    String userId,
    List<Map<String, dynamic>> connections,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$userId';
      final timestampKey = '$_cacheTimestampKeyPrefix$userId';

      // JSON 인코딩
      final jsonString = json.encode(connections);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 저장
      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt(timestampKey, timestamp);
    } catch (e) {
      debugPrint('⚠️ 캐시 저장 실패: $e');
      // 캐시 저장 실패는 치명적이지 않으므로 무시
    }
  }

  /// 캐시 무효화
  static Future<void> _invalidateCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$userId';
      final timestampKey = '$_cacheTimestampKeyPrefix$userId';

      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      debugPrint('⚠️ 캐시 무효화 실패: $e');
    }
  }

  /// 에러 메시지를 사용자 친화적으로 변환
  static String getErrorMessage(dynamic error) {
    if (error == null) {
      return '알 수 없는 오류가 발생했습니다';
    }

    // PostgrestException 직접 처리
    if (error is PostgrestException) {
      // message 속성에서 직접 추출
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }

    final errorString = error.toString();

    // PostgrestException 문자열에서 메시지 추출
    if (errorString.contains('PostgrestException')) {
      // "message: 이미 등록된 계정입니다" 형식에서 메시지 추출
      final messageMatch = RegExp(
        r'message:\s*([^,]+)',
      ).firstMatch(errorString);
      if (messageMatch != null) {
        return messageMatch.group(1)?.trim() ?? '오류가 발생했습니다';
      }
    }

    // 일반 Exception 처리
    if (error is Exception) {
      final message = error.toString();
      // "Exception: 메시지" 형식에서 메시지 추출
      if (message.startsWith('Exception: ')) {
        return message.substring(11);
      }
      return message;
    }

    // 기본 에러 메시지
    return errorString.contains('이미 등록된 계정')
        ? '이미 등록된 계정입니다'
        : errorString.contains('주소')
        ? '주소를 입력해주세요'
        : errorString.contains('로그인')
        ? '로그인이 필요합니다'
        : '오류가 발생했습니다. 다시 시도해주세요';
  }
}
