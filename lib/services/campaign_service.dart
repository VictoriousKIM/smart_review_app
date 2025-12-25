import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/campaign.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';
import '../utils/error_handler.dart';
import '../utils/date_time_utils.dart';
import 'campaign_duplicate_check_service.dart';
import 'cloudflare_workers_service.dart';
import 'auth_service.dart';

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final CampaignDuplicateCheckService _duplicateCheckService =
      CampaignDuplicateCheckService(SupabaseConfig.client);

  // 캠페인 목록 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Campaign>>> getCampaigns({
    int page = 1,
    int limit = 10,
    String? campaignType,
    String? sortBy = 'latest',
  }) async {
    try {
      // ✅ 모든 필드 선택 (캠페인 편집 화면과 동일하게)
      // 명시적으로 필요한 필드 선택 (RLS 정책으로 인한 필드 누락 방지)
      dynamic query = _supabase
          .from('campaigns')
          .select('''
            id,
            title,
            description,
            company_id,
            product_name,
            product_image_url,
            platform,
            campaign_type,
            product_price,
            campaign_reward,
            apply_start_date,
            apply_end_date,
            review_start_date,
            review_end_date,
            current_participants,
            max_participants,
            max_per_reviewer,
            status,
            created_at,
            user_id,
            keyword,
            option,
            quantity,
            seller,
            product_number,
            purchase_method,
            product_provision_type,
            review_type,
            review_text_length,
            review_image_count,
            review_keywords,
            prevent_product_duplicate,
            prevent_store_duplicate,
            duplicate_prevent_days,
            payment_method,
            total_cost
          ''')
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

      // 디버깅: Supabase 응답 확인
      if (response is List && response.isNotEmpty) {
        debugPrint('📥 Supabase 응답 확인 (첫 번째 캠페인):');
        debugPrint('   전체 JSON: ${response[0]}');
        debugPrint('   platform: ${response[0]['platform']}');
        debugPrint(
          '   product_provision_type: ${response[0]['product_provision_type']}',
        );
        debugPrint('   payment_method: ${response[0]['payment_method']}');
      }

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      // 중복 체크 필터링
      final filteredCampaigns = await _filterDuplicateCampaigns(campaigns);

      return ApiResponse<List<Campaign>>(
        success: true,
        data: filteredCampaigns,
      );
    } on TimeoutException {
      ErrorHandler.handleNetworkError(
        'Request timeout',
        context: {
          'operation': 'get_campaigns',
          'page': page,
          'limit': limit,
          'campaign_type': campaignType,
          'sort_by': sortBy,
        },
      );

      return ApiResponse<List<Campaign>>(
        success: false,
        error: '요청 시간이 초과되었습니다. 다시 시도해주세요.',
      );
    } catch (e) {
      ErrorHandler.handleDatabaseError(
        e,
        context: {
          'operation': 'get_campaigns',
          'page': page,
          'limit': limit,
          'campaign_type': campaignType,
          'sort_by': sortBy,
        },
      );

      return ApiResponse<List<Campaign>>(
        success: false,
        error: '캠페인을 불러오는 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }

  // 캠페인 상세 정보 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<Campaign>> getCampaignById(String campaignId) async {
    try {
      // 명시적으로 필요한 필드 선택
      final response = await _supabase
          .from('campaigns')
          .select('''
            id,
            title,
            description,
            company_id,
            product_name,
            product_image_url,
            platform,
            campaign_type,
            product_price,
            campaign_reward,
            apply_start_date,
            apply_end_date,
            review_start_date,
            review_end_date,
            current_participants,
            max_participants,
            max_per_reviewer,
            status,
            created_at,
            user_id,
            keyword,
            option,
            quantity,
            seller,
            product_number,
            purchase_method,
            product_provision_type,
            review_type,
            review_text_length,
            review_image_count,
            review_keywords,
            prevent_product_duplicate,
            prevent_store_duplicate,
            duplicate_prevent_days,
            payment_method,
            total_cost
          ''')
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
      final now = DateTime.now();

      // ✅ 모든 필드 선택 (캠페인 편집 화면과 동일하게)
      // ✅ campaign_type 필터 제거: DB의 유효한 값은 'store', 'journalist', 'visit' (CHECK 제약조건)
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active')
          // 날짜 필터링: 모집중인 캠페인만 표시 (신청 기간)
          .lte('apply_start_date', now.toIso8601String())
          .gte('apply_end_date', now.toIso8601String())
          .order('current_participants', ascending: false)
          .limit(limit);

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      // 중복 체크 필터링
      final filteredCampaigns = await _filterDuplicateCampaigns(campaigns);

      return ApiResponse<List<Campaign>>(
        success: true,
        data: filteredCampaigns,
      );
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  // 새 캠페인 가져오기 (RLS + 직접 쿼리 - 최적화)
  Future<ApiResponse<List<Campaign>>> getNewCampaigns({int limit = 5}) async {
    try {
      final now = DateTime.now();

      // ✅ 모든 필드 선택 (캠페인 편집 화면과 동일하게)
      // ✅ campaign_type 필터 제거: DB의 유효한 값은 'store', 'journalist', 'visit' (CHECK 제약조건)
      // 명시적으로 필요한 필드 선택
      final response = await _supabase
          .from('campaigns')
          .select('''
            id,
            title,
            description,
            company_id,
            product_name,
            product_image_url,
            platform,
            campaign_type,
            product_price,
            campaign_reward,
            apply_start_date,
            apply_end_date,
            review_start_date,
            review_end_date,
            current_participants,
            max_participants,
            max_per_reviewer,
            status,
            created_at,
            user_id,
            keyword,
            option,
            quantity,
            seller,
            product_number,
            purchase_method,
            product_provision_type,
            review_type,
            review_text_length,
            review_image_count,
            review_keywords,
            prevent_product_duplicate,
            prevent_store_duplicate,
            duplicate_prevent_days,
            payment_method,
            total_cost
          ''')
          .eq('status', 'active')
          // 날짜 필터링: 모집중인 캠페인만 표시 (신청 기간)
          .lte('apply_start_date', now.toIso8601String())
          .gte('apply_end_date', now.toIso8601String())
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
      final now = DateTime.now();

      // ✅ 모든 필드 선택 (캠페인 편집 화면과 동일하게)
      // 명시적으로 필요한 필드 선택
      var searchQuery = _supabase
          .from('campaigns')
          .select('''
            id,
            title,
            description,
            company_id,
            product_name,
            product_image_url,
            platform,
            campaign_type,
            product_price,
            campaign_reward,
            apply_start_date,
            apply_end_date,
            review_start_date,
            review_end_date,
            current_participants,
            max_participants,
            max_per_reviewer,
            status,
            created_at,
            user_id,
            keyword,
            option,
            quantity,
            seller,
            product_number,
            purchase_method,
            product_provision_type,
            review_type,
            review_text_length,
            review_image_count,
            review_keywords,
            prevent_product_duplicate,
            prevent_store_duplicate,
            duplicate_prevent_days,
            payment_method,
            total_cost
          ''')
          .eq('status', 'active')
          // 날짜 필터링: 모집중인 캠페인만 표시 (신청 기간)
          .lte('apply_start_date', now.toIso8601String())
          .gte('apply_end_date', now.toIso8601String())
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

      // 중복 체크 필터링
      final filteredCampaigns = await _filterDuplicateCampaigns(campaigns);

      return ApiResponse<List<Campaign>>(
        success: true,
        data: filteredCampaigns,
      );
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  /// 최적화된 활성 캠페인 조회 (다음 오픈 시간 포함)
  /// 이그레스 비용 최소화: 미래 캠페인 데이터를 전송하지 않고, 다음 오픈 시간만 반환
  Future<ApiResponse<Map<String, dynamic>>>
  getActiveCampaignsOptimized() async {
    try {
      final response = await _supabase.rpc('get_active_campaigns_optimized');

      final campaignsJson = response['campaigns'] as List?;
      final nextOpenAtStr = response['next_open_at'] as String?;

      final campaigns = campaignsJson != null
          ? campaignsJson.map((json) => Campaign.fromJson(json)).toList()
          : <Campaign>[];

      DateTime? nextOpenAt;
      if (nextOpenAtStr != null) {
        // ⚠️ 중요: DB에서 받은 UTC 시간을 KST로 변환
        // parseKST()는 UTC 문자열을 KST DateTime으로 변환함
        nextOpenAt = DateTimeUtils.parseKST(nextOpenAtStr);
      }

      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: {'campaigns': campaigns, 'nextOpenAt': nextOpenAt},
      );
    } catch (e) {
      debugPrint('❌ getActiveCampaignsOptimized 실패: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: e.toString(),
      );
    }
  }

  // 중복 체크 필터링 헬퍼 메서드
  Future<List<Campaign>> _filterDuplicateCampaigns(
    List<Campaign> campaigns,
  ) async {
    // 로그인한 사용자인 경우 중복 체크
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      // 비로그인 사용자는 모든 캠페인 반환
      return campaigns;
    }

    final filteredCampaigns = <Campaign>[];

    for (final campaign in campaigns) {
      // 중복 체크
      final duplicateCheck = await _duplicateCheckService
          .checkCampaignDuplicate(
            userId: userId,
            campaign: {
              'id': campaign.id,
              'title': campaign.title,
              'seller': campaign.seller,
              'prevent_product_duplicate': campaign.preventProductDuplicate,
              'prevent_store_duplicate': campaign.preventStoreDuplicate,
              'duplicate_prevent_days': campaign.duplicatePreventDays,
            },
          );

      // 중복이 아닌 경우만 추가
      if (!duplicateCheck['isDuplicate']) {
        filteredCampaigns.add(campaign);
      }
    }

    return filteredCampaigns;
  }

  // 캠페인 참여 (RPC 사용 - 비즈니스 로직)
  Future<ApiResponse<Map<String, dynamic>>> joinCampaign(
    String campaignId, {
    String? applicationMessage,
  }) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 캠페인 참여 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response = await _supabase.rpc(
        'join_campaign_safe',
        params: {
          'p_campaign_id': campaignId,
          'p_application_message': applicationMessage,
          'p_user_id': userId,
        },
      );

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
  Future<ApiResponse<Map<String, dynamic>>> leaveCampaign(
    String campaignId,
  ) async {
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 캠페인 참여 취소 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final response = await _supabase.rpc(
        'leave_campaign_safe',
        params: {'p_campaign_id': campaignId, 'p_user_id': userId},
      );

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
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: '로그인이 필요합니다.',
      );
    }

    try {
      // RPC 함수 호출로 안전한 사용자 캠페인 조회
      final offset = (page - 1) * limit;
      final statusParam = status ?? 'all';

      debugPrint('📞 get_user_campaigns_safe 호출:');
      debugPrint('   p_user_id: $userId');
      debugPrint('   p_status: $statusParam');
      debugPrint('   p_offset: $offset');
      debugPrint('   p_limit: $limit');

      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final currentUserId = await AuthService.getCurrentUserId();

      final response = await _supabase.rpc(
        'get_user_campaigns_safe',
        params: {
          'p_user_id': userId,
          'p_status': statusParam,
          'p_offset': offset,
          'p_limit': limit,
          'p_current_user_id': currentUserId,
        },
      );

      debugPrint('✅ get_user_campaigns_safe 성공:');
      debugPrint(
        '   campaigns 수: ${(response['campaigns'] as List?)?.length ?? 0}',
      );
      debugPrint('   total_count: ${response['total_count']}');

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
    } catch (e) {
      debugPrint('❌ get_user_campaigns_safe 실패: $e');
      debugPrint(
        '   파라미터: p_user_id=$userId, p_status=${status ?? 'all'}, p_offset=${(page - 1) * limit}, p_limit=$limit',
      );
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
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      // RPC 함수 호출로 안전한 참여 캠페인 조회
      final response = await _supabase.rpc(
        'get_user_participated_campaigns_safe',
        params: {
          'p_user_id': userId,
          'p_status': status,
          'p_page': page,
          'p_limit': limit,
        },
      );

      return ApiResponse<Map<String, dynamic>>(success: true, data: response);
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
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<List<Campaign>>(
          success: false,
          error: '로그인이 필요합니다.',
        );
      }

      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
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
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
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
        'campaign_type': previousCampaign.campaignType.name,
        'product_price': previousCampaign.productPrice,
        'campaign_reward': previousCampaign.campaignReward,
        'apply_start_date': startDate.toIso8601String(),
        'apply_end_date': endDate.toIso8601String(),
        'review_start_date': startDate.toIso8601String(),
        'review_end_date': endDate.toIso8601String(),
        'max_participants': maxParticipants,
        'current_participants': 0,
        'status': 'active',
        'user_id': userId,
        'is_template': false,
        'template_name': null,
      };

      final response = await _supabase
          .from('campaigns')
          .insert(newCampaign)
          .select()
          .single();

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
    required int campaignReward,
    required DateTime startDate,
    required DateTime endDate,
    required int maxParticipants,
    String? productImageUrl,
  }) async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
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

      if (productPrice < 0 || campaignReward < 0) {
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
          'p_campaign_reward': campaignReward,
          'p_max_participants': maxParticipants,
          'p_apply_start_date': startDate.toIso8601String(),
          'p_apply_end_date': endDate.toIso8601String(),
          'p_review_start_date': startDate.toIso8601String(),
          'p_review_end_date': endDate.toIso8601String(),
          'p_product_image_url': productImageUrl,
          'p_platform': platform,
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

      return ApiResponse<Campaign>(success: false, error: '캠페인 생성에 실패했습니다.');
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
          error: '회사에 소속되어 있지 않습니다. 광고주 등록을 먼저 진행해주세요.',
        );
      } else if (errorMessage.contains('회사 지갑이 없습니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '회사 지갑이 생성되지 않았습니다. 관리자에게 문의하세요.',
        );
      }

      debugPrint('❌ 캠페인 생성 실패: $e');
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
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
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
          .eq('user_id', userId)
          .ilike('title', '%${query.trim()}%')
          .order('created_at', ascending: false)
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
    required int campaignReward,
    required int maxParticipants,
    int maxPerReviewer = 1, // 리뷰어당 신청 가능 개수 (기본값: 1)
    required DateTime applyStartDate,
    required DateTime applyEndDate,
    required DateTime reviewStartDate,
    required DateTime reviewEndDate,
    String? keyword,
    String? option,
    int? quantity,
    required String seller, // NOT NULL
    String? productNumber,
    required String productName, // NOT NULL
    required int productPrice, // NOT NULL
    String? reviewType,
    int? reviewTextLength, // NULL 가능
    int? reviewImageCount, // NULL 가능
    bool? preventProductDuplicate,
    bool? preventStoreDuplicate,
    int? duplicatePreventDays,
    required String paymentMethod, // NOT NULL
    required String productImageUrl, // NOT NULL
    required String purchaseMethod, // NOT NULL
    String? productProvisionType, // 상품 제공 방법 (delivery, return, other)
    List<String>? reviewKeywords, // ✅ 추가: 리뷰 키워드 (최대 3개)
  }) async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Campaign>(success: false, error: '로그인이 필요합니다.');
      }

      // 입력값 검증
      if (title.trim().isEmpty) {
        return ApiResponse<Campaign>(success: false, error: '제품명을 입력해주세요.');
      }

      // 날짜 검증
      if (applyStartDate.isAfter(applyEndDate)) {
        return ApiResponse<Campaign>(
          success: false,
          error: '신청 시작일시는 종료일시보다 빠를 수 없습니다.',
        );
      }

      if (applyEndDate.isAfter(reviewStartDate)) {
        return ApiResponse<Campaign>(
          success: false,
          error: '신청 종료일시는 리뷰 시작일시보다 빠를 수 없습니다.',
        );
      }

      if (reviewStartDate.isAfter(reviewEndDate)) {
        return ApiResponse<Campaign>(
          success: false,
          error: '리뷰 시작일시는 종료일시보다 빠를 수 없습니다.',
        );
      }

      if (maxParticipants <= 0) {
        return ApiResponse<Campaign>(
          success: false,
          error: '모집 인원은 1명 이상이어야 합니다.',
        );
      }

      // RPC 함수 호출 (create_campaign_with_points_v2)
      // params 맵 생성
      final params = <String, dynamic>{
        'p_title': title,
        'p_description': description,
        'p_campaign_type': campaignType,
        'p_campaign_reward': campaignReward,
        'p_max_participants': maxParticipants,
        'p_max_per_reviewer': maxPerReviewer,
        'p_apply_start_date': DateTimeUtils.toIso8601StringKST(applyStartDate),
        'p_apply_end_date': DateTimeUtils.toIso8601StringKST(applyEndDate),
        'p_review_start_date': DateTimeUtils.toIso8601StringKST(
          reviewStartDate,
        ),
        'p_review_end_date': DateTimeUtils.toIso8601StringKST(reviewEndDate),
        'p_platform': platform,
        'p_keyword': keyword,
        'p_option': option,
        'p_quantity': quantity ?? 1,
        'p_seller': seller,
        'p_product_number': productNumber,
        'p_product_image_url': productImageUrl,
        'p_product_name': productName, // ✅ 추가
        'p_product_price': productPrice, // ✅ 추가 (paymentAmount 대체)
        'p_purchase_method': purchaseMethod, // ✅ 하드코딩 제거
        'p_product_provision_type': productProvisionType,
        'p_product_description': null, // ✅ 제거 (NULL로 설정)
        'p_review_type': reviewType ?? 'star_only',
        'p_review_text_length': reviewTextLength, // ✅ NULL 가능
        'p_review_image_count': reviewImageCount, // ✅ NULL 가능
        'p_prevent_product_duplicate': preventProductDuplicate ?? false,
        'p_prevent_store_duplicate': preventStoreDuplicate ?? false,
        'p_duplicate_prevent_days': duplicatePreventDays ?? 0,
        'p_payment_method': paymentMethod,
        'p_review_keywords': reviewKeywords, // ✅ 추가
        'p_user_id': userId, // ✅ Custom JWT 세션 지원
      };

      final response = await _supabase.rpc(
        'create_campaign_with_points_v2',
        params: params,
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
          error: '회사에 소속되어 있지 않습니다. 광고주 등록을 먼저 진행해주세요.',
        );
      } else if (errorMessage.contains('회사 지갑이 없습니다')) {
        return ApiResponse<Campaign>(
          success: false,
          error: '회사 지갑이 생성되지 않았습니다. 관리자에게 문의하세요.',
        );
      }

      debugPrint('❌ 캠페인 생성 실패: $e');
      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 생성 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }

  /// 캠페인 업데이트
  Future<ApiResponse<Campaign>> updateCampaignV2({
    required String campaignId,
    required String title,
    required String description,
    required String campaignType,
    required String platform,
    required int campaignReward,
    required int maxParticipants,
    required int maxPerReviewer,
    required DateTime applyStartDate,
    required DateTime applyEndDate,
    required DateTime reviewStartDate,
    required DateTime reviewEndDate,
    String? keyword,
    String? option,
    int? quantity,
    required String seller, // NOT NULL
    String? productNumber,
    required String productName, // NOT NULL
    required int productPrice, // NOT NULL
    required String purchaseMethod, // NOT NULL
    required String productProvisionType, // 상품 제공 방법 (실배송, 회수, 또는 사용자 입력 텍스트)
    String? reviewType,
    int? reviewTextLength,
    int? reviewImageCount,
    bool? preventProductDuplicate,
    bool? preventStoreDuplicate,
    int? duplicatePreventDays,
    required String paymentMethod, // NOT NULL
    required String productImageUrl, // NOT NULL
    List<String>? reviewKeywords, // ✅ 추가: 리뷰 키워드 (최대 3개)
  }) async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Campaign>(success: false, error: '로그인이 필요합니다.');
      }

      // RPC 함수 호출 (update_campaign_v2)
      // params 맵 생성
      final params = <String, dynamic>{
        'p_campaign_id': campaignId,
        'p_title': title,
        'p_description': description,
        'p_campaign_type': campaignType,
        'p_campaign_reward': campaignReward,
        'p_max_participants': maxParticipants,
        'p_max_per_reviewer': maxPerReviewer,
        'p_apply_start_date': DateTimeUtils.toIso8601StringKST(applyStartDate),
        'p_apply_end_date': DateTimeUtils.toIso8601StringKST(applyEndDate),
        'p_review_start_date': DateTimeUtils.toIso8601StringKST(
          reviewStartDate,
        ),
        'p_review_end_date': DateTimeUtils.toIso8601StringKST(reviewEndDate),
        'p_platform': platform,
        'p_keyword': keyword,
        'p_option': option,
        'p_quantity': quantity ?? 1,
        'p_seller': seller,
        'p_product_number': productNumber,
        'p_product_image_url': productImageUrl,
        'p_product_name': productName,
        'p_product_price': productPrice,
        'p_purchase_method': purchaseMethod,
        'p_product_provision_type': productProvisionType,
        'p_review_type': reviewType ?? 'star_only',
        'p_review_text_length': reviewTextLength,
        'p_review_image_count': reviewImageCount,
        'p_prevent_product_duplicate': preventProductDuplicate ?? false,
        'p_prevent_store_duplicate': preventStoreDuplicate ?? false,
        'p_duplicate_prevent_days': duplicatePreventDays ?? 0,
        'p_payment_method': paymentMethod,
        'p_review_keywords': reviewKeywords, // ✅ 추가
        'p_user_id': userId, // Custom JWT 세션 지원
      };

      debugPrint('📡 [CampaignService.updateCampaignV2] RPC 호출 시작');
      debugPrint('   - 함수명: update_campaign_v2');
      debugPrint('   - 파라미터 개수: ${params.length}');

      final response = await _supabase.rpc(
        'update_campaign_v2',
        params: params,
      );

      debugPrint('📥 [CampaignService.updateCampaignV2] RPC 응답 수신');
      debugPrint('   - response 타입: ${response.runtimeType}');
      debugPrint('   - success: ${response['success']}');
      debugPrint('   - error: ${response['error']}');
      debugPrint('   - 전체 응답: $response');

      if (response['success'] == true) {
        debugPrint('✅ [CampaignService.updateCampaignV2] RPC 성공, 캠페인 조회 시작...');
        // 업데이트된 캠페인 조회
        final updatedCampaign = await getCampaignById(campaignId);
        debugPrint('✅ [CampaignService.updateCampaignV2] 캠페인 조회 완료');
        return updatedCampaign;
      }

      debugPrint(
        '❌ [CampaignService.updateCampaignV2] RPC 실패: ${response['error']}',
      );
      return ApiResponse<Campaign>(
        success: false,
        error: response['error'] ?? '캠페인 업데이트에 실패했습니다.',
      );
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      debugPrint('❌ [CampaignService.updateCampaignV2] 예외 발생!');
      debugPrint('   - 에러 타입: ${e.runtimeType}');
      debugPrint('   - 에러 메시지: $errorMessage');
      debugPrint('   - 스택 트레이스: $stackTrace');
      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 업데이트 중 오류가 발생했습니다: $errorMessage',
      );
    }
  }

  /// 캠페인 상태 업데이트
  Future<ApiResponse<Campaign>> updateCampaignStatus({
    required String campaignId,
    required CampaignStatus status,
  }) async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<Campaign>(success: false, error: '로그인이 필요합니다.');
      }

      final response = await _supabase.rpc(
        'update_campaign_status',
        params: {
          'p_campaign_id': campaignId,
          'p_status': status.name,
          'p_user_id': userId,
        },
      );

      if (response['success'] == true) {
        // 업데이트된 캠페인 조회
        final updatedCampaign = await getCampaignById(campaignId);
        return updatedCampaign;
      } else {
        return ApiResponse<Campaign>(
          success: false,
          error: response['error'] ?? '상태 업데이트에 실패했습니다',
        );
      }
    } catch (e) {
      return ApiResponse<Campaign>(
        success: false,
        error: '상태 업데이트 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }

  /// 캠페인 삭제 (하드 삭제)
  Future<ApiResponse<void>> deleteCampaign(String campaignId) async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        return ApiResponse<void>(success: false, error: '로그인이 필요합니다.');
      }

      // 캠페인 삭제 전에 이미지 URL 가져오기
      String? productImageUrl;
      try {
        final campaignResult = await getCampaignById(campaignId);
        if (campaignResult.success && campaignResult.data != null) {
          productImageUrl = campaignResult.data!.productImageUrl;
          debugPrint('🔍 캠페인 이미지 URL: $productImageUrl');
        }
      } catch (e) {
        debugPrint('⚠️ 캠페인 정보 조회 실패 (이미지 삭제 스킵): $e');
      }

      final response = await _supabase.rpc(
        'delete_campaign',
        params: {'p_campaign_id': campaignId, 'p_user_id': userId},
      );

      // response가 Map인지 확인
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          // 캠페인 삭제 성공 후 R2 이미지도 삭제
          if (productImageUrl != null && productImageUrl.isNotEmpty) {
            try {
              debugPrint('🗑️ R2 이미지 삭제 시도: $productImageUrl');
              await CloudflareWorkersService.deleteFile(productImageUrl);
              debugPrint('✅ 캠페인 이미지 삭제 성공: $productImageUrl');
            } catch (e, stackTrace) {
              // 이미지 삭제 실패해도 캠페인 삭제는 성공한 것으로 처리
              debugPrint('⚠️ 캠페인 이미지 삭제 실패 (무시): $e');
              debugPrint('⚠️ 스택 트레이스: $stackTrace');
            }
          } else {
            debugPrint('ℹ️ 삭제할 이미지 URL이 없습니다.');
          }

          return ApiResponse<void>(
            success: true,
            message: response['message'] ?? '캠페인이 삭제되었습니다',
          );
        } else {
          // 에러 메시지 상세 출력
          final errorMsg = response['error'] ?? '캠페인 삭제에 실패했습니다';
          debugPrint('❌ 캠페인 삭제 실패: $errorMsg');
          debugPrint('❌ 전체 응답: $response');
          return ApiResponse<void>(success: false, error: errorMsg);
        }
      } else {
        // 예상치 못한 응답 형식
        debugPrint('❌ 예상치 못한 응답 형식: $response (${response.runtimeType})');
        return ApiResponse<void>(
          success: false,
          error: '서버 응답 형식이 올바르지 않습니다: ${response.toString()}',
        );
      }
    } catch (e, stackTrace) {
      // 에러 상세 정보 출력
      debugPrint('❌ 캠페인 삭제 예외 발생: $e');
      debugPrint('❌ 스택 트레이스: $stackTrace');
      return ApiResponse<void>(
        success: false,
        error: '캠페인 삭제 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }
}
