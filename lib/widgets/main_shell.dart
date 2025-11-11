import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_user;

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  String? _previousPath;
  String? _lastMyPagePath;

  @override
  Widget build(BuildContext context) {
    // 현재 경로를 확인하여 마이페이지 기본 경로만 저장
    final location = GoRouterState.of(context).uri.path;
    String? basePath;

    if (location.startsWith('/mypage/admin')) {
      basePath = '/mypage/admin';
    } else if (location.startsWith('/mypage/reviewer')) {
      basePath = '/mypage/reviewer';
    } else if (location.startsWith('/mypage/advertiser')) {
      basePath = '/mypage/advertiser';
    }

    // 기본 경로가 있고 변경되었을 때만 업데이트
    if (basePath != null && _previousPath != basePath) {
      _previousPath = basePath;
      _lastMyPagePath = basePath;
    }
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context, ref),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: '캠페인',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            activeIcon: Icon(Icons.help),
            label: '이용가이드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/campaigns')) {
      return 1;
    }
    if (location.startsWith('/guide')) {
      return 2;
    }
    if (location.startsWith('/mypage')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    final currentIndex = _calculateSelectedIndex(context);

    // 같은 탭을 다시 클릭한 경우는 무시
    if (currentIndex == index) return;

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/campaigns');
        break;
      case 2:
        context.go('/guide');
        break;
      case 3:
        // 마이페이지: 마지막 방문한 경로가 있으면 그 경로로, 없으면 사용자 타입에 따라 이동
        if (_lastMyPagePath != null) {
          // 마지막 방문한 경로로 이동
          context.go(_lastMyPagePath!);
        } else {
          // 마지막 경로가 없으면 사용자 타입에 따라 적절한 경로로 이동
          final user = ref.read(currentUserProvider).value;
          if (user != null) {
            if (user.userType == app_user.UserType.admin) {
              context.go('/mypage/admin');
            } else if (user.companyId != null) {
              context.go('/mypage/advertiser');
            } else {
              context.go('/mypage/reviewer');
            }
          } else {
            context.go('/mypage');
          }
        }
        break;
    }
  }
}
