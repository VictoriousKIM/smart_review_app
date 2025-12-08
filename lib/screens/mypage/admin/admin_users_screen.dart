import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../services/admin_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/error_message_utils.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  final _adminService = AdminService();
  final _authService = AuthService();
  
  List<app_user.User> _users = [];
  bool _isLoading = true;
  String? _searchQuery;
  String? _userTypeFilter;
  String? _statusFilter = 'active';
  int _currentPage = 0;
  final int _pageSize = 20;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getUsers(
        searchQuery: _searchQuery,
        userTypeFilter: _userTypeFilter,
        statusFilter: _statusFilter,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      final count = await _adminService.getUsersCount(
        searchQuery: _searchQuery,
        userTypeFilter: _userTypeFilter,
        statusFilter: _statusFilter,
      );
      
      setState(() {
        _users = users;
        _totalCount = count;
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

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.isEmpty ? null : query;
      _currentPage = 0;
    });
    _loadUsers();
  }

  void _onFilterChanged(String? userType, String? status) {
    setState(() {
      _userTypeFilter = userType;
      _statusFilter = status;
      _currentPage = 0;
    });
    _loadUsers();
  }

  Future<void> _changeUserRole(app_user.User user, String newRole) async {
    try {
      await _authService.adminChangeUserRole(user.uid, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 권한이 변경되었습니다')),
        );
        _loadUsers();
      }
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

  Future<void> _changeUserStatus(app_user.User user, String newStatus) async {
    try {
      await _adminService.updateUserStatus(user.uid, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 상태가 $newStatus로 변경되었습니다')),
        );
        _loadUsers();
      }
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
        title: const Text('사용자 관리'),
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
          // 검색 및 필터 섹션
          _buildSearchAndFilterSection(),

          // 사용자 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('사용자가 없습니다'))
                    : _buildUsersList(),
          ),

          // 페이지네이션
          if (!_isLoading && _users.isNotEmpty) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // 검색 바
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '이메일 또는 이름으로 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: _onSearch,
          ),
          const SizedBox(height: 12),
          // 필터
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _userTypeFilter,
                  decoration: InputDecoration(
                    labelText: '사용자 타입',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    const DropdownMenuItem(value: 'user', child: Text('일반 사용자')),
                    const DropdownMenuItem(value: 'admin', child: Text('관리자')),
                  ],
                  onChanged: (value) => _onFilterChanged(value, _statusFilter),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _statusFilter,
                  decoration: InputDecoration(
                    labelText: '상태',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    const DropdownMenuItem(value: 'active', child: Text('활성')),
                    const DropdownMenuItem(value: 'inactive', child: Text('비활성')),
                  ],
                  onChanged: (value) => _onFilterChanged(_userTypeFilter, value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: user.userType == app_user.UserType.admin
                  ? Colors.purple
                  : Colors.blue,
              child: Text(
                (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              user.displayName ?? '이름 없음',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        user.userType == app_user.UserType.admin ? '관리자' : '일반',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: user.userType == app_user.UserType.admin
                          ? Colors.purple[100]
                          : Colors.blue[100],
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        user.status ?? 'active',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: (user.status ?? 'active') == 'active'
                          ? Colors.green[100]
                          : Colors.grey[100],
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                if (user.userType != app_user.UserType.admin)
                  const PopupMenuItem(
                    value: 'make_admin',
                    child: Text('관리자로 변경'),
                  ),
                if (user.userType == app_user.UserType.admin)
                  const PopupMenuItem(
                    value: 'make_user',
                    child: Text('일반 사용자로 변경'),
                  ),
                if ((user.status ?? 'active') == 'active')
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text('비활성화'),
                  ),
                if ((user.status ?? 'active') != 'active')
                  const PopupMenuItem(
                    value: 'activate',
                    child: Text('활성화'),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'make_admin':
                    _showConfirmDialog(
                      '관리자로 변경',
                      '이 사용자를 관리자로 변경하시겠습니까?',
                      () => _changeUserRole(user, 'admin'),
                    );
                    break;
                  case 'make_user':
                    _showConfirmDialog(
                      '일반 사용자로 변경',
                      '이 사용자를 일반 사용자로 변경하시겠습니까?',
                      () => _changeUserRole(user, 'user'),
                    );
                    break;
                  case 'deactivate':
                    _showConfirmDialog(
                      '비활성화',
                      '이 사용자를 비활성화하시겠습니까?',
                      () => _changeUserStatus(user, 'inactive'),
                    );
                    break;
                  case 'activate':
                    _changeUserStatus(user, 'active');
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _pageSize).ceil();
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _loadUsers();
                  }
                : null,
          ),
          Text('${_currentPage + 1} / $totalPages (총 $_totalCount명)'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _loadUsers();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

