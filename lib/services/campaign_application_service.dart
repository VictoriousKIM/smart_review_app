import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';

class CampaignApplicationService {
  static final CampaignApplicationService _instance =
      CampaignApplicationService._internal();
  factory CampaignApplicationService() => _instance;
  CampaignApplicationService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

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

      // 이미 신청했는지 확인
      final existingApplication = await _supabase
          .from('campaign_participants')
          .select()
          .eq('campaign_id', campaignId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingApplication != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '이미 신청한 캠페인입니다.',
        );
      }

      // 캠페인 정보 확인
      final campaign = await _supabase
          .from('campaigns')
          .select()
          .eq('id', campaignId)
          .eq('status', 'active')
          .single();

      if (campaign == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '존재하지 않거나 비활성화된 캠페인입니다.',
        );
      }

      // 신청 데이터 삽입
      final applicationData = {
        'campaign_id': campaignId,
        'user_id': user.id,
        'status': 'applied',
        'applied_at': DateTime.now().toIso8601String(),
        'application_message': applicationMessage,
      };

      final response = await _supabase
          .from('campaign_participants')
          .insert(applicationData)
          .select()
          .single();

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
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

      dynamic query = _supabase
          .from('campaign_participants')
          .select('''
            *,
            campaigns (
              id,
              title,
              description,
              product_image_url,
              platform,
              platform_logo_url,
              product_price,
              review_reward,
              start_date,
              end_date,
              max_participants,
              current_participants,
              status
            )
          ''')
          .eq('user_id', user.id)
          .order('applied_at', ascending: false);

      if (status != null) {
        query = query.eq('status', status);
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
          .select('created_by')
          .eq('id', campaignId)
          .single();

      if (campaign['created_by'] != user.id) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: '권한이 없습니다.',
        );
      }

      dynamic query = _supabase
          .from('campaign_participants')
          .select('''
            *,
            users (
              id,
              display_name,
              email,
              review_count,
              level
            )
          ''')
          .eq('campaign_id', campaignId)
          .order('applied_at', ascending: false);

      if (status != null) {
        query = query.eq('status', status);
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
          .from('campaign_participants')
          .select('campaign_id, campaigns!inner(created_by)')
          .eq('id', applicationId)
          .single();

      // 권한 확인
      if (application['campaigns']['created_by'] != user.id) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '권한이 없습니다.',
        );
      }

      // 상태 업데이트 데이터 준비
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 상태별 추가 필드 설정
      switch (status) {
        case 'approved':
          updateData['approved_at'] = DateTime.now().toIso8601String();
          break;
        case 'rejected':
          updateData['rejected_at'] = DateTime.now().toIso8601String();
          if (rejectionReason != null) {
            updateData['rejection_reason'] = rejectionReason;
          }
          break;
        case 'completed':
          updateData['completed_at'] = DateTime.now().toIso8601String();
          break;
      }

      final response = await _supabase
          .from('campaign_participants')
          .update(updateData)
          .eq('id', applicationId)
          .select()
          .single();

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
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
          .from('campaign_participants')
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
      await _supabase
          .from('campaign_participants')
          .delete()
          .eq('id', applicationId);

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

      final response = await _supabase
          .from('campaign_participants')
          .select('status')
          .eq('user_id', user.id);

      final stats = <String, int>{
        'total': response.length,
        'applied': 0,
        'approved': 0,
        'rejected': 0,
        'completed': 0,
      };

      for (final item in response) {
        final status = item['status'] as String;
        if (stats.containsKey(status)) {
          stats[status] = stats[status]! + 1;
        }
      }

      return ApiResponse<Map<String, int>>(success: true, data: stats);
    } catch (e) {
      return ApiResponse<Map<String, int>>(
        success: false,
        error: '통계 조회 실패: $e',
      );
    }
  }
}

