import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/campaign.dart';
import '../../../models/campaign_realtime_event.dart';
import '../../../services/campaign_service.dart';
import '../../../services/campaign_realtime_manager.dart';
import '../../../services/company_user_service.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../utils/date_time_utils.dart';

class AdvertiserMyCampaignsScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  // push().then() 패턴으로 변경하여 refresh, campaignId 파라미터는 더 이상 사용하지 않음
  // @Deprecated('push().then() 패턴으로 변경하여 더 이상 사용하지 않음')
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
  // WidgetsBindingObserver 제거 (앱 레벨에서 처리)
  late TabController _tabController;
  final CampaignService _campaignService = CampaignService();
  final _realtimeManager = CampaignRealtimeManager.instance;
  static const String _screenId = 'advertiser_my_campaigns';

  List<Campaign> _allCampaigns = [];
  List<Campaign> _pendingCampaigns = [];
  List<Campaign> _recruitingCampaigns = [];
  List<Campaign> _selectedCampaigns = [];
  List<Campaign> _registeredCampaigns = [];
  List<Campaign> _completedCampaigns = [];

  bool _isLoading = true;
  bool _shouldRefreshOnRestore = false; // 화면 복원 시 새로고침 플래그

  // Pull-to-Refresh 충돌 방지용 큐
  final List<CampaignRealtimeEvent> _pendingRealtimeEvents = [];

  // 디바운싱/스로틀링용 타이머
  Timer? _updateTimer;
  DateTime? _lastParticipantsUpdate;
  CampaignRealtimeEvent? _pendingEvent; // 마지막 이벤트 저장 (debounce용)

  // 다음 캠페인 오픈 시간 예약용 타이머
  Timer? _preciseTimer;

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

    // Realtime 구독 시작
    _initRealtimeSubscription();
  }

  /// Realtime 구독 초기화
  Future<void> _initRealtimeSubscription() async {
    try {
      // 이미 일시정지된 구독이 있으면 재개
      if (_realtimeManager.isSubscribed(_screenId)) {
        debugPrint('ℹ️ 이미 구독 중입니다: $_screenId');
        return;
      }

      // 일시정지된 구독이 있으면 재개
      final subscriptionInfo = _realtimeManager.getSubscriptionInfo(_screenId);
      if (subscriptionInfo['exists'] == true &&
          subscriptionInfo['isPaused'] == true) {
        debugPrint('▶️ 일시정지된 구독 재개: $_screenId');
        _realtimeManager.resumeSubscription(_screenId);
        return;
      }

      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;

      // 회사 ID 조회
      final companyId = await CompanyUserService.getUserCompanyId(userId);
      if (companyId == null) {
        debugPrint('⚠️ 회사 ID를 찾을 수 없어 Realtime 구독을 시작하지 않습니다.');
        return;
      }

      await _realtimeManager.subscribeWithRetry(
        screenId: _screenId,
        companyId: companyId,
        activeOnly: false, // 모든 상태의 캠페인 구독
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
    debugPrint('');
    debugPrint('🔄 ========================================');
    debugPrint('🔄 _handleRealtimeUpdate 호출 (advertiser_my_campaigns)');
    debugPrint('🔄 event.type: ${event.type}');
    debugPrint('🔄 event.isInsert: ${event.isInsert}');
    debugPrint('🔄 event.isUpdate: ${event.isUpdate}');
    debugPrint('🔄 event.campaign?.id: ${event.campaign?.id}');
    debugPrint('🔄 _isLoading: $_isLoading');
    debugPrint('🔄 ========================================');

    // Pull-to-Refresh 중이면 이벤트를 큐에 저장
    if (_isLoading) {
      debugPrint('⏳ 로딩 중 - 이벤트 큐에 저장');
      _pendingRealtimeEvents.add(event);
      return;
    }

    // INSERT 이벤트는 즉시 처리 (새 캠페인 생성은 즉시 반영되어야 함)
    if (event.isInsert && event.campaign != null) {
      debugPrint('🚀 INSERT 이벤트 - 즉시 처리');
      _processRealtimeEvent(event);
      return;
    }

    // DELETE 이벤트도 즉시 처리
    if (event.isDelete && event.oldRecord != null) {
      debugPrint('🚀 DELETE 이벤트 - 즉시 처리');
      _processRealtimeEvent(event);
      return;
    }

    // 참여자 수 업데이트는 Throttle (500ms)
    // 하지만 debounce 타이머는 항상 설정하여 마지막 이벤트를 처리
    if (event.isUpdate && event.campaign != null) {
      final now = DateTime.now();
      if (_lastParticipantsUpdate != null &&
          now.difference(_lastParticipantsUpdate!) <
              const Duration(milliseconds: 500)) {
        // Throttle: 500ms 이내의 업데이트는 마지막 이벤트만 저장
        debugPrint(
          '⏱️ Throttle 적용 - 마지막 이벤트 저장 (참여자 수: ${event.campaign?.currentParticipants})',
        );
        _pendingEvent = event;
        // debounce 타이머는 계속 설정 (마지막 이벤트 처리)
        _updateTimer?.cancel();
        _updateTimer = Timer(const Duration(milliseconds: 1000), () {
          if (_pendingEvent != null) {
            debugPrint(
              '✅ Debounce 완료 - 이벤트 처리 (참여자 수: ${_pendingEvent!.campaign?.currentParticipants})',
            );
            _processRealtimeEvent(_pendingEvent!);
            _pendingEvent = null;
          }
        });
        return;
      }
      _lastParticipantsUpdate = now;
    }

    // UPDATE 이벤트는 Debounce (1초)
    // 마지막 이벤트 저장
    if (event.isUpdate) {
      debugPrint('⏱️ UPDATE 이벤트 - Debounce 타이머 설정 (1초)');
      _pendingEvent = event;
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 1000), () {
        if (_pendingEvent != null) {
          debugPrint('✅ Debounce 완료 - 이벤트 처리');
          _processRealtimeEvent(_pendingEvent!);
          _pendingEvent = null;
        }
      });
    }
  }

  /// Realtime 이벤트 처리 (실제 업데이트) - 디버깅 강화
  void _processRealtimeEvent(CampaignRealtimeEvent event) {
    if (!mounted) {
      debugPrint('⚠️ 화면이 마운트되지 않음 - 이벤트 처리 건너뜀');
      return;
    }

    debugPrint('');
    debugPrint('🔄 ========================================');
    debugPrint('🔄 _processRealtimeEvent 시작 (advertiser_my_campaigns)');
    debugPrint('🔄 event.type: ${event.type}');
    debugPrint('🔄 event.isInsert: ${event.isInsert}');
    debugPrint('🔄 event.isUpdate: ${event.isUpdate}');
    debugPrint('🔄 event.isDelete: ${event.isDelete}');
    debugPrint('🔄 event.campaign?.id: ${event.campaign?.id}');
    debugPrint('🔄 ========================================');

    setState(() {
      if (event.isInsert && event.campaign != null) {
        // 새 캠페인 추가
        debugPrint('➕ INSERT 이벤트 처리');
        if (!_allCampaigns.any((c) => c.id == event.campaign!.id)) {
          debugPrint('✅ 새 캠페인 추가: ${event.campaign!.id}');
          debugPrint('   제목: ${event.campaign!.title}');
          debugPrint('   상태: ${event.campaign!.status}');
          _allCampaigns.insert(0, event.campaign!);
          _updateFilteredCampaigns();
          _scheduleNextCampaignOpen();
          debugPrint('✅ 캠페인 추가 완료, _allCampaigns 개수: ${_allCampaigns.length}');
        } else {
          debugPrint('⚠️ 이미 존재하는 캠페인: ${event.campaign!.id}');
        }
      } else if (event.isUpdate && event.campaign != null) {
        // 캠페인 정보 업데이트
        debugPrint('📝 UPDATE 이벤트 처리');
        final index = _allCampaigns.indexWhere(
          (c) => c.id == event.campaign!.id,
        );
        if (index != -1) {
          final oldCampaign = _allCampaigns[index];
          final oldParticipants = oldCampaign.currentParticipants;
          final newParticipants = event.campaign!.currentParticipants;

          // 이전 상태 확인 (대기중인지)
          final now = DateTimeUtils.nowKST();
          final wasPending = oldCampaign.applyStartDate.isAfter(now);

          debugPrint(
            '✅ 캠페인 업데이트: ${event.campaign!.id} (참여자 수: $oldParticipants → $newParticipants)',
          );
          debugPrint('   이전 상태: ${wasPending ? "대기중" : "대기중 아님"}');

          _allCampaigns[index] = event.campaign!;
          _updateFilteredCampaigns();

          // 다음 상태 전환 시간 예약 업데이트
          _scheduleNextCampaignOpen();
        } else {
          debugPrint('⚠️ 캠페인을 찾을 수 없음: ${event.campaign!.id}');
          // 목록에 없으면 추가 (새로 생성된 캠페인일 수 있음)
          debugPrint('➕ 목록에 없으므로 추가 시도');
          _allCampaigns.insert(0, event.campaign!);
          _updateFilteredCampaigns();
          _scheduleNextCampaignOpen();
        }
      } else if (event.isDelete && event.oldRecord != null) {
        // 캠페인 삭제
        debugPrint('🗑️ DELETE 이벤트 처리');
        final campaignId = event.oldRecord!['id'] as String?;
        if (campaignId != null) {
          debugPrint('✅ 캠페인 삭제: $campaignId');
          _allCampaigns.removeWhere((c) => c.id == campaignId);
          _updateFilteredCampaigns();
          _scheduleNextCampaignOpen();
        }
      } else {
        debugPrint('⚠️ 처리되지 않은 이벤트');
        debugPrint('   event.isInsert: ${event.isInsert}');
        debugPrint('   event.isUpdate: ${event.isUpdate}');
        debugPrint('   event.isDelete: ${event.isDelete}');
        debugPrint('   event.campaign: ${event.campaign}');
        debugPrint('   event.oldRecord: ${event.oldRecord}');
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pendingEvent = null;
    // 화면이 dispose될 때는 일시정지만 (구독 정보는 유지)
    // 완전히 제거될 때만 force=true로 해제
    _realtimeManager.unsubscribe(_screenId, force: false);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 활성화될 때 (pop 후 복원될 때) 구독 재개 및 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true && mounted) {
        // 일시정지된 구독이 있으면 재개
        _realtimeManager.resumeSubscription(_screenId);

        if (_shouldRefreshOnRestore) {
          _shouldRefreshOnRestore = false;
          debugPrint('🔄 화면 복원 감지 - 캠페인 목록 새로고침');
          // DB에 캠페인이 반영될 시간을 주기 위해 약간의 지연 후 새로고침
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _loadCampaigns();
            }
          });
        }
      }
    });
  }

  /// 캠페인 생성 화면으로 이동 (push().then() 패턴)
  /// pushNamed 대신 push를 사용하여 반환값 전달 안정성 향상
  void _navigateToCreateCampaign() {
    // 캠페인 생성 화면으로 이동할 때 플래그 설정
    _shouldRefreshOnRestore = true;
    // pushNamed 대신 push 사용 (다른 화면에서 검증된 패턴)
    context
        .push('/mypage/advertiser/my-campaigns/create')
        .then((result) {
          debugPrint(
            '📥 캠페인 생성 화면에서 반환된 결과: $result (타입: ${result.runtimeType})',
          );

          if (result != null && result is Campaign) {
            // 생성된 Campaign 객체를 직접 목록에 추가 (즉시 반영)
            debugPrint('✅ Campaign 객체를 받았습니다. 목록에 직접 추가합니다.');
            _shouldRefreshOnRestore = false; // 성공적으로 처리되었으므로 플래그 해제
            _addCampaignDirectly(result);
            // DB에서 최신 데이터를 다시 조회하여 확실하게 반영
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                debugPrint('🔄 DB에서 최신 캠페인 목록 다시 조회');
                _loadCampaigns();
              }
            });
          } else if (result == true) {
            // 일반 새로고침
            debugPrint('🔄 일반 새로고침 실행 (result == true)');
            _shouldRefreshOnRestore = false; // 새로고침 실행했으므로 플래그 해제
            _loadCampaigns();
          } else {
            // result가 null이거나 예상치 못한 값인 경우
            // didChangeDependencies에서 새로고침하도록 플래그 유지
            debugPrint(
              '⚠️ 예상치 못한 반환값: $result - didChangeDependencies에서 새로고침 예정',
            );
          }
        })
        .catchError((error) {
          debugPrint('❌ 캠페인 생성 화면에서 에러 발생: $error');
          // 에러 발생 시에도 didChangeDependencies에서 새로고침하도록 플래그 유지
        });
  }

  /// 생성된 Campaign 객체를 직접 목록에 추가 (1단계: 주 방법)
  void _addCampaignDirectly(Campaign campaign) {
    if (!mounted) return;

    debugPrint('➕ 생성된 캠페인을 목록에 직접 추가 - ${campaign.title}');

    // 중복 체크
    if (!_allCampaigns.any((c) => c.id == campaign.id)) {
      if (mounted) {
        setState(() {
          _allCampaigns.insert(0, campaign);
          _updateFilteredCampaigns();
          _isLoading = false;
        });
        debugPrint('✅ UI 업데이트 완료 - 총 캠페인 수: ${_allCampaigns.length}');
      }
    } else {
      debugPrint('ℹ️ 캠페인이 이미 목록에 있습니다: ${campaign.id}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 생성된 캠페인을 폴링 방식으로 조회 (2단계: fallback)
  // TODO: 향후 폴링 기능 구현 시 사용 예정
  // ignore: unused_element
  /*
  Future<void> _addCampaignByIdWithPolling(String campaignId) async {
    if (!mounted) return;

    debugPrint('🔍 생성된 캠페인 폴링 조회 시작 - campaignId: $campaignId');

    const maxAttempts = 5;
    const initialDelay = Duration(milliseconds: 300);
    const maxDelay = Duration(milliseconds: 2000);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 지수 백오프 (exponential backoff)
      final delay = Duration(
        milliseconds: (initialDelay.inMilliseconds * (1 << attempt)).clamp(
          initialDelay.inMilliseconds,
          maxDelay.inMilliseconds,
        ),
      );

      await Future.delayed(delay);

      if (!mounted) return;

      try {
        final result = await _campaignService.getCampaignById(campaignId);

        if (result.success && result.data != null) {
          final campaign = result.data!;

          // 중복 체크
          if (!_allCampaigns.any((c) => c.id == campaignId)) {
            if (mounted) {
              setState(() {
                _allCampaigns.insert(0, campaign);
                _updateFilteredCampaigns();
                _isLoading = false;
              });
              debugPrint('✅ 캠페인 조회 성공 (시도 ${attempt + 1}/$maxAttempts)');
              return; // 성공 시 종료
            }
          } else {
            debugPrint('ℹ️ 캠페인이 이미 목록에 있습니다');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('⚠️ 캠페인 조회 실패 (시도 ${attempt + 1}/$maxAttempts): $e');
      }
    }

    // 모든 시도 실패 시 일반 새로고침
    debugPrint('❌ 폴링 실패 - 일반 새로고침 실행');
    if (mounted) {
      _loadCampaigns();
    }
  }
  */

  // ============================================
  // 폴링 관련 메서드 (더 이상 사용하지 않음, 참고용으로 유지)
  // push().then() 패턴으로 변경하여 같은 세션에서 조회하므로 폴링 불필요
  // ============================================

  /// 새로고침 처리 (폴링 및 직접 조회) - 사용하지 않음
  // ignore: unused_element
  @Deprecated('push().then() 패턴으로 변경하여 더 이상 사용하지 않음')
  /*
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
  */
  Future<void> _loadCampaigns({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('캠페인을 불러오는데 실패했습니다: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      _allCampaigns = loadedCampaigns;

      // 상태별 필터링
      _updateFilteredCampaigns();

      // 다음 캠페인 오픈 시간 예약
      _scheduleNextCampaignOpen();

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
          '   - ${campaign.title}: status=$status, applyStartDate=${campaign.applyStartDate}, applyEndDate=${campaign.applyEndDate}',
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 로딩이 끝나면 큐에 쌓인 Realtime 이벤트 처리
        if (_pendingRealtimeEvents.isNotEmpty) {
          for (final event in _pendingRealtimeEvents) {
            _processRealtimeEvent(event);
          }
          _pendingRealtimeEvents.clear();
        }
      }
    } catch (e) {
      debugPrint('❌ 캠페인 로드 실패: $e');
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
  // ignore: unused_element
  @Deprecated('push().then() 패턴으로 변경하여 더 이상 사용하지 않음')
  /*
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
  */
  /// 다음 상태 전환 시간에 맞춰 정확한 타이밍에 필터링 실행
  void _scheduleNextCampaignOpen() {
    _preciseTimer?.cancel(); // 기존 예약 취소 (타이머 누적 방지)

    if (_allCampaigns.isEmpty) return;

    final now = DateTimeUtils.nowKST();
    DateTime? nearestTransitionTime;

    // 모든 캠페인의 상태 전환 시간 중 가장 가까운 시간 찾기
    for (final campaign in _allCampaigns) {
      if (campaign.status != CampaignStatus.active) continue;

      // 1. 대기중 → 모집중: applyStartDate
      if (campaign.applyStartDate.isAfter(now)) {
        if (nearestTransitionTime == null ||
            campaign.applyStartDate.isBefore(nearestTransitionTime)) {
          nearestTransitionTime = campaign.applyStartDate;
        }
      }

      // 2. 모집중 → 선정완료: applyEndDate (참여자 수에 따라)
      if (campaign.applyEndDate.isAfter(now)) {
        if (nearestTransitionTime == null ||
            campaign.applyEndDate.isBefore(nearestTransitionTime)) {
          nearestTransitionTime = campaign.applyEndDate;
        }
      }

      // 3. 선정완료 → 등록기간: reviewStartDate
      if (campaign.reviewStartDate.isAfter(now)) {
        if (nearestTransitionTime == null ||
            campaign.reviewStartDate.isBefore(nearestTransitionTime)) {
          nearestTransitionTime = campaign.reviewStartDate;
        }
      }

      // 4. 등록기간 → 종료: reviewEndDate
      if (campaign.reviewEndDate.isAfter(now)) {
        if (nearestTransitionTime == null ||
            campaign.reviewEndDate.isBefore(nearestTransitionTime)) {
          nearestTransitionTime = campaign.reviewEndDate;
        }
      }
    }

    // 예약 걸기
    if (nearestTransitionTime != null) {
      // ⚠️ 중요: 타임존 동기화 확인
      // nearestTransitionTime과 now 모두 KST이므로 타임존 일치
      final difference = nearestTransitionTime.difference(now);

      // 정확한 타이밍을 위해 +500ms 정도 여유를 둠 (시스템 딜레이 고려)
      // ⚠️ 참고: 네트워크 딜레이(0.5~1초)는 별도로 고려됨
      final duration = difference + const Duration(milliseconds: 500);

      if (!duration.isNegative) {
        debugPrint(
          '💰 [나의 캠페인] 다음 상태 전환 예약: ${duration.inSeconds}초 후 ($nearestTransitionTime)',
        );
        _preciseTimer = Timer(duration, () {
          if (mounted) {
            debugPrint('⏰ [나의 캠페인] 상태 전환 시간 도달! 리스트 갱신');
            setState(() {
              _updateFilteredCampaigns(); // 리스트 새로고침
            });
            _scheduleNextCampaignOpen(); // 그 다음 전환 시간 예약
          }
        });
      }
    }
  }

  /// 상태별 필터링 업데이트
  ///
  /// 제안된 필터 기준:
  /// 1. 대기중: 캠페인 신청기간 이전
  /// 2. 모집중: 캠페인 신청기간 - 캠페인 종료기간 (and 신청자 다 안참)
  /// 3. 선정완료: 캠페인 신청기간 - 캠페인 종료기간 (and 신청자 다 참) OR 캠페인 종료기간 - 리뷰신청기간
  /// 4. 등록기간: 리뷰신청기간 - 리뷰종료기간
  /// 5. 종료: 리뷰종료기간 이후 또는 status가 inactive
  void _updateFilteredCampaigns() {
    final now = DateTimeUtils.nowKST(); // 한국 시간 사용

    // 모든 리스트 초기화
    _pendingCampaigns = [];
    _recruitingCampaigns = [];
    _selectedCampaigns = [];
    _registeredCampaigns = [];
    _completedCampaigns = [];

    for (final campaign in _allCampaigns) {
      // 1. 종료: inactive 상태 또는 리뷰 종료일 이후
      if (campaign.status == CampaignStatus.inactive ||
          campaign.reviewEndDate.isBefore(now)) {
        _completedCampaigns.add(campaign);
        continue;
      }

      // active 상태만 계속 처리
      if (campaign.status != CampaignStatus.active) continue;

      // 2. 등록기간: 리뷰 시작일 ~ 리뷰 종료일 사이
      if (!campaign.reviewStartDate.isAfter(now) &&
          !campaign.reviewEndDate.isBefore(now)) {
        _registeredCampaigns.add(campaign);
        continue;
      }

      // 3. 선정완료:
      //    - 신청기간 ~ 종료기간 사이 AND 신청자 다 참
      //    - OR 종료기간 ~ 리뷰시작기간 사이
      final isInApplyPeriod =
          !campaign.applyStartDate.isAfter(now) &&
          !campaign.applyEndDate.isBefore(now);
      final isBetweenApplyEndAndReviewStart =
          campaign.applyEndDate.isBefore(now) &&
          campaign.reviewStartDate.isAfter(now);
      final isFull = campaign.currentParticipants == campaign.maxParticipants!;

      if ((isInApplyPeriod && isFull) || isBetweenApplyEndAndReviewStart) {
        _selectedCampaigns.add(campaign);
        continue;
      }

      // 4. 모집중: 신청기간 ~ 종료기간 사이 AND 신청자 다 안참
      if (isInApplyPeriod &&
          campaign.currentParticipants < campaign.maxParticipants!) {
        _recruitingCampaigns.add(campaign);
        continue;
      }

      // 5. 대기중: 신청기간 이전
      if (campaign.applyStartDate.isAfter(now)) {
        _pendingCampaigns.add(campaign);
        continue;
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
    final now = DateTimeUtils.nowKST(); // 한국 시간 사용

    // Status와 날짜를 기반으로 상태 결정
    if (campaign.status == CampaignStatus.inactive) {
      statusText = '종료';
      statusColor = Colors.grey;
    } else if (campaign.applyStartDate.isAfter(now)) {
      // 신청 시작 전
      statusText = '모집';
      statusColor = Colors.orange;
    } else if (campaign.applyStartDate.isBefore(now) ||
        campaign.applyStartDate.isAtSameMomentAs(now)) {
      // 신청 기간 중
      if (campaign.applyEndDate.isAfter(now) ||
          campaign.applyEndDate.isAtSameMomentAs(now)) {
        // 신청 기간 내
        if (campaign.maxParticipants != null &&
            campaign.currentParticipants >= campaign.maxParticipants!) {
          statusText = '선정완료';
          statusColor = Colors.purple;
        } else {
          statusText = '모집중';
          statusColor = Colors.green;
        }
      } else {
        // 신청 기간 종료 후
        if (campaign.reviewStartDate.isBefore(now) ||
            campaign.reviewStartDate.isAtSameMomentAs(now)) {
          // 리뷰 기간 중
          if (campaign.reviewEndDate.isAfter(now) ||
              campaign.reviewEndDate.isAtSameMomentAs(now)) {
            statusText = '등록기간';
            statusColor = Colors.blue;
          } else {
            // 리뷰 기간 종료
            statusText = '종료';
            statusColor = Colors.grey;
          }
        } else {
          // 리뷰 시작 전 (신청 종료 후 ~ 리뷰 시작 전)
          statusText = '종료';
          statusColor = Colors.grey;
        }
      }
    } else {
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
        onTap: () => context
            .pushNamed(
              'advertiser-campaign-detail',
              pathParameters: {'id': campaign.id},
            )
            .then((result) {
              // 디테일 화면에서 상태 변경이 있었으면 새로고침
              if (result == true) {
                _loadCampaigns();
              }
            }),
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
                      child: CachedNetworkImage(
                        imageUrl: campaign.productImageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) {
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
                    '${campaign.campaignReward} P',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
              ...[
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
                      '${_formatDateTime(campaign.applyStartDate)} ~ ${_formatDateTime(campaign.applyEndDate)}',
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

  /// 날짜와 시간을 시, 분까지 표시하는 포맷 함수
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
