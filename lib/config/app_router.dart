import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Providers & Services
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_user;
import '../config/supabase_config.dart';
import '../services/auth_service.dart';

// Widgets & Shells
import '../widgets/main_shell.dart';
import '../widgets/loading_screen.dart'; // 껍데기 UI 위젯 (파일 재생성 필요)
import '../widgets/mypage_route_wrapper.dart';

// Screens - Auth & Home
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/reviewer_signup_screen.dart';
import '../screens/auth/advertiser_signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/guide/guide_screen.dart';

// Screens - Campaign
import '../screens/campaign/campaigns_screen.dart';
import '../screens/campaign/campaign_creation_screen.dart';
import '../screens/campaign/campaign_edit_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';

// Screens - Mypage (Reviewer)
import '../screens/mypage/reviewer/my_campaigns_screen.dart';
import '../screens/mypage/reviewer/reviewer_reviews_screen.dart';
import '../screens/mypage/reviewer/sns_connection_screen.dart';
import '../screens/mypage/reviewer/reviewer_company_request_screen.dart';

// Screens - Mypage (Advertiser)
import '../screens/mypage/advertiser/advertiser_my_campaigns_screen.dart';
import '../screens/mypage/advertiser/advertiser_campaign_detail_screen.dart';
import '../screens/mypage/advertiser/advertiser_analytics_screen.dart';
import '../screens/mypage/advertiser/advertiser_participants_screen.dart';
import '../screens/mypage/advertiser/advertiser_manager_screen.dart';
import '../screens/mypage/advertiser/advertiser_penalties_screen.dart';
import '../screens/mypage/advertiser/advertiser_reviewer_screen.dart';

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
      final fullPath = state.uri.path;
      final uriString = state.uri.toString();

      debugPrint('Redirect: 실행됨 - matchedLocation=$matchedLocation, fullPath=$fullPath, uri=$uriString');

      final isLoggingIn = matchedLocation == '/login';
      final isRoot = matchedLocation == '/';
      final isMyPage = matchedLocation.startsWith('/mypage');

      // Signup 관련 경로는 redirect 제외 (무한 루프 방지)
      // matchedLocation과 fullPath 모두 확인하여 이중 방어
      if (matchedLocation.startsWith('/signup') || fullPath.startsWith('/signup')) {
        debugPrint('Redirect: Signup 경로는 redirect 제외: matchedLocation=$matchedLocation, fullPath=$fullPath');
        return null;
      }

      // 1. 마이페이지 경로는 전역 redirect에서 특별 처리 (새로고침 시 경로 유지)
      if (isMyPage) {
        final userState = await authService.getUserState();
        if (userState == UserState.notLoggedIn || userState == UserState.tempSession) {
          return '/login';
        }
        return null;
      }

      // 2. 사용자 상태 확인 (중복 프로필 체크 제거)
      final userState = await authService.getUserState();

      // 3. 임시 세션 (프로필 없음) → signup으로 리다이렉트
      if (userState == UserState.tempSession) {
        final session = SupabaseConfig.client.auth.currentSession;
        if (session != null) {
          final provider = _extractProvider(session.user);
          return '/signup?type=oauth&provider=$provider';
        }
      }

      // 4. 비로그인 상태
      if (userState == UserState.notLoggedIn) {
        if (isLoggingIn) return null;
        return '/login';
      }

      // 5. 로그인 상태
      if (userState == UserState.loggedIn) {
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

      // 회원가입 (OAuth 로그인 후 프로필 없을 때)
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) {
          final type = state.uri.queryParameters['type']; // 'oauth'
          final provider =
              state.uri.queryParameters['provider']; // 'google', 'kakao'
          final companyId = state.uri.queryParameters['companyid'];
          return SignupScreen(
            type: type,
            provider: provider,
            companyId: companyId,
          );
        },
        routes: [
          // 리뷰어 회원가입
          GoRoute(
            path: 'reviewer',
            name: 'reviewer-signup',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ReviewerSignupScreen(
                companyId: extra?['companyId'] as String?,
                provider: extra?['provider'] as String?,
              );
            },
          ),
          // 광고주 회원가입
          GoRoute(
            path: 'advertiser',
            name: 'advertiser-signup',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AdvertiserSignupScreen(
                provider: extra?['provider'] as String?,
              );
            },
          ),
        ],
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
              // ✅ ref.watch()를 사용하여 상태 변경 감지 (ref.read() 대신)
              // ref.read()는 한 번만 읽고 재빌드되지 않아 로딩 상태가 계속 유지되는 문제 해결
              return _MyPageRedirectWidget();
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
              GoRoute(
                path: 'company-request',
                name: 'reviewer-company-request',
                builder: (context, state) =>
                    const ReviewerCompanyRequestScreen(),
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
                    path: 'edit/:id',
                    name: 'advertiser-campaign-edit',
                    builder: (context, state) {
                      final campaignId = state.pathParameters['id']!;
                      return CampaignEditScreen(campaignId: campaignId);
                    },
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
                path: 'reviewers',
                name: 'advertiser-reviewers',
                builder: (context, state) => const AdvertiserReviewerScreen(),
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

          // [5] 관리자 마이페이지
          GoRoute(
            path: '/mypage/admin',
            name: 'admin-dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
            routes: [
              GoRoute(
                path: 'users',
                name: 'admin-users',
                builder: (context, state) => const AdminUsersScreen(),
              ),
              GoRoute(
                path: 'companies',
                name: 'admin-companies',
                builder: (context, state) => const AdminCompaniesScreen(),
              ),
              GoRoute(
                path: 'campaigns',
                name: 'admin-campaigns',
                builder: (context, state) => const AdminCampaignsScreen(),
              ),
              GoRoute(
                path: 'reviews',
                name: 'admin-reviews',
                builder: (context, state) => const AdminReviewsScreen(),
              ),
              GoRoute(
                path: 'points',
                name: 'admin-points',
                builder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  return AdminPointsScreen(initialTab: tab);
                },
              ),
              GoRoute(
                path: 'statistics',
                name: 'admin-statistics',
                builder: (context, state) => const AdminStatisticsScreen(),
              ),
              GoRoute(
                path: 'settings',
                name: 'admin-settings',
                builder: (context, state) => const AdminSettingsScreen(),
              ),
            ],
          ),
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

