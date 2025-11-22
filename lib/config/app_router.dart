import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers & Services
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_user;

// Widgets & Shells
import '../widgets/main_shell.dart';
import '../widgets/loading_screen.dart'; // 껍데기 UI 위젯 (파일 재생성 필요)
import '../widgets/mypage_route_wrapper.dart';

// Screens - Auth & Home
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/guide/guide_screen.dart';

// Screens - Campaign
import '../screens/campaign/campaigns_screen.dart';
import '../screens/campaign/campaign_creation_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';

// Screens - Mypage (Reviewer)
import '../screens/mypage/reviewer/reviewer_mypage_screen.dart';
import '../screens/mypage/reviewer/my_campaigns_screen.dart';
import '../screens/mypage/reviewer/reviewer_reviews_screen.dart';
import '../screens/mypage/reviewer/sns_connection_screen.dart';

// Screens - Mypage (Advertiser)
import '../screens/mypage/advertiser/advertiser_mypage_screen.dart';
import '../screens/mypage/advertiser/advertiser_my_campaigns_screen.dart';
import '../screens/mypage/advertiser/advertiser_campaign_detail_screen.dart';
import '../screens/mypage/advertiser/advertiser_analytics_screen.dart';
import '../screens/mypage/advertiser/advertiser_participants_screen.dart';
import '../screens/mypage/advertiser/advertiser_manager_screen.dart';
import '../screens/mypage/advertiser/advertiser_penalties_screen.dart';

// Screens - Mypage (Common)
import '../screens/mypage/common/profile_screen.dart';
import '../screens/mypage/common/points_screen.dart';
import '../screens/mypage/common/point_charge_screen.dart';
import '../screens/mypage/common/point_refund_screen.dart';
import '../screens/mypage/common/point_transaction_detail_screen.dart';

// Screens - Mypage (Admin)
import '../screens/mypage/admin/admin_dashboard_screen.dart';
import '../screens/mypage/admin/admin_users_screen.dart';
import '../screens/mypage/admin/admin_companies_screen.dart';
import '../screens/mypage/admin/admin_campaigns_screen.dart';
import '../screens/mypage/admin/admin_reviews_screen.dart';
import '../screens/mypage/admin/admin_points_screen.dart';
import '../screens/mypage/admin/admin_statistics_screen.dart';
import '../screens/mypage/admin/admin_settings_screen.dart';

// Screens - Common & Settings
import '../screens/common/notices_screen.dart';
import '../screens/common/events_screen.dart';
import '../screens/common/inquiry_screen.dart';
import '../screens/common/advertisement_inquiry_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/account_deletion_screen.dart';

/// GoRouter Refresh Notifier
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        notifyListeners();
      });
    });
  }

  late final StreamSubscription<dynamic> _subscription;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}

