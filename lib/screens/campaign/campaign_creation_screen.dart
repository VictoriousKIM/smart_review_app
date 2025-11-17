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
import '../../services/cloudflare_workers_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../config/supabase_config.dart';
import '../../utils/error_handler.dart';

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

  // ✅ 6. 이미지 캐싱
  final Map<String, Uint8List> _imageCache = {};

  // 이미지 관련
  Uint8List? _capturedImage;
  Uint8List? _productImage;
  Rect? _currentCropRect;
  bool _isAnalyzing = false;
  bool _isLoadingImage = false;
  bool _isEditingImage = false;
  bool _isCreatingCampaign = false;
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;
  String? _lastCampaignCreationId; // 중복 호출 방지용

  // 컨트롤러들
  final _keywordController = TextEditingController();
  final _productNameController = TextEditingController();
  final _optionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _sellerController = TextEditingController();
  final _productNumberController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _reviewRewardController = TextEditingController();
  final _reviewTextLengthController = TextEditingController(text: '100');
  final _reviewImageCountController = TextEditingController(text: '1');
  final _maxParticipantsController = TextEditingController(text: '10');
  final _duplicateCheckDaysController = TextEditingController(text: '0');
  final _productProvisionOtherController = TextEditingController();

  // 선택 필드
  String _campaignType = 'reviewer';
  String _platform = 'coupang';
  String _paymentType = 'platform';
  String _purchaseMethod = 'mobile'; // ✅ 추가: 구매방법 선택
  String _productProvisionType = 'delivery'; // ✅ 필수, 초기값: 실배송
  String _productProvisionOther = '';
  bool _onlyAllowedReviewers = true;
  String _reviewType = 'star_only';
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  bool _preventProductDuplicate = false;
  bool _preventStoreDuplicate = false;

  // 비용 및 잔액
  int _totalCost = 0;
  int _currentBalance = 0;
  bool _isLoadingBalance = false;

  String? _errorMessage;

  // ✅ 5. 비용 계산 디바운싱
  Timer? _costCalculationTimer;
  bool _ignoreCostListeners = false;

  // ✅ 9. Throttle
  Timer? _throttleTimer;
  bool _throttleActive = false;

  // DateTime 컨트롤러
  late final TextEditingController _startDateTimeController;
  late final TextEditingController _endDateTimeController;

  // ✅ 5. 포맷팅 캐싱
  String? _cachedFormattedBalance;
  String? _cachedFormattedTotalCost;
  String? _cachedFormattedRemaining;

  // ✅ 1. initState 최적화 - 단계별 초기화
  @override
  void initState() {
    super.initState();

    // 가벼운 작업만 동기 실행
    _startDateTimeController = TextEditingController();
    _endDateTimeController = TextEditingController();

    // 무거운 작업은 프레임 렌더링 후 단계별 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeInStages();
    });
  }

  // ✅ 1. 단계별 초기화 (우선순위별 로딩)
  Future<void> _initializeInStages() async {
    if (!mounted) return;

    // 1단계: 즉시 필요한 데이터 (최우선 - 사용자에게 보이는 정보)
    await _loadCompanyBalance();

    // 2단계: UI 인터랙션 준비 (중요 - 입력 필드 리스너)
    await Future.microtask(() {
      if (mounted) _setupCostListeners();
    });

    // 3단계: 부가 기능 (나중에 - 초기 화면에 영향 없음)
    await Future.microtask(() {
      if (mounted) {
        _updateDateTimeControllers();
        _calculateCost(); // 초기 비용 계산
      }
    });
  }

  @override
  void dispose() {
    _costCalculationTimer?.cancel();
    _throttleTimer?.cancel();
    _imageCache.clear(); // ✅ 6. 캐시 정리

    // 컨트롤러 정리
    _keywordController.dispose();
    _productNameController.dispose();
    _optionController.dispose();
    _quantityController.dispose();
    _sellerController.dispose();
    _productNumberController.dispose();
    _paymentAmountController.dispose();
    _reviewRewardController.dispose();
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
    _paymentAmountController.addListener(_calculateCostDebounced);
    _reviewRewardController.addListener(_calculateCostDebounced);
    _maxParticipantsController.addListener(_calculateCostDebounced);
  }

  // ✅ 5. 디바운싱된 비용 계산
  void _calculateCostDebounced() {
    if (_ignoreCostListeners) return;
    _costCalculationTimer?.cancel();
    _costCalculationTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _calculateCost();
    });
  }

  Future<void> _loadCompanyBalance() async {
    // 즉시 로딩 상태만 표시
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
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
          if (pendingBalance != null) {
            _currentBalance = pendingBalance;
            _cachedFormattedBalance = null; // 캐시 무효화
            _cachedFormattedRemaining = null;
          }
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
        });
      }
    }
  }

  // ✅ 5. 비용 계산 최적화 (값 변경 시만 setState)
  void _calculateCost() {
    final paymentAmount = int.tryParse(_paymentAmountController.text) ?? 0;
    final reviewReward = int.tryParse(_reviewRewardController.text) ?? 0;
    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 1;

    int cost = 0;
    if (_paymentType == 'platform') {
      cost = (paymentAmount + reviewReward + 500) * maxParticipants;
    } else {
      cost = 500 * maxParticipants;
    }

    // ✅ 값이 변경되었을 때만 setState
    if (_totalCost != cost) {
      _totalCost = cost;

      // ✅ 포맷팅 캐싱 (매번 계산하지 않음)
      _cachedFormattedBalance = _formatNumber(_currentBalance);
      _cachedFormattedTotalCost = _formatNumber(_totalCost);
      _cachedFormattedRemaining = _formatNumber(_currentBalance - _totalCost);

      if (mounted) {
        setState(() {}); // 빈 setState (UI만 갱신)
      }
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String get _formattedBalance =>
      _cachedFormattedBalance ?? _formatNumber(_currentBalance);
  String get _formattedTotalCost =>
      _cachedFormattedTotalCost ?? _formatNumber(_totalCost);
  String get _formattedRemaining =>
      _cachedFormattedRemaining ?? _formatNumber(_currentBalance - _totalCost);

  // ✅ 2. 이미지 선택 최적화 (즉각적인 UI 피드백)
  Future<void> _pickImage() async {
    // 즉시 로딩 상태만 표시 (동기 실행)
    setState(() {
      _isLoadingImage = true;
      _errorMessage = null;
    });

    // UI 업데이트 후 비동기 작업 실행
    Future.microtask(() async {
      Uint8List? pendingImageBytes;
      String? pendingErrorMessage;

      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1920,
        );

        if (image != null) {
          final bytes = await image.readAsBytes();

          if (bytes.length > 5 * 1024 * 1024) {
            pendingErrorMessage = '이미지 크기가 너무 큽니다. (최대 5MB)';
          } else {
            // ✅ 6. 캐시 확인 후 리사이징
            pendingImageBytes = await _getCachedOrResizeImage(bytes);
          }
        }
      } catch (e) {
        pendingErrorMessage = '이미지 선택 실패: $e';
      }

      if (mounted) {
        setState(() {
          _isLoadingImage = false;
          if (pendingImageBytes != null) {
            _capturedImage = pendingImageBytes;
            _productImage = null;
            _currentCropRect = null;
            _errorMessage = null;
          }
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
        });
      }
    });
  }

  // ✅ 6. 이미지 캐싱 (중복 처리 방지)
  Future<Uint8List> _getCachedOrResizeImage(Uint8List originalBytes) async {
    final key = '${originalBytes.lengthInBytes}_${originalBytes.hashCode}';

    if (_imageCache.containsKey(key)) {
      print('✅ 캐시된 이미지 사용');
      return _imageCache[key]!;
    }

    print('🔄 이미지 리사이징 시작...');
    final resized = await compute(
      _resizeImageInIsolate,
      _ResizeImageParams(
        imageBytes: originalBytes,
        maxWidth: 1920,
        maxHeight: 1920,
        quality: 85,
      ),
    );

    _imageCache[key] = resized;
    return resized;
  }

  // ✅ 3. 이미지 분석 최적화 (백그라운드 처리)
  Future<void> _extractFromImage() async {
    if (_capturedImage == null) {
      setState(() => _errorMessage = '먼저 이미지를 선택해주세요.');
      return;
    }

    // 즉시 로딩 표시
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    // 비동기 작업을 마이크로태스크로 분리
    Future.microtask(() async {
      String? pendingErrorMessage;
      Map<String, dynamic>? pendingExtractedData;

      try {
        final extractedData = await _campaignImageService.extractFromImage(
          _capturedImage!,
        );

        if (extractedData != null) {
          pendingExtractedData = extractedData;

          // ✅ 플래그로 리스너 무시 (불필요한 비용 계산 방지)
          _ignoreCostListeners = true;

          _keywordController.text = extractedData['keyword'] ?? '';
          _productNameController.text = extractedData['title'] ?? '';
          _optionController.text = extractedData['option'] ?? '';
          _quantityController.text = (extractedData['quantity'] ?? 1)
              .toString();
          _sellerController.text = extractedData['seller'] ?? '';
          _productNumberController.text = extractedData['productNumber'] ?? '';
          _paymentAmountController.text =
              (extractedData['productPrice'] ??
                      extractedData['paymentAmount'] ??
                      0)
                  .toString();

          _ignoreCostListeners = false;
          _calculateCost();

          // ✅ 크롭 작업은 별도로 비동기 실행 (UI 블로킹 방지)
          final cropData = extractedData['productImageCrop'];
          if (cropData != null) {
            _processCropInBackground(cropData);
          } else {
            if (mounted) {
              setState(() => _productImage = _capturedImage);
            }
          }
        } else {
          pendingErrorMessage = '이미지에서 정보를 추출할 수 없습니다.';
        }
      } catch (e) {
        pendingErrorMessage = '이미지 분석 실패: $e';
      }

      // 분석 완료 상태 업데이트
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (pendingErrorMessage != null) {
            _errorMessage = pendingErrorMessage;
          }
        });

        // 성공 메시지는 별도로
        if (pendingExtractedData != null && pendingErrorMessage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 분석 완료!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  // ✅ 3. 크롭 작업을 백그라운드에서 실행 (UI와 독립적)
  Future<void> _processCropInBackground(Map<String, dynamic> cropData) async {
    try {
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
        _currentCropRect = Rect.fromLTWH(
          normalizedResult['normalizedX']!.toDouble(),
          normalizedResult['normalizedY']!.toDouble(),
          normalizedResult['normalizedWidth']!.toDouble(),
          normalizedResult['normalizedHeight']!.toDouble(),
        );

        // 크롭 작업도 비동기로
        await _cropProductImage(
          _capturedImage!,
          normalizedResult['normalizedX']!,
          normalizedResult['normalizedY']!,
          normalizedResult['normalizedWidth']!,
          normalizedResult['normalizedHeight']!,
        );
      }
    } catch (e) {
      print('⚠️ 백그라운드 크롭 처리 실패: $e');
      if (mounted) {
        setState(() => _productImage = _capturedImage);
      }
    }
  }

  Future<void> _cropProductImage(
    Uint8List imageBytes,
    int x,
    int y,
    int width,
    int height,
  ) async {
    try {
      print('🔧 크롭 작업 시작: x=$x, y=$y, w=$width, h=$height');

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

      print('✅ 크롭 완료: ${cropWidth}x${cropHeight}');

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
      }
    } catch (e, stackTrace) {
      print('❌ 크롭 실패: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _productImage = imageBytes;
          _errorMessage = '이미지 크롭 실패: $e';
        });
      }
    }
  }

  static Map<String, dynamic>? _cropImageInIsolate(_CropImageParams params) {
    try {
      final originalImage = img.decodeImage(params.imageBytes);
      if (originalImage == null) return null;

      final imageWidth = originalImage.width;
      final imageHeight = originalImage.height;

      int cropX = params.x.clamp(0, imageWidth - 1);
      int cropY = params.y.clamp(0, imageHeight - 1);
      int cropWidth = params.width.clamp(1, imageWidth - cropX);
      int cropHeight = params.height.clamp(1, imageHeight - cropY);

      if (cropWidth < 10 || cropHeight < 10) return null;

      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

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
      print('❌ Isolate 크롭 실패: $e');
      return null;
    }
  }

  static Map<String, int>? _normalizeCropCoordinates(
    _NormalizeCropParams params,
  ) {
    try {
      final image = img.decodeImage(params.imageBytes);
      if (image == null) return null;

      final actualWidth = image.width;
      final actualHeight = image.height;

      int normalizedX = params.x.clamp(0, actualWidth - 1);
      int normalizedY = params.y.clamp(0, actualHeight - 1);
      int normalizedWidth = params.width.clamp(1, actualWidth - normalizedX);
      int normalizedHeight = params.height.clamp(1, actualHeight - normalizedY);

      return {
        'normalizedX': normalizedX,
        'normalizedY': normalizedY,
        'normalizedWidth': normalizedWidth,
        'normalizedHeight': normalizedHeight,
      };
    } catch (e) {
      print('❌ 크롭 좌표 정규화 실패: $e');
      return null;
    }
  }

  // ✅ 9. Throttle 헬퍼 함수
  void _throttle(
    VoidCallback action, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    if (_throttleActive) return;

    _throttleActive = true;
    action();

    _throttleTimer?.cancel();
    _throttleTimer = Timer(duration, () {
      _throttleActive = false;
    });
  }

  // ✅ 9. Throttle 적용한 이미지 편집
  Future<void> _editProductImage() async {
    _throttle(() async {
      if (_capturedImage == null) {
        setState(() => _errorMessage = '먼저 이미지를 선택해주세요.');
        return;
      }

      setState(() {
        _isEditingImage = true;
        _errorMessage = null;
      });

      String? pendingErrorMessage;
      Uint8List? pendingProductImage;
      bool webDialogShown = false;

      try {
        if (kIsWeb) {
          await _showWebCropDialog();
          webDialogShown = true;
          if (mounted) {
            setState(() => _isEditingImage = false);
          }
          return;
        }

        final tempDir = Directory.systemTemp;
        File? tempFile;

        try {
          tempFile = File(
            '${tempDir.path}/temp_crop_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await tempFile.writeAsBytes(_capturedImage!);

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
          try {
            if (tempFile != null && await tempFile.exists()) {
              await tempFile.delete();
            }
          } catch (e) {
            print('⚠️ 임시 파일 삭제 실패: $e');
          }
        }
      } catch (e) {
        print('❌ 이미지 크롭 실패: $e');
        pendingErrorMessage = '이미지 편집 실패: $e';

        if (kIsWeb && !webDialogShown) {
          try {
            await _showWebCropDialog();
            pendingErrorMessage = null;
          } catch (e2) {
            pendingErrorMessage = '이미지 편집 실패: $e2';
          }
        }
      } finally {
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
    });
  }

  Future<void> _showWebCropDialog() async {
    if (_capturedImage == null) return;

    final originalImage = await compute(_decodeImageInIsolate, _capturedImage!);
    if (originalImage == null) {
      if (mounted) {
        setState(() => _errorMessage = '이미지 디코딩에 실패했습니다.');
      }
      return;
    }

    final imgWidth = originalImage.width;
    final imgHeight = originalImage.height;

    Rect? initialCrop =
        _currentCropRect ??
        Rect.fromLTWH(0, 0, imgWidth / 2, imgHeight.toDouble());

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => ImageCropEditor(
        imageBytes: _capturedImage!,
        decodedImage: originalImage,
        initialCrop: initialCrop,
      ),
    );

    if (result == null || _capturedImage == null) return;

    if (result['width']! <= 0 || result['height']! <= 0) {
      setState(() => _errorMessage = '유효하지 않은 크롭 영역입니다');
      return;
    }

    _currentCropRect = Rect.fromLTWH(
      result['x']!.toDouble(),
      result['y']!.toDouble(),
      result['width']!.toDouble(),
      result['height']!.toDouble(),
    );

    await _cropProductImage(
      _capturedImage!,
      result['x']!,
      result['y']!,
      result['width']!,
      result['height']!,
    );
  }

  // 상품 이미지 업로드 (Presigned URL 방식) - 재시도 로직 포함
  Future<String?> _uploadProductImage(
    Uint8List imageBytes, {
    int maxRetries = 3,
    bool showRetryDialog = true,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        setState(() {
          _isUploadingImage = true;
          _uploadProgress = 0.0;
          _errorMessage = null;
        });

        final user = SupabaseConfig.client.auth.currentUser;
        if (user == null) {
          throw Exception('로그인이 필요합니다.');
        }

        // 파일명 생성
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'product_${timestamp}.jpg';

        // 1. Presigned URL 요청
        setState(() {
          _uploadProgress = 0.1;
        });

        final presignedUrlResponse =
            await CloudflareWorkersService.getPresignedUrl(
              fileName: fileName,
              userId: user.id,
              contentType: 'image/jpeg',
              fileType: 'campaign-images',
              method: 'PUT',
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Presigned URL 요청 시간 초과');
              },
            );

        if (!presignedUrlResponse.success) {
          throw Exception('Presigned URL 생성 실패');
        }

        // 2. Presigned URL로 R2에 직접 업로드
        setState(() {
          _uploadProgress = 0.3;
        });

        await CloudflareWorkersService.uploadToPresignedUrl(
          presignedUrl: presignedUrlResponse.url,
          fileBytes: imageBytes,
          contentType: 'image/jpeg',
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('이미지 업로드 시간 초과');
          },
        );

        // 3. Public URL 생성 (Cloudflare Workers를 통해 제공)
        // R2 Public URL은 직접 접근이 안 될 수 있으므로 Workers를 통해 제공
        final publicUrl =
            '${SupabaseConfig.workersApiUrl}/api/files/${presignedUrlResponse.filePath}';

        setState(() {
          _uploadProgress = 1.0;
          _isUploadingImage = false;
        });

        return publicUrl;
      } catch (e) {
        // 에러 타입 감지 및 로깅
        final errorType = ErrorHandler.detectErrorType(e);
        ErrorHandler.handleNetworkError(
          e,
          context: {
            'operation': 'upload_product_image',
            'attempt': attempt,
            'maxRetries': maxRetries,
          },
        );

        // 사용자 친화적 에러 메시지 생성
        final userFriendlyMessage = ErrorHandler.getUserFriendlyMessage(
          errorType,
          e.toString(),
        );

        // 재시도 불가능한 에러인 경우 즉시 종료
        if (_isNonRetryableError(e)) {
          setState(() {
            _errorMessage = userFriendlyMessage;
            _isUploadingImage = false;
          });
          return null;
        }

        // 마지막 시도인 경우
        if (attempt >= maxRetries) {
          setState(() {
            _errorMessage = userFriendlyMessage;
            _isUploadingImage = false;
          });
          return null;
        }

        // 재시도 가능한 경우 다이얼로그 표시
        if (showRetryDialog && mounted) {
          final shouldRetry = await _showRetryDialog(
            context,
            userFriendlyMessage,
            attempt,
            maxRetries,
          );

          if (!shouldRetry) {
            // 사용자가 취소
            setState(() {
              _isUploadingImage = false;
            });
            return null;
          }
        }

        // 재시도 전 대기 (지수 백오프)
        setState(() {
          _uploadProgress = 0.0;
        });
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    setState(() {
      _isUploadingImage = false;
    });
    return null;
  }

  // 재시도 불가능한 에러인지 확인
  bool _isNonRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // 인증 에러는 재시도 불가
    if (errorString.contains('unauthorized') ||
        errorString.contains('로그인이 필요') ||
        errorString.contains('auth')) {
      return true;
    }

    // 잘못된 요청은 재시도 불가
    if (errorString.contains('bad request') ||
        errorString.contains('400') ||
        errorString.contains('invalid')) {
      return true;
    }

    return false;
  }

  // 재시도 다이얼로그 표시
  Future<bool> _showRetryDialog(
    BuildContext context,
    String errorMessage,
    int currentAttempt,
    int maxRetries,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('업로드 실패'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorMessage),
                  const SizedBox(height: 16),
                  Text(
                    '시도 횟수: $currentAttempt / $maxRetries',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '다시 시도하시겠습니까?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _createCampaign() async {
    // ✅ 즉시 체크 (setState 전에) - 중복 호출 방지
    if (_isCreatingCampaign) {
      debugPrint('⚠️ 캠페인 생성이 이미 진행 중입니다.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_totalCost > _currentBalance) {
      setState(() {
        _errorMessage =
            '잔액이 부족합니다. 필요: ${_totalCost}P, 현재: ${_currentBalance}P';
      });
      return;
    }

    // ✅ 생성 시도 ID 생성 (중복 방지용)
    final creationId = DateTime.now().millisecondsSinceEpoch.toString();
    if (_lastCampaignCreationId == creationId) {
      debugPrint('⚠️ 동일한 생성 시도가 감지되었습니다.');
      return;
    }
    _lastCampaignCreationId = creationId;

    // ✅ 즉시 플래그 설정 (setState 전에)
    _isCreatingCampaign = true;

    setState(() {
      _isCreatingCampaign = true;
      _errorMessage = null;
    });

    try {
      // ✅ 이미지 업로드
      String? productImageUrl;
      if (_productImage != null) {
        productImageUrl = await _uploadProductImage(_productImage!);
        if (productImageUrl == null) {
          // 업로드 실패 시 생성 중단
          setState(() {
            _isCreatingCampaign = false;
          });
          return;
        }
      } else if (_capturedImage != null) {
        productImageUrl = await _uploadProductImage(_capturedImage!);
        if (productImageUrl == null) {
          setState(() {
            _isCreatingCampaign = false;
          });
          return;
        }
      }

      // ✅ review_type에 따른 값 설정
      int? reviewTextLength;
      int? reviewImageCount;

      if (_reviewType == 'star_only') {
        reviewTextLength = null;
        reviewImageCount = null;
      } else if (_reviewType == 'star_text') {
        reviewTextLength = int.tryParse(_reviewTextLengthController.text);
        if (reviewTextLength == null || reviewTextLength <= 0) {
          setState(() {
            _errorMessage = '리뷰 텍스트 최소 글자 수를 입력해주세요';
            _isCreatingCampaign = false;
          });
          return;
        }
        reviewImageCount = null;
      } else if (_reviewType == 'star_text_image') {
        reviewTextLength = int.tryParse(_reviewTextLengthController.text);
        reviewImageCount = int.tryParse(_reviewImageCountController.text);
        if (reviewTextLength == null || reviewTextLength <= 0) {
          setState(() {
            _errorMessage = '리뷰 텍스트 최소 글자 수를 입력해주세요';
            _isCreatingCampaign = false;
          });
          return;
        }
        if (reviewImageCount == null || reviewImageCount <= 0) {
          setState(() {
            _errorMessage = '사진 최소 개수를 입력해주세요';
            _isCreatingCampaign = false;
          });
          return;
        }
      }

      final response = await _campaignService.createCampaignV2(
        title: _productNameController.text.trim(),
        description: '', // ✅ product_description 제거
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
        productName: _productNameController.text.trim(), // ✅ 추가
        productPrice:
            int.tryParse(_paymentAmountController.text) ??
            0, // ✅ paymentAmount를 productPrice로 변경
        reviewType: _reviewType,
        reviewTextLength: reviewTextLength, // ✅ NULL 가능
        reviewImageCount: reviewImageCount, // ✅ NULL 가능
        preventProductDuplicate: _preventProductDuplicate,
        preventStoreDuplicate: _preventStoreDuplicate,
        duplicatePreventDays:
            int.tryParse(_duplicateCheckDaysController.text) ?? 0,
        paymentMethod: _paymentType,
        productImageUrl: productImageUrl,
        purchaseMethod: _purchaseMethod, // ✅ 추가
      );

      if (response.success) {
        // ✅ 성공 시 즉시 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '캠페인이 생성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          // pushNamed().then() 패턴: 생성된 캠페인 ID를 전달하여 상위 화면에서 직접 조회
          final campaignId = response.data?.id;
          context.pop(campaignId); // 생성된 캠페인 ID를 반환
        }
      } else {
        // ✅ 에러 시에도 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        setState(() {
          _errorMessage = response.error ?? '캠페인 생성에 실패했습니다.';
        });
      }
    } catch (e) {
      // ✅ 예외 시에도 플래그 해제
      _isCreatingCampaign = false;
      _lastCampaignCreationId = null;

      setState(() {
        _errorMessage = '예상치 못한 오류: $e';
      });
    } finally {
      // ✅ 최종적으로 플래그 해제
      if (mounted) {
        setState(() {
          _isCreatingCampaign = false;
        });
      }
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

              RepaintBoundary(child: _buildCampaignTypeSection()),
              const SizedBox(height: 24),

              RepaintBoundary(child: _buildImageSection()),
              const SizedBox(height: 24),

              if (_productImage != null || _capturedImage != null) ...[
                RepaintBoundary(child: _buildProductImageSection()),
                const SizedBox(height: 24),
              ],

              RepaintBoundary(child: _buildProductInfoSection()),
              const SizedBox(height: 24),

              RepaintBoundary(child: _buildReviewSettings()),
              const SizedBox(height: 24),

              RepaintBoundary(child: _buildScheduleSection()),
              const SizedBox(height: 24),

              RepaintBoundary(child: _buildDuplicatePreventSection()),
              const SizedBox(height: 24),

              RepaintBoundary(child: _buildCostSection()),
              const SizedBox(height: 24),

              if (_isUploadingImage) ...[
                RepaintBoundary(child: _buildUploadProgressSection()),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 32),

              RepaintBoundary(
                child: AbsorbPointer(
                  absorbing:
                      !_canCreateCampaign() ||
                      _isCreatingCampaign ||
                      _isUploadingImage,
                  child: Opacity(
                    opacity:
                        (_canCreateCampaign() &&
                            !_isCreatingCampaign &&
                            !_isUploadingImage)
                        ? 1.0
                        : 0.6,
                    child: CustomButton(
                      text: '캠페인 생성하기',
                      onPressed:
                          _canCreateCampaign() &&
                              !_isCreatingCampaign &&
                              !_isUploadingImage
                          ? () {
                              // 중복 호출 방지: 즉시 체크
                              if (_isCreatingCampaign) {
                                debugPrint('⚠️ 캠페인 생성이 이미 진행 중입니다.');
                                return;
                              }
                              _createCampaign();
                            }
                          : null,
                      isLoading: _isCreatingCampaign || _isUploadingImage,
                      backgroundColor: const Color(0xFF137fec),
                      textColor: Colors.white,
                    ),
                  ),
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
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_capturedImage!, fit: BoxFit.contain),
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
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(displayImage, fit: BoxFit.contain),
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
              ],
              onChanged: null, // 변경 불가능하게 설정
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
              onChanged: null, // 변경 불가능하게 설정
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
            CustomTextField(controller: _keywordController, labelText: '키워드'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _productNameController,
              labelText: '제품명 *',
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
            CustomTextField(controller: _sellerController, labelText: '판매자'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _productNumberController,
              labelText: '상품번호',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _paymentAmountController,
              labelText: '상품가격 *',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '상품가격을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _purchaseMethod,
              decoration: const InputDecoration(
                labelText: '구매방법 *',
                border: OutlineInputBorder(),
                helperText: '상품 구매 시 사용할 방법을 선택하세요',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'mobile',
                  child: Row(
                    children: [
                      Icon(Icons.smartphone, size: 20),
                      SizedBox(width: 8),
                      Text('모바일'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'pc',
                  child: Row(
                    children: [
                      Icon(Icons.computer, size: 20),
                      SizedBox(width: 8),
                      Text('PC'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _purchaseMethod = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '구매방법을 선택해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _productProvisionType,
              decoration: const InputDecoration(
                labelText: '상품제공여부 *',
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
                  _productProvisionType = value!;
                  if (value != 'other') {
                    _productProvisionOther = '';
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '상품제공여부를 선택해주세요';
                }
                return null;
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
            // ✅ product_description 필드 제거됨
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
              labelText: '리뷰비',
              hintText: '선택사항, 미입력 시 0',
              keyboardType: TextInputType.number,
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
                    controller: _startDateTimeController,
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
                    controller: _endDateTimeController,
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
          0,
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
          _updateDateTimeControllers();
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

  Widget _buildUploadProgressSection() {
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
                Icon(Icons.cloud_upload, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  '이미지 업로드 중',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              backgroundColor: Colors.blue[100],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
            const SizedBox(height: 8),
            Text(
              _uploadProgress > 0
                  ? '업로드 진행 중... (${(_uploadProgress * 100).toStringAsFixed(0)}%)'
                  : '업로드 준비 중...',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
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
                              '$_formattedBalance P',
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
                        '$_formattedTotalCost P',
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
                        '$_formattedRemaining P',
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
        (int.tryParse(maxParticipants) ?? 0) > 0 &&
        !_isUploadingImage &&
        !_isCreatingCampaign; // ✅ 중복 호출 방지
  }

  void _updateDateTimeControllers() {
    _startDateTimeController.text = _startDateTime != null
        ? '${_startDateTime!.year}-${_startDateTime!.month.toString().padLeft(2, '0')}-${_startDateTime!.day.toString().padLeft(2, '0')} ${_startDateTime!.hour.toString().padLeft(2, '0')}:00'
        : '';

    _endDateTimeController.text = _endDateTime != null
        ? '${_endDateTime!.year}-${_endDateTime!.month.toString().padLeft(2, '0')}-${_endDateTime!.day.toString().padLeft(2, '0')} ${_endDateTime!.hour.toString().padLeft(2, '0')}:00'
        : '';
  }

  static img.Image? _decodeImageInIsolate(Uint8List imageBytes) {
    try {
      return img.decodeImage(imageBytes);
    } catch (e) {
      print('❌ Isolate 이미지 디코딩 실패: $e');
      return null;
    }
  }

  static Uint8List _resizeImageInIsolate(_ResizeImageParams params) {
    try {
      final originalImage = img.decodeImage(params.imageBytes);
      if (originalImage == null) {
        print('❌ 이미지 디코딩 실패, 원본 반환');
        return params.imageBytes;
      }

      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;

      if (originalWidth <= params.maxWidth &&
          originalHeight <= params.maxHeight) {
        return params.imageBytes;
      }

      double scale = 1.0;
      if (originalWidth > params.maxWidth) {
        scale = params.maxWidth / originalWidth;
      }
      if (originalHeight > params.maxHeight) {
        final heightScale = params.maxHeight / originalHeight;
        if (heightScale < scale) {
          scale = heightScale;
        }
      }

      final newWidth = (originalWidth * scale).round();
      final newHeight = (originalHeight * scale).round();

      final resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      final resizedBytes = Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: params.quality),
      );

      print(
        '✅ 이미지 리사이징: ${originalWidth}x${originalHeight} -> ${newWidth}x${newHeight}',
      );

      return resizedBytes;
    } catch (e) {
      print('❌ 리사이징 실패: $e, 원본 반환');
      return params.imageBytes;
    }
  }
}

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

class _ResizeImageParams {
  final Uint8List imageBytes;
  final int maxWidth;
  final int maxHeight;
  final int quality;

  _ResizeImageParams({
    required this.imageBytes,
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });
}
