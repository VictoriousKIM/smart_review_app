import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/company_user_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/error_message_utils.dart';

class AdvertiserManagerScreen extends ConsumerStatefulWidget {
  const AdvertiserManagerScreen({super.key});

  @override
  ConsumerState<AdvertiserManagerScreen> createState() =>
      _AdvertiserManagerScreenState();
}

class _AdvertiserManagerScreenState
    extends ConsumerState<AdvertiserManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingManagers = [];
  List<Map<String, dynamic>> _activeManagers = [];
  List<Map<String, dynamic>> _inactiveManagers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadManagers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadManagers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자의 company_id 조회 (owner인 경우)
      final companyId = await CompanyUserService.getUserCompanyId(userId);
      if (companyId == null) {
        throw Exception('회사 정보를 찾을 수 없습니다.');
      }

      final supabase = Supabase.instance.client;

      // RPC 함수로 매니저 목록 조회 (이메일 포함, Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final managerListResponse = await supabase.rpc(
        'get_company_managers',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
        },
      );

      final managerList = (managerListResponse as List).map((item) {
        return {
          'company_id': item['company_id'],
          'user_id': item['user_id'],
          'status': item['status'],
          'created_at': item['created_at'],
          'requested_at': item['created_at'],
          'email': item['email'] ?? '',
          'display_name': item['display_name'] ?? '',
        };
      }).toList();

      // pending, active, inactive로 분리
      final pendingList = managerList
          .where((item) => item['status'] == 'pending')
          .toList();
      final activeList = managerList
          .where((item) => item['status'] == 'active')
          .toList();
      final inactiveList = managerList
          .where((item) => item['status'] == 'inactive')
          .toList();

      setState(() {
        _pendingManagers = pendingList;
        _activeManagers = activeList;
        _inactiveManagers = inactiveList;
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: '승인 대기'),
            Tab(text: '활성 매니저'),
            Tab(text: '비활성 매니저'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingManagersList(),
                _buildActiveManagersList(),
                _buildInactiveManagersList(),
              ],
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

  Widget _buildInactiveManagersList() {
    if (_inactiveManagers.isEmpty) {
      return _buildEmptyState('비활성 매니저가 없습니다.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inactiveManagers.length,
      itemBuilder: (context, index) {
        final manager = _inactiveManagers[index];
        return _buildInactiveManagerCard(manager);
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
                if (manager['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '등록일시: ${_formatDate(manager['created_at'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
            onPressed: () => _showActiveManagerMenu(manager),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveManagerCard(Map<String, dynamic> manager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
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
            backgroundColor: Colors.grey[300],
            child: Text(
              (manager['email'] ?? manager['display_name'] ?? 'M')
                  .substring(0, 1)
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                if ((manager['display_name'] ?? '') != '') ...[
                  const SizedBox(height: 4),
                  Text(
                    manager['display_name'] ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
                if (manager['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '등록일시: ${_formatDate(manager['created_at'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '비활성',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onPressed: () => _showInactiveManagerMenu(manager),
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
        date = DateTimeUtils.parseKST(dateValue);
      } else if (dateValue is DateTime) {
        date = DateTimeUtils.toKST(dateValue);
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

      // RPC 함수로 매니저 승인 (복합 키 사용, Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달)
      final userId = await AuthService.getCurrentUserId();
      await supabase.rpc(
        'approve_manager',
        params: {
          'p_company_id': manager['company_id'],
          'p_user_id': manager['user_id'],
          'p_current_user_id': userId,
        },
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
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
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
            child: Text('거절', style: TextStyle(color: Colors.red[600])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;

      // RPC 함수로 매니저 거절 (복합 키 사용, Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달)
      final userId = await AuthService.getCurrentUserId();
      await supabase.rpc(
        'reject_manager',
        params: {
          'p_company_id': manager['company_id'],
          'p_user_id': manager['user_id'],
          'p_current_user_id': userId,
        },
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
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showActiveManagerMenu(Map<String, dynamic> manager) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.pause_circle_outline,
                color: Colors.orange,
              ),
              title: const Text('매니저 비활성화'),
              onTap: () {
                Navigator.pop(context);
                _deactivateManager(manager);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
              ),
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

  void _showInactiveManagerMenu(Map<String, dynamic> manager) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.play_circle_outline,
                color: Colors.blue,
              ),
              title: const Text('매니저 활성화'),
              onTap: () {
                Navigator.pop(context);
                _activateManager(manager);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
              ),
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

  Future<void> _deactivateManager(Map<String, dynamic> manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매니저 비활성화'),
        content: Text(
          '${manager['display_name'] ?? manager['email'] ?? '이름 없음'} 매니저를 비활성화하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('비활성화', style: TextStyle(color: Colors.orange[600])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await CompanyUserService.deactivateManager(
        companyId: manager['company_id'],
        userId: manager['user_id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '매니저가 비활성화되었습니다.'),
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
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _activateManager(Map<String, dynamic> manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매니저 활성화'),
        content: Text(
          '${manager['display_name'] ?? manager['email'] ?? '이름 없음'} 매니저를 활성화하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('활성화', style: TextStyle(color: Colors.blue[600])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await CompanyUserService.activateManager(
        companyId: manager['company_id'],
        userId: manager['user_id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '매니저가 활성화되었습니다.'),
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
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _removeManager(Map<String, dynamic> manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매니저 제거'),
        content: Text(
          '${manager['display_name'] ?? manager['email'] ?? '이름 없음'} 매니저를 제거하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('제거', style: TextStyle(color: Colors.red[600])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;

      // company_users 테이블에서 레코드 삭제 (복합 키 사용)
      await supabase
          .from('company_users')
          .delete()
          .eq('company_id', manager['company_id'])
          .eq('user_id', manager['user_id'])
          .eq('company_role', 'manager');

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
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
