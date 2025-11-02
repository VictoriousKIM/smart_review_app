import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/campaign.dart';
import '../../../services/campaign_service.dart';
import '../../../config/supabase_config.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserMyCampaignsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const AdvertiserMyCampaignsScreen({super.key, this.initialTab});

  @override
  ConsumerState<AdvertiserMyCampaignsScreen> createState() =>
      _AdvertiserMyCampaignsScreenState();
}

class _AdvertiserMyCampaignsScreenState
    extends ConsumerState<AdvertiserMyCampaignsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CampaignService _campaignService = CampaignService();

  List<Campaign> _allCampaigns = [];
  List<Campaign> _pendingCampaigns = [];
  List<Campaign> _recruitingCampaigns = [];
  List<Campaign> _selectedCampaigns = [];
  List<Campaign> _registeredCampaigns = [];
  List<Campaign> _completedCampaigns = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 초기 탭 설정
    int initialIndex = 0;
    if (widget.initialTab != null) {
      switch (widget.initialTab) {
        case 'pending':
          initialIndex = 0;
          break;
        case 'recruiting':
          initialIndex = 1;
          break;
        case 'selected':
          initialIndex = 2;
          break;
        case 'registered':
          initialIndex = 3;
          break;
        case 'completed':
          initialIndex = 4;
          break;
      }
    }

    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCampaigns();
      }
    });

    _loadCampaigns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // 모든 캠페인 가져오기
      final result = await _campaignService.getUserCampaigns(
        page: 1,
        limit: 100,
      );

      if (!mounted) return;

      if (result.success && result.data != null) {
        final campaignsData = result.data!;
        final campaignsList = campaignsData['campaigns'] as List?;

        if (campaignsList != null) {
          _allCampaigns = campaignsList
              .map((item) {
                final campaignData = item['campaign'] as Map<String, dynamic>?;
                if (campaignData != null) {
                  return Campaign.fromJson(campaignData);
                }
                return null;
              })
              .whereType<Campaign>()
              .toList();
        } else {
          // RPC 응답이 다른 형식일 수 있으므로 직접 조회
          final directResult = await SupabaseConfig.client
              .from('campaigns')
              .select()
              .eq('user_id', user.id)
              .order('created_at', ascending: false);

          _allCampaigns = (directResult as List)
              .map((json) => Campaign.fromJson(json))
              .toList();
        }

        // 상태별 필터링
        final now = DateTime.now();

        // 대기중: upcoming 상태 또는 시작일이 아직 지나지 않음
        _pendingCampaigns = _allCampaigns.where((campaign) {
          return campaign.status == CampaignStatus.upcoming ||
              (campaign.startDate != null && campaign.startDate!.isAfter(now));
        }).toList();

        // 모집중: active 상태이고 현재 기간 내
        _recruitingCampaigns = _allCampaigns.where((campaign) {
          return campaign.status == CampaignStatus.active &&
              (campaign.startDate == null ||
                  campaign.startDate!.isBefore(now)) &&
              (campaign.endDate == null || campaign.endDate!.isAfter(now));
        }).toList();

        // 선정완료: active 상태이지만 참여자 선정이 완료된 경우
        // (실제로는 campaign_logs의 approved 상태를 확인해야 하지만, 여기서는 간단히 처리)
        _selectedCampaigns = _recruitingCampaigns.where((campaign) {
          return campaign.currentParticipants >=
              (campaign.maxParticipants ?? 0);
        }).toList();

        // 등록기간: active 상태이지만 모집이 완료되고 진행 중인 상태
        _registeredCampaigns = _allCampaigns.where((campaign) {
          return campaign.status == CampaignStatus.active &&
              campaign.currentParticipants > 0 &&
              (campaign.maxParticipants == null ||
                  campaign.currentParticipants < campaign.maxParticipants!);
        }).toList();

        // 종료: completed 상태 또는 종료일이 지남
        _completedCampaigns = _allCampaigns.where((campaign) {
          return campaign.status == CampaignStatus.completed ||
              (campaign.endDate != null && campaign.endDate!.isBefore(now));
        }).toList();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 캠페인 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('나의 캠페인'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/advertiser'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () =>
                context.go('/mypage/advertiser/my-campaigns/create'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '대기중'),
            Tab(text: '모집중'),
            Tab(text: '선정완료'),
            Tab(text: '등록기간'),
            Tab(text: '종료'),
          ],
          labelColor: const Color(0xFF137fec),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF137fec),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCampaignList(_pendingCampaigns, '대기중인 캠페인이 없습니다'),
                _buildCampaignList(_recruitingCampaigns, '모집중인 캠페인이 없습니다'),
                _buildCampaignList(_selectedCampaigns, '선정완료된 캠페인이 없습니다'),
                _buildCampaignList(_registeredCampaigns, '등록기간인 캠페인이 없습니다'),
                _buildCampaignList(_completedCampaigns, '종료된 캠페인이 없습니다'),
              ],
            ),
    );
  }

  Widget _buildCampaignList(List<Campaign> campaigns, String emptyMessage) {
    if (campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '새로운 캠페인을 등록해보세요!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: '캠페인 등록하기',
              onPressed: () =>
                  context.go('/mypage/advertiser/my-campaigns/create'),
              backgroundColor: const Color(0xFF137fec),
              textColor: Colors.white,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: campaigns.length,
        itemBuilder: (context, index) {
          return _buildCampaignCard(campaigns[index]);
        },
      ),
    );
  }

  Widget _buildCampaignCard(Campaign campaign) {
    String statusText;
    Color statusColor;

    if (campaign.status == CampaignStatus.upcoming) {
      statusText = '대기중';
      statusColor = Colors.orange;
    } else if (campaign.status == CampaignStatus.active) {
      statusText = '모집중';
      statusColor = Colors.green;
    } else {
      // CampaignStatus.completed
      statusText = '종료';
      statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.go('/campaigns/${campaign.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제품 이미지
                  if (campaign.productImageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        campaign.productImageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  const SizedBox(width: 12),
                  // 캠페인 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (campaign.platform.isNotEmpty)
                          Row(
                            children: [
                              if (campaign.platformLogoUrl.isNotEmpty)
                                Image.network(
                                  campaign.platformLogoUrl,
                                  width: 16,
                                  height: 16,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox.shrink(),
                                ),
                              if (campaign.platformLogoUrl.isNotEmpty)
                                const SizedBox(width: 4),
                              Text(
                                campaign.platform,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        // 상태 표시
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 참여자 정보
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '참여자: ${campaign.currentParticipants}${campaign.maxParticipants != null ? '/${campaign.maxParticipants}' : ''}명',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Icon(Icons.stars, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    '${campaign.reviewReward} OP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
              if (campaign.startDate != null || campaign.endDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${campaign.startDate != null ? campaign.startDate!.toString().substring(0, 10) : '미정'} ~ ${campaign.endDate != null ? campaign.endDate!.toString().substring(0, 10) : '미정'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
