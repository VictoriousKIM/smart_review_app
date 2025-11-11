import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../config/supabase_config.dart';

class AdminCampaignsScreen extends ConsumerStatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  ConsumerState<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends ConsumerState<AdminCampaignsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _campaigns = [];
  bool _isLoading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);
    try {
      var query = SupabaseConfig.client.from('campaigns').select();
      
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        query = query.eq('status', _statusFilter!);
      }

      final response = await query.order('created_at', ascending: false);
      
      setState(() {
        _campaigns = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캠페인 목록을 불러오는데 실패했습니다: $e')),
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
        title: const Text('캠페인 관리'),
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
      body: Column(
        children: [
          // 검색 및 필터
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '캠페인 제목으로 검색',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _loadCampaigns(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _statusFilter,
                  decoration: InputDecoration(
                    labelText: '상태',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    const DropdownMenuItem(value: 'active', child: Text('진행중')),
                    const DropdownMenuItem(value: 'completed', child: Text('완료')),
                    const DropdownMenuItem(value: 'cancelled', child: Text('취소')),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _loadCampaigns();
                  },
                ),
              ],
            ),
          ),

          // 캠페인 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _campaigns.isEmpty
                    ? const Center(child: Text('캠페인이 없습니다'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _campaigns.length,
                        itemBuilder: (context, index) {
                          final campaign = _campaigns[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: const Icon(Icons.campaign, size: 40),
                              title: Text(
                                campaign['title'] ?? '제목 없음',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('상태: ${campaign['status'] ?? ''}'),
                                  Text('참여자: ${campaign['current_participants'] ?? 0} / ${campaign['max_participants'] ?? 0}'),
                                  Text('보상: ${campaign['review_reward'] ?? 0}P'),
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

