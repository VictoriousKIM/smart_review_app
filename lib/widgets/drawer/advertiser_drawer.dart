import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';

class AdvertiserDrawer extends ConsumerWidget {
  const AdvertiserDrawer({super.key});

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
                // 광고주 활동 섹션
                _buildSectionHeader('광고주 활동'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.business_outlined,
                  title: '나의 캠페인',
                  routePath: '/mypage/advertiser/my-campaigns',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/advertiser/my-campaigns');
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.add_circle_outline,
                  title: '캠페인 등록',
                  routePath: '/mypage/advertiser/my-campaigns/create',
                  onTap: () {
                    Navigator.pop(context);
                    // Flutter 웹에서 URL 업데이트 문제 해결
                    if (kIsWeb) {
                      context.go('/mypage/advertiser/my-campaigns/create');
                    } else {
                      context.go('/mypage/advertiser/my-campaigns/create');
                    }
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.analytics_outlined,
                  title: '캠페인 분석',
                  routePath: '/mypage/advertiser/analytics',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/advertiser/analytics');
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.people_outline,
                  title: '참여자 관리',
                  routePath: '/mypage/advertiser/participants',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/advertiser/participants');
                  },
                ),

                const Divider(),

                // 계정 관리 섹션
                _buildSectionHeader('계정관리'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.person_outline,
                  title: '내 계정',
                  routePath: '/mypage/profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/profile');
                  },
                ),
                if (user.companyId != null) ...[
                  _buildMenuItem(
                    context: context,
                    icon: Icons.business_center_outlined,
                    title: '회사 정보',
                    routePath: '/mypage/advertiser/company',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/mypage/advertiser/company');
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.admin_panel_settings_outlined,
                    title: '페널티 관리',
                    routePath: '/mypage/advertiser/penalties',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/mypage/advertiser/penalties');
                    },
                  ),
                ],
                _buildMenuItem(
                  context: context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: '내 포인트',
                  routePath: '/mypage/advertiser/points',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mypage/advertiser/points');
                  },
                ),

                const Divider(),

                // 고객 센터 섹션
                _buildSectionHeader('고객 센터'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.notifications_outlined,
                  title: '공지사항',
                  routePath: '/notices',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/notices');
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.event_outlined,
                  title: '이벤트',
                  routePath: '/events',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/events');
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.help_outline,
                  title: '1:1문의',
                  routePath: '/inquiry',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/inquiry');
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.campaign_outlined,
                  title: '광고문의',
                  routePath: '/advertisement-inquiry',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/advertisement-inquiry');
                  },
                ),

                const Divider(),

                // 설정 섹션
                _buildSectionHeader('설정'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.notifications_active_outlined,
                  title: '알림 설정',
                  routePath: '/settings/notifications',
                  trailing: Switch(
                    value: true, // TODO: 실제 알림 설정 상태 연결
                    onChanged: (value) {
                      // TODO: 알림 설정 토글 로직
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/settings/notifications');
                  },
                ),

                // 리뷰어 전환 버튼
                const Divider(),
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
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)], // 파란색 그라데이션
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
            user.displayName ?? '사용자',
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '광고주',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (user.companyId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.companyRole?.name == 'owner' ? '회사 소유자' : '회사 관리자',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
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
        color: isActive ? const Color(0xFF2196F3) : const Color(0xFF333333),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isActive ? const Color(0xFF2196F3) : const Color(0xFF333333),
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: isActive
          ? Text(
              routePath,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2196F3)),
            )
          : null,
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF999999)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      tileColor: isActive ? const Color(0xFFE3F2FD) : null,
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
