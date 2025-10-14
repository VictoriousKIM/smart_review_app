import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserCampaignsScreen extends ConsumerStatefulWidget {
  const AdvertiserCampaignsScreen({super.key});

  @override
  ConsumerState<AdvertiserCampaignsScreen> createState() =>
      _AdvertiserCampaignsScreenState();
}

class _AdvertiserCampaignsScreenState
    extends ConsumerState<AdvertiserCampaignsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _campaigns = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _campaigns = [
        {
          'id': '1',
          'title': '새로운 스마트폰 리뷰 캠페인',
          'status': 'active',
          'statusText': '모집중',
          'participants': 15,
          'maxParticipants': 50,
          'startDate': '2024-01-15',
          'endDate': '2024-02-15',
          'reward': 50000,
        },
        {
          'id': '2',
          'title': '헤드폰 리뷰 캠페인',
          'status': 'completed',
          'statusText': '완료',
          'participants': 30,
          'maxParticipants': 30,
          'startDate': '2024-01-01',
          'endDate': '2024-01-31',
          'reward': 30000,
        },
        {
          'id': '3',
          'title': '키보드 리뷰 캠페인',
          'status': 'draft',
          'statusText': '임시저장',
          'participants': 0,
          'maxParticipants': 20,
          'startDate': '2024-02-01',
          'endDate': '2024-02-28',
          'reward': 25000,
        },
      ];
      _isLoading = false;
    });
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
          onPressed: () => context.go('/mypage'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/campaigns/create');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 필터 탭
        _buildFilterTabs(),

        // 캠페인 목록
        Expanded(
          child: _campaigns.isEmpty
              ? _buildEmptyState()
              : _buildCampaignsList(),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': '전체'},
      {'key': 'active', 'label': '모집중'},
      {'key': 'completed', 'label': '완료'},
      {'key': 'draft', 'label': '임시저장'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['key']!;
                  });
                },
                selectedColor: const Color(0xFF137fec),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '등록된 캠페인이 없습니다',
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
            onPressed: () {
              Navigator.pushNamed(context, '/campaigns/create');
            },
            backgroundColor: const Color(0xFF137fec),
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsList() {
    final filteredCampaigns = _selectedFilter == 'all'
        ? _campaigns
        : _campaigns
              .where((campaign) => campaign['status'] == _selectedFilter)
              .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCampaigns.length,
      itemBuilder: (context, index) {
        final campaign = filteredCampaigns[index];
        return _buildCampaignCard(campaign);
      },
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    Color statusColor;
    switch (campaign['status']) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      case 'draft':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    campaign['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    campaign['statusText'],
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
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
                  '참여자: ${campaign['participants']}/${campaign['maxParticipants']}명',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${campaign['reward'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 기간 정보
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${campaign['startDate']} ~ ${campaign['endDate']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 액션 버튼들
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: '상세보기',
                    onPressed: () => _viewCampaignDetail(campaign),
                    backgroundColor: Colors.grey[100],
                    textColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                if (campaign['status'] == 'draft')
                  Expanded(
                    child: CustomButton(
                      text: '수정',
                      onPressed: () => _editCampaign(campaign),
                      backgroundColor: const Color(0xFF137fec),
                      textColor: Colors.white,
                    ),
                  ),
                if (campaign['status'] == 'active') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: '참여자 관리',
                      onPressed: () => _manageParticipants(campaign),
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewCampaignDetail(Map<String, dynamic> campaign) {
    Navigator.pushNamed(context, '/campaigns/${campaign['id']}');
  }

  void _editCampaign(Map<String, dynamic> campaign) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캠페인 수정 기능은 준비 중입니다')));
  }

  void _manageParticipants(Map<String, dynamic> campaign) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('참여자 관리 기능은 준비 중입니다')));
  }
}
