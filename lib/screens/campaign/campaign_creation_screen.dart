import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import '../../services/campaign_image_service.dart';
import '../../widgets/image_crop_editor.dart';
import '../../services/campaign_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../config/supabase_config.dart';

class CampaignCreationScreen extends ConsumerStatefulWidget {
  const CampaignCreationScreen({super.key});

  @override
  ConsumerState<CampaignCreationScreen> createState() =>
      _CampaignCreationScreenState();
}

class _CampaignCreationScreenState
    extends ConsumerState<CampaignCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _campaignImageService = CampaignImageService();
  final _campaignService = CampaignService();

  // 이미지 관련
  Uint8List? _capturedImage;
  Uint8List? _productImage; // 크롭된 상품 이미지
  Rect? _currentCropRect; // 현재 크롭 영역 좌표 저장
  bool _isAnalyzing = false;
  bool _isLoadingImage = false; // 이미지 선택 중
  bool _isEditingImage = false; // 이미지 편집 중
  bool _isCreatingCampaign = false;

  // 자동 추출 필드 컨트롤러
  final _keywordController = TextEditingController();
  final _productNameController = TextEditingController();
  final _optionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _sellerController = TextEditingController();
  final _productNumberController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _reviewRewardController = TextEditingController();

  // 추가 필드 컨트롤러
  final _productDescriptionController = TextEditingController();
  final _reviewTextLengthController = TextEditingController(text: '100');
  final _reviewImageCountController = TextEditingController(text: '1');
  final _maxParticipantsController = TextEditingController(text: '10');
  final _duplicateCheckDaysController = TextEditingController(text: '0');
  final _productProvisionOtherController = TextEditingController();

  // 선택 필드
  String _campaignType = 'reviewer';
  String _platform = 'coupang';
  String _paymentType = 'platform';
  String? _productProvisionType; // null, 'delivery', 'return', 'other'
  String _productProvisionOther = '';
  bool _onlyAllowedReviewers = false;
  String _reviewType =
      'star_only'; // 'star_only', 'star_text', 'star_text_image'
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  bool _preventProductDuplicate = false;
  bool _preventStoreDuplicate = false;

  // 비용 및 잔액
  int _totalCost = 0;
  int _currentBalance = 0;
  bool _isLoadingBalance = false;

  String? _errorMessage;

  // 성능 최적화: 디바운싱용 Timer
  Timer? _costCalculationTimer;

  // 디바운싱 중 리스너 무시 플래그
  bool _ignoreCostListeners = false;

  // 성능 최적화: DateTime 필드용 컨트롤러
  late final TextEditingController _startDateTimeController;
  late final TextEditingController _endDateTimeController;

  @override
  void initState() {
    super.initState();
    // DateTime 컨트롤러 초기화
    _startDateTimeController = TextEditingController();
    _endDateTimeController = TextEditingController();

    // ✅ 첫 프레임 렌더링 후 실행하여 초기 렌더링 속도 향상
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupCostListeners();
      _loadCompanyBalance();
      _updateDateTimeControllers();
    });
  }

  @override
  void dispose() {
    // Timer 정리
    _costCalculationTimer?.cancel();
    // 컨트롤러 정리
    _keywordController.dispose();
    _productNameController.dispose();
    _optionController.dispose();
    _quantityController.dispose();
    _sellerController.dispose();
    _productNumberController.dispose();
    _paymentAmountController.dispose();
    _reviewRewardController.dispose();
    _productDescriptionController.dispose();
    _reviewTextLengthController.dispose();
    _reviewImageCountController.dispose();
    _maxParticipantsController.dispose();
    _duplicateCheckDaysController.dispose();
    _productProvisionOtherController.dispose();
    _startDateTimeController.dispose();
    _endDateTimeController.dispose();
    super.dispose();
  }

  void _setupCostListeners() {
    // 비용 계산에 영향을 주는 필드들 리스너 설정 (디바운싱 적용)
    _paymentAmountController.addListener(_calculateCostDebounced);
    _reviewRewardController.addListener(_calculateCostDebounced);
    _maxParticipantsController.addListener(_calculateCostDebounced);
  }

  // 디바운싱된 비용 계산 (500ms 지연)
  void _calculateCostDebounced() {
    if (_ignoreCostListeners) return; // 리스너 무시 중이면 스킵
    _costCalculationTimer?.cancel();
    _costCalculationTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _calculateCost();
      }
    });
  }

  Future<void> _loadCompanyBalance() async {
    // ✅ 초기 로딩 상태만 즉시 업데이트 (사용자 피드백)
    if (mounted) {
      setState(() {
        _isLoadingBalance = true;
      });
    }

    int? pendingBalance;
    String? pendingErrorMessage;

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        pendingErrorMessage = '로그인이 필요합니다.';
      } else {
        // 회사 지갑 조회
        final wallets = await WalletService.getCompanyWallets();
        if (wallets.isNotEmpty) {
          pendingBalance = wallets.first.currentPoints;
        } else {
          pendingBalance = 0;
          pendingErrorMessage = '회사 지갑을 찾을 수 없습니다.';
        }
      }
    } catch (e) {
      pendingErrorMessage = '잔액 조회 실패: $e';
    } finally {
      // ✅ 마지막에 한 번만 setState 호출
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
          if (pendingBalance != null) {
            _currentBalance = pendingBalance;
            // 포맷팅 캐시 무효화
            _cachedFormattedBalance = null;
            _cachedFormattedRemaining = null;
          }
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
        });
      }
    }
  }

  void _calculateCost() {
    final paymentAmount = int.tryParse(_paymentAmountController.text) ?? 0;
    final reviewReward = int.tryParse(_reviewRewardController.text) ?? 0;
    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 1;

    int cost = 0;
    if (_paymentType == 'platform') {
      // 플랫폼 지급: (결제금액 + 리뷰비 + 500) * 신청인원
      cost = (paymentAmount + reviewReward + 500) * maxParticipants;
    } else {
      // 직접 지급: 500 * 신청인원
      cost = 500 * maxParticipants;
    }

    // 값이 변경되었을 때만 setState 호출 및 포맷팅 캐싱
    if (_totalCost != cost) {
      _totalCost = cost;
      // 포맷팅 캐싱 업데이트
      _cachedFormattedBalance = _formatNumber(_currentBalance);
      _cachedFormattedTotalCost = _formatNumber(_totalCost);
      _cachedFormattedRemaining = _formatNumber(_currentBalance - _totalCost);

      if (mounted) {
        setState(() {});
      }
    }
  }

  // 숫자 포맷팅 헬퍼 함수
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // 포맷된 값 캐싱 (비용 계산 시에만 업데이트)
  String? _cachedFormattedBalance;
  String? _cachedFormattedTotalCost;
  String? _cachedFormattedRemaining;

  // 포맷된 값 getter (캐시된 값 사용)
  String get _formattedBalance =>
      _cachedFormattedBalance ?? _formatNumber(_currentBalance);
  String get _formattedTotalCost =>
      _cachedFormattedTotalCost ?? _formatNumber(_totalCost);
  String get _formattedRemaining =>
      _cachedFormattedRemaining ?? _formatNumber(_currentBalance - _totalCost);

  Future<void> _pickImage() async {
    // 로딩 상태 시작
    if (mounted) {
      setState(() {
        _isLoadingImage = true;
        _errorMessage = null;
      });
    }

    Uint8List? pendingImageBytes;
    String? pendingErrorMessage;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // 품질 감소로 메모리 사용량 감소
        maxWidth: 1920, // 최대 크기 제한
        maxHeight: 1920,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        // 이미지 크기 제한 (5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          pendingErrorMessage = '이미지 크기가 너무 큽니다. (최대 5MB)';
        } else {
          pendingImageBytes = bytes;
        }
      }
    } catch (e) {
      pendingErrorMessage = '이미지 선택 실패: $e';
    } finally {
      // 마지막에 한 번만 setState 호출
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
          if (pendingImageBytes != null) {
            _capturedImage = pendingImageBytes;
            _productImage = null; // 새 이미지 선택 시 상품 이미지 초기화
            _currentCropRect = null;
            _errorMessage = null;
          }
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
        });
      }
    }
  }

  Future<void> _extractFromImage() async {
    if (_capturedImage == null) {
      if (mounted) {
        setState(() {
          _errorMessage = '먼저 이미지를 선택해주세요.';
        });
      }
      return;
    }

    // 초기 상태 업데이트
    if (mounted) {
      setState(() {
        _isAnalyzing = true;
        _errorMessage = null;
      });
    }

    String? pendingErrorMessage;
    Map<String, dynamic>? pendingExtractedData;
    bool shouldUpdateProductImage = false;
    Uint8List? pendingProductImage;

    try {
      final extractedData = await _campaignImageService.extractFromImage(
        _capturedImage!,
      );

      if (extractedData != null) {
        pendingExtractedData = extractedData;

        // ✅ 플래그로 리스너 무시 (비용 계산 트리거 방지)
        _ignoreCostListeners = true;

        // 컨트롤러 업데이트
        _keywordController.text = extractedData['keyword'] ?? '';
        _productNameController.text = extractedData['title'] ?? '';
        _optionController.text = extractedData['option'] ?? '';
        _quantityController.text = (extractedData['quantity'] ?? 1).toString();
        _sellerController.text = extractedData['seller'] ?? '';
        _productNumberController.text = extractedData['productNumber'] ?? '';
        _paymentAmountController.text = (extractedData['paymentAmount'] ?? 0)
            .toString();

        // 플래그 해제 및 비용 재계산 (한 번만 실행)
        _ignoreCostListeners = false;
        _calculateCost();

        // 상품 이미지 크롭 처리
        final cropData = extractedData['productImageCrop'];
        print('🔍 크롭 데이터: $cropData');

        if (cropData != null && _capturedImage != null) {
          try {
            // 이미지 크기 확인 및 정규화를 Isolate에서 한 번에 처리
            final normalizedResult = await compute(
              _normalizeCropCoordinates,
              _NormalizeCropParams(
                imageBytes: _capturedImage!,
                x: cropData['x']?.toInt() ?? 0,
                y: cropData['y']?.toInt() ?? 0,
                width: cropData['width']?.toInt() ?? 0,
                height: cropData['height']?.toInt() ?? 0,
              ),
            );

            if (normalizedResult != null &&
                normalizedResult['normalizedWidth']! > 0 &&
                normalizedResult['normalizedHeight']! > 0) {
              final normalizedX = normalizedResult['normalizedX'] as int;
              final normalizedY = normalizedResult['normalizedY'] as int;
              final normalizedWidth =
                  normalizedResult['normalizedWidth'] as int;
              final normalizedHeight =
                  normalizedResult['normalizedHeight'] as int;

              print(
                '📐 정규화된 크롭 좌표: x=$normalizedX, y=$normalizedY, width=$normalizedWidth, height=$normalizedHeight',
              );

              // 크롭 좌표 저장
              _currentCropRect = Rect.fromLTWH(
                normalizedX.toDouble(),
                normalizedY.toDouble(),
                normalizedWidth.toDouble(),
                normalizedHeight.toDouble(),
              );

              // 크롭 작업 실행 (비동기로 진행, 결과는 별도 처리)
              _cropProductImage(
                _capturedImage!,
                normalizedX,
                normalizedY,
                normalizedWidth,
                normalizedHeight,
              ).catchError((error) {
                print('❌ 크롭 작업 실패: $error');
                // 크롭 실패 시 전체 이미지 사용 (별도 setState)
                if (mounted) {
                  setState(() {
                    _productImage = _capturedImage;
                    _errorMessage = '이미지 크롭 실패: $error';
                  });
                }
              });
            } else {
              print('⚠️ 크롭 좌표가 유효하지 않음. 전체 이미지를 사용합니다.');
              shouldUpdateProductImage = true;
              pendingProductImage = _capturedImage;
            }
          } catch (e) {
            print('⚠️ 크롭 정규화 실패: $e. 전체 이미지를 사용합니다.');
            shouldUpdateProductImage = true;
            pendingProductImage = _capturedImage;
          }
        } else {
          print('⚠️ 크롭 데이터가 없음. 전체 이미지를 사용합니다.');
          shouldUpdateProductImage = true;
          pendingProductImage = _capturedImage;
        }
      } else {
        pendingErrorMessage = '이미지에서 정보를 추출할 수 없습니다.';
      }
    } catch (e) {
      pendingErrorMessage = '이미지 분석 실패: $e';
    } finally {
      // 마지막에 한 번만 setState 호출
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
          if (shouldUpdateProductImage && pendingProductImage != null) {
            _productImage = pendingProductImage;
          }
        });

        // 성공 메시지는 setState 외부에서
        if (pendingExtractedData != null && pendingErrorMessage == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이미지 분석 완료! 필요시 수정해주세요.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        }
      }
    }
  }

  /// 이미지를 지정된 좌표로 크롭 (디버깅 강화)
  /// isolate에서 실행하여 UI 블로킹 방지
  Future<void> _cropProductImage(
    Uint8List imageBytes,
    int x,
    int y,
    int width,
    int height,
  ) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔧 크롭 작업 시작');
      print('   입력 좌표:');
      print('     X: $x');
      print('     Y: $y');
      print('     W: $width');
      print('     H: $height');

      // 이미지 크롭 작업을 isolate에서 실행
      final cropResult = await compute(
        _cropImageInIsolate,
        _CropImageParams(
          imageBytes: imageBytes,
          x: x,
          y: y,
          width: width,
          height: height,
        ),
      );

      if (cropResult == null) {
        print('❌ 이미지 크롭 실패');
        if (mounted) {
          setState(() {
            _errorMessage = '이미지를 처리할 수 없습니다.';
            _productImage = imageBytes;
          });
        }
        return;
      }

      final croppedBytes = cropResult['croppedBytes'] as Uint8List;
      final cropX = cropResult['cropX'] as int;
      final cropY = cropResult['cropY'] as int;
      final cropWidth = cropResult['cropWidth'] as int;
      final cropHeight = cropResult['cropHeight'] as int;

      print('✓ 크롭 완료');
      print('   결과 크기: ${cropWidth}x${cropHeight}');
      print('   파일 크기: ${(croppedBytes.length / 1024).toStringAsFixed(2)} KB');

      if (mounted) {
        setState(() {
          _productImage = croppedBytes;
          _currentCropRect = Rect.fromLTWH(
            cropX.toDouble(),
            cropY.toDouble(),
            cropWidth.toDouble(),
            cropHeight.toDouble(),
          );
          _errorMessage = null;
        });

        print('✅ 상품 이미지 업데이트 완료');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('크롭 완료: ${cropWidth}x${cropHeight}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ 크롭 실패');
      print('에러: $e');
      print('스택 트레이스:');
      print(stackTrace);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (mounted) {
        setState(() {
          _productImage = imageBytes;
          _errorMessage = '이미지 크롭 실패: $e';
        });
      }
    }
  }

  // Isolate에서 실행할 이미지 크롭 함수
  static Map<String, dynamic>? _cropImageInIsolate(_CropImageParams params) {
    try {
      final imageBytes = params.imageBytes;
      final x = params.x;
      final y = params.y;
      final width = params.width;
      final height = params.height;

      // 이미지 디코딩
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        return null;
      }

      final imageWidth = originalImage.width;
      final imageHeight = originalImage.height;

      // 좌표 보정
      int cropX = x.clamp(0, imageWidth - 1);
      int cropY = y.clamp(0, imageHeight - 1);
      int cropWidth = width.clamp(1, imageWidth - cropX);
      int cropHeight = height.clamp(1, imageHeight - cropY);

      // 최소 크기 확인
      if (cropWidth < 10 || cropHeight < 10) {
        return null;
      }

      // 이미지 크롭 수행
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // ✅ JPEG로 인코딩하여 메모리 사용량 감소 (품질 85%)
      final croppedBytes = Uint8List.fromList(
        img.encodeJpg(croppedImage, quality: 85),
      );

      return {
        'croppedBytes': croppedBytes,
        'cropX': cropX,
        'cropY': cropY,
        'cropWidth': cropWidth,
        'cropHeight': cropHeight,
      };
    } catch (e) {
      print('❌ Isolate에서 크롭 실패: $e');
      return null;
    }
  }

  // Isolate에서 실행할 크롭 좌표 정규화 함수
  static Map<String, int>? _normalizeCropCoordinates(
    _NormalizeCropParams params,
  ) {
    try {
      // 이미지 디코딩
      final image = img.decodeImage(params.imageBytes);
      if (image == null) {
        return null;
      }

      final actualWidth = image.width;
      final actualHeight = image.height;

      // 원본 크롭 좌표
      int x = params.x;
      int y = params.y;
      int width = params.width;
      int height = params.height;

      // 크롭 좌표 정규화
      int normalizedX = x;
      int normalizedY = y;
      int normalizedWidth = width;
      int normalizedHeight = height;

      // 좌표가 이미지 범위를 벗어나면 조정
      if (normalizedX < 0) normalizedX = 0;
      if (normalizedY < 0) normalizedY = 0;
      if (normalizedX >= actualWidth) normalizedX = 0;
      if (normalizedY >= actualHeight) normalizedY = 0;

      // 크롭 좌표가 이미지 크기를 초과하는 경우 조정
      if (normalizedX + normalizedWidth > actualWidth) {
        normalizedWidth = actualWidth - normalizedX;
      }
      if (normalizedY + normalizedHeight > actualHeight) {
        normalizedHeight = actualHeight - normalizedY;
      }

      // 너비/높이가 0이거나 음수면 기본값 사용
      if (normalizedWidth <= 0) {
        normalizedWidth = (actualWidth / 2).round();
      }
      if (normalizedHeight <= 0) {
        normalizedHeight = actualHeight;
      }

      // 최종 크롭 영역이 이미지 범위를 벗어나지 않도록 보정
      if (normalizedX + normalizedWidth > actualWidth) {
        normalizedWidth = actualWidth - normalizedX;
      }
      if (normalizedY + normalizedHeight > actualHeight) {
        normalizedHeight = actualHeight - normalizedY;
      }

      return {
        'normalizedX': normalizedX,
        'normalizedY': normalizedY,
        'normalizedWidth': normalizedWidth,
        'normalizedHeight': normalizedHeight,
      };
    } catch (e) {
      print('❌ Isolate에서 크롭 좌표 정규화 실패: $e');
      return null;
    }
  }

  /// 이미지 크롭 에디터 열기
  Future<void> _editProductImage() async {
    if (_capturedImage == null) {
      if (mounted) {
        setState(() {
          _errorMessage = '먼저 이미지를 선택해주세요.';
        });
      }
      return;
    }

    // 로딩 상태 시작
    if (mounted) {
      setState(() {
        _isEditingImage = true;
        _errorMessage = null;
      });
    }

    String? pendingErrorMessage;
    Uint8List? pendingProductImage;
    bool webDialogShown = false;

    try {
      // 웹에서는 image_cropper가 동작하지 않으므로 간단한 좌표 입력 다이얼로그 사용
      if (kIsWeb) {
        await _showWebCropDialog();
        webDialogShown = true;
        // _showWebCropDialog 내부에서 setState 처리하므로 여기서는 로딩만 해제
        if (mounted) {
          setState(() {
            _isEditingImage = false;
          });
        }
        return;
      }

      // 모바일/데스크톱에서는 image_cropper 사용
      final tempDir = Directory.systemTemp;
      File? tempFile;

      try {
        tempFile = File(
          '${tempDir.path}/temp_crop_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await tempFile.writeAsBytes(_capturedImage!);

        // 이미지 크롭 에디터 열기
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: tempFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: '상품 이미지 크롭',
              toolbarColor: const Color(0xFF137fec),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(title: '상품 이미지 크롭', aspectRatioLockEnabled: false),
          ],
        );

        if (croppedFile != null) {
          pendingProductImage = await croppedFile.readAsBytes();
        }
      } finally {
        // 임시 파일 삭제 (에러 발생해도 삭제)
        try {
          if (tempFile != null && await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          print('⚠️ 임시 파일 삭제 실패: $e');
        }
      }
    } catch (e) {
      print('❌ 이미지 크롭 에디터 실패: $e');
      pendingErrorMessage = '이미지 편집 실패: $e';

      // 웹에서는 fallback으로 크롭 다이얼로그 표시
      if (kIsWeb && !webDialogShown) {
        try {
          await _showWebCropDialog();
          pendingErrorMessage = null; // 성공하면 에러 메시지 제거
        } catch (e2) {
          pendingErrorMessage = '이미지 편집 실패: $e2';
        }
      }
    } finally {
      // 마지막에 한 번만 setState 호출
      if (mounted && !webDialogShown) {
        setState(() {
          _isEditingImage = false;
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
          if (pendingProductImage != null) {
            _productImage = pendingProductImage;
          }
        });
      }
    }
  }

  /// 웹용 시각적 크롭 다이얼로그 (디버깅 강화)
  Future<void> _showWebCropDialog() async {
    if (_capturedImage == null) {
      print('❌ _capturedImage가 null입니다');
      return;
    }

    // 이미지 크기 가져오기
    final originalImage = img.decodeImage(_capturedImage!);
    if (originalImage == null) {
      print('❌ 이미지 디코딩 실패');
      return;
    }

    final imgWidth = originalImage.width;
    final imgHeight = originalImage.height;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🖼️ 원본 이미지 정보:');
    print('   크기: ${imgWidth}x${imgHeight}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 현재 크롭 영역이 있으면 초기값으로 사용
    Rect? initialCrop = _currentCropRect;
    if (initialCrop == null) {
      initialCrop = Rect.fromLTWH(0, 0, imgWidth / 2, imgHeight.toDouble());
      print('📐 초기 크롭 영역 (기본값):');
    } else {
      print('📐 초기 크롭 영역 (저장된 값):');
    }
    print('   X: ${initialCrop.left.toInt()}');
    print('   Y: ${initialCrop.top.toInt()}');
    print('   W: ${initialCrop.width.toInt()}');
    print('   H: ${initialCrop.height.toInt()}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 디코딩된 이미지를 ImageCropEditor에 전달하여 중복 디코딩 방지
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => ImageCropEditor(
        imageBytes: _capturedImage!,
        decodedImage: originalImage, // 이미 디코딩된 이미지 전달
        initialCrop: initialCrop,
      ),
    );

    if (result == null) {
      print('❌ 사용자가 크롭을 취소했습니다');
      return;
    }

    if (_capturedImage == null) {
      print('❌ 크롭 후 _capturedImage가 null입니다');
      return;
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('✅ 에디터에서 반환된 크롭 좌표:');
    print('   X: ${result['x']}');
    print('   Y: ${result['y']}');
    print('   W: ${result['width']}');
    print('   H: ${result['height']}');

    // 유효성 검사
    if (result['width']! <= 0 || result['height']! <= 0) {
      print('❌ 유효하지 않은 크기입니다');
      setState(() {
        _errorMessage = '유효하지 않은 크롭 영역입니다';
      });
      return;
    }

    if (result['x']! < 0 ||
        result['y']! < 0 ||
        result['x']! >= imgWidth ||
        result['y']! >= imgHeight) {
      print('❌ 좌표가 이미지 범위를 벗어났습니다');
      setState(() {
        _errorMessage = '크롭 좌표가 이미지 범위를 벗어났습니다';
      });
      return;
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 크롭 좌표 저장
    _currentCropRect = Rect.fromLTWH(
      result['x']!.toDouble(),
      result['y']!.toDouble(),
      result['width']!.toDouble(),
      result['height']!.toDouble(),
    );

    // 실제 크롭 수행
    await _cropProductImage(
      _capturedImage!,
      result['x']!,
      result['y']!,
      result['width']!,
      result['height']!,
    );
  }

  Future<void> _createCampaign() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 잔액 확인
    if (_totalCost > _currentBalance) {
      setState(() {
        _errorMessage =
            '잔액이 부족합니다. 필요: ${_totalCost}P, 현재: ${_currentBalance}P';
      });
      return;
    }

    setState(() {
      _isCreatingCampaign = true;
      _errorMessage = null;
    });

    try {
      final response = await _campaignService.createCampaignV2(
        title: _productNameController.text.trim(),
        description: _productDescriptionController.text.trim(),
        campaignType: _campaignType,
        platform: _platform,
        reviewReward: int.tryParse(_reviewRewardController.text) ?? 0,
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 10,
        startDate: _startDateTime!,
        endDate: _endDateTime!,
        keyword: _keywordController.text.trim(),
        option: _optionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 1,
        seller: _sellerController.text.trim(),
        productNumber: _productNumberController.text.trim(),
        paymentAmount: int.tryParse(_paymentAmountController.text) ?? 0,
        reviewType: _reviewType,
        reviewTextLength: int.tryParse(_reviewTextLengthController.text) ?? 100,
        reviewImageCount: int.tryParse(_reviewImageCountController.text) ?? 0,
        preventProductDuplicate: _preventProductDuplicate,
        preventStoreDuplicate: _preventStoreDuplicate,
        duplicatePreventDays:
            int.tryParse(_duplicateCheckDaysController.text) ?? 0,
        paymentMethod: _paymentType,
      );

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '캠페인이 생성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/mypage/advertiser/my-campaigns');
        }
      } else {
        setState(() {
          _errorMessage = response.error ?? '캠페인 생성에 실패했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '예상치 못한 오류: $e';
      });
    } finally {
      setState(() {
        _isCreatingCampaign = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('캠페인 생성'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mypage/advertiser/my-campaigns'),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 에러 메시지
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 캠페인 타입 및 플랫폼 (최상단)
              RepaintBoundary(child: _buildCampaignTypeSection()),
              const SizedBox(height: 24),

              // 이미지 업로드 및 추출
              RepaintBoundary(child: _buildImageSection()),
              const SizedBox(height: 24),

              // 상품 이미지 (자동 추출 후 또는 수동 편집 시 표시)
              if (_productImage != null || _capturedImage != null) ...[
                RepaintBoundary(child: _buildProductImageSection()),
                const SizedBox(height: 24),
              ],

              // 상품 정보
              RepaintBoundary(child: _buildProductInfoSection()),
              const SizedBox(height: 24),

              // 리뷰 설정
              RepaintBoundary(child: _buildReviewSettings()),
              const SizedBox(height: 24),

              // 일정 설정
              RepaintBoundary(child: _buildScheduleSection()),
              const SizedBox(height: 24),

              // 중복 방지 설정
              RepaintBoundary(child: _buildDuplicatePreventSection()),
              const SizedBox(height: 24),

              // 비용 설정
              RepaintBoundary(child: _buildCostSection()),
              const SizedBox(height: 32),

              // 생성 버튼
              RepaintBoundary(
                child: CustomButton(
                  text: '캠페인 생성하기',
                  onPressed: _canCreateCampaign() && !_isCreatingCampaign
                      ? _createCampaign
                      : null,
                  isLoading: _isCreatingCampaign,
                  backgroundColor: const Color(0xFF137fec),
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  '캡처 이미지로 자동 추출',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_capturedImage != null)
              Container(
                height: 300, // 고정 높이
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _capturedImage!,
                    fit: BoxFit.contain, // 박스 안에 전체가 보이도록
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '주문 화면 캡처 이미지를 선택하세요',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: '이미지 선택',
                    onPressed: _isLoadingImage ? null : _pickImage,
                    isLoading: _isLoadingImage,
                    backgroundColor: Colors.grey[700]!,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: '자동 추출',
                    onPressed:
                        _capturedImage != null &&
                            !_isAnalyzing &&
                            !_isLoadingImage
                        ? _extractFromImage
                        : null,
                    isLoading: _isAnalyzing,
                    backgroundColor: const Color(0xFF137fec),
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImageSection() {
    // 크롭된 이미지가 있으면 크롭된 이미지, 없으면 null (원본은 표시 안 함)
    final displayImage = _productImage;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text(
                  '상품 이미지',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_productImage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      '크롭 완료',
                      style: TextStyle(fontSize: 12, color: Colors.green[800]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayImage != null)
              Container(
                height: 300, // 고정 높이
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    displayImage,
                    fit: BoxFit.contain, // 박스 안에 전체가 보이도록
                  ),
                ),
              )
            else
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.crop_original,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '상품 이미지가 없습니다',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '자동 추출을 실행하면 상품 이미지가 표시됩니다',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_capturedImage != null)
              CustomButton(
                text: _productImage != null ? '이미지 편집' : '이미지 크롭',
                onPressed: _isEditingImage ? null : _editProductImage,
                isLoading: _isEditingImage,
                backgroundColor: const Color(0xFF137fec),
                textColor: Colors.white,
                icon: Icons.edit,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignTypeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '캠페인 타입 및 플랫폼',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _campaignType,
              decoration: const InputDecoration(
                labelText: '캠페인 타입 *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'reviewer', child: Text('리뷰어')),
                DropdownMenuItem(value: 'press', child: Text('기자단')),
                DropdownMenuItem(value: 'visit', child: Text('방문형')),
              ],
              onChanged: (value) {
                setState(() {
                  _campaignType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _platform,
              decoration: const InputDecoration(
                labelText: '플랫폼 *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'coupang', child: Text('쿠팡')),
                DropdownMenuItem(value: 'naver', child: Text('네이버 쇼핑')),
                DropdownMenuItem(value: '11st', child: Text('11번가')),
                DropdownMenuItem(value: 'gmarket', child: Text('G마켓')),
              ],
              onChanged: (value) {
                setState(() {
                  _platform = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('사업자가 허용한 리뷰어만 가능'),
              subtitle: const Text('사업자가 승인한 리뷰어만 캠페인에 참여할 수 있습니다'),
              value: _onlyAllowedReviewers,
              onChanged: (value) {
                setState(() {
                  _onlyAllowedReviewers = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text(
                  '상품 정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _keywordController,
              labelText: '키워드',
              hintText: '예: 화장실 선반',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _productNameController,
              labelText: '제품명 *',
              hintText: '예: 브림유 BRIMU 무타공 흡착식 욕실선반',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제품명을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _optionController,
                    labelText: '옵션',
                    hintText: '예: 투명실버',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _quantityController,
                    labelText: '개수 *',
                    hintText: '1',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '개수를 입력해주세요';
                      }
                      final qty = int.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return '올바른 개수를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _sellerController,
              labelText: '판매자',
              hintText: '예: 브림유',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _productNumberController,
              labelText: '상품번호',
              hintText: '예: 8325154393',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _paymentAmountController,
              labelText: '결제금액 *',
              hintText: '13800',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '결제금액을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // 상품제공여부 필드
            DropdownButtonFormField<String>(
              value: _productProvisionType,
              decoration: const InputDecoration(
                labelText: '상품제공여부',
                border: OutlineInputBorder(),
                hintText: '선택하세요',
              ),
              items: const [
                DropdownMenuItem(value: 'delivery', child: Text('실배송')),
                DropdownMenuItem(value: 'return', child: Text('회수')),
                DropdownMenuItem(value: 'other', child: Text('그외')),
              ],
              onChanged: (value) {
                setState(() {
                  _productProvisionType = value;
                  if (value != 'other') {
                    _productProvisionOther = '';
                  }
                });
              },
            ),
            if (_productProvisionType == 'other') ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _productProvisionOtherController,
                labelText: '상품제공 방법 상세',
                hintText: '상품제공 방법을 입력하세요',
                maxLines: 2,
                onChanged: (value) {
                  setState(() {
                    _productProvisionOther = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            CustomTextField(
              controller: _productDescriptionController,
              labelText: '제품 설명',
              hintText: '캠페인에 대한 상세 설명을 입력하세요',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSettings() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rate_review, color: Colors.purple[600]),
                const SizedBox(width: 8),
                const Text(
                  '리뷰 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 리뷰 타입 선택
            DropdownButtonFormField<String>(
              value: _reviewType,
              decoration: const InputDecoration(
                labelText: '리뷰 타입 *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'star_only', child: Text('별점만')),
                DropdownMenuItem(
                  value: 'star_text',
                  child: Text('별점 + 텍스트 리뷰'),
                ),
                DropdownMenuItem(
                  value: 'star_text_image',
                  child: Text('별점 + 텍스트 + 사진'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _reviewType = value!;
                });
              },
            ),

            // 텍스트 리뷰 설정 (별점+텍스트 또는 별점+텍스트+사진일 때)
            if (_reviewType == 'star_text' ||
                _reviewType == 'star_text_image') ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _reviewTextLengthController,
                labelText: '텍스트 리뷰 최소 글자 수 *',
                hintText: '100',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_reviewType == 'star_text' ||
                      _reviewType == 'star_text_image') {
                    if (value == null || value.isEmpty) {
                      return '필수 입력';
                    }
                    final length = int.tryParse(value);
                    if (length == null || length < 0) {
                      return '올바른 값을 입력해주세요';
                    }
                  }
                  return null;
                },
              ),
            ],

            // 사진 리뷰 설정 (별점+텍스트+사진일 때)
            if (_reviewType == 'star_text_image') ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _reviewImageCountController,
                labelText: '사진 최소 개수 *',
                hintText: '1',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_reviewType == 'star_text_image') {
                    if (value == null || value.isEmpty) {
                      return '필수 입력';
                    }
                    final count = int.tryParse(value);
                    if (count == null || count <= 0) {
                      return '1개 이상 입력해주세요';
                    }
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 16),
            CustomTextField(
              controller: _reviewRewardController,
              labelText: '리뷰비 *',
              hintText: '1000',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '리뷰비를 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.teal[600]),
                const SizedBox(width: 8),
                const Text(
                  '일정 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '시작 일시 *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDateTime(context, true),
                    controller: _startDateTimeController, // 재사용
                    validator: (value) {
                      if (_startDateTime == null) {
                        return '시작 일시를 선택해주세요';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '종료 일시 *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () => _selectDateTime(context, false),
                    controller: _endDateTimeController, // 재사용
                    validator: (value) {
                      if (_endDateTime == null) {
                        return '종료 일시를 선택해주세요';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _maxParticipantsController,
              labelText: '모집 인원 *',
              hintText: '10',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '모집 인원을 입력해주세요';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return '올바른 인원수를 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      // ignore: use_build_context_synchronously
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          0, // 분은 0으로 고정 (시까지만)
        );

        setState(() {
          if (isStart) {
            _startDateTime = dateTime;
            if (_endDateTime != null &&
                _startDateTime!.isAfter(_endDateTime!)) {
              _endDateTime = _startDateTime!.add(const Duration(days: 7));
            }
          } else {
            _endDateTime = dateTime;
          }
          _updateDateTimeControllers(); // 컨트롤러 업데이트
        });
      }
    }
  }

  Widget _buildDuplicatePreventSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text(
                  '중복 방지 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('상품 중복 금지'),
              subtitle: const Text('동일 상품에 대한 중복 참여 방지'),
              value: _preventProductDuplicate,
              onChanged: (value) {
                setState(() {
                  _preventProductDuplicate = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('스토어 중복 금지'),
              subtitle: const Text('동일 스토어에 대한 중복 참여 방지'),
              value: _preventStoreDuplicate,
              onChanged: (value) {
                setState(() {
                  _preventStoreDuplicate = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _duplicateCheckDaysController,
              labelText: '며칠 내 중복 금지',
              hintText: '0 (0이면 비활성화)',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '일수를 입력해주세요';
                }
                final days = int.tryParse(value);
                if (days == null || days < 0) {
                  return '올바른 일수를 입력해주세요 (0 이상)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSection() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  '비용 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentType,
              decoration: const InputDecoration(
                labelText: '비용 지급 방법 *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'platform',
                  child: Text('플랫폼 지급 (결제금액 + 리뷰비 + 500)'),
                ),
                DropdownMenuItem(
                  value: 'direct',
                  child: Text('직접 지급 (500 × 신청인원)'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentType = value!;
                  _calculateCost();
                });
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '회사 지갑 잔액',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      _isLoadingBalance
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              '${_formattedBalance} P',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '예상 총 비용',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formattedTotalCost} P',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('잔여 금액'),
                      Text(
                        '${_formattedRemaining} P',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _totalCost <= _currentBalance
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  if (_totalCost > _currentBalance) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '잔액이 부족합니다. 포인트를 충전해주세요.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreateCampaign() {
    final productName = _productNameController.text.trim();
    final maxParticipants = _maxParticipantsController.text;

    return productName.isNotEmpty &&
        _startDateTime != null &&
        _endDateTime != null &&
        _totalCost <= _currentBalance &&
        (int.tryParse(maxParticipants) ?? 0) > 0;
  }

  // DateTime 컨트롤러 업데이트 헬퍼
  void _updateDateTimeControllers() {
    _startDateTimeController.text = _startDateTime != null
        ? '${_startDateTime!.year}-${_startDateTime!.month.toString().padLeft(2, '0')}-${_startDateTime!.day.toString().padLeft(2, '0')} ${_startDateTime!.hour.toString().padLeft(2, '0')}:00'
        : '';

    _endDateTimeController.text = _endDateTime != null
        ? '${_endDateTime!.year}-${_endDateTime!.month.toString().padLeft(2, '0')}-${_endDateTime!.day.toString().padLeft(2, '0')} ${_endDateTime!.hour.toString().padLeft(2, '0')}:00'
        : '';
  }
}

// Isolate에서 사용할 이미지 크롭 파라미터 클래스
class _CropImageParams {
  final Uint8List imageBytes;
  final int x;
  final int y;
  final int width;
  final int height;

  _CropImageParams({
    required this.imageBytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

// Isolate에서 사용할 크롭 좌표 정규화 파라미터 클래스
class _NormalizeCropParams {
  final Uint8List imageBytes;
  final int x;
  final int y;
  final int width;
  final int height;

  _NormalizeCropParams({
    required this.imageBytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
