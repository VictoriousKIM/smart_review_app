import 'package:flutter/material.dart';
import '../../../../utils/date_time_utils.dart';

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
    final createdAt = transaction['created_at'] as String?;
    final companyName = transaction['company_name'] as String?;
    final companyBusinessNumber = transaction['company_business_number'] as String?;
    final amount = (transaction['point_amount'] ?? transaction['amount'] ?? 0) as int;
    final userName = transaction['user_name'] as String? ?? '';

    final isPending = status == 'pending';
    final isDeposit = transactionType == 'deposit';
    final isAdvertiser = userType == 'advertiser';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 배지들
              Row(
                children: [
                  _buildCompactBadge(
                    icon: isAdvertiser ? Icons.business : Icons.person,
                    label: isAdvertiser ? '사업자' : '리뷰어',
                    color: isAdvertiser ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  _buildCompactBadge(
                    icon: isDeposit ? Icons.add_circle : Icons.remove_circle,
                    label: isDeposit ? '입금' : '출금',
                    color: isDeposit ? Colors.green : Colors.red,
                  ),
                  const Spacer(),
                  // 상태 배지 (더 크게)
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
              // 제목/날짜와 버튼을 행으로 배치
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 왼쪽 열: 제목과 날짜
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목: 회사명(사업자번호) 또는 사용자명
                        Text(
                          _buildTitleText(
                            isAdvertiser: isAdvertiser,
                            companyName: companyName,
                            companyBusinessNumber: companyBusinessNumber,
                            userName: userName,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                          const SizedBox(height: 4),
                        // 포인트 (줄바꿈)
                              Text(
                          _buildAmountText(amount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // 날짜
                        if (createdAt != null)
                            Text(
                            DateTimeUtils.formatKST(DateTimeUtils.parseKST(createdAt)),
                              style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                  const SizedBox(width: 16),
                  // 오른쪽 열: 액션 버튼 (아래쪽 정렬)
              if (isPending) ...[
                    OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('거절'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137fec),
                          foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('승인'),
                    ),
                  ] else if (onDetail != null)
                    OutlinedButton(
                      onPressed: onDetail,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('상세보기'),
                    ),
                  ],
                ),
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
        return Colors.green;
      case 'rejected':
        return Colors.red;
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
      case 'cancelled':
        return '취소됨';
      default:
        return status;
    }
  }

  // 제목 텍스트 생성
  String _buildTitleText({
    required bool isAdvertiser,
    String? companyName,
    String? companyBusinessNumber,
    String? userName,
  }) {
    if (isAdvertiser && companyName != null) {
      // 사업자: 회사명(사업자번호)
      final businessNumber = companyBusinessNumber ?? '';
      if (businessNumber.isNotEmpty) {
        return '$companyName($businessNumber)';
      } else {
        return companyName;
      }
    } else {
      // 리뷰어: 사용자명
      final displayName = (userName != null && userName.isNotEmpty) ? userName : '리뷰어';
      return displayName;
    }
  }

  // 포인트 텍스트 생성
  String _buildAmountText(int amount) {
    final formattedAmount = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${formattedAmount}P';
  }

  // 컴팩트한 배지 위젯
  Widget _buildCompactBadge({
    IconData? icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

}


