import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import '../utils/error_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // 사용자의 알림 목록 조회 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Map<String, dynamic>>>> getUserNotifications({
    bool? isRead,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // 필요한 필드만 선택하여 성능 최적화
      dynamic query = _supabase
          .from('notifications')
          .select('''
            id,
            type,
            title,
            message,
            is_read,
            read_at,
            created_at,
            related_campaign_id,
            campaigns!related_campaign_id (
              id,
              title,
              product_image_url
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (isRead != null) {
        query = query.eq('is_read', isRead);
      }

      // 페이지네이션
      final offset = (page - 1) * limit;
      query = query.range(offset, offset + limit - 1);

      final response = await query.timeout(const Duration(seconds: 10));

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

  // 알림 읽음 처리
  Future<ApiResponse<void>> markAsRead(String notificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', user.id);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '알림 읽음 처리 실패: $e');
    }
  }

  // 모든 알림 읽음 처리
  Future<ApiResponse<void>> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('is_read', false);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '모든 알림 읽음 처리 실패: $e');
    }
  }

  // 읽지 않은 알림 개수 조회 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<int>> getUnreadCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<int>(success: false, error: '로그인이 필요합니다.');
      }

      // COUNT 쿼리로 최적화
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      return ApiResponse<int>(success: true, data: response.length);
    } catch (e) {
      return ApiResponse<int>(success: false, error: '읽지 않은 알림 개수 조회 실패: $e');
    }
  }

  // 알림 삭제
  Future<ApiResponse<void>> deleteNotification(String notificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', user.id);

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

