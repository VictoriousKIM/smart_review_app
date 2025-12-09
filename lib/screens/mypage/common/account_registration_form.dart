import 'package:flutter/material.dart';
import '../../../models/wallet_models.dart';
import '../../../services/wallet_service.dart';
import '../../../utils/error_message_utils.dart';

/// 계좌등록폼 위젯
/// 리뷰어용과 사업자용 모두 지원
class AccountRegistrationForm extends StatefulWidget {
  final UserWallet? userWallet;
  final CompanyWallet? companyWallet;
  final VoidCallback? onSaved;
  final bool isBusinessTab; // 사업자 탭인지 구분

  const AccountRegistrationForm({
    super.key,
    this.userWallet,
    this.companyWallet,
    this.onSaved,
    this.isBusinessTab = false,
  });

  @override
  State<AccountRegistrationForm> createState() =>
      _AccountRegistrationFormState();
}

class _AccountRegistrationFormState extends State<AccountRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  /// 회사 지갑인지 확인
  /// 사업자 탭에서는 companyWallet이 null이면 false 반환 (개인 지갑으로 처리하지 않음)
  bool get _isCompanyWallet {
    if (widget.isBusinessTab) {
      // 사업자 탭에서는 companyWallet이 null이면 개인 지갑으로 처리하지 않음
      return widget.companyWallet != null;
    }
    // 리뷰어 탭에서는 companyWallet이 있으면 회사 지갑, 없으면 개인 지갑
    return widget.companyWallet != null;
  }

  /// 편집 권한 확인
  /// - 회사 지갑인 경우: company_role이 'owner'인 경우만 편집 가능
  /// - 개인 지갑인 경우: 항상 편집 가능
  bool get _canEdit {
    if (!_isCompanyWallet) {
      return true; // 개인 지갑은 항상 편집 가능
    }
    // 회사 지갑인 경우 company_role이 'owner'인 경우만 편집 가능
    final userRole = widget.companyWallet?.userRole;
    return userRole == 'owner';
  }

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  @override
  void didUpdateWidget(AccountRegistrationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userWalletChanged =
        oldWidget.userWallet?.id != widget.userWallet?.id ||
        oldWidget.userWallet?.withdrawBankName !=
            widget.userWallet?.withdrawBankName ||
        oldWidget.userWallet?.withdrawAccountNumber !=
            widget.userWallet?.withdrawAccountNumber ||
        oldWidget.userWallet?.withdrawAccountHolder !=
            widget.userWallet?.withdrawAccountHolder;
    final companyWalletChanged =
        oldWidget.companyWallet?.id != widget.companyWallet?.id ||
        oldWidget.companyWallet?.withdrawBankName !=
            widget.companyWallet?.withdrawBankName ||
        oldWidget.companyWallet?.withdrawAccountNumber !=
            widget.companyWallet?.withdrawAccountNumber ||
        oldWidget.companyWallet?.withdrawAccountHolder !=
            widget.companyWallet?.withdrawAccountHolder;

    if (userWalletChanged || companyWalletChanged) {
      if (!_isEditing) {
        debugPrint('🔄 지갑 데이터 변경 감지, 계좌정보 다시 로드');
        _loadAccountData();
      }
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  void _loadAccountData() {
    // 사업자 탭에서 companyWallet이 null이면 로드하지 않음
    if (widget.isBusinessTab && widget.companyWallet == null) {
      return;
    }

    if (_isCompanyWallet) {
      final bankName = widget.companyWallet?.withdrawBankName ?? '';
      final accountNumber = widget.companyWallet?.withdrawAccountNumber ?? '';
      final accountHolder = widget.companyWallet?.withdrawAccountHolder ?? '';
      debugPrint(
        '📝 회사 지갑 계좌정보 로드: 은행=$bankName, 계좌=$accountNumber, 예금주=$accountHolder',
      );
      setState(() {
        _bankNameController.text = bankName;
        _accountNumberController.text = accountNumber;
        _accountHolderController.text = accountHolder;
      });
    } else {
      // 리뷰어 탭에서만 개인 지갑 로드
      if (!widget.isBusinessTab) {
        final bankName = widget.userWallet?.withdrawBankName ?? '';
        final accountNumber = widget.userWallet?.withdrawAccountNumber ?? '';
        final accountHolder = widget.userWallet?.withdrawAccountHolder ?? '';
        debugPrint(
          '📝 개인 지갑 계좌정보 로드: 은행=$bankName, 계좌=$accountNumber, 예금주=$accountHolder',
        );
        setState(() {
          _bankNameController.text = bankName;
          _accountNumberController.text = accountNumber;
          _accountHolderController.text = accountHolder;
        });
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _loadAccountData();
    });
  }

  Future<void> _saveAccountInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isCompanyWallet) {
        if (widget.companyWallet == null ||
            widget.companyWallet!.companyId.isEmpty) {
          throw Exception('회사 정보를 찾을 수 없습니다');
        }

        await WalletService.updateCompanyWalletAccount(
          companyId: widget.companyWallet!.companyId,
          bankName: _bankNameController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          accountHolder: _accountHolderController.text.trim(),
        );
      } else {
        await WalletService.updateUserWalletAccount(
          bankName: _bankNameController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          accountHolder: _accountHolderController.text.trim(),
        );
      }

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('계좌정보가 저장되었습니다'),
          duration: Duration(seconds: 2),
        ));
      }

      // 콜백 호출
      widget.onSaved?.call();
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageUtils.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF137fec), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 사업자 탭에서 companyWallet이 null이면 아무것도 표시하지 않음
    if (widget.isBusinessTab && widget.companyWallet == null) {
      return const SizedBox.shrink();
    }

    // 개인 지갑도 없으면 아무것도 표시하지 않음
    if (!widget.isBusinessTab &&
        widget.userWallet == null &&
        widget.companyWallet == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '계좌정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                if (!_isEditing && _canEdit)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('편집'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  )
                else if (_isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _cancelEdit,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _isSaving ? null : _saveAccountInfo,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('저장'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: '은행명',
              controller: _bankNameController,
              enabled: _isEditing && _canEdit,
              validator: _isEditing
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '은행명을 입력해주세요';
                      }
                      return null;
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: '계좌번호',
              controller: _accountNumberController,
              enabled: _isEditing && _canEdit,
              keyboardType: TextInputType.number,
              validator: _isEditing
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '계좌번호를 입력해주세요';
                      }
                      return null;
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: '예금주',
              controller: _accountHolderController,
              enabled: _isEditing && _canEdit,
              validator: _isEditing
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '예금주를 입력해주세요';
                      }
                      return null;
                    }
                  : null,
            ),
            if (_isCompanyWallet && !_canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '계좌정보는 회사 소유자만 수정할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
