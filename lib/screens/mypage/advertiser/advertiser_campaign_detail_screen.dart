import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../models/campaign.dart';
import '../../../providers/campaign_provider.dart';
import '../../../services/campaign_service.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserCampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;

  const AdvertiserCampaignDetailScreen({super.key, required this.campaignId});

  @override
  ConsumerState<AdvertiserCampaignDetailScreen> createState() =>
      _AdvertiserCampaignDetailScreenState();
}

class _AdvertiserCampaignDetailScreenState
    extends ConsumerState<AdvertiserCampaignDetailScreen> {
  final CampaignService _campaignService = CampaignService();
  bool _isUpdatingStatus = false;
  bool _isDeleting = false;
  bool _hasChanges = false; // 상태 변경 여부 추적

  @override
  Widget build(BuildContext context) {
    final campaignAsync = ref.watch(campaignDetailProvider(widget.campaignId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('캠페인 상세'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 변경사항이 있으면 true 반환, 없으면 null 반환
            context.pop(_hasChanges ? true : null);
          },
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
                  Text(response.error ?? '캠페인을 불러올 수 없습니다'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(
                      campaignDetailProvider(widget.campaignId),
                    ),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final campaign = response.data!;
          return _buildCampaignDetail(context, campaign);
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
                    ref.invalidate(campaignDetailProvider(widget.campaignId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignDetail(BuildContext context, Campaign campaign) {
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
                // 상태 배지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: campaign.status == CampaignStatus.active
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: campaign.status == CampaignStatus.active
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  child: Text(
                    campaign.status == CampaignStatus.active ? '활성화' : '비활성화',
                    style: TextStyle(
                      color: campaign.status == CampaignStatus.active
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                if (campaign.description.isNotEmpty)
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
                              '${_formatNumber(campaign.campaignReward)} P',
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
                    '신청 시작일시',
                    _formatDate(campaign.applyStartDate),
                  ),
                  _buildInfoItem(
                    context,
                    '신청 종료일시',
                    _formatDate(campaign.applyEndDate),
                  ),
                  _buildInfoItem(
                    context,
                    '리뷰 시작일시',
                    _formatDate(campaign.reviewStartDate),
                  ),
                  _buildInfoItem(
                    context,
                    '리뷰 종료일시',
                    _formatDate(campaign.reviewEndDate),
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
                  if (campaign.maxParticipants != null)
                    _buildInfoItem(
                      context,
                      '참여율',
                      '${((campaign.currentParticipants / campaign.maxParticipants!) * 100).toStringAsFixed(1)}%',
                    ),
                ]),

                const SizedBox(height: 32),

                // 활성화/비활성화 토글
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '캠페인 상태',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            campaign.status == CampaignStatus.active
                                ? '캠페인이 활성화되어 있습니다'
                                : '캠페인이 비활성화되어 있습니다',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      if (_isUpdatingStatus)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: campaign.status == CampaignStatus.active,
                          onChanged: (value) {
                            _handleStatusToggle(context, campaign, value);
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 편집 및 삭제 가능 여부 확인
                Builder(
                  builder: (context) {
                    final canEditOrDelete =
                        campaign.status == CampaignStatus.inactive &&
                        campaign.currentParticipants == 0;

                    return Column(
                      children: [
                        // 편집 버튼
                        CustomButton(
                          text: '캠페인 편집',
                          onPressed: canEditOrDelete
                              ? () => _handleEdit(context, campaign)
                              : null,
                          backgroundColor: canEditOrDelete
                              ? Colors.blue
                              : Colors.grey[300],
                          textColor: Colors.white,
                          width: double.infinity,
                        ),
                        const SizedBox(height: 8),
                        // 삭제 버튼
                        CustomButton(
                          text: '캠페인 삭제',
                          onPressed: canEditOrDelete
                              ? () => _handleDelete(context, campaign)
                              : null,
                          backgroundColor: canEditOrDelete
                              ? Colors.red
                              : Colors.grey[300],
                          textColor: Colors.white,
                          width: double.infinity,
                          isLoading: _isDeleting,
                        ),
                        if (!canEditOrDelete)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '편집과 삭제는 신청자가 없고 비활성화된 캠페인만 가능합니다',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),
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
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 16),
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
      case CampaignCategory.store:
        return '스토어';
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

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _handleStatusToggle(
    BuildContext context,
    Campaign campaign,
    bool isActive,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? '캠페인 활성화' : '캠페인 비활성화'),
        content: Text(isActive ? '이 캠페인을 활성화하시겠습니까?' : '이 캠페인을 비활성화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    final newStatus = isActive
        ? CampaignStatus.active
        : CampaignStatus.inactive;
    final result = await _campaignService.updateCampaignStatus(
      campaignId: campaign.id,
      status: newStatus,
    );

    setState(() {
      _isUpdatingStatus = false;
    });

    if (!mounted) return;

    if (result.success) {
      // Provider 새로고침
      ref.invalidate(campaignDetailProvider(widget.campaignId));

      setState(() {
        _hasChanges = true; // 변경사항 있음 표시
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? '캠페인이 활성화되었습니다' : '캠페인이 비활성화되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? '상태 업데이트에 실패했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDelete(BuildContext context, Campaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캠페인 삭제'),
        content: const Text('이 캠페인을 삭제하시겠습니까?\n삭제된 캠페인은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final result = await _campaignService.deleteCampaign(campaign.id);

    setState(() {
      _isDeleting = false;
    });

    if (!mounted) return;

    if (result.success) {
      // Provider 무효화
      ref.invalidate(campaignDetailProvider(widget.campaignId));

      // 변경사항 있음 표시
      setState(() {
        _hasChanges = true;
      });

      // 환불 금액이 있는 경우 메시지에 포함
      final refundMessage = result.message ?? '캠페인이 삭제되었습니다';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refundMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // 목록 화면으로 이동하면서 새로고침 트리거
      context.pop(true); // true를 반환하여 새로고침 필요함을 알림
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? '캠페인 삭제에 실패했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleEdit(BuildContext context, Campaign campaign) {
    context.push('/mypage/advertiser/my-campaigns/edit/${campaign.id}');
  }
}
