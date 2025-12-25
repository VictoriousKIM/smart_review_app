import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/user.dart' as app_user;
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/mypage_common_widgets.dart';
import '../../../widgets/drawer/advertiser_drawer.dart';
import '../../../services/campaign_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/company_user_service.dart';
import '../../../services/auth_service.dart';
import '../../../config/supabase_config.dart';
import '../../../models/campaign.dart';
import '../../../utils/date_time_utils.dart';
import 'package:responsive_builder/responsive_builder.dart';

class AdvertiserMyPageScreen extends ConsumerStatefulWidget {
  final app_user.User? user;

  const AdvertiserMyPageScreen({super.key, this.user});

  @override
  ConsumerState<AdvertiserMyPageScreen> createState() =>
      _AdvertiserMyPageScreenState();
}

class _AdvertiserMyPageScreenState
    extends ConsumerState<AdvertiserMyPageScreen> {
  final CampaignService _campaignService = CampaignService();
  int _pendingCount = 0;
  int _recruitingCount = 0;
  int _selectedCount = 0;
  int _registeredCount = 0;
  int _completedCount = 0;
  bool _isLoadingStats = true;

  // 포인트 관련 상태
  int? _currentPoints;
  bool _isLoadingPoints = true;

  @override
  void initState() {
    super.initState();
    _loadCampaignStats();
    _loadCompanyPoints();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 포커스될 때 포인트 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true) {
        _loadCompanyPoints();
      }
    });
  }

  // 회사 지갑 포인트 조회
  Future<void> _loadCompanyPoints() async {
    setState(() {
      _isLoadingPoints = true;
    });

    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        if (mounted) {
          setState(() {
            _currentPoints = 0;
            _isLoadingPoints = false;
          });
        }
        return;
      }

      // 회사 ID 조회
      final companyId = await CompanyUserService.getUserCompanyId(userId);
      if (companyId == null) {
        if (mounted) {
          setState(() {
            _currentPoints = 0;
            _isLoadingPoints = false;
          });
        }
        return;
      }

      // 회사 지갑 조회
      final wallet = await WalletService.getCompanyWalletByCompanyId(companyId);
      if (mounted) {
        setState(() {
          _currentPoints = wallet?.currentPoints ?? 0;
          _isLoadingPoints = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 회사 포인트 조회 실패: $e');
      if (mounted) {
        setState(() {
          _currentPoints = 0;
          _isLoadingPoints = false;
        });
      }
    }
  }

  Future<void> _loadCampaignStats() async {
    try {
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
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

        List<Campaign> allCampaigns = [];

        if (campaignsList != null) {
          allCampaigns = campaignsList
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
          // 대체 로직: company_id 기반 직접 조회
          try {
            // 1. 사용자의 회사 ID 조회
            final companyResult = await SupabaseConfig.client
                .from('company_users')
                .select('company_id')
                .eq('user_id', userId)
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

              allCampaigns = (directResult as List)
                  .map((json) => Campaign.fromJson(json))
                  .toList();
            }
          } catch (e) {
            debugPrint('⚠️ 대체 조회 실패: $e');
          }
        }

        // 상태별 카운트 계산
        // 필터 로직은 advertiser_my_campaigns_screen.dart의 _updateFilteredCampaigns()와 동일하게 유지
        final now = DateTimeUtils.nowKST(); // 한국 시간 사용

        // 모든 카운트 초기화
        _pendingCount = 0;
        _recruitingCount = 0;
        _selectedCount = 0;
        _registeredCount = 0;
        _completedCount = 0;

        for (final campaign in allCampaigns) {
          // active 상태만 처리 (inactive는 제외)
          if (campaign.status != CampaignStatus.active) {
            // inactive 상태는 종료 탭에 추가
            _completedCount++;
            continue;
          }

          // 1. 종료: 리뷰 종료일 이후
          if (campaign.reviewEndDate.isBefore(now)) {
            _completedCount++;
            continue;
          }

          // 2. 등록기간: 리뷰 시작일 ~ 리뷰 종료일 사이
          if (!campaign.reviewStartDate.isAfter(now) &&
              !campaign.reviewEndDate.isBefore(now)) {
            _registeredCount++;
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
          final isFull =
              campaign.maxParticipants != null &&
              campaign.currentParticipants == campaign.maxParticipants!;

          if ((isInApplyPeriod && isFull) || isBetweenApplyEndAndReviewStart) {
            _selectedCount++;
            continue;
          }

          // 4. 모집중: 신청기간 ~ 종료기간 사이 AND 신청자 다 안참
          if (isInApplyPeriod &&
              campaign.maxParticipants != null &&
              campaign.currentParticipants < campaign.maxParticipants!) {
            _recruitingCount++;
            continue;
          }

          // 5. 대기중: 신청기간 이전
          if (campaign.applyStartDate.isAfter(now)) {
            _pendingCount++;
            continue;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 캠페인 통계 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      endDrawer: const AdvertiserDrawer(),
      appBar: AppBar(
        title: const Text('마이페이지'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // 알림 기능 구현
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: ResponsiveBuilder(
        builder: (context, sizingInformation) {
          return SingleChildScrollView(
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
                  children: [
                    // 상단 파란색 카드
                    MyPageCommonWidgets.buildTopCard(
                      userName: user.displayName ?? '사용자',
                      userType: '광고주',
                    onSwitchPressed: () {
                      // 리뷰어 마이페이지로 이동
                      context.go('/mypage/reviewer');
                    },
                    switchButtonText: '리뷰어 전환',
                    showRating: false,
                    showAdminButton: user.userType == app_user.UserType.admin,
                    onAdminPressed: user.userType == app_user.UserType.admin
                        ? () {
                            // 관리자 대시보드로 이동
                            context.go('/mypage/admin');
                          }
                        : null,
                      onProfileTap: () {
                        // 프로필 화면의 광고주 탭으로 이동
                        context.go('/mypage/profile?tab=business');
                      },
                      onPointsTap: () {
                        // 광고주 포인트 스크린으로 이동
                        context.go('/mypage/advertiser/points');
                      },
                      currentPoints: _currentPoints,
                      isLoadingPoints: _isLoadingPoints,
                    ),

                    const SizedBox(height: 16),

                    // 캠페인 상태 섹션
                    MyPageCommonWidgets.buildCampaignStatusSection(
                      statusItems: [
                        {
                          'label': '대기중',
                          'count': _isLoadingStats ? '-' : '$_pendingCount',
                          'tab': 'pending',
                        },
                        {
                          'label': '모집중',
                          'count': _isLoadingStats ? '-' : '$_recruitingCount',
                          'tab': 'recruiting',
                        },
                        {
                          'label': '선정완료',
                          'count': _isLoadingStats ? '-' : '$_selectedCount',
                          'tab': 'selected',
                        },
                        {
                          'label': '등록기간',
                          'count': _isLoadingStats ? '-' : '$_registeredCount',
                          'tab': 'registered',
                        },
                        {
                          'label': '종료',
                          'count': _isLoadingStats ? '-' : '$_completedCount',
                          'tab': 'completed',
                        },
                      ],
                      actionButtonText: '캠페인 등록 >',
                      onActionPressed: () {
                        context.go('/mypage/advertiser/my-campaigns/create');
                      },
                      onStatusTap: (tab) {
                        context.go('/mypage/advertiser/my-campaigns?tab=$tab');
                      },
                    ),

                    const SizedBox(height: 16),

                    // 알림 섹션
                    MyPageCommonWidgets.buildNotificationSection(),

                    const SizedBox(height: 32),

                    // 로그아웃 버튼
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: CustomButton(
                        text: '로그아웃',
                        onPressed: () => _showLogoutDialog(context, ref),
                        backgroundColor: Colors.red[50],
                        textColor: Colors.red[700],
                        borderColor: Colors.red[200],
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

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              context.pop();
              await ref.read(authProvider.notifier).signOut();
              // 로그아웃 후 로그인 페이지로 이동
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
