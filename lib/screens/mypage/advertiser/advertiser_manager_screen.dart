import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/company_user_service.dart';
import '../../../services/auth_service.dart';

class AdvertiserManagerScreen extends ConsumerStatefulWidget {
  const AdvertiserManagerScreen({super.key});

  @override
  ConsumerState<AdvertiserManagerScreen> createState() =>
      _AdvertiserManagerScreenState();
}

class _AdvertiserManagerScreenState
    extends ConsumerState<AdvertiserManagerScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingManagers = [];
  List<Map<String, dynamic>> _activeManagers = [];
  String _selectedFilter = 'pending'; // 'pending' or 'active'

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService().currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자의 company_id 조회 (owner인 경우)
      final companyId = await CompanyUserService.getUserCompanyId(user.uid);
      if (companyId == null) {
        throw Exception('회사 정보를 찾을 수 없습니다.');
      }

      final supabase = Supabase.instance.client;

      // RPC 함수로 매니저 목록 조회 (이메일 포함)
      final managerListResponse = await supabase.rpc(
        'get_company_managers',
        params: {'p_company_id': companyId},
      );

      final managerList = (managerListResponse as List).map((item) {
        return {
          'id': item['id'],
          'user_id': item['user_id'],
          'status': item['status'],
          'created_at': item['created_at'],
          'requested_at': item['created_at'],
          'email': item['email'] ?? '',
          'display_name': item['display_name'] ?? '',
        };
      }).toList();

      // pending과 active로 분리
      final pendingList = managerList
          .where((item) => item['status'] == 'pending')
          .toList();
      final activeList = managerList
          .where((item) => item['status'] == 'active')
          .toList();

      setState(() {
        _pendingManagers = pendingList;
        _activeManagers = activeList;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 매니저 목록 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('매니저 목록을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('매니저 관리'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/advertiser'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 필터 탭
        _buildFilterTabs(),
        // 매니저 목록
        Expanded(
          child: _selectedFilter == 'pending'
              ? _buildPendingManagersList()
              : _buildActiveManagersList(),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab('pending', '승인 대기', _pendingManagers.length),
          ),
          Expanded(
            child: _buildFilterTab('active', '활성 매니저', _activeManagers.length),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filter, String title, int count) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.blue[700] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[600] : Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingManagersList() {
    if (_pendingManagers.isEmpty) {
      return _buildEmptyState('승인 대기 중인 매니저가 없습니다.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingManagers.length,
      itemBuilder: (context, index) {
        final manager = _pendingManagers[index];
        return _buildPendingManagerCard(manager);
      },
    );
  }

  Widget _buildActiveManagersList() {
    if (_activeManagers.isEmpty) {
      return _buildEmptyState('활성 매니저가 없습니다.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeManagers.length,
      itemBuilder: (context, index) {
        final manager = _activeManagers[index];
        return _buildActiveManagerCard(manager);
      },
    );
  }

  Widget _buildPendingManagerCard(Map<String, dynamic> manager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[100],
                child: Text(
                  (manager['email'] ?? manager['display_name'] ?? 'M')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manager['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((manager['display_name'] ?? '') != '') ...[
                      const SizedBox(height: 4),
                      Text(
                        manager['display_name'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '승인 대기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (manager['requested_at'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '신청일시: ${_formatDate(manager['requested_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: '승인',
                  onPressed: () => _approveManager(manager),
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: '거절',
                  onPressed: () => _rejectManager(manager),
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveManagerCard(Map<String, dynamic> manager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green[100],
            child: Text(
              (manager['email'] ?? manager['display_name'] ?? 'M')
                  .substring(0, 1)
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((manager['display_name'] ?? '') != '') ...[
                  const SizedBox(height: 4),
                  Text(
                    manager['display_name'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (manager['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '등록일시: ${_formatDate(manager['created_at'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '활성',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onPressed: () => _showManagerMenu(manager),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return '';
      
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return '';
      }

      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _approveManager(Map<String, dynamic> manager) async {
    try {
      final supabase = Supabase.instance.client;
      
      // RPC 함수로 매니저 승인
      await supabase.rpc(
        'approve_manager',
        params: {'p_company_user_id': manager['id']},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매니저가 승인되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 목록 다시 로드
      await _loadManagers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectManager(Map<String, dynamic> manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매니저 거절'),
        content: const Text('이 매니저 요청을 거절하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '거절',
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      
      // RPC 함수로 매니저 거절
      await supabase.rpc(
        'reject_manager',
        params: {'p_company_user_id': manager['id']},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매니저 요청이 거절되었습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // 목록 다시 로드
      await _loadManagers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거절 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showManagerMenu(Map<String, dynamic> manager) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('매니저 제거'),
              onTap: () {
                Navigator.pop(context);
                _removeManager(manager);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('취소'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeManager(Map<String, dynamic> manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매니저 제거'),
        content: Text('${manager['display_name'] ?? '이름 없음'} 매니저를 제거하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '제거',
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      
      // company_users 테이블에서 레코드 삭제
      await supabase
          .from('company_users')
          .delete()
          .eq('id', manager['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매니저가 제거되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // 목록 다시 로드
      await _loadManagers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('제거 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