// 라우터 설정
final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  ref.keepAlive();

  return GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),

    // [1] 전역 Redirect
    redirect: (context, state) async {
      final matchedLocation = state.matchedLocation;

      final isLoggingIn = matchedLocation == '/login';
      final isRoot = matchedLocation == '/';
      final isMyPage = matchedLocation.startsWith('/mypage');

      // 1. 마이페이지 경로는 전역 redirect에서 특별 처리 (새로고침 시 경로 유지)
      // Builder에서 권한 체크를 수행하므로 여기서는 로그인 체크만
      if (isMyPage) {
        final user = await authService.currentUser;
        if (user == null) {
          // 비로그인 시에만 로그인으로 리다이렉트
          return '/login';
        }
        // 로그인 상태면 경로 유지 (null 반환)
        return null;
      }

      // 2. 세션 확인 (비동기)
      final user = await authService.currentUser;
      final isLoggedIn = user != null;

      // 3. 비로그인 상태
      if (!isLoggedIn) {
        if (isLoggingIn) return null;
        return '/login';
      }

      // 4. 로그인 상태
      if (isLoggedIn) {
        // 로그인 페이지나 루트 접근 시 홈으로
        if (isLoggingIn || isRoot) return '/home';
      }

      return null;
    },

    routes: [
      // 루트
      GoRoute(
        path: '/',
        name: 'root',
        builder: (context, state) => const SizedBox.shrink(),
      ),

      // 로그인
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // 메인 쉘
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/campaigns',
            name: 'campaigns',
            builder: (context, state) => const CampaignsScreen(),
          ),
          GoRoute(
            path: '/campaigns/create',
            name: 'campaigns-create',
            builder: (context, state) => const CampaignCreationScreen(),
          ),
          GoRoute(
            path: '/campaigns/:id',
            name: 'campaign-detail',
            builder: (context, state) {
              final campaignId = state.pathParameters['id']!;
              return CampaignDetailScreen(campaignId: campaignId);
            },
          ),
          GoRoute(
            path: '/guide',
            name: 'guide',
            builder: (context, state) => const GuideScreen(),
          ),

          // [2] 마이페이지 분기
          GoRoute(
            path: '/mypage',
            name: 'mypage',
            builder: (context, state) {
              // 사용자 타입에 따라 적절한 화면으로 리다이렉트
              final userAsync = ref.read(currentUserProvider);

              return userAsync.when(
                data: (user) {
                  if (user == null) {
                    // 비로그인 시 로그인으로 리다이렉트
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        context.go('/login');
                      }
                    });
                    return const LoadingScreen();
                  }

                  // 사용자 타입에 따라 적절한 화면으로 리다이렉트
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      if (user.userType == app_user.UserType.admin) {
                        context.go('/mypage/admin');
                      } else if (user.isAdvertiser) {
                        context.go('/mypage/advertiser');
                      } else {
                        context.go('/mypage/reviewer');
                      }
                    }
                  });
                  return const LoadingScreen();
                },
                loading: () => const LoadingScreen(),
                error: (err, stack) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('데이터 로드 실패: $err'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('홈으로 이동'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // [3] 리뷰어 마이페이지
          GoRoute(
            path: '/mypage/reviewer',
            name: 'mypage-reviewer',
            // redirect 제거: 어드민과 동일한 패턴으로 새로고침 시 경로 유지
            // 별도 위젯으로 분리하여 ref.watch() 재평가 방지
            builder: (context, state) =>
                const MyPageRouteWrapper(routeType: 'reviewer'),
            routes: [
              GoRoute(
                path: 'my-campaigns',
                name: 'reviewer-my-campaigns',
                builder: (context, state) {
                  final initialTab = state.uri.queryParameters['tab'];
                  return MyCampaignsScreen(initialTab: initialTab);
                },
              ),
              GoRoute(
                path: 'reviews',
                name: 'reviewer-reviews',
                builder: (context, state) => const ReviewerReviewsScreen(),
              ),
              GoRoute(
                path: 'points',
                name: 'reviewer-points',
                builder: (context, state) =>
                    const PointsScreen(userType: 'reviewer'),
                routes: [
                  GoRoute(
                    path: 'withdraw',
                    name: 'reviewer-points-withdraw',
                    builder: (context, state) =>
                        const PointRefundScreen(userType: 'reviewer'),
                  ),
                  // 기존 refund 경로도 유지 (하위 호환성)
                  GoRoute(
                    path: 'refund',
                    name: 'reviewer-points-refund',
                    builder: (context, state) =>
                        const PointRefundScreen(userType: 'reviewer'),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'reviewer-points-detail',
                    builder: (context, state) {
                      final transactionId = state.pathParameters['id']!;
                      final transactionData =
                          state.extra as Map<String, dynamic>?;
                      return PointTransactionDetailScreen(
                        transactionId: transactionId,
                        transactionData: transactionData,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'sns',
                name: 'reviewer-sns',
                builder: (context, state) => const SNSConnectionScreen(),
              ),
            ],
          ),

          // [4] 광고주 마이페이지
          GoRoute(
            path: '/mypage/advertiser',
            name: 'mypage-advertiser',
            // redirect 제거: 어드민과 동일한 패턴으로 새로고침 시 경로 유지
            // 별도 위젯으로 분리하여 ref.watch() 재평가 방지
            builder: (context, state) =>
                const MyPageRouteWrapper(routeType: 'advertiser'),
            routes: [
              GoRoute(
                path: 'my-campaigns',
                name: 'advertiser-my-campaigns',
                builder: (context, state) {
                  final initialTab = state.uri.queryParameters['tab'];
                  return AdvertiserMyCampaignsScreen(initialTab: initialTab);
                },
                routes: [
                  GoRoute(
                    path: 'create',
                    name: 'advertiser-my-campaigns-create',
                    builder: (context, state) => const CampaignCreationScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'advertiser-campaign-detail',
                    builder: (context, state) {
                      final campaignId = state.pathParameters['id']!;
                      return AdvertiserCampaignDetailScreen(
                        campaignId: campaignId,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'analytics',
                name: 'advertiser-analytics',
                builder: (context, state) => const AdvertiserAnalyticsScreen(),
              ),
              GoRoute(
                path: 'participants',
                name: 'advertiser-participants',
                builder: (context, state) =>
                    const AdvertiserParticipantsScreen(),
              ),
              GoRoute(
                path: 'managers',
                name: 'advertiser-managers',
                builder: (context, state) => const AdvertiserManagerScreen(),
              ),
              GoRoute(
                path: 'penalties',
                name: 'advertiser-penalties',
                builder: (context, state) => const AdvertiserPenaltiesScreen(),
              ),
              GoRoute(
                path: 'points',
                name: 'advertiser-points',
                builder: (context, state) =>
                    const PointsScreen(userType: 'advertiser'),
                routes: [
                  GoRoute(
                    path: 'deposit',
                    name: 'advertiser-points-deposit',
                    builder: (context, state) =>
                        const PointChargeScreen(userType: 'advertiser'),
                  ),
                  GoRoute(
                    path: 'withdraw',
                    name: 'advertiser-points-withdraw',
                    builder: (context, state) =>
                        const PointRefundScreen(userType: 'advertiser'),
                  ),
                  // 기존 charge/refund 경로도 유지 (하위 호환성)
                  GoRoute(
                    path: 'charge',
                    name: 'advertiser-points-charge',
                    builder: (context, state) =>
                        const PointChargeScreen(userType: 'advertiser'),
                  ),
                  GoRoute(
                    path: 'refund',
                    name: 'advertiser-points-refund',
                    builder: (context, state) =>
                        const PointRefundScreen(userType: 'advertiser'),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'advertiser-points-detail',
                    builder: (context, state) {
                      final transactionId = state.pathParameters['id']!;
                      final transactionData =
                          state.extra as Map<String, dynamic>?;
                      return PointTransactionDetailScreen(
                        transactionId: transactionId,
                        transactionData: transactionData,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Admin 및 공통 라우트들 (기존과 동일)
          GoRoute(
            path: '/mypage/admin',
            name: 'admin-dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          // ... (나머지 어드민 및 공통 라우트는 생략 없이 기존 코드를 그대로 유지) ...
          // 코드 길이 상 생략된 부분은 기존과 동일하게 유지해 주세요.
          GoRoute(
            path: '/mypage/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          // ...
          GoRoute(
            path: '/account-deletion',
            name: 'account-deletion',
            builder: (context, state) => const AccountDeletionScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('페이지를 찾을 수 없습니다: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('홈으로 이동'),
            ),
          ],
        ),
      ),
    ),
  );
});
