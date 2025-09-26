import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../splash_screen.dart';

class ProfileScreen extends ConsumerWidget {
  final app_user.User? user;

  const ProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = this.user ?? ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 설정 화면으로 이동
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 프로필 정보
            _buildProfileInfo(context, user),

            const SizedBox(height: 32),

            // 통계 정보
            _buildStats(context, user),

            const SizedBox(height: 32),

            // 메뉴 항목들
            _buildMenuItems(context, ref),

            const SizedBox(height: 32),

            // 로그아웃 버튼
            CustomButton(
              text: '로그아웃',
              onPressed: () => _showLogoutDialog(context, ref),
              backgroundColor: Colors.red[50],
              textColor: Colors.red[700],
              borderColor: Colors.red[200],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context, app_user.User user) {
    return Column(
      children: [
        // 프로필 이미지
        CircleAvatar(
          radius: 50,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          backgroundImage: user.photoURL != null
              ? NetworkImage(user.photoURL!)
              : null,
          child: user.photoURL == null
              ? Icon(
                  Icons.person,
                  size: 50,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),

        const SizedBox(height: 16),

        // 이름
        Text(
          user.displayName ?? '사용자',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 4),

        // 이메일
        Text(
          user.email,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),

        const SizedBox(height: 8),

        // 사용자 타입
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: user.userType == app_user.UserType.reviewer
                ? Colors.blue[50]
                : Colors.green[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.userType == app_user.UserType.reviewer ? '리뷰어' : '광고주',
            style: TextStyle(
              color: user.userType == app_user.UserType.reviewer
                  ? Colors.blue[700]
                  : Colors.green[700],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, app_user.User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              '포인트',
              '${user.points}P',
              Icons.stars,
              Colors.amber,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              context,
              '레벨',
              'Lv.${user.level}',
              Icons.trending_up,
              Colors.blue,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              context,
              '리뷰 수',
              '${user.reviewCount}개',
              Icons.rate_review,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMenuItems(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          icon: Icons.history,
          title: '참여한 캠페인',
          subtitle: '내가 참여한 캠페인을 확인하세요',
          onTap: () {
            // 참여한 캠페인 화면으로 이동
          },
        ),

        _buildMenuItem(
          context,
          icon: Icons.rate_review,
          title: '내 리뷰',
          subtitle: '작성한 리뷰를 관리하세요',
          onTap: () {
            // 내 리뷰 화면으로 이동
          },
        ),

        _buildMenuItem(
          context,
          icon: Icons.notifications,
          title: '알림',
          subtitle: '알림 설정을 관리하세요',
          onTap: () {
            // 알림 설정 화면으로 이동
          },
        ),

        _buildMenuItem(
          context,
          icon: Icons.help,
          title: '도움말',
          subtitle: '자주 묻는 질문과 문의하기',
          onTap: () {
            // 도움말 화면으로 이동
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(authProvider.notifier).signOut();
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