/// OAuth Provider 정보 추출 헬퍼 함수
String _extractProvider(User user) {
  // 1. identities에서 provider 추출 (가장 신뢰할 수 있음)
  if (user.identities != null && user.identities!.isNotEmpty) {
    final identity = user.identities!.firstWhere(
      (i) => i.provider != 'email',
      orElse: () => user.identities!.first,
    );
    if (identity.provider != 'email') {
      return identity.provider;
    }
  }

  // 2. appMetadata에서 추출
  final metadata = user.appMetadata;
  if (metadata.containsKey('provider')) {
    return metadata['provider'] as String;
  }

  // 3. userMetadata에서 추출
  final userMetadata = user.userMetadata;
  if (userMetadata != null && userMetadata.containsKey('provider')) {
    return userMetadata['provider'] as String;
  }

  // 4. email 도메인으로 추정 (google.com → google)
  if (user.email != null) {
    final domain = user.email!.split('@')[1];
    if (domain == 'gmail.com' || domain.contains('google')) {
      return 'google';
    }
  }

  // 5. fallback
  return 'unknown';
}

/// 마이페이지 리다이렉트 위젯
/// ref.watch()를 사용하여 사용자 상태 변경을 감지하고 적절한 화면으로 리다이렉트
class _MyPageRedirectWidget extends ConsumerWidget {
  const _MyPageRedirectWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ ref.watch()를 사용하여 상태 변경 감지 (ref.read() 대신)
    // ref.read()는 한 번만 읽고 재빌드되지 않아 로딩 상태가 계속 유지되는 문제 해결
    final userAsync = ref.watch(currentUserProvider);

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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
  }
}
