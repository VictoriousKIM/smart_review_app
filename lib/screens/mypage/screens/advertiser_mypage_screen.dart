import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/user.dart' as app_user;
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/mypage_common_widgets.dart';
import '../../../widgets/drawer/advertiser_drawer.dart';

class AdvertiserMyPageScreen extends ConsumerWidget {
  final app_user.User? user;

  const AdvertiserMyPageScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = this.user ?? ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      drawer: const AdvertiserDrawer(),
      appBar: AppBar(
        title: const Text('마이페이지'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // 알림 기능 구현
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 파란색 카드
            MyPageCommonWidgets.buildTopCard(
              userName: user.displayName ?? '사용자',
              userType: '광고주',
              onSwitchPressed: () {
                // 리뷰어 마이페이지로 이동
                context.push('/mypage/reviewer');
              },
              switchButtonText: '리뷰어 전환',
              showRating: false,
            ),

            const SizedBox(height: 16),

            // 캠페인 상태 섹션
            MyPageCommonWidgets.buildCampaignStatusSection(
              statusItems: [
                {'label': '대기중', 'count': '0'},
                {'label': '모집중', 'count': '0'},
                {'label': '선정완료', 'count': '0'},
                {'label': '등록기간', 'count': '0'},
                {'label': '종료', 'count': '0'},
              ],
              actionButtonText: '캠페인 등록 >',
              onActionPressed: () {
                context.push('/campaign/create');
              },
            ),

            const SizedBox(height: 16),

            // 알림 섹션
            MyPageCommonWidgets.buildNotificationSection(),

            const SizedBox(height: 32),

            // 로그아웃 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: '로그아웃',
                onPressed: () => _showLogoutDialog(context, ref),
                backgroundColor: Colors.red[50],
                textColor: Colors.red[700],
                borderColor: Colors.red[200],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              context.pop();
              await ref.read(authProvider.notifier).signOut();
              // 로그아웃 후 로그인 페이지로 이동
              context.go('/login');
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
