import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as app_user;
import '../../models/campaign.dart';
import '../../models/campaign_realtime_event.dart';
import '../../widgets/campaign_card.dart';
import '../../services/campaign_service.dart';
import '../../services/campaign_realtime_manager.dart';
import '../../utils/date_time_utils.dart';
import 'package:responsive_builder/responsive_builder.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // WidgetsBindingObserver 제거 (앱 레벨에서 처리)
  final CampaignService _campaignService = CampaignService();
  final _realtimeManager = CampaignRealtimeManager.instance;
  static const String _screenId = 'home';

  List<Campaign> _allCampaigns = [];
  List<Campaign> _recruitingCampaigns = []; // 모집중인 캠페인만 표시
  bool _isLoading = true;

  // Pull-to-Refresh 충돌 방지용 큐
  final List<CampaignRealtimeEvent> _pendingRealtimeEvents = [];

  // 디바운싱/스로틀링용 타이머
  Timer? _updateTimer;
  DateTime? _lastParticipantsUpdate;

  // 스마트 타이머: 다음 캠페인 오픈 시간에 맞춰 정확한 타이밍에 필터링 실행
  Timer? _preciseTimer;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
    _initRealtimeSubscription();
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
          '💰 다음 캠페인 오픈 예약: ${duration.inSeconds}초 후 ($nearestNextStartTime)',
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

  @override
  void dispose() {
    _preciseTimer?.cancel();
    _updateTimer?.cancel();
    // 화면이 dispose될 때는 일시정지만 (구독 정보는 유지)
    _realtimeManager.unsubscribe(_screenId, force: false);
    super.dispose();
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

  /// Realtime 이벤트 처리 (디버깅 강화)
  void _handleRealtimeUpdate(CampaignRealtimeEvent event) {
    debugPrint('');
    debugPrint('🔄 ========================================');
    debugPrint('🔄 _handleRealtimeUpdate 호출');
    debugPrint('🔄 event.type: ${event.type}');
    debugPrint('🔄 event.isUpdate: ${event.isUpdate}');
    debugPrint('🔄 event.campaign: ${event.campaign?.id}');
    debugPrint(
      '🔄 event.campaign?.currentParticipants: ${event.campaign?.currentParticipants}',
    );
    debugPrint('🔄 _isLoading: $_isLoading');
    debugPrint('🔄 ========================================');

    // Pull-to-Refresh 중이면 이벤트를 큐에 저장
    if (_isLoading) {
      debugPrint('⏸️ 로딩 중이므로 이벤트를 큐에 저장');
      _pendingRealtimeEvents.add(event);
      return;
    }

    // 참여자 수 업데이트는 Throttle (300ms로 단축)
    if (event.isUpdate && event.campaign != null) {
      final now = DateTime.now();
      if (_lastParticipantsUpdate != null) {
        final diff = now.difference(_lastParticipantsUpdate!);
        debugPrint('⏱️ 마지막 업데이트로부터: ${diff.inMilliseconds}ms');
        if (diff < const Duration(milliseconds: 300)) {
          debugPrint(
            '⏭️ Throttle로 인해 이벤트 무시 (${diff.inMilliseconds}ms < 300ms)',
          );
          return;
        }
      }
      _lastParticipantsUpdate = now;
    }

    // ⚠️ 디버깅용: Debounce 없이 즉시 처리
    debugPrint('🚀 Debounce 없이 즉시 _processRealtimeEvent 호출');
    _processRealtimeEvent(event);

    // 원래 코드 (Debounce 적용)
    // _updateTimer?.cancel();
    // _updateTimer = Timer(const Duration(milliseconds: 300), () {
    //   _processRealtimeEvent(event);
    // });
  }

  /// Realtime 이벤트 처리 (실제 업데이트) - 디버깅 강화
  void _processRealtimeEvent(CampaignRealtimeEvent event) {
    if (!mounted) {
      debugPrint('⚠️ Widget이 이미 dispose됨, 이벤트 무시');
      return;
    }

    debugPrint('');
    debugPrint('🔄 ========================================');
    debugPrint('🔄 _processRealtimeEvent 시작');
    debugPrint('🔄 event.type: ${event.type}');
    debugPrint('🔄 event.isUpdate: ${event.isUpdate}');
    debugPrint('🔄 event.campaign?.id: ${event.campaign?.id}');
    debugPrint('🔄 ========================================');

    if (event.isInsert && event.campaign != null) {
      debugPrint('➕ INSERT 이벤트 처리');
      _loadCampaignsSmartly();
    } else if (event.isUpdate && event.campaign != null) {
      debugPrint('📝 UPDATE 이벤트 처리');

      final oldStatus = event.oldRecord?['status'] as String?;
      final newStatus = event.newRecord?['status'] as String?;
      final oldParticipants = event.oldRecord?['current_participants'] as int?;
      final newParticipants = event.newRecord?['current_participants'] as int?;

      debugPrint('📊 참여자 수 변경: $oldParticipants -> $newParticipants');
      debugPrint('📊 상태 변경: $oldStatus -> $newStatus');

      // oldStatus와 newStatus가 모두 존재하고 다를 때만 상태 변경으로 판단
      if (oldStatus != null && newStatus != null && oldStatus != newStatus) {
        // 상태 변경: RPC 재호출 (다음 오픈 시간이 바뀔 수 있음)
        debugPrint('📊 상태 변경 감지: RPC 재호출 ($oldStatus -> $newStatus)');
        _loadCampaignsSmartly();
      } else {
        // 참여자 수 변경 등: UI만 업데이트
        final index = _allCampaigns.indexWhere(
          (c) => c.id == event.campaign!.id,
        );

        debugPrint('🔍 캠페인 검색 결과 - index: $index');
        debugPrint('🔍 _allCampaigns 개수: ${_allCampaigns.length}');
        debugPrint(
          '🔍 _allCampaigns IDs: ${_allCampaigns.map((c) => c.id).toList()}',
        );

        if (index != -1) {
          debugPrint('✅ 캠페인 찾음!');
          debugPrint(
            '   기존 참여자 수: ${_allCampaigns[index].currentParticipants}',
          );
          debugPrint('   새 참여자 수: ${event.campaign!.currentParticipants}');

          setState(() {
            _allCampaigns[index] = event.campaign!;
            _updateFilteredCampaigns();
          });

          debugPrint('✅ setState 호출 완료');
          debugPrint(
            '   업데이트 후 _recruitingCampaigns 개수: ${_recruitingCampaigns.length}',
          );
        } else {
          debugPrint('⚠️ 캠페인을 _allCampaigns에서 찾을 수 없음!');
          debugPrint('   찾으려는 ID: ${event.campaign!.id}');
          // 목록에 없으면 추가 (모집중인 경우만)
          debugPrint('➕ 캠페인 목록에 없음, 추가 시도');
          setState(() {
            _allCampaigns.insert(0, event.campaign!);
            _updateFilteredCampaigns();
          });
        }
        // 로컬에서 타이머 재스케줄링
        _scheduleNextCampaignOpen();
      }
    } else if (event.isDelete && event.oldRecord != null) {
      debugPrint('🗑️ DELETE 이벤트 처리');
      _loadCampaignsSmartly();
    } else {
      debugPrint('⚠️ 처리되지 않은 이벤트');
      debugPrint('   event.isInsert: ${event.isInsert}');
      debugPrint('   event.isUpdate: ${event.isUpdate}');
      debugPrint('   event.isDelete: ${event.isDelete}');
      debugPrint('   event.campaign: ${event.campaign}');
      debugPrint('   event.oldRecord: ${event.oldRecord}');
    }
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

        setState(() {
          _allCampaigns = campaigns;
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

  /// 모집중인 캠페인 + 오픈 예정 캠페인 필터링 (Phase 3: 1시간 이내 오픈 예정 포함)
  void _updateFilteredCampaigns() {
    final now = DateTimeUtils.nowKST(); // 한국 시간 사용

    _recruitingCampaigns = _allCampaigns.where((campaign) {
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return _buildHomeTab(user);
  }

  Widget _buildHomeTab(AsyncValue<app_user.User?> user) {
    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ResponsiveBuilder(
        builder: (context, sizingInformation) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: getValueForScreenType<double>(
                    context: context,
                    mobile: double.infinity,
                    tablet: 800,
                    desktop: 1200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Container(
                      padding: getValueForScreenType<EdgeInsets>(
                        context: context,
                        mobile: const EdgeInsets.all(24),
                        tablet: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        desktop: const EdgeInsets.symmetric(horizontal: 60, vertical: 32),
                      ),
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
                  Text(
                    '안녕하세요!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  user.when(
                    data: (userData) => Text(
                      userData?.displayName ?? '게스트',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    loading: () => const Text(
                      '로딩 중...',
                      style: TextStyle(color: Colors.white),
                    ),
                    error: (_, _) => const Text(
                      '게스트',
                      style: TextStyle(color: Colors.white),
                    ),
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

                    // 모집중인 캠페인
                    _buildSection(
                      title: '모집중인 캠페인',
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _recruitingCampaigns.isEmpty
                          ? const Center(child: Text('모집중인 캠페인이 없습니다'))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recruitingCampaigns.length,
                              itemBuilder: (context, index) {
                                final campaign = _recruitingCampaigns[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: CampaignCard(
                                    campaign: campaign,
                                    onTap: () => _navigateToCampaignDetail(campaign.id),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
    // debugPrint('🔥 Home campaign card tapped: $campaignId');
    context.go('/campaigns/$campaignId');
  }
}
