import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as app_user;
import '../../models/campaign.dart';
import '../../widgets/campaign_card.dart';
import '../../services/campaign_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final CampaignService _campaignService = CampaignService();
  List<Campaign> _campaigns = [];
  List<Campaign> _popularCampaigns = [];
  List<Campaign> _newCampaigns = [];
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

      // 인기 캠페인 로드
      final popularResponse = await _campaignService.getPopularCampaigns(
        limit: 5,
      );

      // 새 캠페인 로드
      final newResponse = await _campaignService.getNewCampaigns(limit: 5);

      setState(() {
        if (campaignsResponse.success && campaignsResponse.data != null) {
          _campaigns = campaignsResponse.data!;
        }
        if (popularResponse.success && popularResponse.data != null) {
          _popularCampaigns = popularResponse.data!;
        }
        if (newResponse.success && newResponse.data != null) {
          _newCampaigns = newResponse.data!;
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
            SafeArea(
              minimum: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
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
                      error: (_, __) => const Text(
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
            ),

            // 인기 캠페인
            _buildSection(
              title: '인기 캠페인',
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _popularCampaigns.isEmpty
                  ? const Center(child: Text('인기 캠페인이 없습니다'))
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _popularCampaigns.length,
                        itemBuilder: (context, index) {
                          final campaign = _popularCampaigns[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: CampaignCard(
                              campaign: campaign,
                              onTap: () =>
                                  _navigateToCampaignDetail(campaign.id),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // 새 캠페인
            _buildSection(
              title: '새 캠페인',
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _newCampaigns.isEmpty
                  ? const Center(child: Text('새 캠페인이 없습니다'))
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _newCampaigns.length,
                        itemBuilder: (context, index) {
                          final campaign = _newCampaigns[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: CampaignCard(
                              campaign: campaign,
                              onTap: () =>
                                  _navigateToCampaignDetail(campaign.id),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // 전체 캠페인
            _buildSection(
              title: '전체 캠페인',
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _campaigns.isEmpty
                  ? const Center(child: Text('캠페인이 없습니다'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _campaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = _campaigns[index];
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
    context.push('/campaign/$campaignId');
  }
}
