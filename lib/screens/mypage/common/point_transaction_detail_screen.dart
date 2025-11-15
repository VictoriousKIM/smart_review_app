import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/date_time_utils.dart';
import '../../../services/wallet_service.dart';

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
  bool _isCancelling = false;

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
        title: const Text('포인트 상세'),
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
                  if ((_transaction!['transaction_category'] == 'cash' ||
                          _transaction!['transaction_type'] == 'deposit' ||
                          _transaction!['transaction_type'] == 'withdraw') &&
                      _transaction!['status'] == 'pending') ...[
                    const SizedBox(height: 16),
                    _buildCancelButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final status = _transaction!['status'] as String?;
    final transactionCategory =
        _transaction!['transaction_category'] as String?;
    final transactionType = _transaction!['transaction_type'] as String? ?? '';

    // transaction_category가 없으면 transaction_type으로 판단
    // 'deposit' 또는 'withdraw'는 cash 거래
    final isCashTransaction =
        transactionCategory == 'cash' ||
        transactionType == 'deposit' ||
        transactionType == 'withdraw';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isCashTransaction) {
      // cash 거래는 status를 확인
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
        default:
          // status가 null이거나 알 수 없는 경우 기본값으로 '대기중' 표시
          statusColor = Colors.orange;
          statusText = '대기중';
          statusIcon = Icons.pending;
      }
    } else {
      // campaign 거래는 항상 완료로 표시
      statusColor = Colors.green;
      statusText = '완료됨';
      statusIcon = Icons.check_circle;
    }

    // 신청 정보 필드 준비
    final description = _transaction!['description'] as String? ?? '';
    final createdAt = _transaction!['created_at'] as String?;
    final updatedAt = _transaction!['updated_at'] as String?;
    final rawAmount = (_transaction!['point_amount'] ?? _transaction!['amount'] ?? 0) as int;
    final amount = rawAmount.abs(); // 항상 양수로 표시
    final cashAmount = _transaction!['cash_amount'] as num?;
    final rejectionReason = _transaction!['rejection_reason'] as String?;

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
          // 상태 정보
          Row(
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
          // Divider
          const Divider(height: 32),
          // 신청 정보 섹션
          const Text(
            '신청 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          // 설명
          if (description.isNotEmpty) ...[
            _buildInfoRow('설명', description),
            const SizedBox(height: 12),
          ],
          // 신청일시
          if (createdAt != null) ...[
            _buildInfoRow(
              '신청일시',
              DateTimeUtils.formatKST(DateTimeUtils.parseKST(createdAt)),
            ),
            const SizedBox(height: 12),
          ],
          // 처리일시 (status가 'pending'이 아닐 때만)
          if (status != null && status != 'pending' && updatedAt != null) ...[
            _buildInfoRow(
              '처리일시',
              DateTimeUtils.formatKST(DateTimeUtils.parseKST(updatedAt)),
            ),
            const SizedBox(height: 12),
          ],
          // 신청포인트
          _buildInfoRow(
            '신청포인트',
            '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
          ),
          // 입금금액/출금금액 (cash_amount가 있을 때만)
          if (cashAmount != null && cashAmount > 0) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              transactionType == 'deposit' ? '입금금액' : '출금금액',
              '${cashAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
            ),
          ],
          // 거절 사유 (status가 'rejected'이고 rejection_reason이 있을 때만)
          if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('거절 사유', rejectionReason),
          ],
        ],
      ),
    );
  }


  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신청 취소'),
        content: const Text('정말로 이 신청을 취소하시겠습니까?\n취소된 신청은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('예, 취소합니다'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await WalletService.cancelCashTransaction(
        transactionId: widget.transactionId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청이 취소되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        // 이전 화면으로 돌아가기
        context.pop(true); // true를 반환하여 화면 새로고침을 알림
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('취소 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isCancelling ? null : _handleCancel,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.red[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isCancelling
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Text(
                    '신청 취소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
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
}
