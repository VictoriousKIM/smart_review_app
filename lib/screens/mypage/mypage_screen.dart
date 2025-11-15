import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';
import '../../utils/user_type_helper.dart';
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

    // UserTypeHelper를 사용하여 리뷰어/광고주 구분 (비동기)
    return FutureBuilder<bool>(
      future: UserTypeHelper.isAdvertiser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isAdvertiser = snapshot.data ?? false;

        if (isAdvertiser) {
          return AdvertiserMyPageScreen(user: user);
        } else {
          return ReviewerMyPageScreen(user: user);
        }
      },
    );
  }
}
