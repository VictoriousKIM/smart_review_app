import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_user;
import '../widgets/loading_screen.dart';
import '../screens/mypage/reviewer/reviewer_mypage_screen.dart';
import '../screens/mypage/advertiser/advertiser_mypage_screen.dart';

/// 마이페이지 라우트 래퍼 위젯
/// Builder에서 ref.watch() 사용 시 재평가를 방지하기 위해 별도 위젯으로 분리
class MyPageRouteWrapper extends ConsumerWidget {
  final String routeType; // 'reviewer' or 'advertiser'

  const MyPageRouteWrapper({
    super.key,
    required this.routeType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        if (routeType == 'reviewer') {
          return ReviewerMyPageScreen(user: user);
        } else if (routeType == 'advertiser') {
          // 권한 체크: 어드민은 통과, 광고주는 통과, 그 외는 리뷰어로 리다이렉트
          if (user.userType != app_user.UserType.admin && !user.isAdvertiser) {
            // 광고주가 아니면 리뷰어로 리다이렉트
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/mypage/reviewer');
              }
            });
            return const LoadingScreen();
          }
          return AdvertiserMyPageScreen(user: user);
        }

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
  }
}

