import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/campaign.dart';
import '../../models/campaign_realtime_event.dart';
import '../../services/campaign_service.dart';
import '../../services/campaign_realtime_manager.dart';
import '../../widgets/campaign_card.dart';
import '../../utils/date_time_utils.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  // WidgetsBindingObserver 제거 (앱 레벨에서 처리)
  final CampaignService _campaignService = CampaignService();
  final _realtimeManager = CampaignRealtimeManager.instance;
  static const String _screenId = 'campaigns';

  List<Campaign> _allCampaigns = [];
  List<Campaign> _recruitingCampaigns = []; // 모집중인 캠페인만 표시

  bool _isLoading = true;
  DateTime? _nextOpenAt; // 서버가 알려준 다음 오픈 시간 (Phase 2)
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  // Pull-to-Refresh 충돌 방지용 큐
  List<CampaignRealtimeEvent> _pendingRealtimeEvents = [];

  // 디바운싱/스로틀링용 타이머
  Timer? _updateTimer;
  DateTime? _lastParticipantsUpdate;

  // 스마트 타이머: 다음 캠페인 오픈 시간에 맞춰 정확한 타이밍에 필터링 실행
  Timer? _preciseTimer;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': '전체', 'icon': Icons.apps, 'enabled': true},
    {'key': 'store', 'label': '스토어', 'icon': Icons.store, 'enabled': true},
    {'key': 'press', 'label': '기자단', 'icon': Icons.article, 'enabled': false},
    {'key': 'visit', 'label': '방문형', 'icon': Icons.store, 'enabled': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
    _searchController.addListener(_onSearchChanged);
    _initRealtimeSubscription();
  }

  @override
  void dispose() {
    _preciseTimer?.cancel();
    _updateTimer?.cancel();
    // 화면이 dispose될 때는 일시정지만 (구독 정보는 유지)
    _realtimeManager.unsubscribe(_screenId, force: false);
    _searchController.dispose();
    super.dispose();
  }

  /// 다음 캠페인 오픈 시간에 맞춰 정확한 타이밍에 필터링 실행
  void _scheduleNextCampaignOpen() {
    _preciseTimer?.cancel(); // 기존 예약 취소 (타이머 누적 방지)

    if (_allCampaigns.isEmpty) return;

    final now = DateTimeUtils.nowKST();
    DateTime? nearestNextStartTime;

    // 아직 시작하지 않은 캠페인 중, 가장 빨리 시작하는 시간 찾기
    for (final campaign in _allCampaigns) {
      if (campaign.status == CampaignStatus.active &&
          campaign.applyStartDate.isAfter(now)) {
        if (nearestNextStartTime == null ||
            campaign.applyStartDate.isBefore(nearestNextStartTime)) {
          nearestNextStartTime = campaign.applyStartDate;
        }
      }
    }

    // 예약 걸기
    if (nearestNextStartTime != null) {
      // ⚠️ 중요: 타임존 동기화 확인
      // nearestNextStartTime과 now 모두 KST이므로 타임존 일치
      final difference = nearestNextStartTime.difference(now);

      // 정확한 타이밍을 위해 +500ms 정도 여유를 둠 (시스템 딜레이 고려)
      // ⚠️ 참고: 네트워크 딜레이(0.5~1초)는 별도로 고려됨
      final duration = difference + const Duration(milliseconds: 500);

      if (!duration.isNegative) {
        debugPrint(
          '💰 다음 캠페인 오픈 예약: ${duration.inSeconds}초 후 (${nearestNextStartTime})',
        );
        _preciseTimer = Timer(duration, () {
          if (mounted) {
            debugPrint('⏰ 캠페인 오픈 시간 도달! 리스트 갱신');
            setState(() {
              _updateFilteredCampaigns(); // 리스트 새로고침
            });
            _scheduleNextCampaignOpen(); // 그 다음 타자 예약
          }
        });
      }
    }
  }

  /// Realtime 구독 초기화
  Future<void> _initRealtimeSubscription() async {
    try {
      await _realtimeManager.subscribeWithRetry(
        screenId: _screenId,
        activeOnly: true,
        onEvent: _handleRealtimeUpdate,
        onError: (error) {
          debugPrint('❌ Realtime 구독 에러: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Realtime 구독 초기화 실패: $e');
    }
  }

  /// Realtime 이벤트 처리 (디바운싱/스로틀링 적용)
  void _handleRealtimeUpdate(CampaignRealtimeEvent event) {
    // Pull-to-Refresh 중이면 이벤트를 큐에 저장
    if (_isLoading) {
      _pendingRealtimeEvents.add(event);
      return;
    }

    // 참여자 수 업데이트는 Throttle (500ms)
    if (event.isUpdate && event.campaign != null) {
      final now = DateTime.now();
      if (_lastParticipantsUpdate != null &&
          now.difference(_lastParticipantsUpdate!) <
              const Duration(milliseconds: 500)) {
        // Throttle: 500ms 이내의 업데이트는 무시
        return;
      }
      _lastParticipantsUpdate = now;
    }

    // 리스트 갱신은 Debounce (1초)
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 1000), () {
      _processRealtimeEvent(event);
    });
  }

  /// Realtime 이벤트 처리 (실제 업데이트)
  void _processRealtimeEvent(CampaignRealtimeEvent event) {
    if (!mounted) return;

    setState(() {
      if (event.isInsert && event.campaign != null) {
        // 새 캠페인 추가 (모집중인 경우만)
        if (!_allCampaigns.any((c) => c.id == event.campaign!.id)) {
          _allCampaigns.insert(0, event.campaign!);
          _updateFilteredCampaigns();
        }
        // 새 캠페인 추가 시 타이머 재스케줄링 (다음 오픈 시간이 바뀔 수 있음)
        _scheduleNextCampaignOpen();
      } else if (event.isUpdate && event.campaign != null) {
        // 캠페인 정보 업데이트
        final index = _allCampaigns.indexWhere(
          (c) => c.id == event.campaign!.id,
        );
        if (index != -1) {
          _allCampaigns[index] = event.campaign!;
          _updateFilteredCampaigns();
        } else {
          // 목록에 없으면 추가 (모집중인 경우만)
          _allCampaigns.insert(0, event.campaign!);
          _updateFilteredCampaigns();
        }

        final oldStatus = event.oldRecord?['status'] as String?;
        final newStatus = event.newRecord?['status'] as String?;

        if (oldStatus != newStatus) {
          // 상태 변경: RPC 재호출 (다음 오픈 시간이 바뀔 수 있음)
          _loadCampaignsSmartly();
        } else {
          // 참여자 수 변경 등: 로컬에서 타이머 재스케줄링
          _scheduleNextCampaignOpen();
        }
      } else if (event.isDelete && event.oldRecord != null) {
        // 캠페인 삭제: RPC 재호출 (다음 오픈 시간이 바뀔 수 있음)
        _loadCampaignsSmartly();
      }
    });
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

  /// 모집중인 캠페인 + 오픈 예정 캠페인 필터링 (Phase 3: 1시간 이내 오픈 예정 포함)
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

    // 모집중 + 오픈 예정 캠페인 필터링
    _recruitingCampaigns = searchFiltered.where((campaign) {
      if (campaign.status != CampaignStatus.active) return false;

      // 모집중: 시작기간과 종료기간 사이면서 참여자가 다 차지 않은 경우
      final isRecruiting =
          !campaign.applyStartDate.isAfter(now) &&
          !campaign.applyEndDate.isBefore(now) &&
          campaign.currentParticipants < campaign.maxParticipants!;

      // 오픈 예정: 1시간 이내로 시작 예정인 경우
      final isUpcoming =
          campaign.applyStartDate.isAfter(now) &&
          campaign.applyStartDate.difference(now).inHours <= 1;

      return isRecruiting || isUpcoming;
    }).toList();
  }

  /// 스마트 RPC를 사용한 캠페인 로드 (Phase 2: Next-Tick RPC 전략)
  Future<void> _loadCampaignsSmartly() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _campaignService.getActiveCampaignsOptimized();

      if (response.success && response.data != null) {
        final campaigns = response.data!['campaigns'] as List<Campaign>;
        final nextOpenAt = response.data!['nextOpenAt'] as DateTime?;

        // 카테고리 필터링 적용
        List<Campaign> filteredCampaigns = campaigns;
        if (_selectedCategory != 'all') {
          filteredCampaigns = campaigns.where((campaign) {
            return campaign.campaignType.toString().split('.').last ==
                _selectedCategory;
          }).toList();
        }

        setState(() {
          _allCampaigns = filteredCampaigns;
          _nextOpenAt = nextOpenAt;
          _updateFilteredCampaigns();
          _isLoading = false;
        });

        // 다음 오픈 시간에 맞춰 타이머 설정
        _scheduleNextCampaignOpenFromServer(nextOpenAt);

        // 로딩이 끝나면 큐에 쌓인 Realtime 이벤트 처리
        if (_pendingRealtimeEvents.isNotEmpty) {
          for (final event in _pendingRealtimeEvents) {
            _processRealtimeEvent(event);
          }
          _pendingRealtimeEvents.clear();
        }
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
            content: Text('캠페인을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 서버가 알려준 다음 오픈 시간에 맞춰 타이머 설정 (Phase 2)
  void _scheduleNextCampaignOpenFromServer(DateTime? nextOpenAt) {
    _preciseTimer?.cancel();

    if (nextOpenAt == null) {
      // 서버에서 다음 오픈 시간이 없으면 로컬에서 찾기
      _scheduleNextCampaignOpen();
      return;
    }

    // ⚠️ 중요: 타임존 동기화
    // nextOpenAt은 이미 parseKST()로 KST로 변환된 상태
    // nowKST()도 KST이므로 타임존이 일치함
    final now = DateTimeUtils.nowKST();
    final difference = nextOpenAt.difference(now);

    // 딜레이 고려하여 +500ms 여유
    final duration = difference + const Duration(milliseconds: 500);

    if (!duration.isNegative) {
      debugPrint('💰 다음 현금 캠페인 오픈까지 대기: ${duration.inSeconds}초');
      _preciseTimer = Timer(duration, () {
        if (mounted) {
          debugPrint('⏰ 캠페인 오픈 시간 도달! RPC 재호출');
          // 시간이 되면 다시 로드!
          _loadCampaignsSmartly();
        }
      });
    } else {
      // 이미 지난 시간이면 즉시 재호출
      _loadCampaignsSmartly();
    }
  }

  Future<void> _loadCampaigns() async {
    // Phase 2: 스마트 RPC 사용
    await _loadCampaignsSmartly();
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
              final isEnabled = category['enabled'] as bool? ?? true;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isEnabled
                          ? () {
                              setState(() {
                                _selectedCategory = category['key'] as String;
                              });
                              _loadCampaignsSmartly(); // Phase 2: 스마트 RPC 사용
                            }
                          : null,
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
                              : (isEnabled
                                    ? Colors.grey[50]
                                    : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF137fec)
                                : (isEnabled
                                      ? Colors.grey[300]!
                                      : Colors.grey[200]!),
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
                                  : (isEnabled
                                        ? Colors.grey[600]
                                        : Colors.grey[400]),
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
                                    : (isEnabled
                                          ? Colors.grey[700]
                                          : Colors.grey[400]),
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
