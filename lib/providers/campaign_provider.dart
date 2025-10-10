import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/campaign.dart';
import '../models/api_response.dart';
import '../services/campaign_service.dart';
import 'auth_provider.dart';

part 'campaign_provider.g.dart';

@Riverpod(keepAlive: true)
CampaignService campaignService(Ref ref) => CampaignService();

// 인기 캠페인 가져오기
@riverpod
Future<ApiResponse<List<Campaign>>> popularCampaigns(
  Ref ref, {
  int limit = 5,
}) async {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getPopularCampaigns(limit: limit);
}

// 새 캠페인 가져오기
@riverpod
Future<ApiResponse<List<Campaign>>> newCampaigns(
  Ref ref, {
  int limit = 5,
}) async {
  final campaignService = ref.watch(campaignServiceProvider);
  return campaignService.getNewCampaigns(limit: limit);
}

// 사용자별 캠페인 가져오기
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
@Riverpod(keepAlive: false)
class CampaignNotifier extends _$CampaignNotifier {
  @override
  Future<List<Campaign>> build() async {
    print('🔍 CampaignProvider.build() 호출됨 - 새로고침 후 즉시 캠페인 로드');
    
    try {
      // CampaignService 직접 호출
      final campaignService = CampaignService();
      final response = await campaignService.getCampaigns();
      
      print('🔍 CampaignService 응답: success=${response.success}, data=${response.data?.length}개');
      
      if (response.success && response.data != null) {
        print('🔍 캠페인 로드 성공: ${response.data!.length}개');
        return response.data!;
      } else {
        print('❌ CampaignService 실패: ${response.error}');
        return [];
      }
    } catch (e) {
      print('❌ CampaignProvider 에러 발생: ${e.toString()}');
      return [];
    }
  }
  
  // 새로고침 메서드
  Future<void> refreshCampaigns() async {
    print('🔍 refreshCampaigns 호출됨');
    ref.invalidateSelf();
  }
}