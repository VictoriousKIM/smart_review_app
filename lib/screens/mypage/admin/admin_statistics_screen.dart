import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../config/supabase_config.dart';
import '../../../utils/error_message_utils.dart';
import 'package:responsive_builder/responsive_builder.dart';

class AdminStatisticsScreen extends ConsumerStatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  ConsumerState<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends ConsumerState<AdminStatisticsScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      // 각 통계 조회
      final usersCount = await SupabaseConfig.client
          .from('users')
          .select('id')
          .then((response) => response.length);
      
      final companiesCount = await SupabaseConfig.client
          .from('companies')
          .select('id')
          .then((response) => response.length);
      
      final campaignsCount = await SupabaseConfig.client
          .from('campaigns')
          .select('id')
          .then((response) => response.length);
      
      final reviewsCount = await SupabaseConfig.client
          .from('reviews')
          .select('id')
          .then((response) => response.length);
      
      setState(() {
        _stats = {
          'users': usersCount,
          'companies': companiesCount,
          'campaigns': campaignsCount,
          'reviews': reviewsCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('통계'),
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
      body: ResponsiveBuilder(
        builder: (context, sizingInformation) {
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: getValueForScreenType<EdgeInsets>(
                    context: context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    desktop: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: getValueForScreenType<double>(
                          context: context,
                          mobile: double.infinity,
                          tablet: 1200,
                          desktop: 1400,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  const Text(
                    '시스템 통계',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard('전체 사용자', _stats['users'] ?? 0, Icons.people, Colors.blue),
                      _buildStatCard('등록된 회사', _stats['companies'] ?? 0, Icons.business, Colors.green),
                      _buildStatCard('캠페인', _stats['campaigns'] ?? 0, Icons.campaign, Colors.orange),
                      _buildStatCard('리뷰', _stats['reviews'] ?? 0, Icons.star, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '차트 기능은 향후 구현 예정입니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                        ],
                      ),
                    ),
                  ),
                );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 32),
            const Spacer(),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

