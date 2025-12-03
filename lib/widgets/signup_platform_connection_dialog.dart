import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sns_platform_connection_service.dart';
import '../widgets/address_form_field.dart';
import '../utils/phone_formatter.dart';

/// 회원가입용 플랫폼 연결 다이얼로그
/// DB에 저장하지 않고 데이터만 반환
class SignupPlatformConnectionDialog extends StatefulWidget {
  final String platform;
  final String platformName;
  final String? profileName; // 프로필 이름
  final String? profilePhone; // 프로필 전화번호
  final String? profileAddress; // 프로필 주소 (전체주소)
  final Map<String, dynamic>? initialData; // 수정 시 기존 데이터

  const SignupPlatformConnectionDialog({
    super.key,
    required this.platform,
    required this.platformName,
    this.profileName,
    this.profilePhone,
    this.profileAddress,
    this.initialData,
  });

  @override
  State<SignupPlatformConnectionDialog> createState() =>
      _SignupPlatformConnectionDialogState();
}

class _SignupPlatformConnectionDialogState
    extends State<SignupPlatformConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountIdController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deliveryBaseAddressController = TextEditingController(); // 배송 기본주소
  final _deliveryDetailAddressController = TextEditingController(); // 배송 상세주소
  final _returnBaseAddressController = TextEditingController(); // 반품 기본주소
  final _returnDetailAddressController = TextEditingController(); // 반품 상세주소

  bool _useProfileInfo = false; // 내 프로필 정보 넣기 체크박스

  @override
  void initState() {
    super.initState();
    // 수정 모드인 경우 기존 데이터로 초기화
    if (widget.initialData != null) {
      _accountIdController.text = widget.initialData!['platform_account_id'] ?? '';
      _accountNameController.text = widget.initialData!['platform_account_name'] ?? '';
      _phoneController.text = widget.initialData!['phone'] ?? '';
      
      // 주소 분리 (기본주소 + 상세주소)
      final address = widget.initialData!['address'] as String?;
      if (address != null && address.isNotEmpty) {
        final lastSpaceIndex = address.lastIndexOf(' ');
        if (lastSpaceIndex > 0 && lastSpaceIndex < address.length - 1) {
          _deliveryBaseAddressController.text = address.substring(0, lastSpaceIndex);
          _deliveryDetailAddressController.text = address.substring(lastSpaceIndex + 1);
        } else {
          _deliveryBaseAddressController.text = address;
        }
      }
      
      // 반품주소 분리
      final returnAddress = widget.initialData!['return_address'] as String?;
      if (returnAddress != null && returnAddress.isNotEmpty) {
        final lastSpaceIndex = returnAddress.lastIndexOf(' ');
        if (lastSpaceIndex > 0 && lastSpaceIndex < returnAddress.length - 1) {
          _returnBaseAddressController.text = returnAddress.substring(0, lastSpaceIndex);
          _returnDetailAddressController.text = returnAddress.substring(lastSpaceIndex + 1);
        } else {
          _returnBaseAddressController.text = returnAddress;
        }
      }
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _accountNameController.dispose();
    _phoneController.dispose();
    _deliveryBaseAddressController.dispose();
    _deliveryDetailAddressController.dispose();
    _returnBaseAddressController.dispose();
    _returnDetailAddressController.dispose();
    super.dispose();
  }

  /// 프로필 정보로 자동 입력
  void _fillProfileInfo() {
    if (widget.profileName != null && widget.profileName!.isNotEmpty) {
      _accountNameController.text = widget.profileName!;
    }
    if (widget.profilePhone != null && widget.profilePhone!.isNotEmpty) {
      _phoneController.text = widget.profilePhone!;
    }
    if (widget.profileAddress != null && widget.profileAddress!.isNotEmpty) {
      // 주소를 기본주소와 상세주소로 분리
      final address = widget.profileAddress!.trim();
      final lastSpaceIndex = address.lastIndexOf(' ');
      if (lastSpaceIndex > 0 && lastSpaceIndex < address.length - 1) {
        _deliveryBaseAddressController.text = address.substring(0, lastSpaceIndex);
        _deliveryDetailAddressController.text = address.substring(lastSpaceIndex + 1);
      } else {
        _deliveryBaseAddressController.text = address;
      }
    }
  }


  void _saveConnection() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 스토어 플랫폼 주소 필수 검증
    final isStorePlatform = SNSPlatformConnectionService.isStorePlatform(
      widget.platform,
    );
    
    // 배송주소 전체주소 생성
    String? deliveryAddress;
    final deliveryBase = _deliveryBaseAddressController.text.trim();
    final deliveryDetail = _deliveryDetailAddressController.text.trim();
    if (deliveryBase.isNotEmpty) {
      deliveryAddress = deliveryDetail.isNotEmpty
          ? '$deliveryBase $deliveryDetail'
          : deliveryBase;
    }
    
    if (isStorePlatform && (deliveryAddress == null || deliveryAddress.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.platformName} 플랫폼은 배송주소 입력이 필수입니다'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 반품주소 전체주소 생성
    String? returnAddress;
    final returnBase = _returnBaseAddressController.text.trim();
    final returnDetail = _returnDetailAddressController.text.trim();
    if (returnBase.isNotEmpty) {
      returnAddress = returnDetail.isNotEmpty
          ? '$returnBase $returnDetail'
          : returnBase;
    }

    // 데이터 반환 (DB 저장 안 함)
    Navigator.of(context).pop({
      'platform': widget.platform,
      'platform_account_id': _accountIdController.text.trim(),
      'platform_account_name': _accountNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': isStorePlatform ? deliveryAddress : null,
      'return_address': returnAddress?.isNotEmpty == true ? returnAddress : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStorePlatform = SNSPlatformConnectionService.isStorePlatform(
      widget.platform,
    );

    return AlertDialog(
      title: Text('${widget.platformName} 연결'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _accountIdController,
                  decoration: const InputDecoration(
                    labelText: '계정 ID *',
                    hintText: '플랫폼 계정 ID를 입력해주세요',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '계정 ID를 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // 내 프로필 정보 넣기 체크박스
                if (widget.profileName != null || widget.profilePhone != null || widget.profileAddress != null)
                  CheckboxListTile(
                    title: const Text('내 프로필 정보 넣기'),
                    value: _useProfileInfo,
                    onChanged: (value) {
                      setState(() {
                        _useProfileInfo = value ?? false;
                        if (_useProfileInfo) {
                          _fillProfileInfo();
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                if (widget.profileName != null || widget.profilePhone != null || widget.profileAddress != null)
                  const SizedBox(height: 16),
                TextFormField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(
                    labelText: '계정 이름 *',
                    hintText: '플랫폼에 표시되는 이름',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '계정 이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  hintText: '010-1234-5678',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PhoneNumberFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '전화번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              if (isStorePlatform) ...[
                const SizedBox(height: 16),
                AddressFormField(
                  deliveryBaseAddressController: _deliveryBaseAddressController,
                  deliveryDetailAddressController: _deliveryDetailAddressController,
                  returnBaseAddressController: _returnBaseAddressController,
                  returnDetailAddressController: _returnDetailAddressController,
                  isDeliveryAddressRequired: true,
                  showReturnAddress: true,
                ),
              ],
            ],
          ),
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saveConnection,
          child: Text(widget.initialData != null ? '수정' : '추가'),
        ),
      ],
    );
  }
}
