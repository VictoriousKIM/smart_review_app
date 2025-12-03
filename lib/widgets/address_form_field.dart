import 'package:flutter/material.dart';
import '../utils/postcode_service.dart';

/// 재사용 가능한 주소 입력 폼 위젯
///
/// 배송주소와 반품주소를 입력할 수 있는 폼을 제공합니다.
/// 주소 찾기 기능을 포함하며, 반품주소는 배송주소와 동일하게 설정할 수 있습니다.
class AddressFormField extends StatefulWidget {
  /// 배송 기본주소 컨트롤러
  final TextEditingController deliveryBaseAddressController;

  /// 배송 상세주소 컨트롤러
  final TextEditingController deliveryDetailAddressController;

  /// 반품 기본주소 컨트롤러 (선택)
  final TextEditingController? returnBaseAddressController;

  /// 반품 상세주소 컨트롤러 (선택)
  final TextEditingController? returnDetailAddressController;

  /// 배송주소 필수 여부
  final bool isDeliveryAddressRequired;

  /// 반품주소 표시 여부
  final bool showReturnAddress;

  /// 배송주소 라벨 텍스트
  final String? deliveryAddressLabel;

  /// 반품주소 라벨 텍스트
  final String? returnAddressLabel;

  /// 배송주소 검증 함수
  final String? Function(String?)? deliveryAddressValidator;

  /// 반품주소 검증 함수
  final String? Function(String?)? returnAddressValidator;

  const AddressFormField({
    super.key,
    required this.deliveryBaseAddressController,
    required this.deliveryDetailAddressController,
    this.returnBaseAddressController,
    this.returnDetailAddressController,
    this.isDeliveryAddressRequired = true,
    this.showReturnAddress = false,
    this.deliveryAddressLabel,
    this.returnAddressLabel,
    this.deliveryAddressValidator,
    this.returnAddressValidator,
  });

  @override
  State<AddressFormField> createState() => _AddressFormFieldState();
}

class _AddressFormFieldState extends State<AddressFormField> {
  bool _sameAsDelivery = false;

  /// 반품주소를 배송주소와 동기화
  void _syncReturnAddress() {
    if (widget.returnBaseAddressController != null &&
        widget.returnDetailAddressController != null) {
      widget.returnBaseAddressController!.text =
          widget.deliveryBaseAddressController.text;
      widget.returnDetailAddressController!.text =
          widget.deliveryDetailAddressController.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 배송주소 섹션
        Text(
          widget.deliveryAddressLabel ??
              (widget.isDeliveryAddressRequired ? '배송주소 *' : '배송주소 (선택)'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // 배송 기본주소
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.deliveryBaseAddressController,
                decoration: const InputDecoration(
                  labelText: '기본주소',
                  hintText: '주소를 입력해주세요',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator:
                    widget.deliveryAddressValidator ??
                    (widget.isDeliveryAddressRequired
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '주소를 입력해주세요';
                            }
                            return null;
                          }
                        : null),
                onChanged: (value) {
                  if (_sameAsDelivery) {
                    _syncReturnAddress();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                PostcodeService.openPostcodeDialog(
                  context,
                  onComplete: (postalCode, address, extraAddress) {
                    setState(() {
                      widget.deliveryBaseAddressController.text = address;
                      if (_sameAsDelivery) {
                        _syncReturnAddress();
                      }
                    });
                  },
                );
              },
              child: const Text('주소 찾기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 배송 상세주소
        TextFormField(
          controller: widget.deliveryDetailAddressController,
          decoration: const InputDecoration(
            labelText: '상세주소',
            hintText: '상세주소를 입력해주세요',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (_sameAsDelivery) {
              _syncReturnAddress();
            }
          },
        ),

        // 반품주소 섹션
        if (widget.showReturnAddress &&
            widget.returnBaseAddressController != null &&
            widget.returnDetailAddressController != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.returnAddressLabel ?? '반품주소 (선택)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 배송주소와 같음 체크박스
          CheckboxListTile(
            title: const Text('배송주소와 같음'),
            value: _sameAsDelivery,
            onChanged: (value) {
              setState(() {
                _sameAsDelivery = value ?? false;
                if (_sameAsDelivery) {
                  _syncReturnAddress();
                }
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          // 반품 기본주소
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.returnBaseAddressController,
                  decoration: const InputDecoration(
                    labelText: '기본주소',
                    hintText: '주소를 입력해주세요',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  enabled: !_sameAsDelivery,
                  validator: widget.returnAddressValidator,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sameAsDelivery
                    ? null
                    : () {
                        PostcodeService.openPostcodeDialog(
                          context,
                          onComplete: (postalCode, address, extraAddress) {
                            setState(() {
                              widget.returnBaseAddressController!.text =
                                  address;
                            });
                          },
                        );
                      },
                child: const Text('주소 찾기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 반품 상세주소
          TextFormField(
            controller: widget.returnDetailAddressController,
            decoration: const InputDecoration(
              labelText: '상세주소',
              hintText: '상세주소를 입력해주세요',
              border: OutlineInputBorder(),
            ),
            enabled: !_sameAsDelivery,
          ),
        ],
      ],
    );
  }
}
