import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';
import 'reviewer/reviewer_mypage_screen.dart';
import 'advertiser/advertiser_mypage_screen.dart';

class MyPageScreen extends ConsumerWidget {
  final app_user.User? user;

  const MyPageScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = this.user ?? ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
    }

    // 광고주 인증 여부에 따라 적절한 화면으로 리다이렉트
    if (user.isAdvertiserVerified) {
      return AdvertiserMyPageScreen(user: user);
    } else {
      return ReviewerMyPageScreen(user: user);
    }
  }
}
