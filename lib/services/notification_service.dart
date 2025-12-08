import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import '../utils/error_handler.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // 사용자의 알림 목록 조회 (RPC 함수 사용, Custom JWT 세션 지원)
  Future<ApiResponse<List<Map<String, dynamic>>>> getUserNotifications({
    bool? isRead,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // 페이지네이션
      final offset = (page - 1) * limit;

      // RPC 함수 호출 (Custom JWT 세션 지원)
      final response = await _supabase.rpc(
        'get_user_notifications_safe',
        params: {
          'p_user_id': userId,
          'p_is_read': isRead,
          'p_limit': limit,
          'p_offset': offset,
        },
      ) as List;

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      ErrorHandler.handleDatabaseError(e, context: {
        'operation': 'get_user_notifications',
        'is_read': isRead,
        'page': page,
        'limit': limit,
      });
      
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '알림 조회 실패: $e',
      );
    }
  }

  // 알림 읽음 처리 (RPC 함수 사용, Custom JWT 세션 지원)
  Future<ApiResponse<void>> markAsRead(String notificationId) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (Custom JWT 세션 지원)
      await _supabase.rpc(
        'mark_notification_as_read_safe',
        params: {
          'p_notification_id': notificationId,
          'p_user_id': userId,
        },
      );

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '알림 읽음 처리 실패: $e');
    }
  }

  // 모든 알림 읽음 처리 (RPC 함수 사용, Custom JWT 세션 지원)
  Future<ApiResponse<void>> markAllAsRead() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (Custom JWT 세션 지원)
      await _supabase.rpc(
        'mark_all_notifications_as_read_safe',
        params: {
          'p_user_id': userId,
        },
      );

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '모든 알림 읽음 처리 실패: $e');
    }
  }

  // 읽지 않은 알림 개수 조회 (RPC 함수 사용, Custom JWT 세션 지원)
  Future<ApiResponse<int>> getUnreadCount() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<int>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (Custom JWT 세션 지원)
      final response = await _supabase.rpc(
        'get_user_unread_notifications_count_safe',
        params: {
          'p_user_id': userId,
        },
      ) as int;

      return ApiResponse<int>(success: true, data: response);
    } catch (e) {
      return ApiResponse<int>(success: false, error: '읽지 않은 알림 개수 조회 실패: $e');
    }
  }

  // 알림 삭제 (RPC 함수 사용, Custom JWT 세션 지원)
  Future<ApiResponse<void>> deleteNotification(String notificationId) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (Custom JWT 세션 지원)
      await _supabase.rpc(
        'delete_notification_safe',
        params: {
          'p_notification_id': notificationId,
          'p_user_id': userId,
        },
      );

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '알림 삭제 실패: $e');
    }
  }

  // 알림 생성 (시스템용 - RLS + 직접 쿼리)
  Future<ApiResponse<String>> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? relatedCampaignId,
    String? relatedCampaignLogId,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'is_read': false,
        'related_campaign_id': relatedCampaignId,
        'related_campaign_log_id': relatedCampaignLogId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('notifications')
          .insert(notificationData)
          .select('id')
          .single();

      return ApiResponse<String>(
        success: true,
        data: response['id'],
        message: '알림이 성공적으로 생성되었습니다.',
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        error: '알림 생성 실패: $e',
      );
    }
  }
}

