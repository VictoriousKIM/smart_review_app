import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../config/supabase_config.dart';
import '../../../services/wallet_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _usersCount = 0;
  int _companiesCount = 0;
  int _campaignsCount = 0;
  int _pendingCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    // 관리자 대시보드 진입 시 사용자 정보 새로고침 및 통계 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserAndLoadStats();
    });
  }

  Future<void> _refreshUserAndLoadStats() async {
    // 사용자 정보 새로고침 (Supabase에서 변경된 user_type 반영)
    ref.invalidate(currentUserProvider);
    // 통계 로드
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoadingStats = true);
    try {
      final usersResponse = await SupabaseConfig.client
          .from('users')
          .select('id');
      final users = (usersResponse as List).length;

      final companiesResponse = await SupabaseConfig.client
          .from('companies')
          .select('id');
      final companies = (companiesResponse as List).length;

      final campaignsResponse = await SupabaseConfig.client
          .from('campaigns')
          .select('id');
      final campaigns = (campaignsResponse as List).length;

      // 대기 중인 포인트 거래 개수 조회
      int pending = 0;
      try {
        final pendingTransactions =
            await WalletService.getPendingCashTransactions(
              status: 'pending',
              limit: 1000, // 충분히 큰 값으로 설정
            );
        pending = pendingTransactions.length;
      } catch (e) {
        debugPrint('대기 중 포인트 거래 개수 조회 실패: $e');
        pending = 0;
      }

      setState(() {
        _usersCount = users;
        _companiesCount = companies;
        _campaignsCount = campaigns;
        _pendingCount = pending;
        _isLoadingStats = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ 통계 로드 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    // 권한 체크
    if (user == null || user.userType != app_user.UserType.admin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                '관리자 권한이 필요합니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
        title: const Text('관리자 대시보드'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // 알림 기능 구현 예정
            },
          ),
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
            // 환영 메시지
            _buildWelcomeCard(user),

            const SizedBox(height: 24),

            // 통계 카드 그리드
            _buildStatisticsGrid(),

            const SizedBox(height: 24),

            // 빠른 액션 섹션
            _buildQuickActionsSection(),

            const SizedBox(height: 24),

            // 최근 활동 섹션
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(app_user.User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '관리자 대시보드',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // 리뷰어 전환 버튼
              TextButton.icon(
                onPressed: () {
                  context.go('/mypage/reviewer');
                },
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('리뷰어'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
              // 광고주 전환 버튼 (companyId가 있는 경우만 표시)
              if (user.companyId != null)
                TextButton.icon(
                  onPressed: () {
                    context.go('/mypage/advertiser');
                  },
                  icon: const Icon(Icons.business_outlined, size: 18),
                  label: const Text('광고주'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${user.displayName ?? '관리자'}님, 환영합니다',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          title: '전체 사용자',
          value: _isLoadingStats ? '...' : _usersCount.toString(),
          icon: Icons.people_outlined,
          color: Colors.blue,
          onTap: () {
            context.go('/mypage/admin/users');
          },
        ),
        _buildStatCard(
          title: '등록된 회사',
          value: _isLoadingStats ? '...' : _companiesCount.toString(),
          icon: Icons.business_outlined,
          color: Colors.green,
          onTap: () {
            context.go('/mypage/admin/companies');
          },
        ),
        _buildStatCard(
          title: '진행 중 캠페인',
          value: _isLoadingStats ? '...' : _campaignsCount.toString(),
          icon: Icons.campaign_outlined,
          color: Colors.orange,
          onTap: () {
            context.go('/mypage/admin/campaigns');
          },
        ),
        _buildStatCard(
          title: '대기 중 포인트',
          value: _isLoadingStats ? '...' : _pendingCount.toString(),
          icon: Icons.pending_outlined,
          color: Colors.red,
          onTap: () {
            context.go('/mypage/admin/points?tab=pending');
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 아이콘과 숫자를 같은 행에 배치
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 32),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '빠른 액션',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              icon: Icons.people_outlined,
              label: '사용자 관리',
              color: Colors.blue,
              onTap: () {
                context.go('/mypage/admin/users');
              },
            ),
            _buildActionButton(
              icon: Icons.business_outlined,
              label: '회사 관리',
              color: Colors.green,
              onTap: () {
                context.go('/mypage/admin/companies');
              },
            ),
            _buildActionButton(
              icon: Icons.campaign_outlined,
              label: '캠페인 관리',
              color: Colors.orange,
              onTap: () {
                context.go('/mypage/admin/campaigns');
              },
            ),
            _buildActionButton(
              icon: Icons.account_balance_wallet_outlined,
              label: '포인트 관리',
              color: Colors.teal,
              onTap: () {
                context.go('/mypage/admin/points');
              },
            ),
            _buildActionButton(
              icon: Icons.bar_chart_outlined,
              label: '통계 보기',
              color: Colors.purple,
              onTap: () {
                context.go('/mypage/admin/statistics');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 활동',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityItem(
                  icon: Icons.info_outline,
                  title: '최근 활동이 없습니다',
                  subtitle: '시스템 활동 내역이 표시됩니다',
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}
