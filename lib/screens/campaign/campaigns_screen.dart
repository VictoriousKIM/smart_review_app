import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/campaign.dart';
import '../../services/campaign_service.dart';
import '../../widgets/campaign_card.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  final CampaignService _campaignService = CampaignService();
  List<Campaign> _campaigns = [];
  List<Campaign> _filteredCampaigns = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': '전체'},
    {'key': 'reviewer', 'label': '리뷰어'},
    {'key': 'press', 'label': '기자단'},
    {'key': 'visit', 'label': '방문형'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterCampaigns();
    });
  }

  void _filterCampaigns() {
    if (_searchQuery.isEmpty) {
      _filteredCampaigns = _campaigns;
    } else {
      _filteredCampaigns = _campaigns.where((campaign) {
        return campaign.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            campaign.description.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            campaign.platform.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _campaignService.getCampaigns(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );

      if (response.success && response.data != null) {
        setState(() {
          _campaigns = response.data!;
          _filterCampaigns();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('캠페인을 불러오는데 실패했습니다: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
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
      body: Column(
        children: [
          // 헤더
          _buildHeader(),
          // 검색바 (검색 모드일 때만 표시)
          if (_isSearchVisible) _buildSearchBar(),
          // 카테고리 필터
          _buildCategoryFilter(),
          // 캠페인 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCampaigns.isEmpty
                ? _buildEmptyState()
                : _buildCampaignList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '캠페인',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchVisible = !_isSearchVisible;
                    if (!_isSearchVisible) {
                      _searchController.clear();
                      _searchQuery = '';
                      _filterCampaigns();
                    }
                  });
                },
                icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
                tooltip: _isSearchVisible ? '검색 닫기' : '검색',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '캠페인 제목, 설명, 플랫폼으로 검색...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF137fec), width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = category['key']!;
                  });
                  _loadCampaigns();
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

  Widget _buildCampaignList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCampaigns.length,
      itemBuilder: (context, index) {
        final campaign = _filteredCampaigns[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CampaignCard(
            campaign: campaign,
            onTap: () {
              print('🔥 Campaign card tapped: ${campaign.id}');
              context.go('/campaign/${campaign.id}');
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.campaign_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? '검색 결과가 없습니다' : '캠페인이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching ? '다른 검색어로 시도해보세요' : '새로운 캠페인이 등록되면 알려드릴게요!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF137fec),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('검색 초기화'),
            ),
          ],
        ],
      ),
    );
  }
}
