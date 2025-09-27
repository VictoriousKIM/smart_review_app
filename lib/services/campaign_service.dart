import 'package:supabase_flutter/supabase_flutter.dart';
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
      var query = _supabase.from('campaigns').select().eq('status', 'active');

      if (category != null) {
        query = query.eq('category', category);
      }

      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query;

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
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

  // 인기 캠페인 가져오기
  Future<ApiResponse<List<Campaign>>> getPopularCampaigns({
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active')
          .eq('type', 'popular')
          .limit(limit);

      final campaigns = (response as List)
          .map((json) => Campaign.fromJson(json))
          .toList();

      return ApiResponse<List<Campaign>>(success: true, data: campaigns);
    } catch (e) {
      return ApiResponse<List<Campaign>>(success: false, error: e.toString());
    }
  }

  // 새 캠페인 가져오기
  Future<ApiResponse<List<Campaign>>> getNewCampaigns({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('status', 'active')
          .eq('type', 'new')
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
}
