import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  bool _hasCheckedAuth = false;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    // 짧은 딜레이 후 인증 상태 확인 (위젯 트리가 완전히 빌드된 후)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkAuthAndRedirect();
      }
    });
  }

  Future<void> _checkAuthAndRedirect() async {
    // 이미 체크했거나 리다이렉트 중이면 중단
    if (_hasCheckedAuth || _isRedirecting) return;
    _hasCheckedAuth = true;
    _isRedirecting = true;

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.currentUser;
      
      if (!mounted) {
        _isRedirecting = false;
        return;
      }
      
      // 현재 경로 확인 (이미 다른 페이지로 이동했는지)
      final currentPath = GoRouterState.of(context).matchedLocation;
      if (currentPath != '/loading') {
        // 이미 다른 페이지로 이동했으면 리다이렉트하지 않음
        _isRedirecting = false;
        return;
      }
      
      // 인증 상태에 따라 적절한 페이지로 리다이렉트
      if (user != null) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    } catch (e) {
      // 에러 발생 시 로그인 페이지로 리다이렉트
      if (!mounted) {
        _isRedirecting = false;
        return;
      }
      
      // 현재 경로 확인
      final currentPath = GoRouterState.of(context).matchedLocation;
      if (currentPath == '/loading') {
        context.go('/login');
      }
    } finally {
      // 리다이렉트 완료 후 플래그 리셋
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isRedirecting = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('로딩 중...', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

