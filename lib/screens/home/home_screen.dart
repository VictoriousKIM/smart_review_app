import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/campaign_provider.dart';
import '../../models/user.dart' as app_user;
import '../../models/campaign.dart';
import '../../models/api_response.dart';
import '../../widgets/campaign_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 캠페인 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(campaignProvider.notifier).loadCampaigns(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final campaigns = ref.watch(campaignProvider);
    final popularCampaigns = ref.watch(popularCampaignsProvider(limit: 5));
    final newCampaigns = ref.watch(newCampaignsProvider(limit: 5));

    return _buildHomeTab(user, campaigns, popularCampaigns, newCampaigns);
  }

  Widget _buildHomeTab(
    AsyncValue<app_user.User?> user,
    AsyncValue<List<Campaign>> campaigns,
    AsyncValue<ApiResponse<List<Campaign>>> popularCampaigns,
    AsyncValue<ApiResponse<List<Campaign>>> newCampaigns,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(campaignProvider.notifier).refreshCampaigns();
      },
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '안녕하세요!',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          user.when(
                            data: (userData) => Text(
                              userData?.displayName ?? '사용자',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            loading: () => const Text(
                              '로딩 중...',
                              style: TextStyle(color: Colors.white),
                            ),
                            error: (_, __) => const Text(
                              '사용자',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: user.when(
                          data: (userData) => userData?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    userData!.photoURL!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.white),
                          loading: () =>
                              const Icon(Icons.person, color: Colors.white),
                          error: (_, __) =>
                              const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                    ],
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

            // 인기 캠페인
            _buildSection(
              title: '인기 캠페인',
              child: popularCampaigns.when(
                data: (data) => data.success && data.data != null
                    ? SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: data.data!.length,
                          itemBuilder: (context, index) {
                            final campaign = data.data![index];
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
                      )
                    : const Center(child: Text('인기 캠페인이 없습니다')),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('오류: $error')),
              ),
            ),

            // 새 캠페인
            _buildSection(
              title: '새 캠페인',
              child: newCampaigns.when(
                data: (data) => data.success && data.data != null
                    ? SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: data.data!.length,
                          itemBuilder: (context, index) {
                            final campaign = data.data![index];
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
                      )
                    : const Center(child: Text('새 캠페인이 없습니다')),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('오류: $error')),
              ),
            ),

            // 전체 캠페인
            _buildSection(
              title: '전체 캠페인',
              child: campaigns.when(
                data: (data) => data.isEmpty
                    ? const Center(child: Text('캠페인이 없습니다'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final campaign = data[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: CampaignCard(
                              campaign: campaign,
                              onTap: () =>
                                  _navigateToCampaignDetail(campaign.id),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('오류: $error')),
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
