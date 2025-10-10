import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bottom_navigation.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigation(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
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

  void _onItemTapped(int index, BuildContext context) {
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
        context.go('/mypage');
        break;
    }
  }
}
