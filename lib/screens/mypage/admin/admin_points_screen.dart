import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/drawer/admin_drawer.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart' as app_user;
import '../../../services/wallet_service.dart';
import 'widgets/pending_transaction_card.dart';
import 'widgets/approve_dialog.dart';
import 'widgets/reject_dialog.dart';
import '../common/point_transaction_detail_screen.dart';

class AdminPointsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const AdminPointsScreen({super.key, this.initialTab});

  @override
  ConsumerState<AdminPointsScreen> createState() => _AdminPointsScreenState();
}

class _AdminPointsScreenState extends ConsumerState<AdminPointsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  late TabController _tabController;

  // 필터 상태
  String? _selectedStatus; // null = 전체, 'pending', 'approved', 'rejected'
  String? _selectedTransactionType; // null = 전체, 'deposit', 'withdraw'
  String? _selectedUserType; // null = 전체, 'advertiser', 'reviewer'

  @override
  void initState() {
    super.initState();

    // 초기 탭 설정
    int initialIndex = 0;
    if (widget.initialTab != null) {
      switch (widget.initialTab) {
        case 'pending':
          initialIndex = 1; // 대기중
          break;
        case 'approved':
          initialIndex = 2; // 승인됨
          break;
        case 'rejected':
          initialIndex = 3; // 거절됨
          break;
        default:
          initialIndex = 0; // 전체
      }
    }

    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });

    // 초기 탭에 맞는 상태 설정
    _onTabChanged(initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      switch (index) {
        case 0: // 전체
          _selectedStatus = null;
          break;
        case 1: // 대기중
          _selectedStatus = 'pending';
          break;
        case 2: // 승인됨
          _selectedStatus = 'approved';
          break;
        case 3: // 거절됨
          _selectedStatus = 'rejected';
          break;
      }
    });
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await WalletService.getPendingCashTransactions(
        status: _selectedStatus,
        transactionType: _selectedTransactionType,
        userType: _selectedUserType,
        limit: 100,
      );

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('거래 목록을 불러오는데 실패했습니다: $e')));
      }
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ApproveDialog(transaction: transaction),
    );

    if (confirmed != true) return;

    try {
      await WalletService.updatePointCashTransactionStatus(
        transactionId: transaction['id'] as String,
        status: 'approved',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래가 승인되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTransactions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> transaction) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => RejectDialog(transaction: transaction),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await WalletService.updatePointCashTransactionStatus(
        transactionId: transaction['id'] as String,
        status: 'rejected',
        rejectionReason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래가 거절되었습니다'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadTransactions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거절 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PointTransactionDetailScreen(
          transactionId: transaction['id'] as String,
          transactionData: transaction,
        ),
      ),
    ).then((result) {
      // 취소 또는 변경 시 거래 목록 다시 로드
      if (result == true) {
        _loadTransactions();
      }
    });
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 거래 타입 필터
          Row(
            children: [
              const Text(
                '거래 타입:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: '전체',
                      isSelected: _selectedTransactionType == null,
                      onTap: () {
                        setState(() {
                          _selectedTransactionType = null;
                        });
                        _loadTransactions();
                      },
                    ),
                    _buildFilterChip(
                      label: '입금',
                      isSelected: _selectedTransactionType == 'deposit',
                      onTap: () {
                        setState(() {
                          _selectedTransactionType = 'deposit';
                        });
                        _loadTransactions();
                      },
                    ),
                    _buildFilterChip(
                      label: '출금',
                      isSelected: _selectedTransactionType == 'withdraw',
                      onTap: () {
                        setState(() {
                          _selectedTransactionType = 'withdraw';
                        });
                        _loadTransactions();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 유저 타입 필터
          Row(
            children: [
              const Text(
                '유저 타입:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: '전체',
                      isSelected: _selectedUserType == null,
                      onTap: () {
                        setState(() {
                          _selectedUserType = null;
                        });
                        _loadTransactions();
                      },
                    ),
                    _buildFilterChip(
                      label: '사업자',
                      isSelected: _selectedUserType == 'advertiser',
                      onTap: () {
                        setState(() {
                          _selectedUserType = 'advertiser';
                        });
                        _loadTransactions();
                      },
                    ),
                    _buildFilterChip(
                      label: '리뷰어',
                      isSelected: _selectedUserType == 'reviewer',
                      onTap: () {
                        setState(() {
                          _selectedUserType = 'reviewer';
                        });
                        _loadTransactions();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF137fec) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF137fec) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: '새로고침',
          ),
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
          // 필터 섹션 (고정)
          _buildFilterSection(),

          // TabBar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '전체'),
              Tab(text: '대기중'),
              Tab(text: '승인됨'),
              Tab(text: '거절됨'),
            ],
          ),

          // 카드 리스트
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            '거래 내역이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        return PendingTransactionCard(
                          transaction: transaction,
                          onApprove: () => _handleApprove(transaction),
                          onReject: () => _handleReject(transaction),
                          onDetail: () => _showDetail(transaction),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
