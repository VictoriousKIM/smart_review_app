import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campaign_log.dart';
import '../models/api_response.dart';
import '../utils/date_time_utils.dart';

class CampaignLogService {
  final SupabaseClient _supabase;

  CampaignLogService(this._supabase);

  // 캠페인 신청
  Future<ApiResponse<String>> applyToCampaign({
    required String campaignId,
    required String userId,
    String? applicationMessage,
    // rewardType, rewardAmount는 DB에 없으므로 제거
  }) async {
    try {
      // 이미 신청했는지 확인
      final existingLog = await _supabase
          .from('campaign_action_logs')
          .select('id')
          .eq('campaign_id', campaignId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLog != null) {
        return ApiResponse<String>(success: false, error: '이미 신청한 캠페인입니다.');
      }

      // 새 로그 생성
      // action 필드는 JSONB 형식: {"type": "join", "data": {...}}
      final response = await _supabase
          .from('campaign_action_logs')
          .insert({
            'campaign_id': campaignId,
            'user_id': userId,
            'action': {'type': 'join'}, // JSONB 필드
            'application_message': applicationMessage,
            'status': 'pending', // DB 기본값
          })
          .select('id')
          .single();

      return ApiResponse<String>(success: true, data: response['id']);
    } catch (e) {
      return ApiResponse<String>(success: false, error: '신청 실패: $e');
    }
  }

