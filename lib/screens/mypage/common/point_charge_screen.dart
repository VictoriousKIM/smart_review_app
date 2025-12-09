import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/company_user_service.dart';
import '../../../services/company_service.dart';
import '../../../utils/user_type_helper.dart';
import '../../../utils/error_message_utils.dart';
import '../../../utils/postcode_service.dart';

class PointChargeScreen extends StatefulWidget {
  final String userType;

  const PointChargeScreen({super.key, required this.userType});

  @override
  State<PointChargeScreen> createState() => _PointChargeScreenState();
}

class _PointChargeScreenState extends State<PointChargeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  int _currentPoints = 0;
  String _walletId = '';
  int? _selectedAmount;
  final TextEditingController _depositorNameController =
      TextEditingController();
  String? _receiptType; // 'cash_receipt', 'tax_invoice', 'none'
  
  // 현금영수증 관련 필드
  String? _cashReceiptRecipientType; // 'individual', 'business'
  final TextEditingController _cashReceiptNameController = TextEditingController();
  final TextEditingController _cashReceiptPhoneController = TextEditingController();
  final TextEditingController _cashReceiptBusinessNameController = TextEditingController();
  final TextEditingController _cashReceiptBusinessNumberController = TextEditingController();
  
  // 세금계산서 관련 필드
  final TextEditingController _taxInvoiceRepresentativeController = TextEditingController();
  final TextEditingController _taxInvoiceCompanyNameController = TextEditingController();
  final TextEditingController _taxInvoiceBusinessNumberController = TextEditingController();
  final TextEditingController _taxInvoiceEmailController = TextEditingController();
  final TextEditingController _taxInvoiceAddressController = TextEditingController();
  final TextEditingController _taxInvoiceDetailAddressController = TextEditingController();

  // 충전 금액 옵션 (포인트, 현금)
  final List<Map<String, int>> _chargeOptions = [
    {'points': 50000, 'cash': 55000},
    {'points': 100000, 'cash': 110000},
    {'points': 200000, 'cash': 220000},
    {'points': 300000, 'cash': 330000},
    {'points': 500000, 'cash': 550000},
  ];

  @override
  void initState() {
    super.initState();
    // 리뷰어는 충전 불가
    if (widget.userType == 'reviewer') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰어는 포인트 충전이 불가능합니다.'),
              backgroundColor: Colors.red,
            ),
          );
          context.pop();
        }
      });
      return;
    }
    _loadWalletInfo();
  }

  @override
  void dispose() {
    _depositorNameController.dispose();
    _cashReceiptNameController.dispose();
    _cashReceiptPhoneController.dispose();
    _cashReceiptBusinessNameController.dispose();
    _cashReceiptBusinessNumberController.dispose();
    _taxInvoiceRepresentativeController.dispose();
    _taxInvoiceCompanyNameController.dispose();
    _taxInvoiceBusinessNumberController.dispose();
    _taxInvoiceEmailController.dispose();
    _taxInvoiceAddressController.dispose();
    _taxInvoiceDetailAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyInfoForTaxInvoice() async {
    try {
      final user = await _authService.currentUser;
      if (user == null) return;

      final companyData = await CompanyService.getCompanyByUserId(user.uid);
      if (companyData != null) {
        setState(() {
          _taxInvoiceRepresentativeController.text = 
              companyData['representative_name']?.toString() ?? '';
          _taxInvoiceCompanyNameController.text = 
              companyData['business_name']?.toString() ?? '';
          _taxInvoiceBusinessNumberController.text = 
              companyData['business_number']?.toString() ?? '';
          _taxInvoiceEmailController.text = 
              companyData['contact_email']?.toString() ?? '';
          // 주소는 address 필드에서 가져오기
          final address = companyData['address']?.toString() ?? '';
          _taxInvoiceAddressController.text = address;
        });
      }
    } catch (e) {
      print('❌ 회사 정보 로드 실패: $e');
    }
  }

  Future<void> _loadWalletInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.currentUser;
      if (user == null) return;

      // 광고주만 처리 (리뷰어는 initState에서 차단됨)
      if (widget.userType == 'advertiser') {
        final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);
        if (isOwner) {
          // owner: 회사 지갑 조회
          final companyId = await CompanyUserService.getUserCompanyId(user.uid);
          if (companyId != null) {
            final companyWallet =
                await WalletService.getCompanyWalletByCompanyId(companyId);
            _currentPoints = companyWallet?.currentPoints ?? 0;
            _walletId = companyWallet?.id ?? '';
          }
        } else {
          // manager: 개인 지갑 조회
          final wallet = await WalletService.getUserWallet();
          _currentPoints = wallet?.currentPoints ?? 0;
          _walletId = wallet?.id ?? '';
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

  Future<void> _submitCharge() async {
    if (_selectedAmount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('충전 금액을 선택해주세요.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    if (_depositorNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('입금자명을 입력해주세요.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    if (_receiptType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('영수증 발행 방법을 선택해주세요.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    // 현금영수증 선택 시 검증
    if (_receiptType == 'cash_receipt') {
      if (_cashReceiptRecipientType == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('수령인 유형을 선택해주세요.'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
      if (_cashReceiptRecipientType == 'individual') {
        if (_cashReceiptNameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(
            content: Text('이름을 입력해주세요.'),
            duration: Duration(seconds: 2),
          ));
          return;
        }
        if (_cashReceiptPhoneController.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(
            content: Text('휴대폰 번호를 입력해주세요.'),
            duration: Duration(seconds: 2),
          ));
          return;
        }
      } else if (_cashReceiptRecipientType == 'business') {
        if (_cashReceiptBusinessNameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(
            content: Text('사업자명을 입력해주세요.'),
            duration: Duration(seconds: 2),
          ));
          return;
        }
        if (_cashReceiptBusinessNumberController.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(
            content: Text('사업자 번호를 입력해주세요.'),
            duration: Duration(seconds: 2),
          ));
          return;
        }
      }
    }

    // 세금계산서 선택 시 검증
    if (_receiptType == 'tax_invoice') {
      if (_taxInvoiceRepresentativeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('대표자명을 입력해주세요.'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
      if (_taxInvoiceCompanyNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('회사명을 입력해주세요.'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
      if (_taxInvoiceBusinessNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('사업자번호를 입력해주세요.'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
      if (_taxInvoiceAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('주소를 입력해주세요.'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
    }

    if (_walletId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('지갑 정보를 찾을 수 없습니다.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    try {
      final selectedOption = _chargeOptions.firstWhere(
        (option) => option['points'] == _selectedAmount,
      );
      final cashAmount = selectedOption['cash']!;

      // 영수증 정보 준비
      String? receiptType = _receiptType;
      String? cashReceiptRecipientType;
      String? cashReceiptName;
      String? cashReceiptPhone;
      String? cashReceiptBusinessName;
      String? cashReceiptBusinessNumber;
      String? taxInvoiceRepresentative;
      String? taxInvoiceCompanyName;
      String? taxInvoiceBusinessNumber;
      String? taxInvoiceEmail;
      String? taxInvoiceAddress;
      String? taxInvoiceDetailAddress;

      if (_receiptType == 'cash_receipt') {
        cashReceiptRecipientType = _cashReceiptRecipientType;
        if (_cashReceiptRecipientType == 'individual') {
          cashReceiptName = _cashReceiptNameController.text.trim();
          cashReceiptPhone = _cashReceiptPhoneController.text.trim();
        } else if (_cashReceiptRecipientType == 'business') {
          cashReceiptBusinessName = _cashReceiptBusinessNameController.text.trim();
          cashReceiptBusinessNumber = _cashReceiptBusinessNumberController.text.trim();
        }
      } else if (_receiptType == 'tax_invoice') {
        taxInvoiceRepresentative = _taxInvoiceRepresentativeController.text.trim();
        taxInvoiceCompanyName = _taxInvoiceCompanyNameController.text.trim();
        taxInvoiceBusinessNumber = _taxInvoiceBusinessNumberController.text.trim();
        taxInvoiceEmail = _taxInvoiceEmailController.text.trim();
        taxInvoiceAddress = _taxInvoiceAddressController.text.trim();
        taxInvoiceDetailAddress = _taxInvoiceDetailAddressController.text.trim();
      }

      await WalletService.createPointCashTransaction(
        walletId: _walletId,
        transactionType: 'deposit',
        pointAmount: _selectedAmount!,
        cashAmount: cashAmount,
        description: '포인트 충전 요청',
        receiptType: receiptType,
        cashReceiptRecipientType: cashReceiptRecipientType,
        cashReceiptName: cashReceiptName,
        cashReceiptPhone: cashReceiptPhone,
        cashReceiptBusinessName: cashReceiptBusinessName,
        cashReceiptBusinessNumber: cashReceiptBusinessNumber,
        taxInvoiceRepresentative: taxInvoiceRepresentative,
        taxInvoiceCompanyName: taxInvoiceCompanyName,
        taxInvoiceBusinessNumber: taxInvoiceBusinessNumber,
        taxInvoiceEmail: taxInvoiceEmail,
        taxInvoicePostalCode: null,
        taxInvoiceAddress: taxInvoiceAddress,
        taxInvoiceDetailAddress: taxInvoiceDetailAddress,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text('충전 요청이 완료되었습니다.'),
          duration: Duration(seconds: 2),
        ));
        context.pop(true); // 성공 시 true 반환
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('포인트 충전'),
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

                  // 충전 금액 선택
                  _buildChargeAmountSection(),
                  const SizedBox(height: 24),

                  // 입금자명
                  _buildDepositorNameSection(),
                  const SizedBox(height: 24),

                  // 입금 계좌 정보
                  _buildDepositAccountSection(),
                  const SizedBox(height: 24),

                  // 영수증 발행
                  _buildReceiptSection(),
                  const SizedBox(height: 24),

                  // 안내 사항
                  _buildNoticeSection(),
                  const SizedBox(height: 24),

                  // 충전 버튼
                  _buildChargeButton(),
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

  Widget _buildChargeAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '충전금액',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        ..._chargeOptions.map((option) {
          final points = option['points']!;
          final cash = option['cash']!;

          return RadioListTile<int>(
            title: Text(
              '${points.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}P',
            ),
            subtitle: Text(
              '(${cash.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)',
            ),
            value: points,
            groupValue: _selectedAmount,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedAmount = value;
                });
              }
            },
            activeColor: const Color(0xFF2196F3),
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Widget _buildDepositorNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '입금자명',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _depositorNameController,
          decoration: const InputDecoration(
            hintText: '입금자명',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() {}); // 버튼 활성화 상태 업데이트
          },
        ),
      ],
    );
  }

  Widget _buildDepositAccountSection() {
    // 광고주일 때만 고정된 계좌 정보 표시
    // (리뷰어는 이 화면에 접근할 수 없음)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '입금계좌정보',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '은행명: 농협',
                style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
              ),
              SizedBox(height: 8),
              Text(
                '계좌번호: 312-0172-8650-01',
                style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
              ),
              SizedBox(height: 8),
              Text(
                '예금주: 김동익',
                style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '영수증 발행',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _receiptType,
          decoration: const InputDecoration(
            hintText: '발행방법(현금영수증/세금계산서/발행안함)',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'cash_receipt', child: Text('현금영수증')),
            DropdownMenuItem(value: 'tax_invoice', child: Text('세금계산서')),
            DropdownMenuItem(value: 'none', child: Text('발행안함')),
          ],
          onChanged: (value) async {
            setState(() {
              _receiptType = value;
              // 영수증 타입 변경 시 관련 필드 초기화
              if (value != 'cash_receipt') {
                _cashReceiptRecipientType = null;
                _cashReceiptNameController.clear();
                _cashReceiptPhoneController.clear();
                _cashReceiptBusinessNameController.clear();
                _cashReceiptBusinessNumberController.clear();
              }
              if (value != 'tax_invoice') {
                _taxInvoiceRepresentativeController.clear();
                _taxInvoiceCompanyNameController.clear();
                _taxInvoiceBusinessNumberController.clear();
                _taxInvoiceEmailController.clear();
                _taxInvoiceAddressController.clear();
                _taxInvoiceDetailAddressController.clear();
              }
            });
            
            // 세금계산서 선택 시 company 테이블에서 회사 정보 자동 로드
            if (value == 'tax_invoice') {
              await _loadCompanyInfoForTaxInvoice();
            }
          },
        ),
        // 현금영수증 선택 시 추가 필드
        if (_receiptType == 'cash_receipt') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('개인'),
                  value: 'individual',
                  groupValue: _cashReceiptRecipientType,
                  onChanged: (value) {
                    setState(() {
                      _cashReceiptRecipientType = value;
                      if (value == 'individual') {
                        _cashReceiptBusinessNameController.clear();
                        _cashReceiptBusinessNumberController.clear();
                      } else {
                        _cashReceiptNameController.clear();
                        _cashReceiptPhoneController.clear();
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('사업자 지출증빙용'),
                  value: 'business',
                  groupValue: _cashReceiptRecipientType,
                  onChanged: (value) {
                    setState(() {
                      _cashReceiptRecipientType = value;
                      if (value == 'individual') {
                        _cashReceiptBusinessNameController.clear();
                        _cashReceiptBusinessNumberController.clear();
                      } else {
                        _cashReceiptNameController.clear();
                        _cashReceiptPhoneController.clear();
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          if (_cashReceiptRecipientType == 'individual') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cashReceiptNameController,
              decoration: const InputDecoration(
                labelText: '이름*',
                hintText: '이름을 입력하세요',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cashReceiptPhoneController,
              decoration: const InputDecoration(
                labelText: '휴대폰 번호*',
                hintText: '01012345678',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) => setState(() {}),
            ),
          ],
          if (_cashReceiptRecipientType == 'business') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cashReceiptBusinessNameController,
              decoration: const InputDecoration(
                labelText: '사업자명*',
                hintText: '사업자명을 입력하세요',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cashReceiptBusinessNumberController,
              decoration: const InputDecoration(
                labelText: '사업자 번호*',
                hintText: '123-45-67890',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
            ),
          ],
        ],
        // 세금계산서 선택 시 추가 필드
        if (_receiptType == 'tax_invoice') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _taxInvoiceRepresentativeController,
            decoration: const InputDecoration(
              labelText: '대표자명*',
              hintText: '대표자명을 입력하세요',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxInvoiceCompanyNameController,
            decoration: const InputDecoration(
              labelText: '회사명*',
              hintText: '회사명을 입력하세요',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxInvoiceBusinessNumberController,
            decoration: const InputDecoration(
              labelText: '사업자번호*',
              hintText: '123-45-67890',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxInvoiceEmailController,
            decoration: const InputDecoration(
              labelText: '이메일',
              hintText: 'example@email.com',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taxInvoiceAddressController,
                  decoration: const InputDecoration(
                    labelText: '주소*',
                    hintText: '주소',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  readOnly: true,
                  onChanged: (value) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  PostcodeService.openPostcodeDialog(
                    context,
                    onComplete: (postalCode, address, extraAddress) {
                      setState(() {
                        _taxInvoiceAddressController.text = address + (extraAddress ?? '');
                      });
                    },
                  );
                },
                child: const Text('주소 찾기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxInvoiceDetailAddressController,
            decoration: const InputDecoration(
              labelText: '상세주소',
              hintText: '상세주소를 입력하세요',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() {}),
          ),
        ],
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
            '※ 포인트 충전 전 꼭 확인해주세요 ※',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          _buildNoticeItem('모든 상품은 부가세(VAT)포함 가격입니다.'),
          _buildNoticeItem('무통장 신청 후 24시간 내에 입금되지 않는 건은 자동 취소 됩니다.'),
          _buildNoticeItem(
            '광고비 충전은 영업일 기준 (am 09:30 ~ pm 06:30) 당일 입금내역 확인 후 충전 됩니다.',
          ),
          _buildNoticeItem(
            '충전하신 광고비는 5년 동안 사용하실 수 있으며, 기한 내 남은 잔여포인트는 환불 가능합니다.',
          ),
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
          const Text('• ', style: TextStyle(color: Color(0xFF666666))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  bool _isReceiptInfoValid() {
    if (_receiptType == null) return false;
    if (_receiptType == 'none') return true;
    
    if (_receiptType == 'cash_receipt') {
      if (_cashReceiptRecipientType == null) return false;
      if (_cashReceiptRecipientType == 'individual') {
        return _cashReceiptNameController.text.trim().isNotEmpty &&
            _cashReceiptPhoneController.text.trim().isNotEmpty;
      } else if (_cashReceiptRecipientType == 'business') {
        return _cashReceiptBusinessNameController.text.trim().isNotEmpty &&
            _cashReceiptBusinessNumberController.text.trim().isNotEmpty;
      }
    }
    
    if (_receiptType == 'tax_invoice') {
      return _taxInvoiceRepresentativeController.text.trim().isNotEmpty &&
          _taxInvoiceCompanyNameController.text.trim().isNotEmpty &&
          _taxInvoiceBusinessNumberController.text.trim().isNotEmpty &&
          _taxInvoiceAddressController.text.trim().isNotEmpty;
    }
    
    return false;
  }

  Widget _buildChargeButton() {
    final isEnabled =
        _selectedAmount != null &&
        _depositorNameController.text.trim().isNotEmpty &&
        _isReceiptInfoValid();

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? _submitCharge : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? const Color(0xFF2196F3)
              : Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '포인트 충전',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
