import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/company_user_service.dart';
import '../../../utils/user_type_helper.dart';
import '../../../utils/error_message_utils.dart';
import '../../../models/wallet_models.dart';

class PointRefundScreen extends StatefulWidget {
  final String userType;

  const PointRefundScreen({super.key, required this.userType});

  @override
  State<PointRefundScreen> createState() => _PointRefundScreenState();
}

class _PointRefundScreenState extends State<PointRefundScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = true;
  int _currentPoints = 0;
  String? _walletId;
  CompanyWallet? _companyWallet;
  UserWallet? _userWallet;
  bool _isCompanyWallet = false;
  static const int _minRefundAmount = 10000;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.currentUser;
      if (user == null) return;

      if (widget.userType == 'reviewer') {
        // 리뷰어: 무조건 개인 지갑 조회
        final wallet = await WalletService.getUserWallet();
        _currentPoints = wallet?.currentPoints ?? 0;
        _walletId = wallet?.id;
        _userWallet = wallet;
        _isCompanyWallet = false;
      } else if (widget.userType == 'advertiser') {
        // 광고주: owner 여부 확인
        final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);
        if (isOwner) {
          // owner: 회사 지갑 조회
          final companyId = await CompanyUserService.getUserCompanyId(user.uid);
          if (companyId != null) {
            final companyWallet =
                await WalletService.getCompanyWalletByCompanyId(companyId);
            _currentPoints = companyWallet?.currentPoints ?? 0;
            _walletId = companyWallet?.id;
            _companyWallet = companyWallet;
            _isCompanyWallet = true;
          }
        } else {
          // manager: 개인 지갑 조회
          final wallet = await WalletService.getUserWallet();
          _currentPoints = wallet?.currentPoints ?? 0;
          _walletId = wallet?.id;
          _userWallet = wallet;
          _isCompanyWallet = false;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _submitRefund() async {
    final amount = int.tryParse(_amountController.text.replaceAll(',', ''));

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액을 입력해주세요.')),
      );
      return;
    }

    if (amount < _minRefundAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('최소 출금 가능 포인트는 $_minRefundAmount P입니다.'),
        ),
      );
      return;
    }

    if (amount > _currentPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보유 포인트보다 많은 금액을 출금할 수 없습니다.')),
      );
      return;
    }

    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지갑 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    try {
      // 계좌 정보 가져오기
      String? bankName, accountNumber, accountHolder;

      if (_isCompanyWallet && _companyWallet != null) {
        bankName = _companyWallet!.withdrawBankName;
        accountNumber = _companyWallet!.withdrawAccountNumber;
        accountHolder = _companyWallet!.withdrawAccountHolder;
      } else if (_userWallet != null) {
        bankName = _userWallet!.withdrawBankName;
        accountNumber = _userWallet!.withdrawAccountNumber;
        accountHolder = _userWallet!.withdrawAccountHolder;
      }

      // RPC 함수 호출하여 현금 거래 생성
      await WalletService.createPointCashTransaction(
        walletId: _walletId!,
        transactionType: 'withdraw',
        pointAmount: amount,
        cashAmount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountHolder: accountHolder,
        description: '포인트 출금 요청',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출금 신청이 완료되었습니다.')),
        );
        context.pop(true); // 성공 시 true 반환
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('포인트 출금'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 보유 포인트
                  _buildCurrentPointsCard(),
                  const SizedBox(height: 24),

                  // 계좌 정보
                  _buildAccountInfoSection(),
                  const SizedBox(height: 24),

                  // 출금 금액
                  _buildRefundAmountSection(),
                  const SizedBox(height: 24),

                  // 안내 사항
                  _buildNoticeSection(),
                  const SizedBox(height: 24),

                  // 출금 신청 버튼
                  _buildRefundButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '보유포인트',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${_currentPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} P',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection() {
    String? accountHolder, bankName, accountNumber;

    if (_isCompanyWallet && _companyWallet != null) {
      accountHolder = _companyWallet!.withdrawAccountHolder;
      bankName = _companyWallet!.withdrawBankName;
      accountNumber = _companyWallet!.withdrawAccountNumber;
    } else if (_userWallet != null) {
      accountHolder = _userWallet!.withdrawAccountHolder;
      bankName = _userWallet!.withdrawBankName;
      accountNumber = _userWallet!.withdrawAccountNumber;
    }

    // 계좌 정보가 없으면 안내 메시지 표시
    if (accountHolder == null || bankName == null || accountNumber == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '계좌정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '출금 계좌 정보가 등록되어 있지 않습니다. 계좌 정보를 등록한 후 출금 신청이 가능합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              '계좌정보',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              '*',
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildReadOnlyField('예금주', accountHolder),
              const SizedBox(height: 12),
              _buildReadOnlyField('은행명', bankName),
              const SizedBox(height: 12),
              _buildReadOnlyField('계좌번호', accountNumber),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefundAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              '출금금액',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              '*',
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '최소 출금 가능 포인트 ${_minRefundAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() {}); // 버튼 활성화 상태 업데이트
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '현재 보유 포인트 : ${_currentPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '* 출금신청 전 꼭 확인해주세요 *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          _buildNoticeItem(
              '최소 출금 가능 포인트는 ${_minRefundAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P입니다.'),
          _buildNoticeItem(
              '입력하신 정보와 예금주 정보가 일치해야 정상 출금 처리가 가능합니다.'),
          _buildNoticeItem(
              '출금신청 후 실제 출금까지 최대 48시간 (영업일 기준)이 소요될 수 있습니다.'),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('- ', style: TextStyle(color: Color(0xFF666666))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAccountInfo() {
    String? accountHolder, bankName, accountNumber;

    if (_isCompanyWallet && _companyWallet != null) {
      accountHolder = _companyWallet!.withdrawAccountHolder;
      bankName = _companyWallet!.withdrawBankName;
      accountNumber = _companyWallet!.withdrawAccountNumber;
    } else if (_userWallet != null) {
      accountHolder = _userWallet!.withdrawAccountHolder;
      bankName = _userWallet!.withdrawBankName;
      accountNumber = _userWallet!.withdrawAccountNumber;
    }

    return accountHolder != null &&
        bankName != null &&
        accountNumber != null;
  }

  Widget _buildRefundButton() {
    final amount = int.tryParse(_amountController.text.replaceAll(',', ''));
    final hasAccount = _hasAccountInfo();
    final isEnabled = amount != null &&
        amount >= _minRefundAmount &&
        amount <= _currentPoints &&
        hasAccount;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? _submitRefund : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? const Color(0xFF2196F3) : Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '출금신청',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

