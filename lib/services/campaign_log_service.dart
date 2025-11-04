import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campaign_log.dart';
import '../models/api_response.dart';

class CampaignLogService {
  final SupabaseClient _supabase;

  CampaignLogService(this._supabase);

  // 캠페인 신청
  Future<ApiResponse<String>> applyToCampaign({
    required String campaignId,
    required String userId,
    String? applicationMessage,
    String rewardType = 'platform_points',
    int? rewardAmount,
  }) async {
    try {
      // 이미 신청했는지 확인
      final existingLog = await _supabase
          .from('campaign_events')
          .select('id')
          .eq('campaign_id', campaignId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLog != null) {
        return ApiResponse<String>(success: false, error: '이미 신청한 캠페인입니다.');
      }

      // 새 로그 생성
      final response = await _supabase
          .from('campaign_events')
          .insert({
            'campaign_id': campaignId,
            'user_id': userId,
            'status': 'applied',
            'reward_type': rewardType,
            'reward_amount': rewardAmount,
            'data': {
              'application_message': applicationMessage,
              'applied_at': DateTime.now().toIso8601String(),
            },
          })
          .select('id')
          .single();

      return ApiResponse<String>(success: true, data: response['id']);
    } catch (e) {
      return ApiResponse<String>(success: false, error: '신청 실패: $e');
    }
  }

  // 상태 업데이트 (단계별 진행)
  Future<ApiResponse<void>> updateStatus({
    required String campaignLogId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // 현재 로그 조회
      final currentLog = await _supabase
          .from('campaign_events')
          .select('data, campaign_id, campaigns!inner(campaign_type)')
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

      // 데이터 병합 (기존 데이터 + 새 데이터)
      final currentData = Map<String, dynamic>.from(currentLog['data'] ?? {});
      if (additionalData != null) {
        currentData.addAll(additionalData);
      }

      // 상태별 추가 처리
      await _handleStatusSpecificLogic(status, campaignLogId, currentData);

      // 로그 업데이트
      await _supabase
          .from('campaign_events')
          .update({
            'status': status,
            'data': currentData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '상태 업데이트 실패: $e');
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
  Future<void> _handleStatusSpecificLogic(
    String status,
    String campaignLogId,
    Map<String, dynamic> data,
  ) async {
    switch (status) {
      case 'purchased':
        data['purchase_date'] = DateTime.now().toIso8601String();
        break;
      case 'review_submitted':
        data['review_submitted_at'] = DateTime.now().toIso8601String();
        break;
      case 'review_approved':
        data['review_approved_at'] = DateTime.now().toIso8601String();
        break;
      case 'visit_completed':
        data['visit_completed_at'] = DateTime.now().toIso8601String();
        break;
      case 'visit_verified':
        data['visit_verified_at'] = DateTime.now().toIso8601String();
        break;
      case 'article_submitted':
        data['article_submitted_at'] = DateTime.now().toIso8601String();
        break;
      case 'article_approved':
        data['article_approved_at'] = DateTime.now().toIso8601String();
        break;
      case 'payment_completed':
        data['payment_completed_at'] = DateTime.now().toIso8601String();
        break;
    }
  }

  // 사용자 캠페인 로그 조회
  Future<ApiResponse<List<CampaignLog>>> getUserCampaignLogs({
    required String userId,
    String? status,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('campaign_events')
          .select('''
            *,
            campaigns!inner(
              id,
              title,
              campaign_type,
              product_image_url,
              platform_logo_url,
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
          .from('campaign_events')
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
          .from('campaign_events')
          .select('''
            *,
            campaigns!inner(
              id,
              title,
              campaign_type,
              product_image_url,
              platform_logo_url,
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
          .from('campaign_events')
          .select('data, status')
          .eq('id', campaignLogId)
          .single();

      // 리뷰 작성 가능한 상태인지 확인
      if (currentLog['status'] != 'approved' &&
          currentLog['status'] != 'purchased') {
        return ApiResponse<void>(success: false, error: '리뷰를 작성할 수 없는 상태입니다.');
      }

      // 리뷰 데이터 추가
      final currentData = Map<String, dynamic>.from(currentLog['data'] ?? {});
      currentData.addAll({
        'title': title,
        'review_content': content,
        'rating': rating,
        'review_url': reviewUrl,
        'review_submitted_at': DateTime.now().toIso8601String(),
      });

      // 상태를 review_submitted로 업데이트
      await _supabase
          .from('campaign_events')
          .update({
            'status': 'review_submitted',
            'data': currentData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '리뷰 제출 실패: $e');
    }
  }

  // 방문 체험 완료
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
          .from('campaign_events')
          .select('data, status')
          .eq('id', campaignLogId)
          .single();

      // 방문 완료 가능한 상태인지 확인
      if (currentLog['status'] != 'approved') {
        return ApiResponse<void>(success: false, error: '방문을 완료할 수 없는 상태입니다.');
      }

      // 방문 데이터 추가
      final currentData = Map<String, dynamic>.from(currentLog['data'] ?? {});
      currentData.addAll({
        'location': location,
        'visit_duration': duration,
        'visit_notes': notes,
        'photos': photos,
        'visit_completed_at': DateTime.now().toIso8601String(),
      });

      // 상태를 visit_completed로 업데이트
      await _supabase
          .from('campaign_events')
          .update({
            'status': 'visit_completed',
            'data': currentData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', campaignLogId);

      return ApiResponse<void>(success: true);
    } catch (e) {
      return ApiResponse<void>(success: false, error: '방문 완료 실패: $e');
    }
  }

  // 기사 작성 완료
  Future<ApiResponse<void>> submitArticle({
    required String campaignLogId,
    required String title,
    required String content,
    String? articleUrl,
  }) async {
    try {
      // 현재 로그 조회
      final currentLog = await _supabase
          .from('campaign_events')
          .select('data, status')
          .eq('id', campaignLogId)
          .single();

      // 기사 작성 가능한 상태인지 확인
      if (currentLog['status'] != 'approved') {
        return ApiResponse<void>(success: false, error: '기사를 작성할 수 없는 상태입니다.');
      }

      // 기사 데이터 추가
      final currentData = Map<String, dynamic>.from(currentLog['data'] ?? {});
      currentData.addAll({
        'title': title,
        'article_content': content,
        'article_url': articleUrl,
        'article_submitted_at': DateTime.now().toIso8601String(),
      });

      // 상태를 article_submitted로 업데이트
      await _supabase
          .from('campaign_events')
          .update({
            'status': 'article_submitted',
            'data': currentData,
            'updated_at': DateTime.now().toIso8601String(),
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
          .from('campaign_events')
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
