import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/campaign.dart';
import '../models/api_response.dart';
import '../services/campaign_service.dart';
import 'auth_provider.dart';

part 'campaign_provider.g.dart';

// CampaignService Provider
@Riverpod(keepAlive: true)
CampaignService campaignService(Ref ref) => CampaignService();

// 캠페인 목록 Provider
@riverpod
Future<ApiResponse<List<Campaign>>> campaigns(
  Ref ref, {
  required int page,
  int limit = 10,
  String? category,
  String? type,
  String sortBy = 'latest',
}) {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getCampaigns(
    page: page,
    limit: limit,
    campaignType: category,
    sortBy: sortBy,
  );
}

// 캠페인 상세 정보 Provider
@riverpod
Future<ApiResponse<Campaign>> campaignDetail(Ref ref, String campaignId) {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getCampaignById(campaignId);
}

// 인기 캠페인 Provider
@riverpod
Future<ApiResponse<List<Campaign>>> popularCampaigns(
  Ref ref, {
  required int limit,
}) {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getPopularCampaigns(limit: limit);
}

// 새 캠페인 Provider
@riverpod
Future<ApiResponse<List<Campaign>>> newCampaigns(
  Ref ref, {
  required int limit,
}) {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getNewCampaigns(limit: limit);
}

// 캠페인 검색 Provider
@riverpod
Future<ApiResponse<List<Campaign>>> searchCampaigns(
  Ref ref, {
  required String query,
  String? category,
  int page = 1,
  int limit = 10,
}) {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.searchCampaigns(
    query: query,
    campaignType: category,
    page: page,
    limit: limit,
  );
}

// 사용자 캠페인 목록 Provider
@riverpod
Future<ApiResponse<List<Campaign>>> userCampaigns(
  Ref ref, {
  required int page,
  int limit = 10,
}) {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getUserCampaigns(page: page, limit: limit);
}

// 캠페인 상태 관리 Notifier
@Riverpod(keepAlive: true)
class CampaignNotifier extends _$CampaignNotifier {
  CampaignService? _campaignService;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _currentCategory;
  String _currentSortBy = 'latest';
  final List<Campaign> _campaigns = [];
  bool _isInitialized = false;

  @override
  Future<List<Campaign>> build() async {
    // CampaignService를 한 번만 초기화
    _campaignService ??= ref.watch(campaignServiceProvider);

    // ⭐ 핵심 개선: 인증 상태에 관계없이 캠페인 로드 시도
    if (!_isInitialized && _campaigns.isEmpty) {
      await _loadCampaigns(refresh: true);
      _isInitialized = true;
    }

    // 인증 상태가 완전히 로드될 때까지 대기
    final authState = ref.watch(currentUserProvider);

    return authState.when(
      data: (user) async {
        if (user == null) {
          _campaigns.clear();
          _isInitialized = false; // 로그아웃 시 초기화 플래그 리셋
          return [];
        }
        return _campaigns;
      },
      loading: () async {
        // 로딩 중일 때도 캠페인 데이터 반환
        return _campaigns;
      },
      error: (_, _) async {
        // 에러 시 빈 리스트 반환하고 초기화 플래그 리셋
        _campaigns.clear();
        _isInitialized = false;
        return [];
      },
    );
  }

  Future<void> _loadCampaigns({
    String? category,
    String? type,
    String? sortBy,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _campaigns.clear();
      _currentCategory = category;
      _currentSortBy = sortBy ?? 'latest';
    }

    if (state.isLoading || !_hasMore) return;

    try {
      state = const AsyncValue.loading();

      if (_campaignService == null) {
        throw Exception('CampaignService가 초기화되지 않았습니다.');
      }

      final response = await _campaignService!.getCampaigns(
        page: _currentPage,
        limit: 10,
        campaignType: _currentCategory,
        sortBy: _currentSortBy,
      );

      if (response.success && response.data != null) {
        final newCampaigns = response.data!;
        _hasMore = newCampaigns.length == 10;
        _currentPage++;
        _campaigns.addAll(newCampaigns);
        state = AsyncValue.data(_campaigns);
      } else {
        throw Exception(response.error ?? '캠페인을 불러올 수 없습니다.');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> loadCampaigns({
    String? category,
    String? type,
    String? sortBy,
    bool refresh = false,
  }) async {
    await _loadCampaigns(
      category: category,
      type: type,
      sortBy: sortBy,
      refresh: refresh,
    );
  }

  Future<void> refreshCampaigns() async {
    _isInitialized = false; // 초기화 플래그 리셋
    await _loadCampaigns(refresh: true);
    _isInitialized = true;
  }

  Future<void> loadMoreCampaigns() async {
    await loadCampaigns();
  }

  Future<bool> joinCampaign(String campaignId) async {
    if (_campaignService == null) {
      return false;
    }

    final response = await _campaignService!.joinCampaign(campaignId);
    if (response.success) {
      await refreshCampaigns();
      return true;
    }
    return false;
  }

  Future<bool> leaveCampaign(String campaignId) async {
    if (_campaignService == null) {
      return false;
    }

    final response = await _campaignService!.leaveCampaign(campaignId);
    if (response.success) {
      await refreshCampaigns();
      return true;
    }
    return false;
  }
}

// 검색 상태 관리 Notifier
@Riverpod(keepAlive: true)
class SearchNotifier extends _$SearchNotifier {
  CampaignService? _campaignService;
  String _currentQuery = '';
  String? _currentCategory;
  int _currentPage = 1;
  bool _hasMore = true;
  final List<Campaign> _results = [];

  @override
  Future<List<Campaign>> build() async {
    _campaignService ??= ref.watch(campaignServiceProvider);
    return _results;
  }

  Future<void> search({
    required String query,
    String? category,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _results.clear();
      _currentQuery = query;
      _currentCategory = category;
    }

    if (state.isLoading || !_hasMore) return;

    try {
      state = const AsyncValue.loading();

      if (_campaignService == null) {
        throw Exception('CampaignService가 초기화되지 않았습니다.');
      }

      final response = await _campaignService!.searchCampaigns(
        query: _currentQuery,
        campaignType: _currentCategory,
        page: _currentPage,
        limit: 10,
      );

      if (response.success && response.data != null) {
        final newResults = response.data!;
        _hasMore = newResults.length == 10;
        _currentPage++;
        _results.addAll(newResults);
        state = AsyncValue.data(_results);
      } else {
        throw Exception(response.error ?? '검색 결과를 불러올 수 없습니다.');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> loadMoreResults() async {
    await search(query: _currentQuery, category: _currentCategory);
  }

  void clearSearch() {
    _results.clear();
    _currentQuery = '';
    _currentCategory = null;
    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.data([]);
  }
}
