import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/campaign.dart';
import '../models/api_response.dart';
import '../config/supabase_config.dart';

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // 캠페인 목록 가져오기
  Future<ApiResponse<List<Campaign>>> getCampaigns({
    int page = 1,
    int limit = 10,
    String? category,
    String? type,
    String? sortBy = 'latest',
  }) async {
    try {
      print('🔍 CampaignService.getCampaigns 호출됨');
      
      // 쿼리 구성 - 타입 안전성을 위해 단계별 구성
      // 인증 확인을 제거하고 직접 쿼리 실행 (Supabase가 자동으로 인증 처리)
      dynamic query = _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active');

      if (category != null) {
        query = query.eq('category', category);
      }

      if (type != null) {
        query = query.eq('type', type);
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

      print('🔍 Supabase 쿼리 실행 중...');
      final response = await query.timeout(const Duration(seconds: 10));
      print('🔍 Supabase 쿼리 응답: ${response.toString()}');

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      print('🔍 파싱된 캠페인 수: ${campaigns.length}');
      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } on TimeoutException {
      print('❌ CampaignService TimeoutException 발생');
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '요청 시간이 초과되었습니다. 다시 시도해주세요.',
      );
    } on AuthException catch (e) {
      print('❌ CampaignService AuthException 발생: ${e.message}');
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '인증 오류: ${e.message}',
      );
    } catch (e) {
      print('❌ CampaignService 일반 에러 발생: ${e.toString()}');
      return ApiResponse<List<Campaign>>(
        success: false,
        error: '캠페인을 불러오는 중 오류가 발생했습니다: ${e.toString()}',
      );
    }
  }

  // 캠페인 상세 정보 가져오기
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

  // 인기 캠페인 가져오기 (참여자 수 기준)
  Future<ApiResponse<List<Campaign>>> getPopularCampaigns({
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active')
          .eq('category', 'reviewer')
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

  // 새 캠페인 가져오기 (최신순)
  Future<ApiResponse<List<Campaign>>> getNewCampaigns({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active')
          .eq('category', 'reviewer')
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

  // 캠페인 검색
  Future<ApiResponse<List<Campaign>>> searchCampaigns({
    required String query,
    String? category,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      var searchQuery = _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active');

      if (category != null) {
        searchQuery = searchQuery.eq('category', category);
      }

      final response = await searchQuery;

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  // 캠페인 참여
  Future<ApiResponse<bool>> joinCampaign(String campaignId) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<bool>(success: false, error: '로그인이 필요합니다.');
      }

      // TODO: 참여 로직 구현
      // 현재는 간단히 성공 응답만 반환

      return ApiResponse<bool>(
        success: true,
        data: true,
        message: '캠페인에 성공적으로 참여했습니다.',
      );
    } catch (e) {
      return ApiResponse<bool>(success: false, error: e.toString());
    }
  }

  // 캠페인 참여 취소
  Future<ApiResponse<bool>> leaveCampaign(String campaignId) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        return ApiResponse<bool>(success: false, error: '로그인이 필요합니다.');
      }

      // TODO: 참여 취소 로직 구현
      // 현재는 간단히 성공 응답만 반환

      return ApiResponse<bool>(
        success: true,
        data: true,
        message: '캠페인 참여를 취소했습니다.',
      );
    } catch (e) {
      return ApiResponse<bool>(success: false, error: e.toString());
    }
  }

  // 사용자가 참여한 캠페인 목록
  Future<ApiResponse<List<Campaign>>> getUserCampaigns({
    int page = 1,
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

      // TODO: 사용자 캠페인 목록 구현
      final campaigns = <Campaign>[];

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
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
          .eq('created_by', user.id)
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
        'category': previousCampaign.category.name,
        'type': previousCampaign.type.name,
        'product_price': previousCampaign.productPrice,
        'review_reward': previousCampaign.reviewReward,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'max_participants': maxParticipants,
        'current_participants': 0,
        'status': 'active',
        'created_by': user.id,
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
        print('Warning: Failed to update usage count: $updateError');
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
    required String category,
    required String type,
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

      final campaign = {
        'title': title.trim(),
        'description': description.trim(),
        'product_image_url': productImageUrl ?? '',
        'platform': platform,
        'platform_logo_url': platformLogoUrl ?? '',
        'category': category,
        'type': type,
        'product_price': productPrice,
        'review_reward': reviewReward,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'max_participants': maxParticipants,
        'current_participants': 0,
        'status': 'active',
        'created_by': user.id,
        'is_template': false,
        'template_name': null,
        'last_used_at': DateTime.now().toIso8601String(),
        'usage_count': 0,
      };

      final response = await _supabase
          .from('campaigns')
          .insert(campaign)
          .select()
          .single();

      final newCampaign = Campaign.fromJson(response);
      return ApiResponse<Campaign>(
        success: true,
        data: newCampaign,
        message: '캠페인이 성공적으로 생성되었습니다.',
      );
    } catch (e) {
      return ApiResponse<Campaign>(
        success: false,
        error: '캠페인 생성에 실패했습니다: ${e.toString()}',
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
          .eq('created_by', user.id)
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
}
