import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';
import 'reviewer/reviewer_mypage_screen.dart';
import 'advertiser/advertiser_mypage_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class MyPageScreen extends ConsumerWidget {
  final app_user.User? user;

  const MyPageScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = this.user ?? ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
    }

    // 관리자인 경우 어드민 대시보드 표시
    if (user.userType == app_user.UserType.admin) {
      return const AdminDashboardScreen();
    }

    // companyId가 있으면 광고주로 판단 (company_users 테이블 사용 전까지 임시)
    if (user.companyId != null) {
      return AdvertiserMyPageScreen(user: user);
    } else {
      return ReviewerMyPageScreen(user: user);
    }
  }
}
