import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';

class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Drawer(child: Center(child: Text('사용자 정보를 불러올 수 없습니다')));
    }

    return Drawer(
      child: Column(
        children: [
          // 헤더
          _buildHeader(context, user),

          // 메뉴 리스트
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 대시보드 섹션
                _buildSectionHeader('관리자 대시보드'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.dashboard_outlined,
                  title: '대시보드',
                  routePath: '/mypage/admin',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin');
                  },
                ),

                const Divider(),

                // 사용자 관리 섹션
                _buildSectionHeader('사용자 관리'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.people_outlined,
                  title: '사용자 관리',
                  routePath: '/mypage/admin/users',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/users');
                  },
                ),

                const Divider(),

                // 회사 관리 섹션
                _buildSectionHeader('회사 관리'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.business_outlined,
                  title: '회사 관리',
                  routePath: '/mypage/admin/companies',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/companies');
                  },
                ),

                const Divider(),

                // 캠페인 관리 섹션
                _buildSectionHeader('캠페인 관리'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.campaign_outlined,
                  title: '캠페인 관리',
                  routePath: '/mypage/admin/campaigns',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/campaigns');
                  },
                ),

                const Divider(),

                // 리뷰 관리 섹션
                _buildSectionHeader('리뷰 관리'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.star_outline,
                  title: '리뷰 관리',
                  routePath: '/mypage/admin/reviews',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/reviews');
                  },
                ),

                const Divider(),

                // 포인트 관리 섹션
                _buildSectionHeader('포인트 관리'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: '포인트 관리',
                  routePath: '/mypage/admin/points',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/points');
                  },
                ),

                const Divider(),

                // 통계 섹션
                _buildSectionHeader('통계'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.bar_chart_outlined,
                  title: '통계',
                  routePath: '/mypage/admin/statistics',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/statistics');
                  },
                ),

                const Divider(),

                // 시스템 설정 섹션
                _buildSectionHeader('시스템 설정'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: '시스템 설정',
                  routePath: '/mypage/admin/settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/admin/settings');
                  },
                ),

                const Divider(),

                // 리뷰어/사업자 모드 전환 버튼
                // 사업자 인증된 경우 사업자 모드로 전환 버튼 표시
                if (user.companyId != null) ...[
                  _buildMenuItem(
                    context: context,
                    icon: Icons.business_outlined,
                    title: '사업자 모드로 전환',
                    routePath: '/mypage/advertiser',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/mypage/advertiser');
                    },
                  ),
                ],
                // 리뷰어 모드로 전환 버튼 (항상 표시)
                _buildMenuItem(
                  context: context,
                  icon: Icons.rate_review_outlined,
                  title: '리뷰어 모드로 전환',
                  routePath: '/mypage/reviewer',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/reviewer');
                  },
                ),
              ],
            ),
          ),

          // 하단 로그아웃 버튼
          _buildLogoutButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, app_user.User user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)], // 보라색 그라데이션 (어드민 전용)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName ?? '관리자',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '관리자',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required String routePath,
    Widget? trailing,
  }) {
    // 현재 URL 확인
    final currentPath = GoRouterState.of(context).uri.path;
    final isActive = currentPath == routePath;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFF7B1FA2) : const Color(0xFF333333),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isActive ? const Color(0xFF7B1FA2) : const Color(0xFF333333),
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: isActive
          ? Text(
              routePath,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7B1FA2)),
            )
          : null,
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF999999)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      tileColor: isActive ? const Color(0xFFF3E5F5) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _showLogoutDialog(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[50],
            foregroundColor: Colors.red[700],
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.red[200]!),
            ),
          ),
          child: const Text(
            '로그아웃',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
