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

  // 캠페인 신청 (RPC 사용)
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

      // RPC 함수 호출
      final response =
          await _supabase.rpc(
                'apply_to_campaign_safe',
                params: {
                  'p_campaign_id': campaignId,
                  'p_application_message': applicationMessage,
                },
              )
              as Map<String, dynamic>;

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '캠페인 신청 실패: $e',
      );
    }
  }

  // 사용자의 캠페인 신청 내역 조회 (RPC 사용)
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

      // RPC 함수 호출 (페이지네이션 포함)
      final offset = (page - 1) * limit;
      final response =
          await _supabase.rpc(
                'get_user_applications_safe',
                params: {
                  'p_status': status,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final applications = response
          .map((e) => e as Map<String, dynamic>)
          .toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: applications,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '신청 내역 조회 실패: $e',
      );
    }
  }

  // 캠페인의 신청자 목록 조회 (광고주용, RPC 사용)
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

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행, 페이지네이션 포함)
      final offset = (page - 1) * limit;
      final response =
          await _supabase.rpc(
                'get_campaign_applications_safe',
                params: {
                  'p_campaign_id': campaignId,
                  'p_status': status,
                  'p_limit': limit,
                  'p_offset': offset,
                },
              )
              as List;

      final applications = response
          .map((e) => e as Map<String, dynamic>)
          .toList();

      return ApiResponse<List<Map<String, dynamic>>>(
        success: true,
        data: applications,
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: '신청자 목록 조회 실패: $e',
      );
    }
  }

  // 신청 상태 업데이트 (광고주용, RPC 사용)
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

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행)
      final response =
          await _supabase.rpc(
                'update_application_status_safe',
                params: {
                  'p_application_id': applicationId,
                  'p_status': status,
                  'p_rejection_reason': rejectionReason,
                },
              )
              as Map<String, dynamic>;

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '신청 상태 업데이트 실패: $e',
      );
    }
  }

  // 신청 취소 (사용자용, RPC 사용)
  Future<ApiResponse<void>> cancelApplication(String applicationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (권한 체크는 RPC 함수 내부에서 수행)
      await _supabase.rpc(
        'cancel_application_safe',
        params: {'p_application_id': applicationId},
      );

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
