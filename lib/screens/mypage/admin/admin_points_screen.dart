import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../config/supabase_config.dart';

class AdminPointsScreen extends ConsumerStatefulWidget {
  const AdminPointsScreen({super.key});

  @override
  ConsumerState<AdminPointsScreen> createState() => _AdminPointsScreenState();
}

class _AdminPointsScreenState extends ConsumerState<AdminPointsScreen> {
  List<Map<String, dynamic>> _wallets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseConfig.client
          .from('wallets')
          .select()
          .order('updated_at', ascending: false)
          .limit(50);
      
      setState(() {
        _wallets = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포인트 정보를 불러오는데 실패했습니다: $e')),
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
                onPressed: () => Navigator.pop(context),
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
        title: const Text('포인트 관리'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
              ? const Center(child: Text('지갑 정보가 없습니다'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = _wallets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(Icons.account_balance_wallet, size: 40),
                        title: Text('포인트: ${wallet['current_points'] ?? 0}P'),
                        subtitle: Text(
                          wallet['user_id'] != null
                              ? '사용자 지갑'
                              : '회사 지갑',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'add',
                              child: Text('포인트 지급'),
                            ),
                            const PopupMenuItem(
                              value: 'deduct',
                              child: Text('포인트 차감'),
                            ),
                            const PopupMenuItem(
                              value: 'history',
                              child: Text('이력 조회'),
                            ),
                          ],
                          onSelected: (value) {
                            // TODO: 포인트 지급/차감 기능 구현
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$value 기능은 구현 예정입니다')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

