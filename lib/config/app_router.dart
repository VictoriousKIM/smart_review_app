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
import '../screens/mypage/common/profile_screen.dart';
import '../screens/mypage/reviewer/sns_connection_screen.dart';
import '../screens/mypage/advertiser/advertiser_my_campaigns_screen.dart';
import '../screens/common/notices_screen.dart';
import '../screens/common/events_screen.dart';
import '../screens/common/inquiry_screen.dart';
import '../screens/common/advertisement_inquiry_screen.dart';
import '../screens/mypage/advertiser/advertiser_analytics_screen.dart';
import '../screens/mypage/advertiser/advertiser_participants_screen.dart';
import '../screens/mypage/advertiser/advertiser_company_screen.dart';
import '../screens/mypage/advertiser/advertiser_penalties_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/account_deletion_screen.dart';
import '../widgets/loading_screen.dart';

// GoRouter Refresh Notifier
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
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
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) async {
      debugPrint(
        '🔍 Redirect called: ${state.matchedLocation} (uri: ${state.uri})',
      );

      // 현재 인증 상태를 직접 확인 (authProvider를 watch하지 않음)
      final user = await authService.currentUser;
      final isLoggedIn = user != null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRoot = state.matchedLocation == '/';
      final isLoading = state.matchedLocation == '/loading';

      // 로딩 페이지는 항상 허용
      if (isLoading) {
        return null;
      }

      // 루트 경로 접근 시 인증 상태에 따라 적절한 페이지로 리다이렉트
      if (isRoot) {
        return isLoggedIn ? '/home' : '/login';
      }

      // 로그인되지 않은 상태에서 보호된 경로 접근 시 로그인 페이지로 리다이렉트
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 로그인된 상태에서 로그인 페이지 접근 시 홈으로 리다이렉트
      if (isLoggedIn && isLoggingIn) {
        return '/home';
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
              // 현재 사용자 정보 가져오기
              final authService = ref.read(authServiceProvider);
              final user = await authService.currentUser;

              if (user == null) {
                return '/login';
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
              return AdvertiserMyCampaignsScreen(initialTab: initialTab);
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
