import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as app_user;
import '../../models/campaign.dart';
import '../../widgets/campaign_card.dart';
import '../../services/campaign_service.dart';
import '../../utils/date_time_utils.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final CampaignService _campaignService = CampaignService();
  List<Campaign> _allCampaigns = [];
  List<Campaign> _recruitingCampaigns = []; // 모집중인 캠페인만 표시
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 전체 캠페인 로드
      final campaignsResponse = await _campaignService.getCampaigns();

      setState(() {
        if (campaignsResponse.success && campaignsResponse.data != null) {
          _allCampaigns = campaignsResponse.data!;
          _updateFilteredCampaigns(); // 모집중인 캠페인만 필터링
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캠페인을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 모집중인 캠페인만 필터링 (광고주 마이캠페인 화면과 동일한 로직)
  void _updateFilteredCampaigns() {
    final now = DateTimeUtils.nowKST(); // 한국 시간 사용

    // 모집중: 시작기간과 종료기간 사이면서 참여자가 다 차지 않은 경우
    _recruitingCampaigns = _allCampaigns.where((campaign) {
      if (campaign.status != CampaignStatus.active) return false;
      // 날짜는 필수이므로 null 체크 불필요
      if (campaign.applyStartDate.isAfter(now)) return false;
      if (campaign.applyEndDate.isBefore(now)) return false;
      if (campaign.maxParticipants != null &&
          campaign.currentParticipants >= campaign.maxParticipants!)
        return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return _buildHomeTab(user);
  }

  Widget _buildHomeTab(AsyncValue<app_user.User?> user) {
    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  user.when(
                    data: (userData) => Text(
                      userData?.displayName ?? '게스트',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    loading: () => const Text(
                      '로딩 중...',
                      style: TextStyle(color: Colors.white),
                    ),
                    error: (_, _) => const Text(
                      '게스트',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '새로운 리뷰 캠페인을 발견해보세요',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // 모집중인 캠페인
            _buildSection(
              title: '모집중인 캠페인',
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recruitingCampaigns.isEmpty
                  ? const Center(child: Text('모집중인 캠페인이 없습니다'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recruitingCampaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = _recruitingCampaigns[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: CampaignCard(
                            campaign: campaign,
                            onTap: () => _navigateToCampaignDetail(campaign.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  void _navigateToCampaignDetail(String campaignId) {
    // print('🔥 Home campaign card tapped: $campaignId');
    context.go('/campaigns/$campaignId');
  }
}
