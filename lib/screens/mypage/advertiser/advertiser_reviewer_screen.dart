import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/company_user_service.dart';
import '../../../services/auth_service.dart';

class AdvertiserReviewerScreen extends ConsumerStatefulWidget {
  const AdvertiserReviewerScreen({super.key});

  @override
  ConsumerState<AdvertiserReviewerScreen> createState() =>
      _AdvertiserReviewerScreenState();
}

class _AdvertiserReviewerScreenState
    extends ConsumerState<AdvertiserReviewerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingReviewers = [];
  List<Map<String, dynamic>> _activeReviewers = [];
  List<Map<String, dynamic>> _inactiveReviewers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReviewers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewers() async {
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

      // RPC 함수로 리뷰어 목록 조회 (Custom JWT 세션 지원을 위해 p_user_id 파라미터 전달)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final reviewerListResponse = await supabase.rpc(
        'get_company_reviewers',
        params: {
          'p_company_id': companyId,
          'p_user_id': userId,
        },
      );

      final reviewerList = (reviewerListResponse as List).map((item) {
        return {
          'company_id': item['company_id'],
          'user_id': item['user_id'],
          'status': item['status'],
          'created_at': item['created_at'],
          'email': item['email'] ?? '',
          'display_name': item['display_name'] ?? '',
        };
      }).toList();

      // pending, active, inactive로 분리
      final pendingList = reviewerList
          .where((item) => item['status'] == 'pending')
          .toList();
      final activeList = reviewerList
          .where((item) => item['status'] == 'active')
          .toList();
      final inactiveList = reviewerList
          .where((item) => item['status'] == 'inactive')
          .toList();

      setState(() {
        _pendingReviewers = pendingList;
        _activeReviewers = activeList;
        _inactiveReviewers = inactiveList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 리뷰어 목록 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('리뷰어 목록을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveReviewer(Map<String, dynamic> reviewer) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      await supabase.rpc(
        'approve_reviewer_role',
        params: {
          'p_company_id': reviewer['company_id'],
          'p_user_id': reviewer['user_id'],
          'p_current_user_id': userId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리뷰어가 승인되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviewers();
      }
    } catch (e) {
      debugPrint('❌ 리뷰어 승인 실패: $e');
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

  Future<void> _rejectReviewer(Map<String, dynamic> reviewer) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      await supabase.rpc(
        'reject_reviewer_role',
        params: {
          'p_company_id': reviewer['company_id'],
          'p_user_id': reviewer['user_id'],
          'p_current_user_id': userId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리뷰어 요청이 거절되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadReviewers();
      }
    } catch (e) {
      debugPrint('❌ 리뷰어 거절 실패: $e');
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

  Future<void> _deactivateReviewer(Map<String, dynamic> reviewer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰어 비활성화'),
        content: const Text('이 리뷰어를 비활성화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('비활성화'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      await supabase.rpc(
        'deactivate_reviewer_role',
        params: {
          'p_company_id': reviewer['company_id'],
          'p_user_id': reviewer['user_id'],
          'p_current_user_id': currentUserId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리뷰어가 비활성화되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadReviewers();
      }
    } catch (e) {
      debugPrint('❌ 리뷰어 비활성화 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비활성화 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _activateReviewer(Map<String, dynamic> reviewer) async {
    try {
      final supabase = Supabase.instance.client;
      // Custom JWT 세션 지원을 위해 p_current_user_id 파라미터 전달
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      await supabase.rpc(
        'activate_reviewer_role',
        params: {
          'p_company_id': reviewer['company_id'],
          'p_user_id': reviewer['user_id'],
          'p_current_user_id': currentUserId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리뷰어가 활성화되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviewers();
      }
    } catch (e) {
      debugPrint('❌ 리뷰어 활성화 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('활성화 실패: $e'),
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
        title: const Text('리뷰어 관리'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/advertiser'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('승인 대기'),
                  if (_pendingReviewers.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingReviewers.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('활성 리뷰어'),
                  if (_activeReviewers.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activeReviewers.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('비활성 리뷰어'),
                  if (_inactiveReviewers.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_inactiveReviewers.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingReviewersList(),
                _buildActiveReviewersList(),
                _buildInactiveReviewersList(),
              ],
            ),
    );
  }

  Widget _buildPendingReviewersList() {
    if (_pendingReviewers.isEmpty) {
      return _buildEmptyState('승인 대기 중인 리뷰어가 없습니다.');
    }

    return RefreshIndicator(
      onRefresh: _loadReviewers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingReviewers.length,
        itemBuilder: (context, index) {
          final reviewer = _pendingReviewers[index];
          return _buildPendingReviewerCard(reviewer);
        },
      ),
    );
  }

  Widget _buildActiveReviewersList() {
    if (_activeReviewers.isEmpty) {
      return _buildEmptyState('활성 리뷰어가 없습니다.');
    }

    return RefreshIndicator(
      onRefresh: _loadReviewers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeReviewers.length,
        itemBuilder: (context, index) {
          final reviewer = _activeReviewers[index];
          return _buildActiveReviewerCard(reviewer);
        },
      ),
    );
  }

  Widget _buildInactiveReviewersList() {
    if (_inactiveReviewers.isEmpty) {
      return _buildEmptyState('비활성 리뷰어가 없습니다.');
    }

    return RefreshIndicator(
      onRefresh: _loadReviewers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _inactiveReviewers.length,
        itemBuilder: (context, index) {
          final reviewer = _inactiveReviewers[index];
          return _buildInactiveReviewerCard(reviewer);
        },
      ),
    );
  }

  Widget _buildPendingReviewerCard(Map<String, dynamic> reviewer) {
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
                backgroundColor: Colors.orange[100],
                child: Text(
                  (reviewer['email'] ?? reviewer['display_name'] ?? 'R')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewer['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((reviewer['display_name'] ?? '') != '') ...[
                      const SizedBox(height: 4),
                      Text(
                        reviewer['display_name'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (reviewer['created_at'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '요청일: ${_formatDate(reviewer['created_at'])}',
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
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '대기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectReviewer(reviewer),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('거절'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[600],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveReviewer(reviewer),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('승인'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveReviewerCard(Map<String, dynamic> reviewer) {
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
              (reviewer['email'] ?? reviewer['display_name'] ?? 'R')
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
                  reviewer['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((reviewer['display_name'] ?? '') != '') ...[
                  const SizedBox(height: 4),
                  Text(
                    reviewer['display_name'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (reviewer['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '등록일: ${_formatDate(reviewer['created_at'])}',
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
            onPressed: () => _showActiveReviewerMenu(reviewer),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveReviewerCard(Map<String, dynamic> reviewer) {
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
            backgroundColor: Colors.grey[300],
            child: Text(
              (reviewer['email'] ?? reviewer['display_name'] ?? 'R')
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
                  reviewer['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((reviewer['display_name'] ?? '') != '') ...[
                  const SizedBox(height: 4),
                  Text(
                    reviewer['display_name'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (reviewer['created_at'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '등록일: ${_formatDate(reviewer['created_at'])}',
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
              color: Colors.grey[200],
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
            onPressed: () => _showInactiveReviewerMenu(reviewer),
          ),
        ],
      ),
    );
  }

  void _showActiveReviewerMenu(Map<String, dynamic> reviewer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orange),
              title: const Text('비활성화'),
              onTap: () {
                Navigator.pop(context);
                _deactivateReviewer(reviewer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInactiveReviewerMenu(Map<String, dynamic> reviewer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('활성화'),
              onTap: () {
                Navigator.pop(context);
                _activateReviewer(reviewer);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
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

      // 한국 시간으로 변환
      final kstDate = date.toLocal();
      return '${kstDate.year}.${kstDate.month.toString().padLeft(2, '0')}.${kstDate.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

