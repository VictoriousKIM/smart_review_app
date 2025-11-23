import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../config/supabase_config.dart';

class AdminCompaniesScreen extends ConsumerStatefulWidget {
  const AdminCompaniesScreen({super.key});

  @override
  ConsumerState<AdminCompaniesScreen> createState() => _AdminCompaniesScreenState();
}

class _AdminCompaniesScreenState extends ConsumerState<AdminCompaniesScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    try {
      var query = SupabaseConfig.client.from('companies').select();
      
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        // TODO: companies 테이블에 status 컬럼이 있는지 확인 필요
      }

      final response = await query.order('created_at', ascending: false);
      
      setState(() {
        _companies = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회사 목록을 불러오는데 실패했습니다: $e')),
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
        title: const Text('회사 관리'),
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
      body: Column(
        children: [
          // 검색 및 필터
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '회사명 또는 사업자번호로 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _loadCompanies(),
            ),
          ),

          // 회사 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _companies.isEmpty
                    ? const Center(child: Text('등록된 회사가 없습니다'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _companies.length,
                        itemBuilder: (context, index) {
                          final company = _companies[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: const Icon(Icons.business, size: 40),
                              title: Text(
                                company['business_name'] ?? '회사명 없음',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('사업자번호: ${company['business_number'] ?? ''}'),
                                  Text('대표자: ${company['representative_name'] ?? ''}'),
                                  Text('업종: ${company['business_type'] ?? ''}'),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'approve',
                                    child: Text('승인'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'reject',
                                    child: Text('거부'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Text('상세보기'),
                                  ),
                                ],
                                onSelected: (value) {
                                  // TODO: 승인/거부 기능 구현
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$value 기능은 구현 예정입니다')),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

