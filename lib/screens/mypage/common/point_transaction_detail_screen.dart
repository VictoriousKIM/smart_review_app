import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/date_time_utils.dart';
import '../../../services/wallet_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/campaign_service.dart';
import '../admin/widgets/approve_dialog.dart';
import '../admin/widgets/reject_dialog.dart';
import 'package:flutter/services.dart';

class PointTransactionDetailScreen extends ConsumerStatefulWidget {
  final String transactionId;
  final Map<String, dynamic>? transactionData;
  final bool showAdminActions; // 관리자 액션(승인/거절) 표시 여부

  const PointTransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.transactionData,
    this.showAdminActions = false, // 기본값은 false
  });

  @override
  ConsumerState<PointTransactionDetailScreen> createState() =>
      _PointTransactionDetailScreenState();
}

class _PointTransactionDetailScreenState
    extends ConsumerState<PointTransactionDetailScreen> {
  Map<String, dynamic>? _transaction;
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _isApproving = false;
  bool _isRejecting = false;
  String? _createdByUserName;
  bool _isLoadingCreator = false;
  String? _campaignTitle;
  bool _isLoadingCampaign = false;

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

      // 신청자 정보 로드
      await _loadCreatorInfo();
      // 캠페인 정보 로드
      await _loadCampaignInfo();
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

  Future<void> _loadCreatorInfo() async {
    if (_transaction == null) return;

    // created_by_user_name이 이미 있으면 사용
    final existingName = _transaction!['created_by_user_name'] as String?;
    if (existingName != null && existingName.isNotEmpty) {
      setState(() {
        _createdByUserName = existingName;
      });
      return;
    }

    // created_by_user_id가 있으면 사용자 정보 조회
    final createdByUserId = _transaction!['created_by_user_id'] as String?;
    if (createdByUserId == null || createdByUserId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingCreator = true;
    });

    try {
      final authService = AuthService();
      final user = await authService.getUserProfile(createdByUserId);

      if (mounted && user != null) {
        setState(() {
          _createdByUserName = user.displayName ?? user.email;
          _isLoadingCreator = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingCreator = false;
        });
      }
    } catch (e) {
      debugPrint('신청자 정보 조회 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingCreator = false;
        });
      }
    }
  }

  Future<void> _loadCampaignInfo() async {
    if (_transaction == null) return;

    final campaignId = _transaction!['campaign_id'] as String?;
    if (campaignId == null || campaignId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingCampaign = true;
    });

    try {
      final campaignService = CampaignService();
      final response = await campaignService.getCampaignById(campaignId);

      if (mounted && response.success && response.data != null) {
        setState(() {
          _campaignTitle = response.data!.title;
          _isLoadingCampaign = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingCampaign = false;
        });
      }
    } catch (e) {
      debugPrint('캠페인 정보 조회 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingCampaign = false;
        });
      }
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
                    _buildActionButtons(),
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
    final rawAmount =
        (_transaction!['point_amount'] ?? _transaction!['amount'] ?? 0) as int;
    final amount = rawAmount.abs(); // 항상 양수로 표시
    final cashAmount = _transaction!['cash_amount'] as num?;
    final rejectionReason = _transaction!['rejection_reason'] as String?;
    final campaignId = _transaction!['campaign_id'] as String?;

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
          // 신청자 (created_by_user_id가 있을 때만)
          if (_transaction!['created_by_user_id'] != null) ...[
            _buildInfoRow(
              '신청자',
              _isLoadingCreator ? '로딩 중...' : (_createdByUserName ?? '알 수 없음'),
            ),
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
          if (status == 'rejected' &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('거절 사유', rejectionReason),
          ],
          // 캠페인 정보 (캠페인 거래인 경우)
          if (campaignId != null && campaignId.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('캠페인 ID', campaignId),
            if (_isLoadingCampaign) ...[
              const SizedBox(height: 12),
              _buildInfoRow('캠페인 제목', '로딩 중...'),
            ] else if (_campaignTitle != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('캠페인 제목', _campaignTitle!),
            ],
          ],
          // 결제 및 계좌 정보 섹션 (cash 거래인 경우)
          if (isCashTransaction) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildPaymentInfoSection(transactionType),
          ],
          // 영수증 정보 섹션
          if (isCashTransaction) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildReceiptInfoSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentInfoSection(String transactionType) {
    final paymentMethod = _transaction!['payment_method'] as String?;
    final bankName = _transaction!['bank_name'] as String?;
    final accountNumber = _transaction!['account_number'] as String?;
    final accountHolder = _transaction!['account_holder'] as String?;

    // 결제 정보나 계좌 정보가 없으면 섹션 표시 안 함
    if (paymentMethod == null &&
        bankName == null &&
        accountNumber == null &&
        accountHolder == null) {
      return const SizedBox.shrink();
    }

    // 결제 방법 한글 변환
    String paymentMethodText = '';
    if (paymentMethod != null) {
      switch (paymentMethod) {
        case 'bank_transfer':
          paymentMethodText = '계좌이체';
          break;
        case 'card':
          paymentMethodText = '카드';
          break;
        default:
          paymentMethodText = paymentMethod;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '결제 및 계좌 정보',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        // 결제 방법 (입금인 경우)
        if (transactionType == 'deposit' && paymentMethodText.isNotEmpty) ...[
          _buildInfoRow('결제 방법', paymentMethodText),
          const SizedBox(height: 12),
        ],
        // 계좌 정보 (출금인 경우)
        if (transactionType == 'withdraw') ...[
          if (bankName != null && bankName.isNotEmpty) ...[
            _buildInfoRow('은행명', bankName),
            const SizedBox(height: 12),
          ],
          if (accountNumber != null && accountNumber.isNotEmpty) ...[
            _buildInfoRow('계좌번호', accountNumber),
            const SizedBox(height: 12),
          ],
          if (accountHolder != null && accountHolder.isNotEmpty) ...[
            _buildInfoRow('예금주', accountHolder),
          ],
        ],
      ],
    );
  }

  Widget _buildReceiptInfoSection() {
    final receiptType = _transaction!['receipt_type'] as String?;

    // receipt_type이 null이면 영수증 정보 섹션 표시 안 함
    if (receiptType == null) {
      return const SizedBox.shrink();
    }

    // 발행 방법 텍스트 변환
    String receiptTypeText;
    switch (receiptType) {
      case 'cash_receipt':
        receiptTypeText = '현금영수증';
        break;
      case 'tax_invoice':
        receiptTypeText = '세금계산서';
        break;
      case 'none':
        receiptTypeText = '발행안함';
        break;
      default:
        receiptTypeText = receiptType;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '영수증 정보',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        // 발행 방법 표시
        _buildInfoRow('발행 방법', receiptTypeText),
        // 발행안함이 아닐 때만 상세 정보 표시
        if (receiptType != 'none') ...[
          const SizedBox(height: 12),
          if (receiptType == 'cash_receipt') ...[
            _buildCashReceiptInfo(),
          ] else if (receiptType == 'tax_invoice') ...[
            _buildTaxInvoiceInfo(),
          ],
        ],
      ],
    );
  }

  Widget _buildCashReceiptInfo() {
    final recipientType =
        _transaction!['cash_receipt_recipient_type'] as String?;

    if (recipientType == 'individual') {
      final name = _transaction!['cash_receipt_name'] as String? ?? '';
      final phone = _transaction!['cash_receipt_phone'] as String? ?? '';

      return Column(
        children: [
          _buildInfoRow('수령인 유형', '개인'),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('이름', name),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('휴대폰 번호', phone),
          ],
        ],
      );
    } else if (recipientType == 'business') {
      final businessName =
          _transaction!['cash_receipt_business_name'] as String? ?? '';
      final businessNumber =
          _transaction!['cash_receipt_business_number'] as String? ?? '';

      return Column(
        children: [
          _buildInfoRow('수령인 유형', '사업자'),
          if (businessName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('사업자명', businessName),
          ],
          if (businessNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('사업자 번호', businessNumber),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTaxInvoiceInfo() {
    final representative =
        _transaction!['tax_invoice_representative'] as String? ?? '';
    final companyName =
        _transaction!['tax_invoice_company_name'] as String? ?? '';
    final businessNumber =
        _transaction!['tax_invoice_business_number'] as String? ?? '';
    final email = _transaction!['tax_invoice_email'] as String? ?? '';
    final address = _transaction!['tax_invoice_address'] as String? ?? '';
    final detailAddress =
        _transaction!['tax_invoice_detail_address'] as String? ?? '';

    return Column(
      children: [
        if (representative.isNotEmpty) ...[
          _buildInfoRow('대표자명', representative),
        ],
        if (companyName.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow('회사명', companyName),
        ],
        if (businessNumber.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow('사업자번호', businessNumber),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow('이메일', email),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            '주소',
            address + (detailAddress.isNotEmpty ? ' $detailAddress' : ''),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    // showAdminActions가 true일 때만 관리자 액션 표시
    if (widget.showAdminActions) {
      // 관리자: 승인/거절 버튼
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isApproving ? null : _handleApprove,
              icon: const Icon(Icons.check_circle),
              label: _isApproving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('승인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isRejecting ? null : _handleReject,
              icon: const Icon(Icons.cancel),
              label: _isRejecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('거절'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // 일반 사용자: 신청 취소 버튼
      return _buildCancelButton();
    }
  }

  Future<void> _handleApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ApproveDialog(transaction: _transaction!),
    );

    if (confirmed != true) return;

    setState(() {
      _isApproving = true;
    });

    try {
      await WalletService.updatePointCashTransactionStatus(
        transactionId: widget.transactionId,
        status: 'approved',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래가 승인되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        // 거래 정보 다시 로드
        await _loadTransactionDetail();
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
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  Future<void> _handleReject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => RejectDialog(transaction: _transaction!),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() {
      _isRejecting = true;
    });

    try {
      await WalletService.updatePointCashTransactionStatus(
        transactionId: widget.transactionId,
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
        // 거래 정보 다시 로드
        await _loadTransactionDetail();
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
    } finally {
      if (mounted) {
        setState(() {
          _isRejecting = false;
        });
      }
    }
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
