import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../widgets/main_shell.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/guide/guide_screen.dart';
import '../screens/mypage/mypage_screen.dart';
import '../screens/mypage/screens/reviewer_mypage_screen.dart';
import '../screens/mypage/screens/advertiser_mypage_screen.dart';
import '../screens/campaign/campaign_detail_screen.dart';
import '../screens/campaign/campaigns_screen.dart';
import '../screens/campaign/campaign_creation_screen.dart';
import '../widgets/loading_screen.dart';

// 라우터 설정
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      return authState.when(
        data: (user) {
          final isLoggedIn = user != null;
          final isLoggingIn = state.matchedLocation == '/login';
          final isSigningUp = state.matchedLocation == '/signup';
          final isRoot = state.matchedLocation == '/';

          // 루트 경로 접근 시 인증 상태에 따라 적절한 페이지로 리다이렉트
          if (isRoot) {
            return isLoggedIn ? '/home' : '/login';
          }

          // 로그인되지 않은 상태에서 보호된 경로 접근 시 로그인 페이지로 리다이렉트
          if (!isLoggedIn && !isLoggingIn && !isSigningUp) {
            return '/login';
          }

          // 로그인된 상태에서 로그인/회원가입 페이지 접근 시 홈으로 리다이렉트
          if (isLoggedIn && (isLoggingIn || isSigningUp)) {
            return '/home';
          }

          return null; // 리다이렉트 없음
        },
        loading: () {
          // ⭐ 핵심 개선: 로딩 중일 때는 리다이렉트하지 않음 (현재 페이지 유지)
          return null; // 현재 페이지 유지
        },
        error: (_, __) {
          // 에러 발생 시 로그인 페이지로 리다이렉트
          final isLoggingIn = state.matchedLocation == '/login';
          final isSigningUp = state.matchedLocation == '/signup';

          if (!isLoggingIn && !isSigningUp) {
            return '/login';
          }

          return null;
        },
      );
    },
    routes: [
      // 루트 경로 - 인증 상태에 따라 적절한 페이지로 리다이렉트
      GoRoute(
        path: '/',
        name: 'root',
        redirect: (context, state) {
          // 인증 상태에 따라 적절한 페이지로 리다이렉트
          // 이 로직은 redirect 함수에서 처리됨
          return '/login'; // 기본적으로 로그인 페이지로 리다이렉트
        },
      ),

      // 인증 관련 라우트
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) {
          final isSocialLogin = state.uri.queryParameters['social'] == 'true';
          return SignupScreen(isSocialLogin: isSocialLogin);
        },
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
            path: '/guide',
            name: 'guide',
            builder: (context, state) => const GuideScreen(),
          ),
          GoRoute(
            path: '/mypage',
            name: 'mypage',
            builder: (context, state) => const MyPageScreen(),
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
        ],
      ),

      // 캠페인 상세 라우트 (ShellRoute 밖에 배치하여 BottomNavBar가 보이지 않게 함)
      GoRoute(
        path: '/campaign/:id',
        name: 'campaign-detail',
        builder: (context, state) {
          final campaignId = state.pathParameters['id']!;
          return CampaignDetailScreen(campaignId: campaignId);
        },
      ),

      // 캠페인 생성 라우트
      GoRoute(
        path: '/campaign/create',
        name: 'campaign-create',
        builder: (context, state) => const CampaignCreationScreen(),
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
