import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/user.dart' as app_user;
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/mypage_common_widgets.dart';
import '../../../widgets/drawer/reviewer_drawer.dart';
import '../../../services/company_user_service.dart';
import '../../../services/campaign_log_service.dart';
import '../../../config/supabase_config.dart';

class ReviewerMyPageScreen extends ConsumerStatefulWidget {
  final app_user.User? user;

  const ReviewerMyPageScreen({super.key, this.user});

  @override
  ConsumerState<ReviewerMyPageScreen> createState() =>
      _ReviewerMyPageScreenState();
}

class _ReviewerMyPageScreenState extends ConsumerState<ReviewerMyPageScreen> {
  final CampaignLogService _campaignLogService = CampaignLogService(
    SupabaseConfig.client,
  );
  int _appliedCount = 0;
  int _approvedCount = 0;
  int _registeredCount = 0;
  int _completedCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadCampaignStats();
  }

  Future<void> _loadCampaignStats() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
          });
        }
        return;
      }

      // 모든 로그 가져오기
      final result = await _campaignLogService.getUserCampaignLogs(
        userId: user.id,
      );

      if (!mounted) return;

      if (result.success && result.data != null) {
        final logs = result.data!;

        // 신청: status = 'applied'
        _appliedCount = logs.where((log) => log.status == 'applied').length;

        // 선정: status = 'approved'
        _approvedCount = logs.where((log) => log.status == 'approved').length;

        // 등록: 진행 중 상태들
        _registeredCount = logs
            .where(
              (log) => [
                'purchased',
                'review_submitted',
                'visit_completed',
                'article_submitted',
                'review_approved',
                'visit_verified',
                'article_approved',
              ].contains(log.status),
            )
            .length;

        // 완료: status = 'payment_completed'
        _completedCount = logs
            .where((log) => log.status == 'payment_completed')
            .length;
      }

      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ 캠페인 통계 로드 실패: $e');
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
      endDrawer: const ReviewerDrawer(),
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
      body: FutureBuilder<bool>(
        future: CompanyUserService.canConvertToAdvertiser(user.uid),
        builder: (context, snapshot) {
          final canConvert = snapshot.data ?? false;

          return SingleChildScrollView(
            child: Column(
              children: [
                // 상단 파란색 카드
                MyPageCommonWidgets.buildTopCard(
                  userName: user.displayName ?? '사용자',
                  userType: '리뷰어',
                  onSwitchPressed: canConvert
                      ? () {
                          // 사업자 모드로 이동
                          context.pushReplacement('/mypage/advertiser');
                        }
                      : () {
                          // 사업자 인증 필요 알림창 표시
                          _showAdvertiserConversionDialog(context);
                        },
                  switchButtonText: '사업자 전환',
                  showRating: true,
                ),

                const SizedBox(height: 16),

                // 캠페인 상태 섹션
                MyPageCommonWidgets.buildCampaignStatusSection(
                  statusItems: [
                    {
                      'label': '신청',
                      'count': _isLoadingStats ? '-' : '$_appliedCount',
                      'tab': 'applied',
                    },
                    {
                      'label': '선정',
                      'count': _isLoadingStats ? '-' : '$_approvedCount',
                      'tab': 'approved',
                    },
                    {
                      'label': '등록',
                      'count': _isLoadingStats ? '-' : '$_registeredCount',
                      'tab': 'registered',
                    },
                    {
                      'label': '완료',
                      'count': _isLoadingStats ? '-' : '$_completedCount',
                      'tab': 'completed',
                    },
                  ],
                  onStatusTap: (tab) {
                    context.go('/mypage/reviewer/my-campaigns?tab=$tab');
                  },
                ),

                const SizedBox(height: 16),

                // 알림 섹션
                MyPageCommonWidgets.buildNotificationSection(),

                const SizedBox(height: 16),

                // SNS 연결 섹션 (리뷰어만)
                MyPageCommonWidgets.buildSNSConnectionSection(context),

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
          );
        },
      ),
    );
  }

  void _showAdvertiserConversionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.business_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('사업자 전환'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '광고주로 전환하려면 사업자 인증이 필요합니다.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '필요한 서류',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 사업자등록증\n• 사업자 정보 (상호명, 대표자명, 사업자등록번호 등)',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('사업자 인증을 진행하시겠습니까?', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 프로필 화면의 사업자 탭으로 이동
              context.go('/mypage/profile?tab=business');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('인증 진행'),
          ),
        ],
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
