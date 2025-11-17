import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/campaign.dart';
import '../../../services/campaign_service.dart';
import '../../../config/supabase_config.dart';
import '../../../widgets/custom_button.dart';

class AdvertiserMyCampaignsScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  // pushNamed().then() 패턴으로 변경하여 refresh, campaignId 파라미터는 더 이상 사용하지 않음
  // @Deprecated('pushNamed().then() 패턴으로 변경하여 더 이상 사용하지 않음')
  // final bool refresh;
  // final String? campaignId;

  const AdvertiserMyCampaignsScreen({
    super.key,
    this.initialTab,
    // this.refresh = false,
    // this.campaignId,
  });

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

    // 초기 데이터 로드
    _loadCampaigns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 캠페인 생성 화면으로 이동 (pushNamed().then() 패턴)
  void _navigateToCreateCampaign() {
    context.pushNamed('advertiser-my-campaigns-create').then((result) {
      // result는 생성된 캠페인 ID (String) 또는 null
      if (result != null && result is String) {
        final campaignId = result;
        debugPrint('✅ 캠페인 생성 완료 - campaignId: $campaignId');
        // 생성된 캠페인을 직접 조회하여 목록에 추가 (Eventual Consistency 문제 해결)
        _addCampaignByIdDirectly(campaignId);
      } else if (result == true) {
        // fallback: true가 반환된 경우 일반 새로고침
        debugPrint('🔄 일반 새로고침 실행');
        _loadCampaigns();
      }
    });
  }

  /// 생성된 캠페인을 직접 조회하여 목록에 추가 (Eventual Consistency 문제 해결)
  Future<void> _addCampaignByIdDirectly(String campaignId) async {
    if (!mounted) return;

    debugPrint('🔍 생성된 캠페인 직접 조회 시작 - campaignId: $campaignId');

    try {
      // 짧은 지연 후 조회 (트랜잭션 커밋 대기)
      await Future.delayed(const Duration(milliseconds: 300));

      final result = await _campaignService.getCampaignById(campaignId);
      debugPrint(
        '📥 캠페인 조회 결과 - success: ${result.success}, data: ${result.data != null}',
      );

      if (result.success && result.data != null && mounted) {
        final campaign = result.data!;

        // 중복 체크
        if (!_allCampaigns.any((c) => c.id == campaignId)) {
          debugPrint('➕ 캠페인을 목록에 추가 - ${campaign.title}');
          _allCampaigns.insert(0, campaign);
          _updateFilteredCampaigns();

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('✅ UI 업데이트 완료 - 총 캠페인 수: ${_allCampaigns.length}');
          }
        } else {
          debugPrint('ℹ️ 캠페인이 이미 목록에 있습니다: $campaignId');
        }
      } else {
        debugPrint('⚠️ 캠페인을 찾을 수 없습니다. 일반 새로고침 실행...');
        // 직접 조회 실패 시 일반 새로고침
        _loadCampaigns();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 캠페인 직접 조회 실패: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // 에러 발생 시 일반 새로고침
      if (mounted) {
        _loadCampaigns();
      }
    }
  }

  // ============================================
  // 폴링 관련 메서드 (더 이상 사용하지 않음, 참고용으로 유지)
  // pushNamed().then() 패턴으로 변경하여 같은 세션에서 조회하므로 폴링 불필요
  // ============================================

  /// 새로고침 처리 (폴링 및 직접 조회) - 사용하지 않음
  @Deprecated('pushNamed().then() 패턴으로 변경하여 더 이상 사용하지 않음')
  Future<void> _handleRefresh(String? campaignId) async {
    debugPrint('🔄 PostFrameCallback 실행 - campaignId: $campaignId');

    if (campaignId != null && campaignId.isNotEmpty) {
      // 폴링 방식으로 캠페인 조회
      debugPrint('📡 폴링 시작 - campaignId: $campaignId');

      // 먼저 직접 조회 시도 (가장 빠른 방법)
      final directResult = await _addCampaignById(campaignId);

      // 직접 조회가 실패하면 폴링 시작
      if (!directResult) {
        await _loadCampaignsWithPolling(
          expectedCampaignId: campaignId,
          maxAttempts: 5,
          initialInterval: const Duration(milliseconds: 200),
        );
      }
    } else {
      // campaignId가 없으면 일반 조회
      debugPrint('⏳ campaignId 없음 - 일반 조회');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _loadCampaigns();
      }
    }

    // URL 파라미터 제거 (폴링 완료 후)
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final routerState = GoRouterState.of(context);
        if (routerState.uri.queryParameters.containsKey('refresh') ||
            routerState.uri.queryParameters.containsKey('campaignId')) {
          final newUri = routerState.uri.replace(
            queryParameters: Map.from(routerState.uri.queryParameters)
              ..remove('refresh')
              ..remove('campaignId'),
          );
          context.go(newUri.toString());
        }
      });
    }
  }

  Future<void> _loadCampaigns({bool forceRefresh = false}) async {
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
      List<Campaign> loadedCampaigns = [];

      debugPrint('📡 getUserCampaigns 호출 시작...');
      final result = await _campaignService.getUserCampaigns(
        page: 1,
        limit: 100,
      );

      if (!mounted) return;

      debugPrint('📥 getUserCampaigns 결과 - success: ${result.success}');

      if (result.success && result.data != null) {
        final campaignsData = result.data!;
        final campaignsList = campaignsData['campaigns'] as List?;

        debugPrint('📋 campaignsList: ${campaignsList?.length ?? 0}개');

        if (campaignsList != null && campaignsList.isNotEmpty) {
          loadedCampaigns = campaignsList
              .map((item) {
                final campaignData = item['campaign'] as Map<String, dynamic>?;
                if (campaignData != null) {
                  return Campaign.fromJson(campaignData);
                }
                return null;
              })
              .whereType<Campaign>()
              .toList();

          debugPrint('✅ RPC로 ${loadedCampaigns.length}개 캠페인 조회 성공');
          for (var campaign in loadedCampaigns.take(3)) {
            debugPrint('   - ${campaign.id}: ${campaign.title}');
          }
        } else {
          debugPrint('⚠️ campaignsList가 비어있거나 null입니다');
        }
      } else {
        debugPrint('❌ getUserCampaigns 실패 - error: ${result.error}');
      }

      // RPC 실패 또는 결과가 비어있으면 대체 로직 실행
      if (loadedCampaigns.isEmpty) {
        debugPrint('⚠️ RPC 결과가 비어있거나 실패. 대체 로직 실행...');
        try {
          // 1. 사용자의 회사 ID 조회
          final companyResult = await SupabaseConfig.client
              .from('company_users')
              .select('company_id')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();

          if (companyResult != null) {
            final companyId = companyResult['company_id'] as String;

            // 2. 회사의 캠페인 조회
            final directResult = await SupabaseConfig.client
                .from('campaigns')
                .select()
                .eq('company_id', companyId)
                .order('created_at', ascending: false);

            loadedCampaigns = (directResult as List)
                .map((json) => Campaign.fromJson(json))
                .toList();

            debugPrint('✅ 대체 로직으로 ${loadedCampaigns.length}개 캠페인 조회 성공');
          } else {
            debugPrint('⚠️ 사용자가 활성 회사에 소속되지 않음');
          }
        } catch (e) {
          debugPrint('❌ 대체 조회 실패: $e');
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

      _allCampaigns = loadedCampaigns;

      // 상태별 필터링
      final now = DateTime.now();

      // 대기중: upcoming 상태 또는 시작일이 아직 지나지 않음
      _pendingCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'upcoming' ||
            (campaign.startDate != null && campaign.startDate!.isAfter(now));
      }).toList();

      // 모집중: active 상태이고 현재 기간 내
      _recruitingCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'active' &&
            (campaign.startDate == null || campaign.startDate!.isBefore(now)) &&
            (campaign.endDate == null || campaign.endDate!.isAfter(now));
      }).toList();

      // 선정완료: active 상태이지만 참여자 선정이 완료된 경우
      // (실제로는 campaign_events의 approved 상태를 확인해야 하지만, 여기서는 간단히 처리)
      _selectedCampaigns = _recruitingCampaigns.where((campaign) {
        return campaign.currentParticipants >= (campaign.maxParticipants ?? 0);
      }).toList();

      // 등록기간: active 상태이지만 모집이 완료되고 진행 중인 상태
      _registeredCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'active' &&
            campaign.currentParticipants > 0 &&
            (campaign.maxParticipants == null ||
                campaign.currentParticipants < campaign.maxParticipants!);
      }).toList();

      // 종료: completed 상태 또는 종료일이 지남
      _completedCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'completed' ||
            (campaign.endDate != null && campaign.endDate!.isBefore(now));
      }).toList();

      // 디버깅 로그
      debugPrint('📊 캠페인 상태 분류:');
      debugPrint('   전체: ${_allCampaigns.length}개');
      debugPrint('   대기중: ${_pendingCampaigns.length}개');
      debugPrint('   모집중: ${_recruitingCampaigns.length}개');
      debugPrint('   선정완료: ${_selectedCampaigns.length}개');
      debugPrint('   등록기간: ${_registeredCampaigns.length}개');
      debugPrint('   종료: ${_completedCampaigns.length}개');
      for (var campaign in _allCampaigns.take(5)) {
        final status = campaign.status.toString().split('.').last;
        debugPrint(
          '   - ${campaign.title}: status=$status, startDate=${campaign.startDate}, endDate=${campaign.endDate}',
        );
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

  /// 폴링 방식으로 캠페인 조회 (생성된 캠페인이 나타날 때까지 재시도) - 사용하지 않음
  @Deprecated('pushNamed().then() 패턴으로 변경하여 더 이상 사용하지 않음')
  Future<void> _loadCampaignsWithPolling({
    required String expectedCampaignId,
    int maxAttempts = 5,
    Duration initialInterval = const Duration(milliseconds: 200),
  }) async {
    debugPrint(
      '🔄 폴링 시작 - expectedCampaignId: $expectedCampaignId, maxAttempts: $maxAttempts',
    );

    // 첫 시도 전에 짧은 지연 (트랜잭션 커밋 대기)
    await Future.delayed(initialInterval);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) {
        debugPrint('⚠️ 위젯이 unmount되어 폴링 중단');
        return;
      }

      debugPrint('📡 폴링 시도 ${attempt + 1}/$maxAttempts - 캠페인 목록 조회 중...');
      await _loadCampaigns();

      // 생성된 캠페인이 목록에 있는지 확인
      final found = _allCampaigns.any((c) => c.id == expectedCampaignId);
      debugPrint('🔍 현재 목록에 있는 캠페인 수: ${_allCampaigns.length}');
      debugPrint('🔍 찾는 캠페인 ID: $expectedCampaignId');
      debugPrint('🔍 찾음 여부: $found');

      if (found) {
        debugPrint(
          '✅ 생성된 캠페인을 찾았습니다: $expectedCampaignId (시도: ${attempt + 1}/$maxAttempts)',
        );
        return;
      }

      // 마지막 시도가 아니면 대기 후 재시도 (Exponential backoff)
      if (attempt < maxAttempts - 1) {
        // Exponential backoff: 200ms, 400ms, 800ms, 1600ms
        final delay = initialInterval * (1 << attempt);
        debugPrint(
          '⏳ 캠페인 조회 재시도 중... (${attempt + 1}/$maxAttempts) - ${delay.inMilliseconds}ms 대기',
        );
        await Future.delayed(delay);
      } else {
        debugPrint('⚠️ 최대 재시도 횟수 초과. 캠페인을 찾지 못했습니다. 직접 조회 시도...');
        // 최대 재시도 횟수 내에서 찾지 못하면 생성된 캠페인을 직접 조회하여 추가
        await _addCampaignById(expectedCampaignId);
      }
    }
  }

  /// 생성된 캠페인을 직접 조회하여 목록에 추가 - 사용하지 않음
  /// Returns: 성공 여부 (true: 추가 성공, false: 실패)
  @Deprecated('pushNamed().then() 패턴으로 변경하여 더 이상 사용하지 않음')
  Future<bool> _addCampaignById(String campaignId) async {
    if (!mounted) return false;

    debugPrint('🔍 캠페인 직접 조회 시작 - campaignId: $campaignId');

    try {
      final result = await _campaignService.getCampaignById(campaignId);
      debugPrint(
        '📥 캠페인 조회 결과 - success: ${result.success}, data: ${result.data != null}',
      );

      if (result.success && result.data != null && mounted) {
        final campaign = result.data!;

        // 중복 체크
        if (!_allCampaigns.any((c) => c.id == campaignId)) {
          debugPrint('➕ 캠페인을 목록에 추가 - ${campaign.title}');
          _allCampaigns.insert(0, campaign);
          _updateFilteredCampaigns();

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('✅ UI 업데이트 완료 - 총 캠페인 수: ${_allCampaigns.length}');
          }

          debugPrint('✅ 생성된 캠페인을 직접 조회하여 추가했습니다: ${campaign.title}');
          return true;
        } else {
          debugPrint('ℹ️ 캠페인이 이미 목록에 있습니다: $campaignId');
          return true; // 이미 있으면 성공으로 간주
        }
      } else {
        debugPrint('⚠️ 캠페인을 찾을 수 없습니다: $campaignId - error: ${result.error}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 캠페인 직접 조회 실패: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// 상태별 필터링 업데이트
  void _updateFilteredCampaigns() {
    final now = DateTime.now();

    // 대기중: upcoming 상태 또는 시작일이 아직 지나지 않음
    _pendingCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'upcoming' ||
          (campaign.startDate != null && campaign.startDate!.isAfter(now));
    }).toList();

    // 모집중: active 상태이고 현재 기간 내
    _recruitingCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'active' &&
          (campaign.startDate == null || campaign.startDate!.isBefore(now)) &&
          (campaign.endDate == null || campaign.endDate!.isAfter(now));
    }).toList();

    // 선정완료: active 상태이지만 참여자 선정이 완료된 경우
    _selectedCampaigns = _recruitingCampaigns.where((campaign) {
      return campaign.currentParticipants >= (campaign.maxParticipants ?? 0);
    }).toList();

    // 등록기간: active 상태이지만 모집이 완료되고 진행 중인 상태
    _registeredCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'active' &&
          campaign.currentParticipants > 0 &&
          (campaign.maxParticipants == null ||
              campaign.currentParticipants < campaign.maxParticipants!);
    }).toList();

    // 종료: completed 상태 또는 종료일이 지남
    _completedCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'completed' ||
          (campaign.endDate != null && campaign.endDate!.isBefore(now));
    }).toList();
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
            onPressed: () => _navigateToCreateCampaign(),
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
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                            '🖼️ 이미지 로딩 실패: ${campaign.productImageUrl}',
                          );
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 30,
                            ),
                          );
                        },
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
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
                          Text(
                            campaign.platform,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
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
