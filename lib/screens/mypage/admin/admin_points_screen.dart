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
  const AdminPointsScreen({super.key});

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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
    _loadTransactions();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('거래 목록을 불러오는데 실패했습니다: $e')),
        );
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
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedTransactionType: _selectedTransactionType,
        selectedUserType: _selectedUserType,
        onApply: (transactionType, userType) {
          setState(() {
            _selectedTransactionType = transactionType;
            _selectedUserType = userType;
          });
          _loadTransactions();
        },
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
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '필터',
          ),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '대기중'),
            Tab(text: '승인됨'),
            Tab(text: '거절됨'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey[400],
                        ),
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
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final String? selectedTransactionType;
  final String? selectedUserType;
  final Function(String?, String?) onApply;

  const _FilterDialog({
    required this.selectedTransactionType,
    required this.selectedUserType,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late String? _transactionType;
  late String? _userType;

  @override
  void initState() {
    super.initState();
    _transactionType = widget.selectedTransactionType;
    _userType = widget.selectedUserType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('필터'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거래 타입',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('전체')),
              ButtonSegment(value: 'deposit', label: Text('입금')),
              ButtonSegment(value: 'withdraw', label: Text('출금')),
            ],
            selected: {_transactionType},
            onSelectionChanged: (Set<String?> newSelection) {
              setState(() {
                _transactionType = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          const Text(
            '사용자 타입',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('전체')),
              ButtonSegment(value: 'advertiser', label: Text('사업자')),
              ButtonSegment(value: 'reviewer', label: Text('리뷰어')),
            ],
            selected: {_userType},
            onSelectionChanged: (Set<String?> newSelection) {
              setState(() {
                _userType = newSelection.first;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _transactionType = null;
              _userType = null;
            });
          },
          child: const Text('초기화'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_transactionType, _userType);
            Navigator.of(context).pop();
          },
          child: const Text('적용'),
        ),
      ],
    );
  }
}
