import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../widgets/main_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/guide/guide_screen.dart';
import '../screens/mypage/reviewer/reviewer_mypage_screen.dart';
import '../screens/mypage/advertiser/advertiser_mypage_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';
import '../screens/campaign/campaigns_screen.dart';
import '../screens/campaign/campaign_creation_screen.dart';
import '../screens/mypage/reviewer/reviewer_reviews_screen.dart';
import '../screens/mypage/reviewer/my_campaigns_screen.dart';
import '../screens/mypage/common/points_screen.dart';
import '../screens/mypage/common/point_charge_screen.dart';
import '../screens/mypage/common/point_refund_screen.dart';
import '../screens/mypage/common/point_transaction_detail_screen.dart';
import '../screens/mypage/common/profile_screen.dart';
import '../screens/mypage/reviewer/sns_connection_screen.dart';
import '../screens/mypage/advertiser/advertiser_my_campaigns_screen.dart';
import '../screens/common/notices_screen.dart';
import '../screens/common/events_screen.dart';
import '../screens/common/inquiry_screen.dart';
import '../screens/common/advertisement_inquiry_screen.dart';
import '../screens/mypage/advertiser/advertiser_analytics_screen.dart';
import '../screens/mypage/advertiser/advertiser_participants_screen.dart';
import '../screens/mypage/advertiser/advertiser_manager_screen.dart';
import '../screens/mypage/advertiser/advertiser_company_screen.dart';
import '../screens/mypage/advertiser/advertiser_penalties_screen.dart';
import '../screens/mypage/admin/admin_dashboard_screen.dart';
import '../screens/mypage/admin/admin_users_screen.dart';
import '../screens/mypage/admin/admin_companies_screen.dart';
import '../screens/mypage/admin/admin_campaigns_screen.dart';
import '../screens/mypage/admin/admin_reviews_screen.dart';
import '../screens/mypage/admin/admin_points_screen.dart';
import '../screens/mypage/admin/admin_statistics_screen.dart';
import '../screens/mypage/admin/admin_settings_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/account_deletion_screen.dart';
import '../widgets/loading_screen.dart';
import '../models/user.dart' as app_user;

