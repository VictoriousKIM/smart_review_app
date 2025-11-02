import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/campaign_log.dart';
import '../../../services/campaign_log_service.dart';
import '../../../config/supabase_config.dart';
import '../../../widgets/custom_button.dart';

class MyCampaignsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const MyCampaignsScreen({
    super.key,
    this.initialTab,
  });

  @override
  ConsumerState<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends ConsumerState<MyCampaignsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CampaignLogService _campaignLogService =
      CampaignLogService(SupabaseConfig.client);

  List<CampaignLog> _appliedCampaigns = [];
  List<CampaignLog> _approvedCampaigns = [];
  List<CampaignLog> _registeredCampaigns = [];
  List<CampaignLog> _completedCampaigns = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // 초기 탭 설정
    int initialIndex = 0;
    if (widget.initialTab != null) {
      switch (widget.initialTab) {
        case 'applied':
          initialIndex = 0;
          break;
        case 'approved':
          initialIndex = 1;
          break;
        case 'registered':
          initialIndex = 2;
          break;
        case 'completed':
          initialIndex = 3;
          break;
      }
    }

    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
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
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 신청 탭: status = 'applied'
      final appliedResult = await _campaignLogService.getUserCampaignLogs(
        userId: user.id,
        status: 'applied',
      );
      _appliedCampaigns = appliedResult.data ?? [];

      // 선정 탭: status = 'approved'
      final approvedResult = await _campaignLogService.getUserCampaignLogs(
        userId: user.id,
        status: 'approved',
      );
      _approvedCampaigns = approvedResult.data ?? [];

      // 등록 탭: status가 'purchased', 'review_submitted', 'visit_completed', 'article_submitted' 등
      final registeredResult = await _campaignLogService.getUserCampaignLogs(
        userId: user.id,
      );
      final allLogs = registeredResult.data ?? [];
      _registeredCampaigns = allLogs.where((log) {
        return ['purchased', 'review_submitted', 'visit_completed', 'article_submitted',
                'review_approved', 'visit_verified', 'article_approved']
            .contains(log.status);
      }).toList();

      // 완료 탭: status = 'payment_completed'
      final completedResult = await _campaignLogService.getUserCampaignLogs(
        userId: user.id,
        status: 'payment_completed',
      );
      _completedCampaigns = completedResult.data ?? [];

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 캠페인 로드 실패: $e');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('나의 캠페인'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/reviewer'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '신청'),
            Tab(text: '선정'),
            Tab(text: '등록'),
            Tab(text: '완료'),
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
                _buildCampaignList(_appliedCampaigns, '신청한 캠페인이 없습니다'),
                _buildCampaignList(_approvedCampaigns, '선정된 캠페인이 없습니다'),
                _buildCampaignList(_registeredCampaigns, '등록된 캠페인이 없습니다'),
                _buildCampaignList(_completedCampaigns, '완료된 캠페인이 없습니다'),
              ],
            ),
    );
  }

  Widget _buildCampaignList(List<CampaignLog> campaigns, String emptyMessage) {
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
              '새로운 캠페인에 참여해보세요!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: '캠페인 둘러보기',
              onPressed: () => context.go('/campaigns'),
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

  Widget _buildCampaignCard(CampaignLog log) {
    final campaign = log.campaign;
    if (campaign == null) {
      return const SizedBox.shrink();
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
                            color: Color(log.statusColor).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.statusDisplayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(log.statusColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 리워드 정보
              if (log.rewardAmount != null && log.rewardAmount! > 0)
                Row(
                  children: [
                    Icon(Icons.stars, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${log.rewardAmount} OP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