  // 상태 업데이트 (단계별 진행)
  // 주의: DB에 data 필드가 없으므로 status와 action만 업데이트
  // data 필드가 필요하면 마이그레이션으로 추가 필요
  Future<ApiResponse<void>> updateStatus({
    required String campaignLogId,
    required String status,
    Map<String, dynamic>? additionalData, // 현재는 사용하지 않음 (data 필드 없음)
  }) async {
    try {
      // 현재 로그 조회
      final currentLog = await _supabase
          .from('campaign_action_logs')
          .select('status, campaign_id, campaigns!inner(campaign_type)')
          .eq('id', campaignLogId)
          .single();

      // 상태 유효성 검증
      if (!_isValidStatusTransition(
        currentLog['status'],
        status,
        currentLog['campaigns']['campaign_type'],
      )) {
        return ApiResponse<void>(success: false, error: '유효하지 않은 상태 전환입니다.');
      }

      // action 필드 결정 (status에 따라)
      String actionType = _getActionFromStatus(status);

      // 로그 업데이트 (status와 action만)
      // action 필드는 JSONB 형식: {"type": "join", "data": {...}}
      await _supabase
          .from('campaign_action_logs')
          .update({
            'status': status,
            'action': {'type': actionType},
            'updated_at': DateTimeUtils.toIso8601StringKST(DateTimeUtils.nowKST()),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '상태 업데이트 실패: $e');
    }
  }

  // status에 따른 action 값 반환
  String _getActionFromStatus(String status) {
    switch (status) {
      case 'applied':
        return 'join';
      case 'approved':
        return 'join';
      case 'rejected':
        return 'leave';
      case 'completed':
      case 'payment_completed':
        return 'complete';
      case 'cancelled':
        return 'cancel';
      default:
        return '진행상황_저장';
    }
  }

  // 상태 전환 유효성 검증
  bool _isValidStatusTransition(
    String currentStatus,
    String newStatus,
    String campaignType,
  ) {
    final validTransitions = {
      'review': [
        'applied',
        'approved',
        'purchased',
        'review_submitted',
        'review_approved',
        'payment_completed',
      ],
      'visit': [
        'applied',
        'approved',
        'visit_completed',
        'visit_verified',
        'payment_completed',
      ],
      'press': [
        'applied',
        'approved',
        'article_submitted',
        'article_approved',
        'payment_completed',
      ],
    };

    final validStatuses = validTransitions[campaignType] ?? [];
    final currentIndex = validStatuses.indexOf(currentStatus);
    final newIndex = validStatuses.indexOf(newStatus);

    return newIndex > currentIndex && newIndex - currentIndex == 1;
  }

  // 상태별 특수 로직 처리
  // 주의: 이 메서드는 현재 사용하지 않음
  // action 필드가 JSONB로 변경되어 action.data에 데이터를 저장할 수 있습니다.
  // ignore: unused_element
  @Deprecated('현재 사용하지 않음. action 필드가 JSONB로 변경되어 action.data에 데이터 저장 가능')
  Future<void> _handleStatusSpecificLogic(
    String status,
    String campaignLogId,
    Map<String, dynamic> data,
  ) async {
    // action 필드가 JSONB로 변경되어 action.data에 데이터를 저장할 수 있습니다.
    // 필요시 이 메서드를 활성화하여 사용 가능
  }

  // 사용자 캠페인 로그 조회
  Future<ApiResponse<List<CampaignLog>>> getUserCampaignLogs({
    required String userId,
    String? status,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('campaign_action_logs')
          .select('''
            *,
            campaigns!inner(
              id,
              title,
              campaign_type,
              product_image_url,
              platform,
              companies!inner(
                id,
                name,
                logo_url
              )
            )
          ''')
          .eq('user_id', userId);

      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      final response = await queryBuilder.order('updated_at', ascending: false);
      return ApiResponse<List<CampaignLog>>(
        success: true,
        data: response.map((e) => CampaignLog.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse<List<CampaignLog>>(
        success: false,
        error: '캠페인 로그 조회 실패: $e',
      );
    }
  }

  // 캠페인별 로그 조회 (광고주용)
  Future<ApiResponse<List<CampaignLog>>> getCampaignLogs({
    required String campaignId,
    String? status,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('campaign_action_logs')
          .select('''
            *,
            users!inner(
              id,
              display_name,
              email
            )
          ''')
          .eq('campaign_id', campaignId);

      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      final response = await queryBuilder.order('updated_at', ascending: false);
      return ApiResponse<List<CampaignLog>>(
        success: true,
        data: response.map((e) => CampaignLog.fromJson(e)).toList(),
      );
    } catch (e) {
      return ApiResponse<List<CampaignLog>>(
        success: false,
        error: '캠페인 로그 조회 실패: $e',
      );
    }
  }

  // 특정 캠페인 로그 조회
  Future<ApiResponse<CampaignLog?>> getCampaignLog({
    required String campaignId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('campaign_action_logs')
          .select('''
            *,
            campaigns!inner(
              id,
              title,
              campaign_type,
              product_image_url,
              platform,
              companies!inner(
                id,
                name,
                logo_url
              )
            )
          ''')
          .eq('campaign_id', campaignId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return ApiResponse<CampaignLog?>(success: true, data: null);
      }

      return ApiResponse<CampaignLog?>(
        success: true,
        data: CampaignLog.fromJson(response),
      );
    } catch (e) {
      return ApiResponse<CampaignLog?>(
        success: false,
        error: '캠페인 로그 조회 실패: $e',
      );
    }
  }

  // 리뷰 작성/수정
  // 주의: DB에 data 필드가 없으므로 리뷰 내용은 저장하지 않음
  // 리뷰 내용 저장이 필요하면 별도 reviews 테이블 생성 또는 data JSONB 컬럼 추가 필요
  Future<ApiResponse<void>> submitReview({
    required String campaignLogId,
    required String title,
    required String content,
    required int rating,
    String? reviewUrl,
  }) async {
    try {
      // 현재 로그 조회
      final currentLog = await _supabase
          .from('campaign_action_logs')
          .select('status')
          .eq('id', campaignLogId)
          .single();

      // 리뷰 작성 가능한 상태인지 확인
      if (currentLog['status'] != 'approved' &&
          currentLog['status'] != 'purchased') {
        return ApiResponse<void>(success: false, error: '리뷰를 작성할 수 없는 상태입니다.');
      }

      // 리뷰 내용을 action.data에 저장 (JSONB)
      // action 필드는 JSONB 형식: {"type": "진행상황_저장", "data": {"title": "...", "content": "...", "rating": 5, "reviewUrl": "..."}}
      await _supabase
          .from('campaign_action_logs')
          .update({
            'status': 'review_submitted',
            'action': {
              'type': '진행상황_저장',
              'data': {
                'title': title,
                'content': content,
                'rating': rating,
                if (reviewUrl != null) 'reviewUrl': reviewUrl,
              },
            },
            'updated_at': DateTimeUtils.toIso8601StringKST(DateTimeUtils.nowKST()),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '리뷰 제출 실패: $e');
    }
  }

  // 방문 체험 완료
  // 주의: DB에 data 필드가 없으므로 방문 상세 정보는 저장하지 않음
  Future<ApiResponse<void>> completeVisit({
    required String campaignLogId,
    required String location,
    required int duration,
    String? notes,
    List<String>? photos,
  }) async {
    try {
      // 현재 로그 조회
      final currentLog = await _supabase
          .from('campaign_action_logs')
          .select('status')
          .eq('id', campaignLogId)
          .single();

      // 방문 완료 가능한 상태인지 확인
      if (currentLog['status'] != 'approved') {
        return ApiResponse<void>(success: false, error: '방문을 완료할 수 없는 상태입니다.');
      }

      // 방문 상세 정보를 action.data에 저장 (JSONB)
      // action 필드는 JSONB 형식: {"type": "진행상황_저장", "data": {"location": "...", "duration": 30, ...}}
      await _supabase
          .from('campaign_action_logs')
          .update({
            'status': 'visit_completed',
            'action': {
              'type': '진행상황_저장',
              'data': {
                'location': location,
                'duration': duration,
                if (notes != null) 'notes': notes,
                if (photos != null) 'photos': photos,
              },
            },
            'updated_at': DateTimeUtils.toIso8601StringKST(DateTimeUtils.nowKST()),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '방문 완료 실패: $e');
    }
  }

  // 기사 작성 완료
  // 주의: DB에 data 필드가 없으므로 기사 내용은 저장하지 않음
  Future<ApiResponse<void>> submitArticle({
    required String campaignLogId,
    required String title,
    required String content,
    String? articleUrl,
  }) async {
    try {
      // 현재 로그 조회
      final currentLog = await _supabase
          .from('campaign_action_logs')
          .select('status')
          .eq('id', campaignLogId)
          .single();

      // 기사 작성 가능한 상태인지 확인
      if (currentLog['status'] != 'approved') {
        return ApiResponse<void>(success: false, error: '기사를 작성할 수 없는 상태입니다.');
      }

      // 기사 내용을 action.data에 저장 (JSONB)
      // action 필드는 JSONB 형식: {"type": "진행상황_저장", "data": {"title": "...", "content": "...", "articleUrl": "..."}}
      await _supabase
          .from('campaign_action_logs')
          .update({
            'status': 'article_submitted',
            'action': {
              'type': '진행상황_저장',
              'data': {
                'title': title,
                'content': content,
                if (articleUrl != null) 'articleUrl': articleUrl,
              },
            },
            'updated_at': DateTimeUtils.toIso8601StringKST(DateTimeUtils.nowKST()),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '기사 제출 실패: $e');
    }
  }

  // 상태별 통계 조회
  Future<ApiResponse<Map<String, int>>> getStatusStats({
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('campaign_action_logs')
          .select('status')
          .eq('user_id', userId);

      final stats = <String, int>{};
      for (final log in response) {
        final status = log['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
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
