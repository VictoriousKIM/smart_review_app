import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';

class ReviewerDrawer extends ConsumerWidget {
  const ReviewerDrawer({super.key});

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
                // 리뷰어 활동 섹션
                _buildSectionHeader('리뷰어 활동'),
                _buildMenuItem(
                  icon: Icons.campaign_outlined,
                  title: '캠페인 신청내역',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/mypage/reviewer/applications');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.favorite_outline,
                  title: '찜한 캠페인',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/mypage/reviewer/favorites');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.star_outline,
                  title: '내 리뷰',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/mypage/reviewer/reviews');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: '내 포인트',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/mypage/reviewer/points');
                  },
                ),

                const Divider(),

                // 계정 관리 섹션
                _buildSectionHeader('계정관리'),
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: '내 계정',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/mypage/profile');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.share_outlined,
                  title: 'SNS 연결',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/mypage/reviewer/sns');
                  },
                ),

                const Divider(),

                // 고객 센터 섹션
                _buildSectionHeader('고객 센터'),
                _buildMenuItem(
                  icon: Icons.notifications_outlined,
                  title: '공지사항',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/notices');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.event_outlined,
                  title: '이벤트',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/events');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: '1:1문의',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/inquiry');
                  },
                ),

                const Divider(),

                // 설정 섹션
                _buildSectionHeader('설정'),
                _buildMenuItem(
                  icon: Icons.notifications_active_outlined,
                  title: '알림 설정',
                  trailing: Switch(
                    value: true, // TODO: 실제 알림 설정 상태 연결
                    onChanged: (value) {
                      // TODO: 알림 설정 토글 로직
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings/notifications');
                  },
                ),

                // 광고주 전환 버튼 (광고주 인증된 사용자만)
                if (user.isAdvertiserVerified) ...[
                  const Divider(),
                  _buildMenuItem(
                    icon: Icons.business_outlined,
                    title: '광고주 모드로 전환',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/mypage/advertiser');
                    },
                  ),
                ],
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
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], // 녹색 그라데이션
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
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
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '리뷰어',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (user.isAdvertiserVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '광고주 인증',
                    style: TextStyle(
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
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF333333), size: 24),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
      ),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF999999)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
