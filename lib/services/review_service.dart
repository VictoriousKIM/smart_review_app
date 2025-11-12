import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import 'campaign_log_service.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final CampaignLogService _campaignLogService = CampaignLogService(
    SupabaseConfig.client,
  );

  // 리뷰 작성
  Future<ApiResponse<Map<String, dynamic>>> createReview({
    required String campaignId,
    required String title,
    required String content,
    required int rating,
    String? reviewUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // 캠페인 로그 조회
      final logResult = await _campaignLogService.getCampaignLog(
        campaignId: campaignId,
        userId: user.id,
      );

      if (!logResult.success || logResult.data == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '캠페인 신청 내역을 찾을 수 없습니다.',
        );
      }

      final campaignLog = logResult.data!;

      // 리뷰 작성 가능한 상태인지 확인
      if (campaignLog.status != 'approved' &&
          campaignLog.status != 'purchased') {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '선정된 캠페인에만 리뷰를 작성할 수 있습니다.',
        );
      }

      // CampaignLogService를 사용하여 리뷰 제출
      final result = await _campaignLogService.submitReview(
        campaignLogId: campaignLog.id,
        title: title,
        content: content,
        rating: rating,
        reviewUrl: reviewUrl,
      );

      if (!result.success) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: result.error,
        );
      }

      // 리뷰 데이터 구성
      final reviewData = {
        'id': campaignLog.id,
        'campaign_id': campaignId,
        'user_id': user.id,
        'title': title,
        'content': content,
        'rating': rating,
        'review_url': reviewUrl,
        'status': 'review_submitted',
        'submitted_at': DateTime.now().toIso8601String(),
      };

      return ApiResponse<Map<String, dynamic>>(success: true, data: reviewData);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '리뷰 작성 실패: $e',
      );
    }
  }

  // 사용자의 리뷰 목록 조회
  Future<ApiResponse<List<Map<String, dynamic>>>> getUserReviews({
    String? status,
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

      // CampaignLogService를 사용하여 로그 조회
      final result = await _campaignLogService.getUserCampaignLogs(
        userId: user.id,
        status: status,
      );

      if (!result.success) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: result.error,
        );
      }

      // 리뷰가 있는 로그만 필터링
      final reviews = result.data!
          .where((log) => log.title.isNotEmpty || log.reviewContent.isNotEmpty)
          .map(
            (log) => {
              'id': log.id,
              'campaign_id': log.campaignId,
              'user_id': log.userId,
              'title': log.title,
              'content': log.reviewContent,
              'rating': log.rating,
              'review_url': log.reviewUrl,
              'status': log.status,
              'submitted_at': log.reviewSubmittedAt?.toIso8601String(),
              'approved_at': log.reviewApprovedAt?.toIso8601String(),
              'campaigns': log.campaign != null
                  ? {
                      'id': log.campaign!.id,
                      'title': log.campaign!.title,
                      'description': log.campaign!.description,
                      'product_image_url': log.campaign!.productImageUrl,
                      'platform': log.campaign!.platform,
                      'platform_logo_url': log.campaign!.platformLogoUrl,
                      'product_price': log.campaign!.productPrice,
                      'review_reward': log.campaign!.reviewReward,
                    }
                  : null,
            },
          )
          .toList();

      // 페이지네이션 적용
      final offset = (page - 1) * limit;
      final paginatedReviews = reviews.skip(offset).take(limit).toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: paginatedReviews,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '리뷰 목록 조회 실패: $e',
      );
    }
  }

  // 캠페인의 리뷰 목록 조회
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignReviews({
    required String campaignId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // CampaignLogService를 사용하여 로그 조회
      final result = await _campaignLogService.getCampaignLogs(
        campaignId: campaignId,
        status: status,
      );

      if (!result.success) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: result.error,
        );
      }

      // 리뷰가 있는 로그만 필터링
      final reviews = result.data!
          .where((log) => log.title.isNotEmpty || log.reviewContent.isNotEmpty)
          .map(
            (log) => {
              'id': log.id,
              'campaign_id': log.campaignId,
              'user_id': log.userId,
              'title': log.title,
              'content': log.reviewContent,
              'rating': log.rating,
              'review_url': log.reviewUrl,
              'status': log.status,
              'submitted_at': log.reviewSubmittedAt?.toIso8601String(),
              'approved_at': log.reviewApprovedAt?.toIso8601String(),
              'users': log.user != null
                  ? {
                      'id': log.user!.uid,
                      'display_name': log.user!.displayName,
                      'level': log.user!.level,
                      'review_count': log.user!.reviewCount,
                    }
                  : null,
            },
          )
          .toList();

      // 페이지네이션 적용
      final offset = (page - 1) * limit;
      final paginatedReviews = reviews.skip(offset).take(limit).toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: paginatedReviews,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '캠페인 리뷰 목록 조회 실패: $e',
      );
    }
  }

  // 리뷰 상태 업데이트 (광고주용)
  Future<ApiResponse<Map<String, dynamic>>> updateReviewStatus({
    required String reviewId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // 리뷰 정보 조회
      final review = await _supabase
          .from('campaign_action_logs')
          .select('campaign_id, campaigns!inner(user_id)')
          .eq('id', reviewId)
          .single();

      // 권한 확인
      if (review['campaigns']['user_id'] != user.id) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '권한이 없습니다.',
        );
      }

      // 상태별 추가 데이터 준비
      Map<String, dynamic>? additionalData;
      switch (status) {
        case 'review_approved':
          additionalData = {
            'review_approved_at': DateTime.now().toIso8601String(),
          };
          break;
        case 'rejected':
          additionalData = {
            'rejected_at': DateTime.now().toIso8601String(),
            'rejection_reason': rejectionReason,
          };
          break;
      }

      // CampaignLogService를 사용하여 상태 업데이트
      final result = await _campaignLogService.updateStatus(
        campaignLogId: reviewId,
        status: status,
        additionalData: additionalData,
      );

      if (!result.success) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: result.error,
        );
      }

      // 업데이트된 로그 조회
      final updatedLog = await _supabase
          .from('campaign_action_logs')
          .select()
          .eq('id', reviewId)
          .single();

      return ApiResponse<Map<String, dynamic>>(success: true, data: updatedLog);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '리뷰 상태 업데이트 실패: $e',
      );
    }
  }

  // 리뷰 수정
  Future<ApiResponse<Map<String, dynamic>>> updateReview({
    required String reviewId,
    required String title,
    required String content,
    required int rating,
    String? reviewUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // 리뷰 정보 조회 및 권한 확인
      final review = await _supabase
          .from('campaign_action_logs')
          .select('user_id, status, data')
          .eq('id', reviewId)
          .single();

      if (review['user_id'] != user.id) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '권한이 없습니다.',
        );
      }

      if (review['status'] == 'review_approved') {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '승인된 리뷰는 수정할 수 없습니다.',
        );
      }

      // 리뷰 데이터 업데이트
      final currentData = Map<String, dynamic>.from(review['data'] ?? {});
      currentData.addAll({
        'title': title,
        'review_content': content,
        'rating': rating,
        'review_url': reviewUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 로그 업데이트
      await _supabase
          .from('campaign_action_logs')
          .update({
            'data': currentData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId);

      // 업데이트된 데이터 반환
      final responseData = {
        'id': reviewId,
        'title': title,
        'content': content,
        'rating': rating,
        'review_url': reviewUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: responseData,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '리뷰 수정 실패: $e',
      );
    }
  }

  // 리뷰 삭제
  Future<ApiResponse<void>> deleteReview(String reviewId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // 리뷰 정보 조회 및 권한 확인
      final review = await _supabase
          .from('campaign_action_logs')
          .select('user_id, status')
          .eq('id', reviewId)
          .single();

      if (review['user_id'] != user.id) {
        return ApiResponse<void>(success: false, error: '권한이 없습니다.');
      }

      if (review['status'] == 'review_approved') {
        return ApiResponse<void>(success: false, error: '승인된 리뷰는 삭제할 수 없습니다.');
      }

      // 리뷰 데이터만 삭제 (로그는 유지)
      final currentData = Map<String, dynamic>.from(review['data'] ?? {});
      currentData.remove('title');
      currentData.remove('review_content');
      currentData.remove('rating');
      currentData.remove('review_url');
      currentData.remove('review_submitted_at');

      // 상태를 이전 단계로 되돌리기
      String previousStatus = 'approved'; // 기본적으로 approved로 되돌림
      if (review['status'] == 'review_submitted') {
        previousStatus = 'approved';
      }

      await _supabase
          .from('campaign_action_logs')
          .update({
            'status': previousStatus,
            'data': currentData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '리뷰 삭제 실패: $e');
    }
  }

  // 사용자의 리뷰 통계 조회
  Future<ApiResponse<Map<String, int>>> getUserReviewStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, int>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // CampaignLogService를 사용하여 통계 조회
      final result = await _campaignLogService.getStatusStats(userId: user.id);

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