// GoRouter Refresh Notifier
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    // 초기 notifyListeners() 호출 제거 - 첫 리다이렉트에서만 처리
    // 디바운싱을 통해 너무 빈번한 리프레시 방지
    _subscription = stream.asBroadcastStream().listen((_) {
      // 디바운싱: 200ms 내에 여러 번 호출되면 마지막 것만 실행
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
  // AuthService를 사용하여 실시간 인증 상태 변화 감지
  final authService = ref.watch(authServiceProvider);

  // GoRouter가 재생성되지 않도록 keepAlive 사용
  ref.keepAlive();

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/loading', // 초기 로딩 화면 표시
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) async {
      final isLoggingIn = state.matchedLocation == '/login';
      final isRoot = state.matchedLocation == '/';
      final isLoading = state.matchedLocation == '/loading';

      // 로딩 페이지는 항상 허용 (로딩 화면에서 직접 인증 상태 확인 및 리다이렉트 처리)
      if (isLoading) {
        return null;
      }

      // 초기화 완료 후 정상적인 리다이렉트 로직
      try {
        final user = await authService.currentUser;
        final isLoggedIn = user != null;

        // 루트 경로 접근 시 인증 상태에 따라 적절한 페이지로 리다이렉트
        if (isRoot) {
          return isLoggedIn ? '/home' : '/login';
        }

        // 로그인되지 않은 상태에서 보호된 경로 접근 시 로그인 페이지로 리다이렉트
        // 단, 로딩 화면이나 로그인 화면이 아닐 때만
        if (!isLoggedIn && !isLoggingIn && !isLoading) {
          return '/login';
        }

        // 로그인된 상태에서 로그인 페이지 접근 시 홈으로 리다이렉트
        if (isLoggedIn && isLoggingIn) {
          return '/home';
        }
      } catch (e) {
        // 인증 상태 확인 실패 시, 로그인 페이지가 아닌 경우에만 로그인으로 리다이렉트
        if (!isLoggingIn && !isLoading && !isRoot) {
          return '/login';
        }
        // 에러 발생 시에도 루트나 로그인 페이지는 그대로 유지
        if (isRoot) {
          return '/login';
        }
      }

      return null; // 리다이렉트 없음
    },
    routes: [
      // 루트 경로 - builder 없이 redirect만 처리 (전역 redirect에서 처리)
      GoRoute(
        path: '/',
        name: 'root',
        builder: (context, state) {
          // 이 빌더는 실행되지 않지만 GoRoute 구조 유지를 위해 필요
          // 실제 리다이렉트는 전역 redirect 함수에서 처리됨
          return const SizedBox.shrink();
        },
      ),

      // 인증 관련 라우트
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/loading',
        name: 'loading',
        builder: (context, state) => const LoadingScreen(),
      ),

      // 메인 앱 라우트 (ShellRoute로 감싸기)
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
          GoRoute(
            path: '/mypage',
            name: 'mypage',
            redirect: (context, state) async {
              // 정확히 /mypage 경로일 때만 리다이렉트 (하위 경로는 유지)
              final matchedLocation = state.matchedLocation;
              if (matchedLocation != '/mypage') {
                return null; // 하위 경로는 리다이렉트하지 않음
              }

              // 현재 사용자 정보 가져오기
              final authService = ref.read(authServiceProvider);
              final user = await authService.currentUser;

              if (user == null) {
                return '/login';
              }

              // 관리자인 경우 어드민 대시보드로 리다이렉트
              if (user.userType == app_user.UserType.admin) {
                return '/mypage/admin';
              }

              // 광고주 인증 여부에 따라 적절한 페이지로 리다이렉트
              if (user.companyId != null) {
                return '/mypage/advertiser';
              } else {
                return '/mypage/reviewer';
              }
            },
          ),
          GoRoute(
            path: '/mypage/reviewer',
            name: 'mypage-reviewer',
            builder: (context, state) => const ReviewerMyPageScreen(),
          ),
          GoRoute(
            path: '/mypage/advertiser',
            name: 'mypage-advertiser',
            builder: (context, state) => const AdvertiserMyPageScreen(),
          ),

          // 리뷰어 관련 라우트
          GoRoute(
            path: '/mypage/reviewer/my-campaigns',
            name: 'reviewer-my-campaigns',
            builder: (context, state) {
              final initialTab = state.uri.queryParameters['tab'];
              return MyCampaignsScreen(initialTab: initialTab);
            },
          ),
          GoRoute(
            path: '/mypage/reviewer/reviews',
            name: 'reviewer-reviews',
            builder: (context, state) => const ReviewerReviewsScreen(),
          ),
          GoRoute(
            path: '/mypage/reviewer/points',
            name: 'reviewer-points',
            builder: (context, state) =>
                const PointsScreen(userType: 'reviewer'),
            routes: [
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
                  final transactionData = state.extra as Map<String, dynamic>?;
                  return PointTransactionDetailScreen(
                    transactionId: transactionId,
                    transactionData: transactionData,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/mypage/reviewer/sns',
            name: 'reviewer-sns',
            builder: (context, state) => const SNSConnectionScreen(),
          ),

          // 광고주 관련 라우트
          GoRoute(
            path: '/mypage/advertiser/my-campaigns',
            name: 'advertiser-my-campaigns',
            builder: (context, state) {
              final initialTab = state.uri.queryParameters['tab'];
              // pushNamed().then() 패턴으로 변경하여 refresh, campaignId 파라미터는 더 이상 사용하지 않음
              return AdvertiserMyCampaignsScreen(
                initialTab: initialTab,
              );
            },
            routes: [
              GoRoute(
                path: 'create',
                name: 'advertiser-my-campaigns-create',
                builder: (context, state) => const CampaignCreationScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/mypage/advertiser/analytics',
            name: 'advertiser-analytics',
            builder: (context, state) => const AdvertiserAnalyticsScreen(),
          ),
          GoRoute(
            path: '/mypage/advertiser/participants',
            name: 'advertiser-participants',
            builder: (context, state) => const AdvertiserParticipantsScreen(),
          ),
          GoRoute(
            path: '/mypage/advertiser/managers',
            name: 'advertiser-managers',
            builder: (context, state) => const AdvertiserManagerScreen(),
          ),
          GoRoute(
            path: '/mypage/advertiser/company',
            name: 'advertiser-company',
            builder: (context, state) => const AdvertiserCompanyScreen(),
          ),
          GoRoute(
            path: '/mypage/advertiser/penalties',
            name: 'advertiser-penalties',
            builder: (context, state) => const AdvertiserPenaltiesScreen(),
          ),
          GoRoute(
            path: '/mypage/advertiser/points',
            name: 'advertiser-points',
            builder: (context, state) =>
                const PointsScreen(userType: 'advertiser'),
            routes: [
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
                  final transactionData = state.extra as Map<String, dynamic>?;
                  return PointTransactionDetailScreen(
                    transactionId: transactionId,
                    transactionData: transactionData,
                  );
                },
              ),
            ],
          ),

          // 어드민 관련 라우트
          GoRoute(
            path: '/mypage/admin',
            name: 'admin-dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/mypage/admin/users',
            name: 'admin-users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/mypage/admin/companies',
            name: 'admin-companies',
            builder: (context, state) => const AdminCompaniesScreen(),
          ),
          GoRoute(
            path: '/mypage/admin/campaigns',
            name: 'admin-campaigns',
            builder: (context, state) => const AdminCampaignsScreen(),
          ),
          GoRoute(
            path: '/mypage/admin/reviews',
            name: 'admin-reviews',
            builder: (context, state) => const AdminReviewsScreen(),
          ),
          GoRoute(
            path: '/mypage/admin/points',
            name: 'admin-points',
            builder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              return AdminPointsScreen(initialTab: tab);
            },
          ),
          GoRoute(
            path: '/mypage/admin/statistics',
            name: 'admin-statistics',
            builder: (context, state) => const AdminStatisticsScreen(),
          ),
          GoRoute(
            path: '/mypage/admin/settings',
            name: 'admin-settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),

          // 공통 라우트
          GoRoute(
            path: '/mypage/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/notices',
            name: 'notices',
            builder: (context, state) => const NoticesScreen(),
          ),
          GoRoute(
            path: '/events',
            name: 'events',
            builder: (context, state) => const EventsScreen(),
          ),
          GoRoute(
            path: '/inquiry',
            name: 'inquiry',
            builder: (context, state) => const InquiryScreen(),
          ),
          GoRoute(
            path: '/advertisement-inquiry',
            name: 'advertisement-inquiry',
            builder: (context, state) => const AdvertisementInquiryScreen(),
          ),
          GoRoute(
            path: '/settings/notifications',
            name: 'notification-settings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),

          // 계정 삭제 관련 라우트
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
