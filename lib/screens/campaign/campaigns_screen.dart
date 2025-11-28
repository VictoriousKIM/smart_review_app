import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/campaign.dart';
import '../../services/campaign_service.dart';
import '../../widgets/campaign_card.dart';
import '../../utils/date_time_utils.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  final CampaignService _campaignService = CampaignService();

  List<Campaign> _allCampaigns = [];
  List<Campaign> _recruitingCampaigns = []; // 모집중인 캠페인만 표시

  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': '전체', 'icon': Icons.apps},
    {'key': 'reviewer', 'label': '리뷰어', 'icon': Icons.rate_review},
    {'key': 'press', 'label': '기자단', 'icon': Icons.article},
    {'key': 'visit', 'label': '방문형', 'icon': Icons.store},
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
    // 검색어에 따라 필터링된 캠페인 목록 업데이트
    _updateFilteredCampaigns();
  }

  /// 모집중인 캠페인만 필터링 (광고주 마이캠페인 화면과 동일한 로직)
  void _updateFilteredCampaigns() {
    final now = DateTimeUtils.nowKST(); // 한국 시간 사용

    // 검색어 필터링
    List<Campaign> searchFiltered = _allCampaigns;
    if (_searchQuery.isNotEmpty) {
      searchFiltered = _allCampaigns.where((campaign) {
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

    // 모집중: 시작기간과 종료기간 사이면서 참여자가 다 차지 않은 경우
    _recruitingCampaigns = searchFiltered.where((campaign) {
      if (campaign.status != CampaignStatus.active) return false;
      if (campaign.applyStartDate.isAfter(now)) return false;
      if (campaign.applyEndDate.isBefore(now)) return false;
      if (campaign.maxParticipants != null &&
          campaign.currentParticipants >= campaign.maxParticipants!)
        return false;
      return true;
    }).toList();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _campaignService.getCampaigns(
        campaignType: _selectedCategory == 'all' ? null : _selectedCategory,
      );

      if (response.success && response.data != null) {
        setState(() {
          _allCampaigns = response.data!;
          _updateFilteredCampaigns();
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
                : _recruitingCampaigns.isEmpty
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category['key'];
              final icon = category['icon'] as IconData;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category['key'] as String;
                        });
                        _loadCampaigns();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF137fec)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF137fec)
                                : Colors.grey[300]!,
                            width: isSelected ? 0 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF137fec,
                                    ).withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _recruitingCampaigns.length,
      itemBuilder: (context, index) {
        final campaign = _recruitingCampaigns[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CampaignCard(
            campaign: campaign,
            onTap: () {
              // print('🔥 Campaign card tapped: ${campaign.id}');
              context.go('/campaigns/${campaign.id}');
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    final message = isSearching ? '검색 결과가 없습니다' : '모집중인 캠페인이 없습니다';

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
            message,
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
