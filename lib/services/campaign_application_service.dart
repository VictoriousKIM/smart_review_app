import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import 'campaign_log_service.dart';

class CampaignApplicationService {
  static final CampaignApplicationService _instance =
      CampaignApplicationService._internal();
  factory CampaignApplicationService() => _instance;
  CampaignApplicationService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final CampaignLogService _campaignLogService = CampaignLogService(
    SupabaseConfig.client,
  );

  // 캠페인 신청
  Future<ApiResponse<Map<String, dynamic>>> applyToCampaign({
    required String campaignId,
    String? applicationMessage,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // 캠페인 정보 확인
      final campaign = await _supabase
          .from('campaigns')
          .select()
          .eq('id', campaignId)
          .eq('status', 'active')
          .single();

      // CampaignLogService를 사용하여 신청
      // 주의: rewardType, rewardAmount는 DB에 없으므로 제거됨
      final result = await _campaignLogService.applyToCampaign(
        campaignId: campaignId,
        userId: user.id,
        applicationMessage: applicationMessage,
      );

      if (!result.success) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: result.error,
        );
      }

      // 신청 성공 응답 데이터 구성
      final responseData = {
        'id': result.data,
        'campaign_id': campaignId,
        'user_id': user.id,
        'status': 'applied',
        'applied_at': DateTime.now().toIso8601String(),
        'application_message': applicationMessage,
      };

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: responseData,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '캠페인 신청 실패: $e',
      );
    }
  }

  // 사용자의 캠페인 신청 내역 조회
  Future<ApiResponse<List<Map<String, dynamic>>>> getUserApplications({
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

      // CampaignLog를 Map으로 변환
      final applications = result.data!
          .map(
            (log) => {
              'id': log.id,
              'campaign_id': log.campaignId,
              'user_id': log.userId,
              'status': log.status,
              'applied_at': log.createdAt.toIso8601String(), // activityAt 대신 createdAt 사용
              'application_message': log.applicationMessage,
              // reward_type, reward_amount는 DB에 없으므로 제거
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
                      'start_date': log.campaign!.startDate?.toIso8601String(),
                      'end_date': log.campaign!.endDate?.toIso8601String(),
                      'max_participants': log.campaign!.maxParticipants,
                      'current_participants': log.campaign!.currentParticipants,
                      'status': log.campaign!.status,
                    }
                  : null,
            },
          )
          .toList();

      // 페이지네이션 적용
      final offset = (page - 1) * limit;
      final paginatedApplications = applications
          .skip(offset)
          .take(limit)
          .toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: paginatedApplications,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '신청 내역 조회 실패: $e',
      );
    }
  }

  // 캠페인의 신청자 목록 조회 (광고주용)
  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignApplications({
    required String campaignId,
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

      // 캠페인 소유자 확인
      final campaign = await _supabase
          .from('campaigns')
          .select('user_id')
          .eq('id', campaignId)
          .single();

      if (campaign['user_id'] != user.id) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: '권한이 없습니다.',
        );
      }

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

      // CampaignLog를 Map으로 변환
      final applications = result.data!
          .map(
            (log) => {
              'id': log.id,
              'campaign_id': log.campaignId,
              'user_id': log.userId,
              'status': log.status,
              'applied_at': log.createdAt.toIso8601String(), // activityAt 대신 createdAt 사용
              'application_message': log.applicationMessage,
              // reward_type, reward_amount는 DB에 없으므로 제거
              'users': log.user != null
                  ? {
                      'id': log.user!.uid,
                      'display_name': log.user!.displayName,
                      'email': log.user!.email,
                      'review_count': log.user!.reviewCount,
                      'level': log.user!.level,
                    }
                  : null,
            },
          )
          .toList();

      // 페이지네이션 적용
      final offset = (page - 1) * limit;
      final paginatedApplications = applications
          .skip(offset)
          .take(limit)
          .toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: paginatedApplications,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '신청자 목록 조회 실패: $e',
      );
    }
  }

  // 신청 상태 업데이트 (광고주용)
  Future<ApiResponse<Map<String, dynamic>>> updateApplicationStatus({
    required String applicationId,
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

      // 신청 정보 조회
      final application = await _supabase
          .from('campaign_action_logs')
          .select('campaign_id, campaigns!inner(user_id)')
          .eq('id', applicationId)
          .single();

      // 권한 확인
      if (application['campaigns']['user_id'] != user.id) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '권한이 없습니다.',
        );
      }

      // CampaignLogService를 사용하여 상태 업데이트
      // 주의: additionalData는 현재 사용하지 않음 (data 필드 없음)
      final result = await _campaignLogService.updateStatus(
        campaignLogId: applicationId,
        status: status,
        additionalData: null, // data 필드가 없으므로 사용하지 않음
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
          .eq('id', applicationId)
          .single();

      return ApiResponse<Map<String, dynamic>>(success: true, data: updatedLog);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '신청 상태 업데이트 실패: $e',
      );
    }
  }

  // 신청 취소 (사용자용)
  Future<ApiResponse<void>> cancelApplication(String applicationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // 신청 정보 조회 및 권한 확인
      final application = await _supabase
          .from('campaign_action_logs')
          .select('user_id, status')
          .eq('id', applicationId)
          .single();

      if (application['user_id'] != user.id) {
        return ApiResponse<void>(success: false, error: '권한이 없습니다.');
      }

      if (application['status'] != 'applied') {
        return ApiResponse<void>(
          success: false,
          error: '이미 처리된 신청은 취소할 수 없습니다.',
        );
      }

      // 신청 삭제
      await _supabase.from('campaign_events').delete().eq('id', applicationId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '신청 취소 실패: $e');
    }
  }

  // 사용자의 신청 통계 조회
  Future<ApiResponse<Map<String, int>>> getUserApplicationStats() async {
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

      // 통계 데이터 구성
      final stats = <String, int>{
        'total': result.data!.values.fold(0, (sum, count) => sum + count),
        'applied': result.data!['applied'] ?? 0,
        'approved': result.data!['approved'] ?? 0,
        'rejected': result.data!['rejected'] ?? 0,
        'completed': result.data!['payment_completed'] ?? 0,
      };

      return ApiResponse<Map<String, int>>(success: true, data: stats);
    } catch (e) {
      return ApiResponse<Map<String, int>>(
        success: false,
        error: '통계 조회 실패: $e',
      );
    }
  }
}
