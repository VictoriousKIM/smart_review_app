import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/campaign.dart';
import '../../providers/campaign_provider.dart';
import '../../widgets/custom_button.dart';

class CampaignDetailScreen extends ConsumerWidget {
  final String campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(campaignDetailProvider(campaignId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('캠페인 상세'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/campaigns'),
        ),
      ),
      body: campaignAsync.when(
        data: (response) {
          if (!response.success || response.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('캠페인을 불러올 수 없습니다'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(campaignDetailProvider(campaignId)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final campaign = response.data!;
          return _buildCampaignDetail(context, ref, campaign);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('오류: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(campaignDetailProvider(campaignId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignDetail(
    BuildContext context,
    WidgetRef ref,
    Campaign campaign,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지
          Container(
            width: double.infinity,
            height: 250,
            color: Colors.grey[100],
            child: CachedNetworkImage(
              imageUrl: campaign.productImageUrl,
              width: double.infinity,
              height: 250,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 250,
                color: Colors.grey[200],
                child: const Icon(Icons.error, size: 64),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 플랫폼
                Text(
                  _getPlatformName(campaign.platform),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                // 제목
                Text(
                  campaign.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // 설명
                Text(
                  campaign.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                const SizedBox(height: 24),

                // 리워드 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '리워드',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${campaign.reviewReward}P',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 캠페인 정보
                _buildInfoSection(context, '캠페인 정보', [
                  _buildInfoItem(
                    context,
                    '캠페인 타입',
                    _getCategoryName(campaign.campaignType),
                  ),
                  _buildInfoItem(
                    context,
                    '마감일',
                    campaign.endDate != null
                        ? _formatDeadline(campaign.endDate!)
                        : '상시',
                  ),
                  _buildInfoItem(
                    context,
                    '참여자 수',
                    '${campaign.currentParticipants}명',
                  ),
                  if (campaign.maxParticipants != null)
                    _buildInfoItem(
                      context,
                      '최대 참여자',
                      '${campaign.maxParticipants}명',
                    ),
                ]),

                // 참여 조건 (새로운 모델에서는 requirements가 없으므로 제거)
                // if (campaign.requirements.isNotEmpty) ...[
                //   const SizedBox(height: 24),
                //   _buildInfoSection(
                //     context,
                //     '참여 조건',
                //     campaign.requirements
                //         .map((req) => _buildInfoItem(context, '', '• $req'))
                //         .toList(),
                //   ),
                // ],

                // 태그 (새로운 모델에서는 tags가 없으므로 제거)
                // if (campaign.tags.isNotEmpty) ...[
                //   const SizedBox(height: 24),
                //   _buildInfoSection(context, '태그', [
                //     Wrap(
                //       spacing: 8,
                //       runSpacing: 8,
                //       children: campaign.tags
                //           .map(
                //             (tag) => Chip(
                //               label: Text(tag),
                //               backgroundColor: Theme.of(
                //                 context,
                //               ).colorScheme.primary.withValues(alpha: 0.1),
                //               labelStyle: TextStyle(
                //                 color: Theme.of(context).colorScheme.primary,
                //                 fontSize: 12,
                //               ),
                //             ),
                //           )
                //           .toList(),
                //     ),
                //   ]),
                // ],
                const SizedBox(height: 32),

                // 참여 버튼
                CustomButton(
                  text: '캠페인 참여하기',
                  onPressed: () => _joinCampaign(context, ref, campaign),
                  width: double.infinity,
                ),

                const SizedBox(height: 16),

                // 공유 버튼
                CustomButton(
                  text: '공유하기',
                  onPressed: () => _shareCampaign(context, campaign),
                  backgroundColor: Colors.white,
                  textColor: Theme.of(context).colorScheme.primary,
                  borderColor: Theme.of(context).colorScheme.primary,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(CampaignCategory category) {
    switch (category) {
      case CampaignCategory.all:
        return '전체';
      case CampaignCategory.reviewer:
        return '리뷰어';
      case CampaignCategory.press:
        return '기자단';
      case CampaignCategory.visit:
        return '방문형';
    }
  }

  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'coupang':
        return '쿠팡';
      case 'naver':
        return '네이버 쇼핑';
      case '11st':
        return '11번가';
      case 'visit':
        return '방문형';
      default:
        return platform;
    }
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 후 (${deadline.year}.${deadline.month}.${deadline.day})';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 후';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 후';
    } else {
      return '마감됨';
    }
  }

  void _joinCampaign(BuildContext context, WidgetRef ref, Campaign campaign) {
    // TODO: 캠페인 참여 로직 구현
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캠페인 참여 기능은 준비 중입니다')));
  }

  void _shareCampaign(BuildContext context, Campaign campaign) {
    // TODO: 캠페인 공유 로직 구현
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('공유 기능은 준비 중입니다')));
  }
}
