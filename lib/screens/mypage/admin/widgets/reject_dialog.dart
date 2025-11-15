import 'package:flutter/material.dart';

class RejectDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const RejectDialog({
    super.key,
    required this.transaction,
  });

  @override
  State<RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<RejectDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionType = widget.transaction['transaction_type'] as String? ?? '';
    final amount = widget.transaction['amount'] as int? ?? 0;
    final cashAmount = widget.transaction['cash_amount'] as num?;
    final userName = widget.transaction['user_name'] as String? ?? '알 수 없음';
    final isDeposit = transactionType == 'deposit';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.close, color: Colors.red),
          SizedBox(width: 8),
          Text('거래 거절'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이 거래를 거절하시겠습니까?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '사용자: $userName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isDeposit ? '입금 포인트' : '출금 포인트',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDeposit ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  if (cashAmount != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '현금 금액',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${cashAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '거절 사유 *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '거절 사유를 입력해주세요',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(null),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _reasonController.text.trim().isEmpty
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final reason = _reasonController.text.trim();
                  Navigator.of(context).pop(reason);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('거절'),
        ),
      ],
    );
  }
}

