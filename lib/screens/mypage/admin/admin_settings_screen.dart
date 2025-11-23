import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null || user.userType != app_user.UserType.admin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('관리자 권한이 필요합니다'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final currentUser = ref.read(currentUserProvider).value;
                  if (currentUser != null) {
                    if (currentUser.userType == app_user.UserType.admin) {
                      context.go('/mypage/admin');
                    } else if (currentUser.companyId != null) {
                      context.go('/mypage/advertiser');
                    } else {
                      context.go('/mypage/reviewer');
                    }
                  } else {
                    context.go('/mypage');
                  }
                },
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      endDrawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('시스템 설정'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/admin'),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시스템 설정',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.build),
                    title: const Text('시스템 점검 모드'),
                    subtitle: const Text('시스템 점검 중 사용자 접근 제한'),
                    trailing: Switch(
                      value: false,
                      onChanged: (value) {
                        // TODO: 점검 모드 설정 구현
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('점검 모드 설정은 구현 예정입니다')),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('공지사항 관리'),
                    subtitle: const Text('시스템 공지사항 작성 및 관리'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 공지사항 관리 페이지로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('공지사항 관리 기능은 구현 예정입니다')),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('이벤트 관리'),
                    subtitle: const Text('이벤트 생성 및 관리'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 이벤트 관리 페이지로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이벤트 관리 기능은 구현 예정입니다')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

