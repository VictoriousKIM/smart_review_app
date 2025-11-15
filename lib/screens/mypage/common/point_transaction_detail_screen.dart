import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PointTransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final Map<String, dynamic>? transactionData;

  const PointTransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.transactionData,
  });

  @override
  State<PointTransactionDetailScreen> createState() =>
      _PointTransactionDetailScreenState();
}

class _PointTransactionDetailScreenState
    extends State<PointTransactionDetailScreen> {
  Map<String, dynamic>? _transaction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactionDetail();
  }

  Future<void> _loadTransactionDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // transactionData가 있으면 사용, 없으면 ID로 조회
      if (widget.transactionData != null) {
        _transaction = widget.transactionData;
      } else {
        // TODO: ID로 거래 상세 정보 조회하는 API 호출
        // 현재는 transactionData를 사용
        _transaction = widget.transactionData;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('거래 정보를 불러올 수 없습니다: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('거래 상세'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
          ? const Center(child: Text('거래 정보를 찾을 수 없습니다.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildTransactionInfoCard(),
                  const SizedBox(height: 16),
                  _buildAmountCard(),
                  if (_transaction!['transaction_category'] == 'cash') ...[
                    const SizedBox(height: 16),
                    _buildCashInfoCard(),
                  ],
                  if (_transaction!['transaction_category'] == 'cash' &&
                      _transaction!['status'] == 'pending') ...[
                    const SizedBox(height: 16),
                    _buildPendingInfoCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final status = _transaction!['status'] as String? ?? 'completed';
    final transactionCategory =
        _transaction!['transaction_category'] as String? ?? 'campaign';
    final transactionType = _transaction!['transaction_type'] as String? ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (transactionCategory == 'cash') {
      switch (status) {
        case 'pending':
          statusColor = Colors.orange;
          statusText = '대기중';
          statusIcon = Icons.pending;
          break;
        case 'approved':
          statusColor = Colors.blue;
          statusText = '승인됨';
          statusIcon = Icons.check_circle;
          break;
        case 'rejected':
          statusColor = Colors.red;
          statusText = '거절됨';
          statusIcon = Icons.cancel;
          break;
        case 'completed':
          statusColor = Colors.green;
          statusText = '완료됨';
          statusIcon = Icons.check_circle;
          break;
        default:
          statusColor = Colors.grey;
          statusText = status;
          statusIcon = Icons.info;
      }
    } else {
      statusColor = Colors.green;
      statusText = '완료됨';
      statusIcon = Icons.check_circle;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transactionCategory == 'cash'
                      ? (transactionType == 'deposit' ? '포인트 충전' : '포인트 출금')
                      : '포인트 거래',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionInfoCard() {
    final createdAt = _transaction!['created_at'] as String?;
    final description = _transaction!['description'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            '거래 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('거래 ID', widget.transactionId),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('설명', description),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow('거래 일시', _formatDateTime(DateTime.parse(createdAt))),
          ],
          if (_transaction!['completed_at'] != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              '완료 일시',
              _formatDateTime(
                DateTime.parse(_transaction!['completed_at'] as String),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final transactionType = _transaction!['transaction_type'] as String? ?? '';
    final transactionCategory =
        _transaction!['transaction_category'] as String? ?? 'campaign';
    // 출금(withdraw) 거래의 경우 amount를 음수로 표시
    final rawAmount = _transaction!['amount'] as int? ?? 0;
    final amount =
        (transactionCategory == 'cash' && transactionType == 'withdraw')
        ? -rawAmount
        : rawAmount;
    final isPositive = amount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            '거래 금액',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                transactionType == 'deposit' || transactionType == 'earn'
                    ? '충전/적립 포인트'
                    : '출금/사용 포인트',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                '${isPositive ? '+' : ''}${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (_transaction!['cash_amount'] != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '실제 현금 금액',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  '${(_transaction!['cash_amount'] as num).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCashInfoCard() {
    final bankName = _transaction!['bank_name'] as String?;
    final accountNumber = _transaction!['account_number'] as String?;
    final accountHolder = _transaction!['account_holder'] as String?;
    final paymentMethod = _transaction!['payment_method'] as String?;

    if (bankName == null &&
        accountNumber == null &&
        accountHolder == null &&
        paymentMethod == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            '결제/계좌 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          if (paymentMethod != null) ...[
            _buildInfoRow('결제 방법', paymentMethod),
            const SizedBox(height: 12),
          ],
          if (bankName != null) ...[
            _buildInfoRow('은행명', bankName),
            const SizedBox(height: 12),
          ],
          if (accountNumber != null) ...[
            _buildInfoRow('계좌번호', accountNumber),
            const SizedBox(height: 12),
          ],
          if (accountHolder != null) ...[_buildInfoRow('예금주', accountHolder)],
        ],
      ),
    );
  }

  Widget _buildPendingInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '승인 대기중',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '관리자의 승인을 기다리고 있습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
