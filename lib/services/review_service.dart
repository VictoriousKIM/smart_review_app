import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import 'campaign_log_service.dart';
import 'auth_service.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final CampaignLogService _campaignLogService = CampaignLogService(
    SupabaseConfig.client,
  );

  // 리뷰 작성 (RPC 사용)
  Future<ApiResponse<Map<String, dynamic>>> createReview({
    required String campaignId,
    required String title,
    required String content,
    required int rating,
    String? reviewUrl,
  }) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출 (상태 체크는 RPC 함수 내부에서 수행)
      final response =
          await _supabase.rpc(
                'create_review_safe',
                params: {
                  'p_campaign_id': campaignId,
                  'p_title': title,
                  'p_content': content,
                  'p_rating': rating,
                  'p_review_url': reviewUrl,
                },
              )
              as Map<String, dynamic>;

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '리뷰 작성 실패: $e',
      );
    }
  }

  // 사용자의 리뷰 목록 조회 (RPC 사용)
  Future<ApiResponse<List<Map<String, dynamic>>>> getUserReviews({
    String? status,
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

      // RPC 함수 호출 (페이지네이션 포함)
      final offset = (page - 1) * limit;
      final response =
          await _supabase.rpc(
                'get_user_reviews_safe',
                params: {
                  'p_status': status,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final reviews = response.map((e) => e as Map<String, dynamic>).toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: reviews,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '리뷰 목록 조회 실패: $e',
      );
    }
  }

  // 캠페인의 리뷰 목록 조회 (RPC 사용)
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignReviews({
    required String campaignId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // RPC 함수 호출 (페이지네이션 포함)
      final offset = (page - 1) * limit;
      final response =
          await _supabase.rpc(
                'get_campaign_reviews_safe',
                params: {
                  'p_campaign_id': campaignId,
                  'p_status': status,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final reviews = response.map((e) => e as Map<String, dynamic>).toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: reviews,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '캠페인 리뷰 목록 조회 실패: $e',
      );
    }
  }

  // 리뷰 상태 업데이트 (광고주용, RPC 사용)
  Future<ApiResponse<Map<String, dynamic>>> updateReviewStatus({
    required String reviewId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행)
      final response =
          await _supabase.rpc(
                'update_review_status_safe',
                params: {
                  'p_review_id': reviewId,
                  'p_status': status,
                  'p_rejection_reason': rejectionReason,
                },
              )
              as Map<String, dynamic>;

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '리뷰 상태 업데이트 실패: $e',
      );
    }
  }

  // 리뷰 수정 (RPC 사용)
  Future<ApiResponse<Map<String, dynamic>>> updateReview({
    required String reviewId,
    required String title,
    required String content,
    required int rating,
    String? reviewUrl,
  }) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행)
      final response =
          await _supabase.rpc(
                'update_review_safe',
                params: {
                  'p_review_id': reviewId,
                  'p_title': title,
                  'p_content': content,
                  'p_rating': rating,
                  'p_review_url': reviewUrl,
                },
              )
              as Map<String, dynamic>;

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '리뷰 수정 실패: $e',
      );
    }
  }

  // 리뷰 삭제 (RPC 사용)
  Future<ApiResponse<void>> deleteReview(String reviewId) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행)
      await _supabase.rpc(
        'delete_review_safe',
        params: {'p_review_id': reviewId},
      );

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '리뷰 삭제 실패: $e');
    }
  }

  // 사용자의 리뷰 통계 조회
  Future<ApiResponse<Map<String, int>>> getUserReviewStats() async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, int>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // CampaignLogService를 사용하여 통계 조회
      final result = await _campaignLogService.getStatusStats(userId: userId);

      if (!result.success) {
        return ApiResponse<Map<String, int>>(
          success: false,
          error: result.error,
        );
      }

      // 리뷰 관련 통계 구성
      final stats = <String, int>{
        'total':
            (result.data!['review_submitted'] ?? 0) +
            (result.data!['review_approved'] ?? 0),
        'submitted': result.data!['review_submitted'] ?? 0,
        'approved': result.data!['review_approved'] ?? 0,
        'rejected': result.data!['rejected'] ?? 0,
      };

      return ApiResponse<Map<String, int>>(success: true, data: stats);
    } catch (e) {
      return ApiResponse<Map<String, int>>(
        success: false,
        error: '리뷰 통계 조회 실패: $e',
      );
    }
  }
}
