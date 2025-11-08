import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/campaign.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import '../utils/error_handler.dart';

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // 캠페인 목록 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Campaign>>> getCampaigns({
    int page = 1,
    int limit = 10,
    String? campaignType,
    String? sortBy = 'latest',
  }) async {
    try {
      // 필요한 필드만 선택하여 성능 최적화
      dynamic query = _supabase
          .from('campaigns')
          .select('id, title, description, product_image_url, campaign_type, product_price, review_reward, current_participants, max_participants, created_at, end_date')
          .eq('status', 'active');

      if (campaignType != null) {
        query = query.eq('campaign_type', campaignType);
      }

      // 정렬 적용
      switch (sortBy) {
        case 'latest':
          query = query.order('created_at', ascending: false);
          break;
        case 'popular':
          query = query.order('current_participants', ascending: false);
          break;
        case 'price':
          query = query.order('product_price', ascending: false);
          break;
        default:
          query = query.order('created_at', ascending: false);
      }

      // 페이지네이션 적용
      final offset = (page - 1) * limit;
      query = query.range(offset, offset + limit - 1);

      final response = await query.timeout(const Duration(seconds: 10));

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } on TimeoutException {
      ErrorHandler.handleNetworkError('Request timeout', context: {
        'operation': 'get_campaigns',
        'page': page,
        'limit': limit,
        'campaign_type': campaignType,
        'sort_by': sortBy,
      });
      
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '요청 시간이 초과되었습니다. 다시 시도해주세요.',
      );
    } catch (e) {
      ErrorHandler.handleDatabaseError(e, context: {
        'operation': 'get_campaigns',
        'page': page,
        'limit': limit,
        'campaign_type': campaignType,
        'sort_by': sortBy,
      });
      
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '캠페인을 불러오는 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }

  // 캠페인 상세 정보 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<Campaign>> getCampaignById(String campaignId) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('id', campaignId)
          .single();

      final campaign = Campaign.fromJson(response);

      return ApiResponse<Campaign>(success: true, data: campaign);
    } catch (e) {
      return ApiResponse<Campaign>(success: false, error: e.toString());
    }
  }

  // 인기 캠페인 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Campaign>>> getPopularCampaigns({
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select('id, title, description, product_image_url, campaign_type, product_price, review_reward, current_participants, max_participants, created_at')
          .eq('status', 'active')
          .eq('campaign_type', 'reviewer')
          .order('current_participants', ascending: false)
          .limit(limit);

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  // 새 캠페인 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Campaign>>> getNewCampaigns({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select('id, title, description, product_image_url, campaign_type, product_price, review_reward, current_participants, max_participants, created_at')
          .eq('status', 'active')
          .eq('campaign_type', 'reviewer')
          .order('created_at', ascending: false)
          .limit(limit);

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  // 캠페인 검색 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Campaign>>> searchCampaigns({
    required String query,
    String? campaignType,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      var searchQuery = _supabase
          .from('campaigns')
          .select('id, title, description, product_image_url, campaign_type, product_price, review_reward, current_participants, max_participants, created_at')
          .eq('status', 'active')
          .ilike('title', '%$query%');

      if (campaignType != null) {
        searchQuery = searchQuery.eq('campaign_type', campaignType);
      }

      // 페이지네이션 적용
      final offset = (page - 1) * limit;
      final finalQuery = searchQuery.range(offset, offset + limit - 1);

      final response = await finalQuery;

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  // 캠페인 참여 (RPC 사용 - 비즈니스 로직)
  Future<ApiResponse<Map<String, dynamic>>> joinCampaign(String campaignId, {String? applicationMessage}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 캠페인 참여
      final response = await _supabase.rpc('join_campaign_safe', params: {
        'p_campaign_id': campaignId,
        'p_application_message': applicationMessage,
      });

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: response,
        message: '캠페인에 성공적으로 참여했습니다.',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '캠페인 참여 실패: $e',
      );
    }
  }

  // 캠페인 참여 취소 (RPC 사용 - 비즈니스 로직)
  Future<ApiResponse<Map<String, dynamic>>> leaveCampaign(String campaignId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 캠페인 참여 취소
      final response = await _supabase.rpc('leave_campaign_safe', params: {
        'p_campaign_id': campaignId,
      });

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: response,
        message: '캠페인 참여를 취소했습니다.',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '캠페인 참여 취소 실패: $e',
      );
    }
  }

  // 사용자가 생성한 캠페인 목록 (RPC 사용 - 복잡한 조회)
  Future<ApiResponse<Map<String, dynamic>>> getUserCampaigns({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 사용자 캠페인 조회
      final response = await _supabase.rpc('get_user_campaigns_safe', params: {
        'p_user_id': user.id,
        'p_status': status,
        'p_page': page,
        'p_limit': limit,
      });

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: response,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '사용자 캠페인 조회 실패: $e',
      );
    }
  }

  // 사용자가 참여한 캠페인 목록 (RPC 사용 - 복잡한 조회)
  Future<ApiResponse<Map<String, dynamic>>> getUserParticipatedCampaigns({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 참여 캠페인 조회
      final response = await _supabase.rpc('get_user_participated_campaigns_safe', params: {
        'p_user_id': user.id,
        'p_status': status,
        'p_page': page,
        'p_limit': limit,
      });

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: response,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '참여 캠페인 조회 실패: $e',
      );
    }
  }

  // 사용자의 이전 캠페인 목록 가져오기 (자동완성용)
  Future<ApiResponse<List<Campaign>>> getUserPreviousCampaigns({
    int limit = 10,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<List<Campaign>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('user_id', user.id)
          .order('last_used_at', ascending: false)
          .order('usage_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '이전 캠페인을 불러오는데 실패했습니다: ${e.toString()}',
      );
    }
  }

  // 캠페인 생성 (이전 캠페인 기반)
  Future<ApiResponse<Campaign>> createCampaignFromPrevious({
    required Campaign previousCampaign,
    required String newTitle,
    required DateTime startDate,
    required DateTime endDate,
    required int maxParticipants,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<Campaign>(success: false, error: '로그인이 필요합니다.');
      }

      // 입력값 검증
      if (newTitle.trim().isEmpty) {
        return ApiResponse<Campaign>(success: false, error: '캠페인 제목을 입력해주세요.');
      }

      if (startDate.isAfter(endDate)) {
        return ApiResponse<Campaign>(
          success: false,
          error: '시작일은 종료일보다 이전이어야 합니다.',
        );
      }

      if (maxParticipants <= 0) {
        return ApiResponse<Campaign>(
          success: false,
          error: '모집 인원은 1명 이상이어야 합니다.',
        );
      }

      // 새 캠페인 생성
      final newCampaign = {
        'title': newTitle.trim(),
        'description': previousCampaign.description,
        'product_image_url': previousCampaign.productImageUrl,
        'platform': previousCampaign.platform,
        'platform_logo_url': previousCampaign.platformLogoUrl,
        'campaign_type': previousCampaign.campaignType.name,
        'product_price': previousCampaign.productPrice,
        'review_reward': previousCampaign.reviewReward,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'max_participants': maxParticipants,
        'current_participants': 0,
        'status': 'active',
        'user_id': user.id,
        'is_template': false,
        'template_name': null,
        'last_used_at': DateTime.now().toIso8601String(),
        'usage_count': 0,
      };

      final response = await _supabase
          .from('campaigns')
          .insert(newCampaign)
          .select()
          .single();

      // 이전 캠페인의 사용 횟수 업데이트
      try {
        await _supabase
            .from('campaigns')
            .update({
              'last_used_at': DateTime.now().toIso8601String(),
              'usage_count': (previousCampaign.usageCount + 1),
            })
            .eq('id', previousCampaign.id);
      } catch (updateError) {
        // 사용 횟수 업데이트 실패는 로그만 남기고 계속 진행
        // print('Warning: Failed to update usage count: $updateError');
      }

      final campaign = Campaign.fromJson(response);
      return ApiResponse<Campaign>(
        success: true,
        data: campaign,
        message: '캠페인이 성공적으로 생성되었습니다.',
      );
    } catch (e) {
      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 생성에 실패했습니다: ${e.toString()}',
      );
    }
  }

  // 일반 캠페인 생성 (신규)
  Future<ApiResponse<Campaign>> createCampaign({
    required String title,
    required String description,
    required String campaignType,
    required String platform,
    required int productPrice,
    required int reviewReward,
    required DateTime startDate,
    required DateTime endDate,
    required int maxParticipants,
    String? productImageUrl,
    String? platformLogoUrl,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<Campaign>(success: false, error: '로그인이 필요합니다.');
      }

      // 입력값 검증
      if (title.trim().isEmpty) {
        return ApiResponse<Campaign>(success: false, error: '캠페인 제목을 입력해주세요.');
      }

      if (startDate.isAfter(endDate)) {
        return ApiResponse<Campaign>(
          success: false,
          error: '시작일은 종료일보다 이전이어야 합니다.',
        );
      }

      if (maxParticipants <= 0) {
        return ApiResponse<Campaign>(
          success: false,
          error: '모집 인원은 1명 이상이어야 합니다.',
        );
      }

      if (productPrice < 0 || reviewReward < 0) {
        return ApiResponse<Campaign>(
          success: false,
          error: '가격과 보상은 0원 이상이어야 합니다.',
        );
      }

      // RPC 호출로 포인트 차감 + 캠페인 생성 원자적 처리
      final response = await _supabase.rpc(
        'create_campaign_with_points',
        params: {
          'p_title': title.trim(),
          'p_description': description.trim(),
          'p_campaign_type': campaignType,
          'p_product_price': productPrice,
          'p_review_reward': reviewReward,
          'p_max_participants': maxParticipants,
          'p_start_date': startDate.toIso8601String(),
          'p_end_date': endDate.toIso8601String(),
          'p_product_image_url': productImageUrl,
          'p_platform': platform,
          'p_platform_logo_url': platformLogoUrl,
        },
      );

      if (response['success'] == true) {
        // 생성된 캠페인 조회
        final campaignId = response['campaign_id'];
        final campaignData = await _supabase
            .from('campaigns')
            .select()
            .eq('id', campaignId)
            .single();

        final newCampaign = Campaign.fromJson(campaignData);
        
        return ApiResponse<Campaign>(
          success: true,
          data: newCampaign,
          message: '캠페인이 생성되었습니다. (소비 포인트: ${response['points_spent']}P)',
        );
      }

      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 생성에 실패했습니다.',
      );
    } catch (e) {
      final errorMessage = e.toString();
      
      // 에러 메시지 파싱
      if (errorMessage.contains('포인트가 부족합니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '포인트가 부족합니다. 충전 후 다시 시도해주세요.',
        );
      } else if (errorMessage.contains('회사에 소속되지 않았습니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '회사에 소속되어 있지 않습니다. 사업자 등록을 먼저 진행해주세요.',
        );
      } else if (errorMessage.contains('회사 지갑이 없습니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '회사 지갑이 생성되지 않았습니다. 관리자에게 문의하세요.',
        );
      }
      
      print('❌ 캠페인 생성 실패: $e');
      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 생성 중 오류가 발생했습니다.',
      );
    }
  }

  // 캠페인 검색 (자동완성용)
  Future<ApiResponse<List<Campaign>>> searchUserCampaigns({
    required String query,
    int limit = 5,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<List<Campaign>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      if (query.trim().isEmpty) {
        return ApiResponse<List<Campaign>>(success: true, data: []);
      }

      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('user_id', user.id)
          .ilike('title', '%${query.trim()}%')
          .order('last_used_at', ascending: false)
          .order('usage_count', ascending: false)
          .limit(limit);

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '캠페인 검색에 실패했습니다: ${e.toString()}',
      );
    }
  }

  // 캠페인 생성 (V2 - 확장 버전)
  Future<ApiResponse<Campaign>> createCampaignV2({
    required String title,
    required String description,
    required String campaignType,
    required String platform,
    required int reviewReward,
    required int maxParticipants,
    required DateTime startDate,
    required DateTime endDate,
    String? keyword,
    String? option,
    int? quantity,
    String? seller,
    String? productNumber,
    int? paymentAmount,
    String? reviewType,
    int? reviewTextLength,
    int? reviewImageCount,
    bool? preventProductDuplicate,
    bool? preventStoreDuplicate,
    int? duplicatePreventDays,
    String? paymentMethod,
    String? productImageUrl,
    String? platformLogoUrl,
  }) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<Campaign>(success: false, error: '로그인이 필요합니다.');
      }

      // 입력값 검증
      if (title.trim().isEmpty) {
        return ApiResponse<Campaign>(success: false, error: '제품명을 입력해주세요.');
      }

      if (startDate.isAfter(endDate)) {
        return ApiResponse<Campaign>(
          success: false,
          error: '시작일은 종료일보다 빠를 수 없습니다.',
        );
      }

      if (maxParticipants <= 0) {
        return ApiResponse<Campaign>(
          success: false,
          error: '모집 인원은 1명 이상이어야 합니다.',
        );
      }

      // RPC 함수 호출 (create_campaign_with_points_v2)
      final response = await _supabase.rpc('create_campaign_with_points_v2', params: {
        'p_title': title,
        'p_description': description,
        'p_campaign_type': campaignType,
        'p_review_reward': reviewReward,
        'p_max_participants': maxParticipants,
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
        'p_platform': platform,
        'p_platform_logo_url': platformLogoUrl,
        'p_keyword': keyword,
        'p_option': option,
        'p_quantity': quantity ?? 1,
        'p_seller': seller,
        'p_product_number': productNumber,
        'p_product_image_url': productImageUrl,
        'p_payment_amount': paymentAmount ?? 0,
        'p_purchase_method': 'mobile',
        'p_product_description': description,
        'p_review_type': reviewType ?? 'star_only',
        'p_review_text_length': reviewTextLength ?? 100,
        'p_review_image_count': reviewImageCount ?? 0,
        'p_prevent_product_duplicate': preventProductDuplicate ?? false,
        'p_prevent_store_duplicate': preventStoreDuplicate ?? false,
        'p_duplicate_prevent_days': duplicatePreventDays ?? 0,
        'p_payment_method': paymentMethod ?? 'platform',
      });

      if (response['success'] == true) {
        // 생성된 캠페인 조회
        final campaignId = response['campaign_id'];
        final campaignData = await _supabase
            .from('campaigns')
            .select()
            .eq('id', campaignId)
            .single();

        final newCampaign = Campaign.fromJson(campaignData);
        
        return ApiResponse<Campaign>(
          success: true,
          data: newCampaign,
          message: '캠페인이 생성되었습니다. (소비 포인트: ${response['points_spent']}P)',
        );
      }

      return ApiResponse<Campaign>(
        success: false,
        error: response['error'] ?? '캠페인 생성에 실패했습니다.',
      );
    } catch (e) {
      final errorMessage = e.toString();
      
      // 에러 메시지 파싱
      if (errorMessage.contains('포인트가 부족합니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '포인트가 부족합니다. 충전 후 다시 시도해주세요.',
        );
      } else if (errorMessage.contains('회사에 소속되지 않았습니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '회사에 소속되어 있지 않습니다. 사업자 등록을 먼저 진행해주세요.',
        );
      } else if (errorMessage.contains('회사 지갑이 없습니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '회사 지갑이 생성되지 않았습니다. 관리자에게 문의하세요.',
        );
      }
      
      print('❌ 캠페인 생성 실패: $e');
      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 생성 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }
}
