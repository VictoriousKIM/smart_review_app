import 'package:flutter/material.dart';

class PendingTransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDetail;

  const PendingTransactionCard({
    super.key,
    required this.transaction,
    this.onApprove,
    this.onReject,
    this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final status = transaction['status'] as String? ?? 'pending';
    final transactionType = transaction['transaction_type'] as String? ?? '';
    final userType = transaction['user_type'] as String? ?? 'reviewer';
    final amount = transaction['amount'] as int? ?? 0;
    final cashAmount = transaction['cash_amount'] as num?;
    final userName = transaction['user_name'] as String? ?? '알 수 없음';
    final userEmail = transaction['user_email'] as String? ?? '';
    final companyName = transaction['company_name'] as String?;
    final description = transaction['description'] as String? ?? '';
    final createdAt = transaction['created_at'] as String?;
    final bankName = transaction['bank_name'] as String?;
    final accountNumber = transaction['account_number'] as String?;
    final accountHolder = transaction['account_holder'] as String?;

    final isPending = status == 'pending';
    final isDeposit = transactionType == 'deposit';
    final isAdvertiser = userType == 'advertiser';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 배지들
              Row(
                children: [
                  // 사용자 타입 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isAdvertiser
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdvertiser ? Icons.business : Icons.person,
                          size: 14,
                          color: isAdvertiser ? Colors.blue[700] : Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAdvertiser ? '사업자' : '리뷰어',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAdvertiser ? Colors.blue[700] : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 거래 타입 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDeposit
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDeposit ? Icons.add_circle : Icons.remove_circle,
                          size: 14,
                          color: isDeposit ? Colors.green[700] : Colors.red[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDeposit ? '입금' : '출금',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDeposit ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 사용자 정보
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (companyName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.business, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                companyName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 금액 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '포인트',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    if (cashAmount != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '현금',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cashAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
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
              ),
              // 계좌 정보 (출금인 경우)
              if (!isDeposit && bankName != null && accountNumber != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$bankName $accountNumber',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[900],
                              ),
                            ),
                            if (accountHolder != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '예금주: $accountHolder',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 설명
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              // 생성 일시
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatDate(DateTime.parse(createdAt)),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
              // 액션 버튼 (대기중인 경우만)
              if (isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('거절'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('승인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // 상세보기 버튼
              if (!isPending) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onDetail,
                    child: const Text('상세보기'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'approved':
        return '승인됨';
      case 'rejected':
        return '거절됨';
      case 'completed':
        return '완료됨';
      case 'cancelled':
        return '취소됨';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

