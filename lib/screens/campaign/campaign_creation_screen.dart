import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:shimmer/shimmer.dart';
import '../../services/campaign_image_service.dart';
import '../../widgets/image_crop_editor.dart';
import '../../services/campaign_service.dart';
import '../../services/wallet_service.dart';
import '../../services/cloudflare_workers_service.dart';
import '../../services/company_user_service.dart';
import '../../services/campaign_default_schedule_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../config/supabase_config.dart';
import '../../utils/error_handler.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/keyword_utils.dart';

/// 리뷰 키워드 입력 제한 Formatter
/// 키워드 3개 이내, 총 20자 이내로 제한
class _ReviewKeywordInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;

    // 빈 값은 허용
    if (newText.trim().isEmpty) {
      return newValue;
    }

    // 정규화된 텍스트로 검증
    final normalized = KeywordUtils.normalizeKeywords(newText);
    final keywords = KeywordUtils.parseKeywords(normalized);
    final textLength = normalized.length;

    // 키워드 개수 제한 (3개 초과 시 입력 거부)
    if (keywords.length > 3) {
      return oldValue; // 이전 값 유지
    }

    // 총 길이 제한 (20자 초과 시 입력 거부)
    if (textLength > 20) {
      return oldValue; // 이전 값 유지
    }

    return newValue; // 허용된 입력
  }
}

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
  final _campaignRewardController = TextEditingController();
  final _reviewTextLengthController = TextEditingController(text: '100');
  final _reviewImageCountController = TextEditingController(text: '1');
  final _maxParticipantsController = TextEditingController(text: '10');
  final _maxPerReviewerController = TextEditingController(text: '1');
  final _duplicateCheckDaysController = TextEditingController(text: '0');
  final _productProvisionOtherController = TextEditingController();

  // 선택 필드
  String _campaignType = 'store';
  String _platform = 'coupang';
  String _paymentType = 'direct';
  String _purchaseMethod = 'mobile'; // ✅ 추가: 구매방법 선택
  String _productProvisionType = 'delivery'; // ✅ 필수, 초기값: 실배송
  String _productProvisionOther = '';
  bool _onlyAllowedReviewers = true;
  String _reviewType = 'star_only';
  DateTime? _applyStartDateTime; // 신청 시작일시
  DateTime? _applyEndDateTime; // 신청 종료일시
  DateTime? _reviewStartDateTime; // 리뷰 시작일시
  DateTime? _reviewEndDateTime; // 리뷰 종료일시
  bool _preventProductDuplicate = false;
  bool _preventStoreDuplicate = false;
  // 리뷰 키워드 관련
  bool _useReviewKeywords = false;
  final _reviewKeywordsController = TextEditingController();

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
  late final TextEditingController _applyStartDateTimeController;
  late final TextEditingController _applyEndDateTimeController;
  late final TextEditingController _reviewStartDateTimeController;
  late final TextEditingController _reviewEndDateTimeController;

  // ✅ 5. 포맷팅 캐싱
  String? _cachedFormattedBalance;
  String? _cachedFormattedTotalCost;
  String? _cachedFormattedRemaining;

  // ✅ Phase 1.1: 스켈레톤 UI를 위한 초기화 상태
  bool _isInitialized = false;

  // ✅ 1. initState 최적화 - 단계별 초기화
  @override
  void initState() {
    super.initState();

    // 가벼운 작업만 동기 실행
    _applyStartDateTimeController = TextEditingController();
    _applyEndDateTimeController = TextEditingController();
    _reviewStartDateTimeController = TextEditingController();
    _reviewEndDateTimeController = TextEditingController();

    // ✅ Phase 1.2: 더 긴 지연 + 프레임 콜백 조합
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;

        // ✅ 1단계: UI 먼저 표시 (50ms 후)
        setState(() => _isInitialized = true);
        await Future.delayed(const Duration(milliseconds: 50));

        // ✅ 2단계: 기본 일정 로드 및 잔액 로딩 (100ms 후)
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _loadDefaultSchedule();
          _loadCompanyBalance();
        }

        // ✅ 3단계: 리스너 설정 (200ms 후)
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          _ignoreCostListeners = true;
          _setupCostListeners();
          _updateDateTimeControllers();
          _ignoreCostListeners = false;
          _calculateCost();
        }
      });
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
    _campaignRewardController.dispose();
    _reviewTextLengthController.dispose();
    _reviewImageCountController.dispose();
    _reviewKeywordsController.dispose();
    _maxParticipantsController.dispose();
    _duplicateCheckDaysController.dispose();
    _productProvisionOtherController.dispose();
    _applyStartDateTimeController.dispose();
    _applyEndDateTimeController.dispose();
    _reviewStartDateTimeController.dispose();
    _reviewEndDateTimeController.dispose();
    super.dispose();
  }

  void _setupCostListeners() {
    _paymentAmountController.addListener(_calculateCostDebounced);
    _campaignRewardController.addListener(_calculateCostDebounced);
    _maxParticipantsController.addListener(_calculateCostDebounced);
  }

  // ✅ 5. 디바운싱된 비용 계산 - 웹 최적화
  void _calculateCostDebounced() {
    if (_ignoreCostListeners) return;
    _costCalculationTimer?.cancel();
    // 웹에서는 더 긴 디바운싱
    final debounceTime = kIsWeb
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 500);
    _costCalculationTimer = Timer(debounceTime, () {
      if (mounted) _calculateCost();
    });
  }

  /// 기본 일정 설정 로드 및 적용
  Future<void> _loadDefaultSchedule() async {
    try {
      final defaultDateTimes =
          await CampaignDefaultScheduleService.loadDefaultDateTimes();
      if (mounted) {
        setState(() {
          _applyStartDateTime = defaultDateTimes['applyStart'];
          _applyEndDateTime = defaultDateTimes['applyEnd'];
          _reviewStartDateTime = defaultDateTimes['reviewStart'];
          _reviewEndDateTime = defaultDateTimes['reviewEnd'];
          _updateDateTimeControllers();
        });
      }
    } catch (e) {
      // 에러 발생 시 기본값 사용
      final defaultDateTimes =
          CampaignDefaultScheduleService.getDefaultDateTimes();
      if (mounted) {
        setState(() {
          _applyStartDateTime = defaultDateTimes['applyStart'];
          _applyEndDateTime = defaultDateTimes['applyEnd'];
          _reviewStartDateTime = defaultDateTimes['reviewStart'];
          _reviewEndDateTime = defaultDateTimes['reviewEnd'];
          _updateDateTimeControllers();
        });
      }
    }
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
      // 사용자 ID 가져오기 (Custom JWT 세션 지원)
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) {
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
    final campaignReward = int.tryParse(_campaignRewardController.text) ?? 0;
    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 1;

    int cost = 0;
    if (_paymentType == 'platform') {
      cost = (paymentAmount + campaignReward + 500) * maxParticipants;
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

    // ✅ UI 업데이트가 렌더링될 시간 확보
    await Future.delayed(const Duration(milliseconds: 50));

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
          // 파일 확장자 검증 (이미지 파일만 허용)
          final fileName = image.name.toLowerCase();
          final isValidImage =
              fileName.endsWith('.jpg') ||
              fileName.endsWith('.jpeg') ||
              fileName.endsWith('.png') ||
              fileName.endsWith('.webp');

          if (!isValidImage) {
            pendingErrorMessage = '이미지 파일만 업로드 가능합니다. (JPG, PNG, WEBP)';
          } else {
            final bytes = await image.readAsBytes();

            if (bytes.length > 5 * 1024 * 1024) {
              pendingErrorMessage = '이미지 크기가 너무 큽니다. (최대 5MB)';
            } else {
              // ✅ 원본 이미지를 먼저 표시 (리사이징 전)
              if (mounted) {
                setState(() {
                  _capturedImage = bytes; // 원본 먼저 표시
                  _isLoadingImage = false; // 로딩 해제
                });
              }

              // ✅ 리사이징은 백그라운드에서 처리
              pendingImageBytes = await _getCachedOrResizeImage(bytes);

              // ✅ 리사이징 완료 후 업데이트
              if (mounted && pendingImageBytes != null) {
                setState(() {
                  _capturedImage = pendingImageBytes; // 리사이징된 이미지로 교체
                });
              }
              return; // 리사이징 완료 후 종료
            }
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

  // ✅ 6. 이미지 캐싱 (중복 처리 방지) - 웹 최적화
  Future<Uint8List> _getCachedOrResizeImage(Uint8List originalBytes) async {
    // 웹: 여러 프레임에 걸쳐 처리하여 UI 블로킹 최소화
    if (kIsWeb) {
      // ✅ UI 업데이트를 위한 프레임 확보
      await Future.delayed(const Duration(milliseconds: 16)); // 1프레임
      return _resizeImageDirect(originalBytes, 1920, 1920, 85);
    }

    // 네이티브: 캐싱 사용
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

    // ✅ Step 1: 즉시 로딩 상태 표시 (동기)
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    // ✅ Step 2: UI 업데이트가 렌더링될 시간 확보 (중요!)
    await Future.delayed(const Duration(milliseconds: 50));

    // ✅ Step 3: 비동기 작업을 마이크로태스크로 분리
    Future.microtask(() async {
      String? pendingErrorMessage;
      Map<String, dynamic>? pendingExtractedData;

      try {
        final extractedData = await _campaignImageService.extractFromImage(
          _capturedImage!,
        );

        if (extractedData != null) {
          pendingExtractedData = extractedData;

          // ✅ 배치 업데이트로 setState 최소화
          if (mounted) {
            setState(() {
              _ignoreCostListeners = true;
              _keywordController.text = extractedData['keyword'] ?? '';
              _productNameController.text = extractedData['title'] ?? '';
              _optionController.text = extractedData['option'] ?? '';
              _quantityController.text = (extractedData['quantity'] ?? 1)
                  .toString();
              _sellerController.text = extractedData['seller'] ?? '';
              // 상품번호에서 띄어쓰기 제거
              final productNumber = extractedData['productNumber'] ?? '';
              _productNumberController.text = productNumber
                  .toString()
                  .replaceAll(' ', '');
              _paymentAmountController.text =
                  (extractedData['productPrice'] ??
                          extractedData['paymentAmount'] ??
                          0)
                      .toString();
              _ignoreCostListeners = false;
            });

            // 비용 계산은 별도로
            await Future.microtask(_calculateCost);
          }

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
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  // ✅ 3. 크롭 작업을 백그라운드에서 실행 (UI와 독립적) - 웹 최적화
  Future<void> _processCropInBackground(Map<String, dynamic> cropData) async {
    try {
      final normalizedResult = kIsWeb
          ? await _normalizeCropCoordinatesDirect(
              _capturedImage!,
              cropData['x']?.toInt() ?? 0,
              cropData['y']?.toInt() ?? 0,
              cropData['width']?.toInt() ?? 0,
              cropData['height']?.toInt() ?? 0,
            )
          : await compute(
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

  // ✅ 웹용 직접 이미지 크롭 함수 (프레임 분리 최적화)
  Future<Map<String, dynamic>?> _cropImageDirect(
    Uint8List imageBytes,
    int x,
    int y,
    int width,
    int height,
  ) async {
    try {
      // ✅ Step 1: 이미지 디코딩 (프레임 분리)
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final originalImage = await Future.microtask(
        () => img.decodeImage(imageBytes),
      );
      if (originalImage == null) return null;

      final imageWidth = originalImage.width;
      final imageHeight = originalImage.height;

      int cropX = x.clamp(0, imageWidth - 1);
      int cropY = y.clamp(0, imageHeight - 1);
      int cropWidth = width.clamp(1, imageWidth - cropX);
      int cropHeight = height.clamp(1, imageHeight - cropY);

      if (cropWidth < 10 || cropHeight < 10) return null;

      // ✅ Step 2: 크롭 실행 (프레임 분리)
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final croppedImage = await Future.microtask(
        () => img.copyCrop(
          originalImage,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        ),
      );

      // ✅ Step 3: 인코딩 (프레임 분리)
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final croppedBytes = await Future.microtask(
        () => Uint8List.fromList(img.encodeJpg(croppedImage, quality: 85)),
      );

      return {
        'croppedBytes': croppedBytes,
        'cropX': cropX,
        'cropY': cropY,
        'cropWidth': cropWidth,
        'cropHeight': cropHeight,
      };
    } catch (e) {
      print('❌ 웹 크롭 실패: $e');
      return null;
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

      final cropResult = kIsWeb
          ? await _cropImageDirect(imageBytes, x, y, width, height)
          : await compute(
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

  // ✅ 웹용 직접 크롭 좌표 정규화 함수 (프레임 분리 최적화)
  Future<Map<String, int>?> _normalizeCropCoordinatesDirect(
    Uint8List bytes,
    int x,
    int y,
    int w,
    int h,
  ) async {
    try {
      // ✅ 프레임 분리하여 UI 블로킹 최소화
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final image = await Future.microtask(() => img.decodeImage(bytes));
      if (image == null) return null;

      return {
        'normalizedX': x.clamp(0, image.width - 1),
        'normalizedY': y.clamp(0, image.height - 1),
        'normalizedWidth': w.clamp(1, image.width - x),
        'normalizedHeight': h.clamp(1, image.height - y),
      };
    } catch (e) {
      print('❌ 크롭 좌표 정규화 실패: $e');
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

    // ✅ 즉시 로딩 상태 표시 (UI 업데이트 먼저)
    if (mounted) {
      setState(() {
        _isEditingImage = true;
        _errorMessage = null;
      });
    }

    // ✅ UI가 렌더링될 시간 확보
    await Future.delayed(const Duration(milliseconds: 50));

    // ✅ 이미지 디코딩을 비동기로 처리 (메인 스레드 블로킹 방지)
    img.Image? originalImage;
    try {
      originalImage = await Future.microtask(() {
        return kIsWeb
            ? img.decodeImage(_capturedImage!)
            : null; // 네이티브는 compute 사용
      });

      // 네이티브에서는 compute 사용
      if (!kIsWeb && originalImage == null) {
        originalImage = await compute(_decodeImageInIsolate, _capturedImage!);
      }
    } catch (e) {
      print('❌ 이미지 디코딩 실패: $e');
      if (mounted) {
        setState(() {
          _isEditingImage = false;
          _errorMessage = '이미지 디코딩에 실패했습니다.';
        });
      }
      return;
    }

    if (originalImage == null) {
      if (mounted) {
        setState(() {
          _isEditingImage = false;
          _errorMessage = '이미지 디코딩에 실패했습니다.';
        });
      }
      return;
    }

    final imgWidth = originalImage.width;
    final imgHeight = originalImage.height;

    Rect? initialCrop =
        _currentCropRect ??
        Rect.fromLTWH(0, 0, imgWidth / 2, imgHeight.toDouble());

    // ✅ 로딩 상태 해제 후 다이얼로그 표시
    if (mounted) {
      setState(() => _isEditingImage = false);
    }

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

        // 사용자 ID 가져오기 (Custom JWT 세션 지원)
        final userId = await AuthService.getCurrentUserId();
        if (userId == null) {
          throw Exception('로그인이 필요합니다.');
        }

        // 회사 ID 가져오기
        final companyId = await CompanyUserService.getUserCompanyId(userId);
        if (companyId == null) {
          throw Exception('회사 정보를 찾을 수 없습니다.');
        }

        // 상품명 가져오기
        final productName = _productNameController.text.trim();
        if (productName.isEmpty) {
          throw Exception('상품명을 입력해주세요.');
        }

        // 파일명 생성 (확장자만 사용)
        final fileName = 'product.jpg';

        // 1. Presigned URL 요청
        setState(() {
          _uploadProgress = 0.1;
        });

        final presignedUrlResponse =
            await CloudflareWorkersService.getPresignedUrl(
              fileName: fileName,
              userId: userId,
              contentType: 'image/jpeg',
              fileType: 'campaign-images',
              method: 'PUT',
              companyId: companyId,
              productName: productName,
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

    // 필수 필드 검증
    if (_productNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '상품명을 입력해주세요';
      });
      return;
    }

    if (_sellerController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '판매자명을 입력해주세요';
      });
      return;
    }

    if (_paymentAmountController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '상품 가격을 입력해주세요';
      });
      return;
    }

    if (_platform.isEmpty) {
      setState(() {
        _errorMessage = '플랫폼을 선택해주세요';
      });
      return;
    }

    if (_purchaseMethod.isEmpty) {
      setState(() {
        _errorMessage = '구매방법을 선택해주세요';
      });
      return;
    }

    if (_reviewType.isEmpty) {
      setState(() {
        _errorMessage = '리뷰 타입을 선택해주세요';
      });
      return;
    }

    if (_paymentType.isEmpty) {
      setState(() {
        _errorMessage = '지급 방법을 선택해주세요';
      });
      return;
    }

    if (_productImage == null && _capturedImage == null) {
      setState(() {
        _errorMessage = '상품 이미지를 업로드해주세요';
      });
      return;
    }

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

      // 날짜 검증
      final nowKST = DateTimeUtils.nowKST();
      final maxDate = nowKST.add(const Duration(days: 14)); // 14일 제한

      if (_applyStartDateTime == null) {
        setState(() {
          _errorMessage = '신청 시작일시를 선택해주세요';
          _isCreatingCampaign = false;
        });
        return;
      }

      // 신청 시작일시는 현재 시간보다 나중이어야 함
      if (_applyStartDateTime!.isBefore(nowKST) ||
          _applyStartDateTime!.isAtSameMomentAs(nowKST)) {
        setState(() {
          _errorMessage = '신청 시작일시는 현재 시간보다 나중이어야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      // 신청 시작일시는 현재 시간으로부터 14일 이내여야 함
      if (_applyStartDateTime!.isAfter(maxDate)) {
        setState(() {
          _errorMessage = '신청 시작일시는 현재 시간으로부터 14일 이내여야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      if (_applyEndDateTime == null) {
        setState(() {
          _errorMessage = '신청 종료일시를 선택해주세요';
          _isCreatingCampaign = false;
        });
        return;
      }

      // 신청 종료일시는 현재 시간으로부터 14일 이내여야 함
      if (_applyEndDateTime!.isAfter(maxDate)) {
        setState(() {
          _errorMessage = '신청 종료일시는 현재 시간으로부터 14일 이내여야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      if (_reviewStartDateTime == null) {
        setState(() {
          _errorMessage = '리뷰 시작일시를 선택해주세요';
          _isCreatingCampaign = false;
        });
        return;
      }

      // 리뷰 시작일시는 현재 시간보다 나중이어야 함
      if (_reviewStartDateTime!.isBefore(nowKST) ||
          _reviewStartDateTime!.isAtSameMomentAs(nowKST)) {
        setState(() {
          _errorMessage = '리뷰 시작일시는 현재 시간보다 나중이어야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      // 리뷰 시작일시는 현재 시간으로부터 14일 이내여야 함
      if (_reviewStartDateTime!.isAfter(maxDate)) {
        setState(() {
          _errorMessage = '리뷰 시작일시는 현재 시간으로부터 14일 이내여야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      if (_reviewEndDateTime == null) {
        setState(() {
          _errorMessage = '리뷰 종료일시를 선택해주세요';
          _isCreatingCampaign = false;
        });
        return;
      }

      // 리뷰 종료일시는 현재 시간으로부터 14일 이내여야 함
      if (_reviewEndDateTime!.isAfter(maxDate)) {
        setState(() {
          _errorMessage = '리뷰 종료일시는 현재 시간으로부터 14일 이내여야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      if (_applyEndDateTime!.isBefore(_applyStartDateTime!) ||
          _applyEndDateTime!.isAtSameMomentAs(_applyStartDateTime!)) {
        setState(() {
          _errorMessage = '신청 종료일시는 시작일시보다 뒤여야 합니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      if (_applyEndDateTime!.isAfter(_reviewStartDateTime!) ||
          _applyEndDateTime!.isAtSameMomentAs(_reviewStartDateTime!)) {
        setState(() {
          _errorMessage = '신청 종료일시는 리뷰 시작일시보다 빠를 수 없습니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      if (_reviewStartDateTime!.isAfter(_reviewEndDateTime!) ||
          _reviewStartDateTime!.isAtSameMomentAs(_reviewEndDateTime!)) {
        setState(() {
          _errorMessage = '리뷰 시작일시는 종료일시보다 빠를 수 없습니다';
          _isCreatingCampaign = false;
        });
        return;
      }

      final response = await _campaignService.createCampaignV2(
        title: _productNameController.text.trim(),
        description: '', // ✅ product_description 제거
        campaignType: _campaignType,
        platform: _platform,
        campaignReward: int.tryParse(_campaignRewardController.text) ?? 0,
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 10,
        maxPerReviewer: int.tryParse(_maxPerReviewerController.text) ?? 1,
        applyStartDate: _applyStartDateTime!,
        applyEndDate: _applyEndDateTime!,
        reviewStartDate: _reviewStartDateTime!,
        reviewEndDate: _reviewEndDateTime!,
        keyword: _keywordController.text.trim(),
        option: _optionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 1,
        seller: _sellerController.text.trim().isEmpty
            ? throw Exception('판매자명을 입력해주세요.')
            : _sellerController.text.trim(),
        productNumber: _productNumberController.text.trim(),
        productName: _productNameController.text.trim().isEmpty
            ? throw Exception('상품명을 입력해주세요.')
            : _productNameController.text.trim(),
        productPrice:
            int.tryParse(_paymentAmountController.text) ??
            (throw Exception('상품 가격을 입력해주세요.')),
        reviewType: _reviewType,
        reviewTextLength: reviewTextLength,
        reviewImageCount: reviewImageCount,
        preventProductDuplicate: _preventProductDuplicate,
        preventStoreDuplicate: _preventStoreDuplicate,
        duplicatePreventDays:
            int.tryParse(_duplicateCheckDaysController.text) ?? 0,
        paymentMethod: _paymentType,
        productImageUrl:
            productImageUrl ?? (throw Exception('상품 이미지를 업로드해주세요.')),
        purchaseMethod: _purchaseMethod,
        reviewKeywords:
            _useReviewKeywords &&
                _reviewKeywordsController.text.trim().isNotEmpty
            ? KeywordUtils.normalizeKeywords(
                _reviewKeywordsController.text.trim(),
              )
            : null,
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
          // pushNamed().then() 패턴: 생성된 캠페인 객체 전체를 반환하여 즉시 목록에 추가
          final campaign = response.data;
          if (campaign != null) {
            debugPrint(
              '✅ 캠페인 생성 성공 - campaignId: ${campaign.id}, title: ${campaign.title}',
            );
            // 캠페인 생성 완료 후 "나의 캠페인"의 "대기중" 탭으로 이동
            // 약간의 지연 후 이동하여 DB 반영 시간 확보
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                context.go('/mypage/advertiser/my-campaigns?tab=pending');
              }
            });
          } else {
            debugPrint('⚠️ Campaign 객체가 null입니다. "나의 캠페인"의 "대기중" 탭으로 이동합니다.');
            // Campaign 객체가 null인 경우에도 "나의 캠페인"의 "대기중" 탭으로 이동
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                context.go('/mypage/advertiser/my-campaigns?tab=pending');
              }
            });
          }
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

  // ✅ 웹에서 RepaintBoundary 조건부 처리 헬퍼
  // 웹에서는 TextField가 포함된 위젯에 RepaintBoundary를 씌우면
  // 커서가 깜빡일 때마다 전체 영역을 텍스처로 다시 굽는 과정이 발생하여 성능 저하
  Widget _buildWithOptionalBoundary(Widget child, {bool alwaysUse = false}) {
    // 웹에서는 TextField가 포함된 위젯의 RepaintBoundary 완전히 제거
    if (kIsWeb) {
      return child; // 웹이면 그냥 child 반환 (커서 깜빡임 성능 이슈 방지)
    }
    // 앱에서는 alwaysUse 플래그에 따라 조건부 사용
    if (alwaysUse) {
      return RepaintBoundary(child: child);
    }
    return child; // 네이티브에서도 기본적으로는 사용하지 않음
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Phase 1.1: 초기화 완료 전까지 스켈레톤 UI 표시
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7F8),
        appBar: AppBar(
          title: const Text('캠페인 생성'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const _CampaignFormSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('캠페인 생성'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '기본 일정 설정 변경',
            onPressed: () => _showDefaultScheduleSettingsDialog(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: kIsWeb
            ? AutovalidateMode.disabled
            : AutovalidateMode.onUserInteraction,
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

              _buildWithOptionalBoundary(_buildCampaignTypeSection()),
              const SizedBox(height: 24),

              _buildWithOptionalBoundary(_buildImageSection(), alwaysUse: true),
              const SizedBox(height: 24),

              if (_productImage != null || _capturedImage != null) ...[
                _buildWithOptionalBoundary(
                  _buildProductImageSection(),
                  alwaysUse: true,
                ),
                const SizedBox(height: 24),
              ],

              _buildWithOptionalBoundary(_buildProductInfoSection()),
              const SizedBox(height: 24),

              _buildWithOptionalBoundary(_buildReviewSettings()),
              const SizedBox(height: 24),

              _buildWithOptionalBoundary(_buildScheduleSection()),
              const SizedBox(height: 24),

              _buildWithOptionalBoundary(_buildDuplicatePreventSection()),
              const SizedBox(height: 24),

              _buildWithOptionalBoundary(_buildCostSection(), alwaysUse: true),
              const SizedBox(height: 24),

              if (_isUploadingImage) ...[
                _buildWithOptionalBoundary(
                  _buildUploadProgressSection(),
                  alwaysUse: true,
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 32),

              _buildWithOptionalBoundary(
                AbsorbPointer(
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
                DropdownMenuItem(value: 'store', child: Text('스토어')),
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
                DropdownMenuItem(
                  value: 'coupang',
                  child: Text('쿠팡'),
                  enabled: true,
                ),
                DropdownMenuItem(
                  value: 'naver',
                  child: Text('네이버 쇼핑 (추가예정)'),
                  enabled: false,
                ),
              ],
              onChanged: (value) {
                if (value != null && value == 'coupang') {
                  setState(() {
                    _platform = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('광고주가 허용한 리뷰어만 가능'),
              subtitle: const Text('광고주가 승인한 리뷰어만 캠페인에 참여할 수 있습니다'),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              labelText: '판매자 *',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '판매자명을 입력해주세요';
                }
                return null;
              },
            ),
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '상품가격을 입력해주세요';
                }
                final price = int.tryParse(value);
                if (price == null || price < 0) {
                  return '올바른 가격을 입력해주세요';
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              controller: _campaignRewardController,
              labelText: '리뷰비',
              hintText: '선택사항, 미입력 시 0',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final reward = int.tryParse(value);
                  if (reward == null || reward < 0) {
                    return '올바른 리뷰비를 입력해주세요';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // 리뷰 키워드 체크박스 및 입력 필드
            CheckboxListTile(
              title: const Text('리뷰 키워드 사용'),
              value: _useReviewKeywords,
              onChanged: (value) {
                setState(() {
                  _useReviewKeywords = value ?? false;
                  if (!_useReviewKeywords) {
                    _reviewKeywordsController.clear();
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_useReviewKeywords) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _reviewKeywordsController,
                decoration: InputDecoration(
                  labelText: '리뷰 키워드',
                  hintText: '예: 키워드1, 키워드2, 키워드3',
                  helperText: '키워드 3개 이내 20자 이내',
                  border: const OutlineInputBorder(),
                  suffixText: () {
                    if (!_useReviewKeywords ||
                        _reviewKeywordsController.text.trim().isEmpty) {
                      return null;
                    }
                    final keywordCount = KeywordUtils.countKeywords(
                      _reviewKeywordsController.text,
                    );
                    final textLength = KeywordUtils.getKeywordTextLength(
                      _reviewKeywordsController.text,
                    );
                    return '$keywordCount/3, $textLength/20';
                  }(),
                ),
                inputFormatters: [_ReviewKeywordInputFormatter()],
                onChanged: (value) {
                  setState(() {}); // 실시간 업데이트를 위한 setState
                },
                validator: (value) {
                  if (_useReviewKeywords) {
                    if (value == null || value.trim().isEmpty) {
                      return '키워드를 입력해주세요';
                    }
                    final (isValid, errorMessage) =
                        KeywordUtils.validateKeywords(value);
                    if (!isValid) {
                      return errorMessage;
                    }
                  }
                  return null;
                },
              ),
            ],
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
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showDefaultScheduleSettingsDialog(context),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('기본 설정 변경'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '신청 시작일시 *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectApplyStartDateTime(context),
              controller: _applyStartDateTimeController,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '신청 종료일시 *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectApplyEndDateTime(context),
              controller: _applyEndDateTimeController,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '리뷰 시작일시 *',
                hintText: 'YYYY-MM-DD HH:00',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectReviewStartDateTime(context),
              controller: _reviewStartDateTimeController,
              validator: (value) {
                if (_reviewStartDateTime == null) {
                  return '리뷰 시작일시를 선택해주세요';
                }
                if (_applyEndDateTime != null &&
                    (_reviewStartDateTime!.isBefore(_applyEndDateTime!) ||
                        _reviewStartDateTime!.isAtSameMomentAs(
                          _applyEndDateTime!,
                        ))) {
                  return '리뷰 시작일시는 신청 종료일시 이후여야 합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '리뷰 종료일시 *',
                hintText: 'YYYY-MM-DD HH:00',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectReviewEndDateTime(context),
              controller: _reviewEndDateTimeController,
              validator: (value) {
                if (_reviewEndDateTime == null) {
                  return '리뷰 종료일시를 선택해주세요';
                }
                if (_reviewStartDateTime != null &&
                    (_reviewEndDateTime!.isBefore(_reviewStartDateTime!) ||
                        _reviewEndDateTime!.isAtSameMomentAs(
                          _reviewStartDateTime!,
                        ))) {
                  return '리뷰 종료일시는 리뷰 시작일시 이후여야 합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _maxParticipantsController,
              labelText: '모집 인원 *',
              hintText: '10',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                // 리뷰어당 신청 가능 개수 필드의 validator 재실행
                if (_formKey.currentState != null) {
                  _formKey.currentState!.validate();
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '모집 인원을 입력해주세요';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return '올바른 인원수를 입력해주세요';
                }
                // 리뷰어당 신청 가능 개수보다 작으면 안 됨
                final maxPerReviewer =
                    int.tryParse(_maxPerReviewerController.text) ?? 0;
                if (maxPerReviewer > 0 && count < maxPerReviewer) {
                  return '모집 인원은 리뷰어당 신청 가능 개수($maxPerReviewer개) 이상이어야 합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _maxPerReviewerController,
              labelText: '리뷰어당 신청 가능 개수',
              hintText: '1',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                // 모집 인원 필드의 validator 재실행
                if (_formKey.currentState != null) {
                  _formKey.currentState!.validate();
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '리뷰어당 신청 가능 개수를 입력해주세요';
                }
                final count = int.tryParse(value);
                if (count == null || count < 1) {
                  return '1 이상의 숫자를 입력해주세요';
                }
                // 모집 인원을 넘지 않아야 함
                final maxParticipants =
                    int.tryParse(_maxParticipantsController.text) ?? 0;
                if (maxParticipants > 0 && count > maxParticipants) {
                  return '모집 인원($maxParticipants명)을 넘을 수 없습니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              '한 리뷰어가 이 캠페인에 신청할 수 있는 최대 횟수',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectApplyStartDateTime(BuildContext context) async {
    final nowKST = DateTimeUtils.nowKST();
    final date = await showDatePicker(
      context: context,
      initialDate: _applyStartDateTime ?? nowKST,
      firstDate: nowKST,
      lastDate: nowKST.add(const Duration(days: 14)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _applyStartDateTime != null
            ? TimeOfDay.fromDateTime(_applyStartDateTime!)
            : TimeOfDay.fromDateTime(nowKST),
        initialEntryMode: TimePickerEntryMode.input,
      );

      if (time != null) {
        // 한국 시간(KST)으로 DateTime 생성
        final dateTime = DateTimeUtils.nowKST().copyWith(
          year: date.year,
          month: date.month,
          day: date.day,
          hour: time.hour,
          minute: time.minute,
          second: 0,
          millisecond: 0,
        );

        // 현재 시간보다 나중인지 검증
        if (dateTime.isBefore(nowKST) || dateTime.isAtSameMomentAs(nowKST)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('신청 시작일시는 현재 시간보다 나중이어야 합니다'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _applyStartDateTime = dateTime;
          _updateDateTimeControllers();
        });
      }
    }
  }

  Future<void> _selectApplyEndDateTime(BuildContext context) async {
    final nowKST = DateTimeUtils.nowKST();
    final date = await showDatePicker(
      context: context,
      initialDate: _applyEndDateTime ?? nowKST,
      firstDate: nowKST,
      lastDate: nowKST.add(const Duration(days: 14)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _applyEndDateTime != null
            ? TimeOfDay.fromDateTime(_applyEndDateTime!)
            : TimeOfDay.fromDateTime(nowKST),
        initialEntryMode: TimePickerEntryMode.input,
      );

      if (time != null) {
        // 한국 시간(KST)으로 DateTime 생성
        final dateTime = DateTimeUtils.nowKST().copyWith(
          year: date.year,
          month: date.month,
          day: date.day,
          hour: time.hour,
          minute: time.minute,
          second: 0,
          millisecond: 0,
        );

        setState(() {
          _applyEndDateTime = dateTime;
          _updateDateTimeControllers();
        });
      }
    }
  }

  Future<void> _selectReviewStartDateTime(BuildContext context) async {
    final nowKST = DateTimeUtils.nowKST();
    final date = await showDatePicker(
      context: context,
      initialDate: _reviewStartDateTime ?? nowKST,
      firstDate: nowKST,
      lastDate: nowKST.add(const Duration(days: 14)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _reviewStartDateTime != null
            ? TimeOfDay.fromDateTime(_reviewStartDateTime!)
            : TimeOfDay.fromDateTime(nowKST),
        initialEntryMode: TimePickerEntryMode.input,
      );

      if (time != null) {
        // 한국 시간(KST)으로 DateTime 생성
        final dateTime = DateTimeUtils.nowKST().copyWith(
          year: date.year,
          month: date.month,
          day: date.day,
          hour: time.hour,
          minute: time.minute,
          second: 0,
          millisecond: 0,
        );

        // 현재 시간보다 나중인지 검증
        if (dateTime.isBefore(nowKST) || dateTime.isAtSameMomentAs(nowKST)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('리뷰 시작일시는 현재 시간보다 나중이어야 합니다'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _reviewStartDateTime = dateTime;
          _updateDateTimeControllers();
        });
      }
    }
  }

  Future<void> _selectReviewEndDateTime(BuildContext context) async {
    final nowKST = DateTimeUtils.nowKST();
    final initialDate = _reviewEndDateTime ?? nowKST;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: nowKST,
      lastDate: nowKST.add(const Duration(days: 14)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _reviewEndDateTime != null
          ? TimeOfDay.fromDateTime(_reviewEndDateTime!)
          : TimeOfDay.fromDateTime(initialDate),
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (time == null) return;

    // 한국 시간(KST)으로 DateTime 생성
    final dateTime = DateTimeUtils.nowKST().copyWith(
      year: date.year,
      month: date.month,
      day: date.day,
      hour: time.hour,
      minute: time.minute,
      second: 0,
      millisecond: 0,
    );

    setState(() {
      _reviewEndDateTime = dateTime;
      _updateDateTimeControllers();
    });
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
              title: const Text('판매자(스토어) 중복 금지'),
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
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '비용 지급 방법 *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              selectedItemBuilder: (BuildContext context) {
                final maxParticipants = _maxParticipantsController.text.isEmpty
                    ? '0'
                    : _maxParticipantsController.text;
                final paymentAmount = _paymentAmountController.text.isEmpty
                    ? '0'
                    : _paymentAmountController.text;
                final campaignReward = _campaignRewardController.text.isEmpty
                    ? '0'
                    : _campaignRewardController.text;

                return [
                  Text(
                    '직접 지급 [플랫폼수수료(500) × 모집인원($maxParticipants)]',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '플랫폼 지급 [플랫폼수수료(500) + 제품금액($paymentAmount) + 리뷰비($campaignReward)] × 모집인원($maxParticipants) (추가예정)',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ];
              },
              items: [
                DropdownMenuItem(
                  value: 'direct',
                  child: Builder(
                    builder: (context) {
                      final maxParticipants =
                          _maxParticipantsController.text.isEmpty
                          ? '0'
                          : _maxParticipantsController.text;
                      return Text(
                        '직접 지급 [플랫폼수수료(500) × 모집인원($maxParticipants)]',
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        maxLines: 2,
                      );
                    },
                  ),
                  enabled: true,
                ),
                DropdownMenuItem(
                  value: 'platform',
                  child: Builder(
                    builder: (context) {
                      final maxParticipants =
                          _maxParticipantsController.text.isEmpty
                          ? '0'
                          : _maxParticipantsController.text;
                      final paymentAmount =
                          _paymentAmountController.text.isEmpty
                          ? '0'
                          : _paymentAmountController.text;
                      final campaignReward =
                          _campaignRewardController.text.isEmpty
                          ? '0'
                          : _campaignRewardController.text;
                      return Text(
                        '플랫폼 지급 [플랫폼수수료(500) + 제품금액($paymentAmount) + 리뷰비($campaignReward)] × 모집인원($maxParticipants) (추가예정)',
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        maxLines: 2,
                      );
                    },
                  ),
                  enabled: false,
                ),
              ],
              onChanged: (value) {
                if (value != null && value == 'direct') {
                  setState(() {
                    _paymentType = value;
                    _calculateCost();
                  });
                }
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
                          ? SizedBox(
                              width: kIsWeb ? 16 : 20,
                              height: kIsWeb ? 16 : 20,
                              child: CircularProgressIndicator(
                                strokeWidth: kIsWeb ? 2 : 2,
                              ),
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
        _applyStartDateTime != null &&
        _applyEndDateTime != null &&
        _reviewStartDateTime != null &&
        _reviewEndDateTime != null &&
        _totalCost <= _currentBalance &&
        (int.tryParse(maxParticipants) ?? 0) > 0 &&
        !_isUploadingImage &&
        !_isCreatingCampaign; // ✅ 중복 호출 방지
  }

  /// 기본 일정 설정 변경 다이얼로그 표시
  Future<void> _showDefaultScheduleSettingsDialog(BuildContext context) async {
    final currentSchedule =
        await CampaignDefaultScheduleService.loadDefaultSchedule();

    // 시간 파싱
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    int applyStartDays = currentSchedule.applyStartDays;
    TimeOfDay applyStartTime = parseTime(currentSchedule.applyStartTime);
    int applyEndDays = currentSchedule.applyEndDays;
    TimeOfDay applyEndTime = parseTime(currentSchedule.applyEndTime);
    int reviewStartDays = currentSchedule.reviewStartDays;
    TimeOfDay reviewStartTime = parseTime(currentSchedule.reviewStartTime);
    int reviewEndDays = currentSchedule.reviewEndDays;
    TimeOfDay reviewEndTime = parseTime(currentSchedule.reviewEndTime);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 미리보기 날짜 계산
          String getPreviewDate(TimeOfDay time, int daysOffset) {
            final now = DateTimeUtils.nowKST();
            final targetDate = now.add(Duration(days: daysOffset));
            final dateTime = targetDate.copyWith(
              hour: time.hour,
              minute: time.minute,
            );
            return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          }

          String getDayLabel(int days) {
            if (days == 0) return '오늘';
            if (days == 1) return '내일';
            return '오늘 +$days일';
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '기본 일정 설정',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '캠페인 생성 시 자동으로 적용될 기본 일정을 설정합니다',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // 스크롤 가능한 내용
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 신청 기간 섹션
                          _buildDefaultScheduleSection(
                            context,
                            '신청 기간',
                            Icons.event_available,
                            Colors.blue,
                            [
                              _buildDayAndTimeSelector(
                                context,
                                '시작',
                                applyStartDays,
                                applyStartTime,
                                (days) {
                                  setDialogState(() {
                                    applyStartDays = days;
                                  });
                                },
                                (time) {
                                  setDialogState(() {
                                    applyStartTime = time;
                                  });
                                },
                                getPreviewDate(applyStartTime, applyStartDays),
                                getDayLabel(applyStartDays),
                              ),
                              const SizedBox(height: 16),
                              _buildDayAndTimeSelector(
                                context,
                                '종료',
                                applyEndDays,
                                applyEndTime,
                                (days) {
                                  setDialogState(() {
                                    applyEndDays = days;
                                  });
                                },
                                (time) {
                                  setDialogState(() {
                                    applyEndTime = time;
                                  });
                                },
                                getPreviewDate(applyEndTime, applyEndDays),
                                getDayLabel(applyEndDays),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 리뷰 기간 섹션
                          _buildDefaultScheduleSection(
                            context,
                            '리뷰 기간',
                            Icons.rate_review,
                            Colors.orange,
                            [
                              _buildDayAndTimeSelector(
                                context,
                                '시작',
                                reviewStartDays,
                                reviewStartTime,
                                (days) {
                                  setDialogState(() {
                                    reviewStartDays = days;
                                  });
                                },
                                (time) {
                                  setDialogState(() {
                                    reviewStartTime = time;
                                  });
                                },
                                getPreviewDate(
                                  reviewStartTime,
                                  reviewStartDays,
                                ),
                                getDayLabel(reviewStartDays),
                              ),
                              const SizedBox(height: 16),
                              _buildDayAndTimeSelector(
                                context,
                                '종료',
                                reviewEndDays,
                                reviewEndTime,
                                (days) {
                                  setDialogState(() {
                                    reviewEndDays = days;
                                  });
                                },
                                (time) {
                                  setDialogState(() {
                                    reviewEndTime = time;
                                  });
                                },
                                getPreviewDate(reviewEndTime, reviewEndDays),
                                getDayLabel(reviewEndDays),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // 14일 제한 검증
                          if (applyStartDays > 14) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('신청 시작일은 오늘로부터 14일 이내여야 합니다'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (applyEndDays > 14) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('신청 종료일은 오늘로부터 14일 이내여야 합니다'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (reviewStartDays > 14) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('리뷰 시작일은 오늘로부터 14일 이내여야 합니다'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (reviewEndDays > 14) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('리뷰 종료일은 오늘로부터 14일 이내여야 합니다'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final schedule = CampaignDefaultSchedule(
                            applyStartDays: applyStartDays,
                            applyStartTime:
                                '${applyStartTime.hour.toString().padLeft(2, '0')}:${applyStartTime.minute.toString().padLeft(2, '0')}',
                            applyEndDays: applyEndDays,
                            applyEndTime:
                                '${applyEndTime.hour.toString().padLeft(2, '0')}:${applyEndTime.minute.toString().padLeft(2, '0')}',
                            reviewStartDays: reviewStartDays,
                            reviewStartTime:
                                '${reviewStartTime.hour.toString().padLeft(2, '0')}:${reviewStartTime.minute.toString().padLeft(2, '0')}',
                            reviewEndDays: reviewEndDays,
                            reviewEndTime:
                                '${reviewEndTime.hour.toString().padLeft(2, '0')}:${reviewEndTime.minute.toString().padLeft(2, '0')}',
                          );

                          final success =
                              await CampaignDefaultScheduleService.saveDefaultSchedule(
                                schedule,
                              );

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('기본 일정 설정이 저장되었습니다'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // 현재 화면의 일정도 업데이트
                              await _loadDefaultSchedule();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('기본 일정 설정 저장에 실패했습니다'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('저장'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultScheduleSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(
    BuildContext context,
    String label,
    TimeOfDay currentTime,
    Function(TimeOfDay) onTimeSelected,
    String preview,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: currentTime,
              initialEntryMode: TimePickerEntryMode.input,
            );
            if (time != null) {
              onTimeSelected(time);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Text(
                  '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '미리보기: $preview',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDayAndTimeSelector(
    BuildContext context,
    String label,
    int currentDays,
    TimeOfDay currentTime,
    Function(int) onDaysSelected,
    Function(TimeOfDay) onTimeSelected,
    String preview,
    String dayLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label 시간',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 일수 선택
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final days = await showDialog<int>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('일수 선택'),
                      content: SizedBox(
                        width: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: 15, // 0~14일 (14일 제한)
                          itemBuilder: (context, index) {
                            final days = index;
                            final label = days == 0
                                ? '오늘'
                                : days == 1
                                ? '내일'
                                : '오늘 +$days일';
                            return ListTile(
                              title: Text(label),
                              selected: days == currentDays,
                              onTap: () => Navigator.of(context).pop(days),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                  if (days != null) {
                    onDaysSelected(days);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dayLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 시간 선택
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: currentTime,
                    initialEntryMode: TimePickerEntryMode.input,
                  );
                  if (time != null) {
                    onTimeSelected(time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '미리보기: $preview',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  void _updateDateTimeControllers() {
    _applyStartDateTimeController.text = _applyStartDateTime != null
        ? '${_applyStartDateTime!.year}-${_applyStartDateTime!.month.toString().padLeft(2, '0')}-${_applyStartDateTime!.day.toString().padLeft(2, '0')} ${_applyStartDateTime!.hour.toString().padLeft(2, '0')}:${_applyStartDateTime!.minute.toString().padLeft(2, '0')}'
        : '';

    _applyEndDateTimeController.text = _applyEndDateTime != null
        ? '${_applyEndDateTime!.year}-${_applyEndDateTime!.month.toString().padLeft(2, '0')}-${_applyEndDateTime!.day.toString().padLeft(2, '0')} ${_applyEndDateTime!.hour.toString().padLeft(2, '0')}:${_applyEndDateTime!.minute.toString().padLeft(2, '0')}'
        : '';

    _reviewStartDateTimeController.text = _reviewStartDateTime != null
        ? '${_reviewStartDateTime!.year}-${_reviewStartDateTime!.month.toString().padLeft(2, '0')}-${_reviewStartDateTime!.day.toString().padLeft(2, '0')} ${_reviewStartDateTime!.hour.toString().padLeft(2, '0')}:${_reviewStartDateTime!.minute.toString().padLeft(2, '0')}'
        : '';

    _reviewEndDateTimeController.text = _reviewEndDateTime != null
        ? '${_reviewEndDateTime!.year}-${_reviewEndDateTime!.month.toString().padLeft(2, '0')}-${_reviewEndDateTime!.day.toString().padLeft(2, '0')} ${_reviewEndDateTime!.hour.toString().padLeft(2, '0')}:${_reviewEndDateTime!.minute.toString().padLeft(2, '0')}'
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

  // ✅ 웹용 직접 이미지 리사이징 함수 (프레임 분리 최적화)
  Future<Uint8List> _resizeImageDirect(
    Uint8List bytes,
    int maxW,
    int maxH,
    int quality,
  ) async {
    try {
      // ✅ Step 1: 이미지 디코딩 (프레임 분리)
      img.Image? image;
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      image = await Future.microtask(() => img.decodeImage(bytes));

      if (image == null) {
        print('❌ 이미지 디코딩 실패, 원본 반환');
        return bytes;
      }

      if (image.width <= maxW && image.height <= maxH) {
        return bytes;
      }

      // ✅ Step 2: 리사이징 계산 (프레임 분리)
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final scale = (maxW / image.width).clamp(0.0, maxH / image.height);
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();

      // ✅ Step 3: 리사이징 실행 (프레임 분리)
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final resized = await Future.microtask(
        () => img.copyResize(
          image!,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        ),
      );

      // ✅ Step 4: 인코딩 (프레임 분리)
      await Future.delayed(const Duration(milliseconds: 16)); // UI 업데이트 시간 확보
      final resizedBytes = await Future.microtask(
        () => Uint8List.fromList(img.encodeJpg(resized, quality: quality)),
      );

      print(
        '✅ 이미지 리사이징 (웹): ${image.width}x${image.height} -> ${resized.width}x${resized.height}',
      );

      return resizedBytes;
    } catch (e) {
      print('❌ 리사이징 실패: $e, 원본 반환');
      return bytes;
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

/// ✅ Phase 1.1: 캠페인 폼 스켈레톤 UI
class _CampaignFormSkeleton extends StatelessWidget {
  const _CampaignFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardSkeleton(),
          const SizedBox(height: 24),
          _buildCardSkeleton(),
          const SizedBox(height: 24),
          _buildCardSkeleton(),
          const SizedBox(height: 24),
          _buildCardSkeleton(),
          const SizedBox(height: 24),
          _buildCardSkeleton(),
        ],
      ),
    );
  }

  Widget _buildCardSkeleton() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShimmerBox(height: 20, width: 150),
            const SizedBox(height: 16),
            _buildShimmerBox(height: 56),
            const SizedBox(height: 16),
            _buildShimmerBox(height: 56),
            const SizedBox(height: 16),
            _buildShimmerBox(height: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({double? height, double? width}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
