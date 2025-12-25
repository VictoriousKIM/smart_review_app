import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/campaign_service.dart';
import '../../services/wallet_service.dart';
import '../../services/campaign_default_schedule_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/review_keywords_input.dart';
import '../../utils/date_time_utils.dart';
import '../../models/campaign.dart';
import 'package:responsive_builder/responsive_builder.dart';

class CampaignEditScreen extends ConsumerStatefulWidget {
  final String campaignId;

  const CampaignEditScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignEditScreen> createState() => _CampaignEditScreenState();
}

class _CampaignEditScreenState extends ConsumerState<CampaignEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _campaignService = CampaignService();

  bool _isCreatingCampaign = false;
  bool _isLoadingCampaign = false;
  Campaign? _originalCampaign;
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
  String _platform = '쿠팡';
  final String _paymentType = 'direct';
  String _purchaseMethod = 'mobile'; // ✅ 추가: 구매방법 선택
  String _productProvisionType = '실배송'; // ✅ 필수, 초기값: 실배송
  final bool _onlyAllowedReviewers = true;
  String _reviewType = 'star_only';
  DateTime? _applyStartDateTime; // 신청 시작일시
  DateTime? _applyEndDateTime; // 신청 종료일시
  DateTime? _reviewStartDateTime; // 리뷰 시작일시
  DateTime? _reviewEndDateTime; // 리뷰 종료일시
  bool _preventProductDuplicate = false;
  bool _preventStoreDuplicate = false;

  // 리뷰 키워드
  bool _useReviewKeywords = false; // 체크박스 상태
  List<String> _reviewKeywords = []; // 키워드 리스트

  // 비용 및 잔액
  int _totalCost = 0;
  int _currentBalance = 0;
  bool _isLoadingBalance = false;

  // ✅ 5. 비용 계산 디바운싱
  Timer? _costCalculationTimer;
  // bool _ignoreCostListeners = false; // 편집 화면에서는 비용 계산 제거로 인해 사용하지 않음

  // DateTime 컨트롤러
  late final TextEditingController _applyStartDateTimeController;
  late final TextEditingController _applyEndDateTimeController;
  late final TextEditingController _reviewStartDateTimeController;
  late final TextEditingController _reviewEndDateTimeController;

  // ✅ 5. 포맷팅 캐싱
  String? _cachedFormattedBalance;

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
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _loadCampaignData();
        }
      });
    });
  }

  Future<void> _loadCampaignData() async {
    setState(() {
      _isLoadingCampaign = true;
    });

    try {
      final result = await _campaignService.getCampaignById(widget.campaignId);
      if (result.success && result.data != null) {
        final campaign = result.data!;
        _originalCampaign = campaign;

        // ✅ [중요] 데이터 세팅 중에는 리스너가 반응하지 않도록 플래그 설정
        // _ignoreCostListeners = true; // 편집 화면에서는 비용 계산 제거로 인해 사용하지 않음

        // 기존 캠페인 데이터로 필드 초기화
        _productNameController.text = campaign.productName;
        _keywordController.text = campaign.keyword ?? '';
        _optionController.text = campaign.option ?? '';
        _quantityController.text = campaign.quantity.toString();
        _sellerController.text = campaign.seller;
        _productNumberController.text = campaign.productNumber ?? '';
        _paymentAmountController.text = campaign.productPrice.toString();
        _campaignRewardController.text = campaign.campaignReward.toString();
        _maxParticipantsController.text =
            campaign.maxParticipants?.toString() ?? '10';
        _maxPerReviewerController.text = campaign.maxPerReviewer.toString();
        _duplicateCheckDaysController.text = campaign.duplicatePreventDays
            .toString();

        _campaignType = campaign.campaignType.name;
        _platform = campaign.platform;
        _purchaseMethod = campaign.purchaseMethod;

        // 상품제공여부 처리
        final provisionType = campaign.productProvisionType;
        if (provisionType == '실배송') {
          _productProvisionType = '실배송';
          _productProvisionOtherController.text = '실배송';
        } else if (provisionType == '회수') {
          _productProvisionType = '회수';
          _productProvisionOtherController.text = '회수';
        } else {
          // '실배송'이나 '회수'가 아니면 '그외'로 처리하고 DB 값 표시
          _productProvisionType = '그외';
          _productProvisionOtherController.text = provisionType;
        }

        _reviewType = campaign.reviewType;
        _preventProductDuplicate = campaign.preventProductDuplicate;
        _preventStoreDuplicate = campaign.preventStoreDuplicate;

        _applyStartDateTime = campaign.applyStartDate;
        _applyEndDateTime = campaign.applyEndDate;
        _reviewStartDateTime = campaign.reviewStartDate;
        _reviewEndDateTime = campaign.reviewEndDate;

        if (campaign.reviewType == 'star_text' ||
            campaign.reviewType == 'star_text_image') {
          _reviewTextLengthController.text = campaign.reviewTextLength
              .toString();
        }
        if (campaign.reviewType == 'star_text_image') {
          _reviewImageCountController.text = campaign.reviewImageCount
              .toString();
        }

        // 리뷰 키워드 로드
        final keywords = campaign.reviewKeywords ?? [];
        _reviewKeywords = keywords;
        _useReviewKeywords = keywords.isNotEmpty; // ✅ 추가: 키워드가 있으면 체크박스 체크

        // ✅ [중요] 데이터 세팅 완료 후 플래그 해제
        // _ignoreCostListeners = false; // 편집 화면에서는 비용 계산 제거로 인해 사용하지 않음
        _updateDateTimeControllers();
        // 편집 화면에서는 비용 계산 제거 (추가 비용 변동 없음)
        // _calculateCost(); // 여기서 딱 한 번만 계산
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? '캠페인을 불러올 수 없습니다.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캠페인 로딩 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCampaign = false;
        });
        await _initializeInStages();
      }
    }
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
        // 편집 화면에서는 비용 계산 제거 (추가 비용 변동 없음)
        // _calculateCost(); // 초기 비용 계산
      }
    });
  }

  @override
  void dispose() {
    _costCalculationTimer?.cancel();

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
    // 편집 화면에서는 비용 계산 리스너 제거 (추가 비용 변동 없음)
    // _paymentAmountController.addListener(_calculateCostDebounced);
    // _campaignRewardController.addListener(_calculateCostDebounced);
    // _maxParticipantsController.addListener(_calculateCostDebounced);
  }

  // ✅ 5. 디바운싱된 비용 계산
  // 편집 화면에서는 비용 계산 제거 (추가 비용 변동 없음)
  // void _calculateCostDebounced() {
  //   // if (_ignoreCostListeners) return;
  //   // _costCalculationTimer?.cancel();
  //   // _costCalculationTimer = Timer(const Duration(milliseconds: 500), () {
  //   //   if (mounted) _calculateCost();
  //   // });
  // }

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
          }
          if (pendingErrorMessage != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(pendingErrorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  // ✅ 5. 비용 계산 최적화 (값 변경 시만 setState)
  // 편집 화면에서는 비용 계산 제거 (추가 비용 변동 없음)
  // void _calculateCost() {
  //   final paymentAmount = int.tryParse(_paymentAmountController.text) ?? 0;
  //   final campaignReward = int.tryParse(_campaignRewardController.text) ?? 0;
  //   final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 1;
  //
  //   int cost = 0;
  //   if (_paymentType == 'platform') {
  //     cost = (paymentAmount + campaignReward + 500) * maxParticipants;
  //   } else {
  //     cost = 500 * maxParticipants;
  //   }
  //
  //   // ✅ 값이 변경되었을 때만 setState
  //   if (_totalCost != cost) {
  //     _totalCost = cost;
  //
  //     // ✅ 포맷팅 캐싱 (매번 계산하지 않음)
  //     _cachedFormattedBalance = _formatNumber(_currentBalance);
  //     _cachedFormattedTotalCost = _formatNumber(_totalCost);
  //     _cachedFormattedRemaining = _formatNumber(_currentBalance - _totalCost);
  //
  //     if (mounted) {
  //       setState(() {}); // 빈 setState (UI만 갱신)
  //     }
  //   }
  // }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String get _formattedBalance =>
      _cachedFormattedBalance ?? _formatNumber(_currentBalance);
  // String get _formattedTotalCost =>
  //     _cachedFormattedTotalCost ?? _formatNumber(_totalCost);
  // String get _formattedRemaining =>
  //     _cachedFormattedRemaining ?? _formatNumber(_currentBalance - _totalCost);

  Future<void> _updateCampaign() async {
    debugPrint('🚀 [캠페인 수정] 시작 - campaignId: ${widget.campaignId}');

    // ✅ 즉시 체크 (setState 전에) - 중복 호출 방지
    if (_isCreatingCampaign) {
      debugPrint(
        '❌ [캠페인 수정] 에러: 이미 진행 중입니다. (_isCreatingCampaign: $_isCreatingCampaign)',
      );
      return;
    }

    debugPrint('✅ [캠페인 수정] 중복 호출 체크 통과');

    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ [캠페인 수정] 에러: Form 유효성 검사 실패');
      return;
    }

    debugPrint('✅ [캠페인 수정] Form 유효성 검사 통과');

    if (_totalCost > _currentBalance) {
      debugPrint(
        '❌ [캠페인 수정] 에러: 잔액 부족 (필요: ${_totalCost}P, 현재: ${_currentBalance}P)',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '잔액이 부족합니다. 필요: ${_totalCost}P, 현재: ${_currentBalance}P',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    debugPrint(
      '✅ [캠페인 수정] 잔액 체크 통과 (필요: ${_totalCost}P, 현재: ${_currentBalance}P)',
    );

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
    });

    try {
      // ✅ review_type에 따른 값 설정
      int? reviewTextLength;
      int? reviewImageCount;

      debugPrint('🔍 [캠페인 수정] 리뷰 타입 검증 시작 - reviewType: $_reviewType');

      if (_reviewType == 'star_only') {
        reviewTextLength = null;
        reviewImageCount = null;
        debugPrint('✅ [캠페인 수정] 리뷰 타입: star_only (검증 없음)');
      } else if (_reviewType == 'star_text') {
        reviewTextLength = int.tryParse(_reviewTextLengthController.text);
        if (reviewTextLength == null || reviewTextLength <= 0) {
          debugPrint(
            '❌ [캠페인 수정] 에러: 리뷰 텍스트 최소 글자 수 없음 (입력값: ${_reviewTextLengthController.text})',
          );
          _isCreatingCampaign = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('리뷰 텍스트 최소 글자 수를 입력해주세요'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        reviewImageCount = null;
        debugPrint('✅ [캠페인 수정] 리뷰 타입: star_text (텍스트 글자 수: $reviewTextLength)');
      } else if (_reviewType == 'star_text_image') {
        reviewTextLength = int.tryParse(_reviewTextLengthController.text);
        reviewImageCount = int.tryParse(_reviewImageCountController.text);
        if (reviewTextLength == null || reviewTextLength <= 0) {
          debugPrint(
            '❌ [캠페인 수정] 에러: 리뷰 텍스트 최소 글자 수 없음 (입력값: ${_reviewTextLengthController.text})',
          );
          _isCreatingCampaign = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('리뷰 텍스트 최소 글자 수를 입력해주세요'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        if (reviewImageCount == null || reviewImageCount <= 0) {
          debugPrint(
            '❌ [캠페인 수정] 에러: 사진 최소 개수 없음 (입력값: ${_reviewImageCountController.text})',
          );
          _isCreatingCampaign = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('사진 최소 개수를 입력해주세요'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        debugPrint(
          '✅ [캠페인 수정] 리뷰 타입: star_text_image (텍스트: $reviewTextLength, 이미지: $reviewImageCount)',
        );
      }

      // 날짜 검증
      debugPrint('🔍 [캠페인 수정] 날짜 검증 시작');

      if (_originalCampaign == null) {
        debugPrint('❌ [캠페인 수정] 에러: 캠페인 정보 없음 (_originalCampaign == null)');
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('캠페인 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final createdAt = _originalCampaign!.createdAt;
      final maxDate = createdAt.add(const Duration(days: 14)); // 생성일 기준 14일 제한
      debugPrint('📅 [캠페인 수정] 날짜 범위 - 생성일: $createdAt, 최대일: $maxDate');

      if (_applyStartDateTime == null) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 시작일시를 선택해주세요'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 신청 시작일시는 생성일자 이후여야 함
      if (_applyStartDateTime!.isBefore(createdAt)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 시작일시는 캠페인 생성일자 이후여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 신청 시작일시는 생성일자로부터 14일 이내여야 함
      if (_applyStartDateTime!.isAfter(maxDate)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 시작일시는 캠페인 생성일자로부터 14일 이내여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_applyEndDateTime == null) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 종료일시를 선택해주세요'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 신청 종료일시는 생성일자로부터 14일 이내여야 함
      if (_applyEndDateTime!.isAfter(maxDate)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 종료일시는 캠페인 생성일자로부터 14일 이내여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_reviewStartDateTime == null) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 시작일시를 선택해주세요'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 리뷰 시작일시는 생성일자 이후여야 함
      if (_reviewStartDateTime!.isBefore(createdAt)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 시작일시는 캠페인 생성일자 이후여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 리뷰 시작일시는 생성일자로부터 14일 이내여야 함
      if (_reviewStartDateTime!.isAfter(maxDate)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 시작일시는 캠페인 생성일자로부터 14일 이내여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_reviewEndDateTime == null) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 종료일시를 선택해주세요'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 리뷰 종료일시는 생성일자로부터 14일 이내여야 함
      if (_reviewEndDateTime!.isAfter(maxDate)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 종료일시는 캠페인 생성일자로부터 14일 이내여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_applyEndDateTime!.isBefore(_applyStartDateTime!) ||
          _applyEndDateTime!.isAtSameMomentAs(_applyStartDateTime!)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 종료일시는 시작일시보다 뒤여야 합니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_applyEndDateTime!.isAfter(_reviewStartDateTime!) ||
          _applyEndDateTime!.isAtSameMomentAs(_reviewStartDateTime!)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 종료일시는 리뷰 시작일시보다 빠를 수 없습니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_reviewStartDateTime!.isAfter(_reviewEndDateTime!) ||
          _reviewStartDateTime!.isAtSameMomentAs(_reviewEndDateTime!)) {
        _isCreatingCampaign = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 시작일시는 종료일시보다 빠를 수 없습니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 기존 이미지 URL 사용 (이미지 변경 불가)
      final finalImageUrl = _originalCampaign?.productImageUrl;

      debugPrint('📡 [캠페인 수정] RPC 호출 준비 완료');
      debugPrint('   - campaignId: ${widget.campaignId}');
      debugPrint('   - title: ${_productNameController.text.trim()}');
      debugPrint('   - seller: ${_sellerController.text.trim()}');
      debugPrint(
        '   - productPrice: ${int.tryParse(_paymentAmountController.text)}',
      );
      debugPrint('   - applyStartDate: $_applyStartDateTime');
      debugPrint('   - applyEndDate: $_applyEndDateTime');
      debugPrint('   - reviewStartDate: $_reviewStartDateTime');
      debugPrint('   - reviewEndDate: $_reviewEndDateTime');

      final response = await _campaignService.updateCampaignV2(
        campaignId: widget.campaignId,
        title: _productNameController.text.trim(),
        description: _originalCampaign?.description ?? '',
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
        seller: () {
          final seller = _sellerController.text.trim();
          if (seller.isEmpty) {
            debugPrint('❌ [캠페인 수정] 에러: 판매자명이 비어있음');
            throw Exception('판매자명을 입력해주세요.');
          }
          debugPrint('✅ [캠페인 수정] 판매자명: $seller');
          return seller;
        }(),
        productNumber: _productNumberController.text.trim(),
        productName: () {
          final productName = _productNameController.text.trim();
          if (productName.isEmpty) {
            debugPrint('❌ [캠페인 수정] 에러: 상품명이 비어있음');
            throw Exception('상품명을 입력해주세요.');
          }
          debugPrint('✅ [캠페인 수정] 상품명: $productName');
          return productName;
        }(),
        productPrice: () {
          final price = int.tryParse(_paymentAmountController.text);
          if (price == null) {
            debugPrint(
              '❌ [캠페인 수정] 에러: 상품 가격 파싱 실패 (입력값: ${_paymentAmountController.text})',
            );
            throw Exception('상품 가격을 입력해주세요.');
          }
          debugPrint('✅ [캠페인 수정] 상품 가격: $price');
          return price;
        }(),
        reviewType: _reviewType,
        reviewTextLength: reviewTextLength,
        reviewImageCount: reviewImageCount,
        preventProductDuplicate: _preventProductDuplicate,
        preventStoreDuplicate: _preventStoreDuplicate,
        duplicatePreventDays:
            int.tryParse(_duplicateCheckDaysController.text) ?? 0,
        paymentMethod: _paymentType,
        productImageUrl: () {
          if (finalImageUrl == null) {
            debugPrint('❌ [캠페인 수정] 에러: 상품 이미지 URL 없음');
            throw Exception('상품 이미지가 필요합니다.');
          }
          debugPrint('✅ [캠페인 수정] 상품 이미지 URL: $finalImageUrl');
          return finalImageUrl;
        }(),
        purchaseMethod: _purchaseMethod,
        // 상품제공여부: '그외' 선택 시 입력한 텍스트 그대로 저장, 아니면 타입값 저장
        productProvisionType: _productProvisionType == '그외'
            ? _productProvisionOtherController.text.trim()
            : _productProvisionType,
        reviewKeywords: _useReviewKeywords && _reviewKeywords.isNotEmpty
            ? _reviewKeywords
            : null, // ✅ 추가
      );

      debugPrint('📥 [캠페인 수정] RPC 응답 수신');
      debugPrint('   - success: ${response.success}');
      debugPrint('   - error: ${response.error}');
      debugPrint('   - message: ${response.message}');
      debugPrint('   - data: ${response.data != null ? "존재" : "null"}');

      if (response.success) {
        debugPrint('✅ [캠페인 수정] 성공!');
        // ✅ 성공 시 즉시 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '캠페인이 수정되었습니다!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          final campaign = response.data;
          if (campaign != null) {
            debugPrint(
              '✅ [캠페인 수정] 완료 - campaignId: ${campaign.id}, title: ${campaign.title}',
            );
            context.pop(campaign);
          } else {
            debugPrint('⚠️ [캠페인 수정] Campaign 객체가 null입니다. 일반 새로고침으로 대체합니다.');
            context.pop(true);
          }
        }
      } else {
        debugPrint('❌ [캠페인 수정] 실패: ${response.error}');
        // ✅ 에러 시에도 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? '캠페인 수정에 실패했습니다.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [캠페인 수정] 예외 발생!');
      debugPrint('   - 에러 타입: ${e.runtimeType}');
      debugPrint('   - 에러 메시지: $e');
      debugPrint('   - 스택 트레이스: $stackTrace');
      // ✅ 예외 시에도 플래그 해제
      _isCreatingCampaign = false;
      _lastCampaignCreationId = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예상치 못한 오류: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '기본 일정 설정 변경',
            onPressed: () => _showDefaultScheduleSettingsDialog(context),
          ),
        ],
        title: const Text('캠페인 편집'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoadingCampaign
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              // ✅ 웹에서는 autovalidateMode 비활성화 (validator 폭주 방지)
              autovalidateMode: kIsWeb
                  ? AutovalidateMode.disabled
                  : AutovalidateMode.onUserInteraction,
              child: ResponsiveBuilder(
                builder: (context, sizingInformation) {
                  return SingleChildScrollView(
                    padding: getValueForScreenType<EdgeInsets>(
                      context: context,
                      mobile: const EdgeInsets.all(16),
                      tablet: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      desktop: const EdgeInsets.symmetric(
                        horizontal: 100,
                        vertical: 30,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: getValueForScreenType<double>(
                            context: context,
                            mobile: double.infinity,
                            tablet: 700,
                            desktop: 900,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBoundary(_buildCampaignTypeSection()),
                            const SizedBox(height: 24),

                            _buildBoundary(_buildProductInfoSection()),
                            const SizedBox(height: 24),

                            _buildBoundary(_buildReviewSettings()),
                            const SizedBox(height: 24),

                            _buildBoundary(_buildScheduleSection()),
                            const SizedBox(height: 24),

                            _buildBoundary(_buildDuplicatePreventSection()),
                            const SizedBox(height: 24),

                            _buildBoundary(_buildCostSection()),
                            const SizedBox(height: 24),

                            const SizedBox(height: 32),

                            _buildBoundary(
                              AbsorbPointer(
                                absorbing:
                                    !_canCreateCampaign() ||
                                    _isCreatingCampaign,
                                child: Opacity(
                                  opacity:
                                      (_canCreateCampaign() &&
                                          !_isCreatingCampaign)
                                      ? 1.0
                                      : 0.6,
                                  child: CustomButton(
                                    text: '캠페인 수정하기',
                                    onPressed:
                                        _canCreateCampaign() &&
                                            !_isCreatingCampaign
                                        ? () {
                                            // 중복 호출 방지: 즉시 체크
                                            if (_isCreatingCampaign) {
                                              debugPrint(
                                                '⚠️ 캠페인 수정이 이미 진행 중입니다.',
                                              );
                                              return;
                                            }
                                            _updateCampaign();
                                          }
                                        : null,
                                    isLoading: _isCreatingCampaign,
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
                },
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
              initialValue: _campaignType,
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
              initialValue: _platform,
              decoration: const InputDecoration(
                labelText: '플랫폼 *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '쿠팡', child: Text('쿠팡')),
                DropdownMenuItem(value: 'N스토어', child: Text('N스토어')),
              ],
              onChanged: (value) {
                if (value != null) {
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
              readOnly: true,
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
              initialValue: _purchaseMethod,
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
              initialValue: _productProvisionType,
              decoration: const InputDecoration(
                labelText: '상품제공여부 *',
                border: OutlineInputBorder(),
                hintText: '선택하세요',
              ),
              items: const [
                DropdownMenuItem(value: '실배송', child: Text('실배송')),
                DropdownMenuItem(value: '회수', child: Text('회수')),
                DropdownMenuItem(value: '그외', child: Text('그외')),
              ],
              onChanged: (value) {
                setState(() {
                  _productProvisionType = value!;
                  // 실배송/회수 선택 시 텍스트 필드에 자동 입력
                  if (value == '실배송') {
                    _productProvisionOtherController.text = '실배송';
                  } else if (value == '회수') {
                    _productProvisionOtherController.text = '회수';
                  } else {
                    // 그외 선택 시: 기존 값이 있으면 유지, 없으면 빈 값
                    // (편집 화면에서는 기존 사용자 입력값을 유지해야 함)
                    if (_productProvisionOtherController.text.isEmpty) {
                      _productProvisionOtherController.clear();
                    }
                    // 기존 값이 있으면 그대로 유지 (아무것도 하지 않음)
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
            const SizedBox(height: 16),
            CustomTextField(
              controller: _productProvisionOtherController,
              labelText: '상품제공 방법 상세',
              hintText: _productProvisionType == '그외'
                  ? '상품제공 방법을 입력하세요 (5글자 이내)'
                  : null,
              maxLines: 1,
              readOnly: _productProvisionType != '그외',
              inputFormatters: _productProvisionType == '그외'
                  ? [LengthLimitingTextInputFormatter(5)]
                  : null,
              validator: (value) {
                if (_productProvisionType == '그외') {
                  if (value == null || value.trim().isEmpty) {
                    return '상품제공 방법을 입력해주세요';
                  }
                  if (value.trim().length > 5) {
                    return '5글자 이내로 입력해주세요';
                  }
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
            ),
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
              initialValue: _reviewType,
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
            ReviewKeywordsInput(
              enabled: _useReviewKeywords,
              keywords: _reviewKeywords,
              onEnabledChanged: (enabled) {
                setState(() {
                  _useReviewKeywords = enabled;
                  if (!enabled) {
                    _reviewKeywords = []; // 비활성화 시 키워드 초기화
                  }
                });
              },
              onChanged: (keywords) {
                setState(() {
                  _reviewKeywords = keywords;
                });
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _campaignRewardController,
              labelText: '리뷰비',
              hintText: '선택사항, 미입력 시 0',
              keyboardType: TextInputType.number,
              readOnly: true,
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
              readOnly: true,
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
    if (_originalCampaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('캠페인 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final createdAt = _originalCampaign!.createdAt;
    final date = await showDatePicker(
      context: context,
      initialDate: _applyStartDateTime ?? createdAt,
      firstDate: createdAt,
      lastDate: createdAt.add(const Duration(days: 14)),
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _applyStartDateTime != null
            ? TimeOfDay.fromDateTime(_applyStartDateTime!)
            : TimeOfDay.fromDateTime(createdAt),
        initialEntryMode: TimePickerEntryMode.input,
      );

      if (time != null) {
        if (!mounted) return;
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

        // 생성일자 이후인지 검증
        if (dateTime.isBefore(createdAt)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 시작일시는 캠페인 생성일자 이후여야 합니다'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
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
    if (_originalCampaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('캠페인 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final createdAt = _originalCampaign!.createdAt;
    final date = await showDatePicker(
      context: context,
      initialDate: _applyEndDateTime ?? createdAt,
      firstDate: createdAt,
      lastDate: createdAt.add(const Duration(days: 14)),
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _applyEndDateTime != null
            ? TimeOfDay.fromDateTime(_applyEndDateTime!)
            : TimeOfDay.fromDateTime(createdAt),
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
    if (_originalCampaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('캠페인 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final createdAt = _originalCampaign!.createdAt;
    final date = await showDatePicker(
      context: context,
      initialDate: _reviewStartDateTime ?? createdAt,
      firstDate: createdAt,
      lastDate: createdAt.add(const Duration(days: 14)),
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _reviewStartDateTime != null
            ? TimeOfDay.fromDateTime(_reviewStartDateTime!)
            : TimeOfDay.fromDateTime(createdAt),
        initialEntryMode: TimePickerEntryMode.input,
      );

      if (time != null) {
        if (!mounted) return;
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

        // 생성일자 이후인지 검증
        if (dateTime.isBefore(createdAt)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리뷰 시작일시는 캠페인 생성일자 이후여야 합니다'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
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
    if (_originalCampaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('캠페인 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final createdAt = _originalCampaign!.createdAt;
    final initialDate = _reviewEndDateTime ?? createdAt;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: createdAt,
      lastDate: createdAt.add(const Duration(days: 14)),
    );

    if (date == null) return;

    if (!mounted) return;
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

  /// 기본 일정 설정 변경 다이얼로그 표시 (캠페인 생성 화면과 동일)
  Future<void> _showDefaultScheduleSettingsDialog(BuildContext context) async {
    final currentSchedule =
        await CampaignDefaultScheduleService.loadDefaultSchedule();

    int applyStartDays = currentSchedule.applyStartDays;
    String applyStartTime = currentSchedule.applyStartTime;
    int applyEndDays = currentSchedule.applyEndDays;
    String applyEndTime = currentSchedule.applyEndTime;
    int reviewStartDays = currentSchedule.reviewStartDays;
    String reviewStartTime = currentSchedule.reviewStartTime;
    int reviewEndDays = currentSchedule.reviewEndDays;
    String reviewEndTime = currentSchedule.reviewEndTime;

    final applyStartDaysController = TextEditingController(
      text: applyStartDays.toString(),
    );
    final applyStartTimeController = TextEditingController(
      text: applyStartTime,
    );
    final applyEndDaysController = TextEditingController(
      text: applyEndDays.toString(),
    );
    final applyEndTimeController = TextEditingController(text: applyEndTime);
    final reviewStartDaysController = TextEditingController(
      text: reviewStartDays.toString(),
    );
    final reviewStartTimeController = TextEditingController(
      text: reviewStartTime,
    );
    final reviewEndDaysController = TextEditingController(
      text: reviewEndDays.toString(),
    );
    final reviewEndTimeController = TextEditingController(text: reviewEndTime);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기본 일정 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '신청 시작일 오프셋 (일)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: applyStartDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '신청 시작 시간 (HH:mm)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: applyStartTimeController,
                decoration: const InputDecoration(
                  hintText: '14:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '신청 종료일 오프셋 (일)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: applyEndDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '신청 종료 시간 (HH:mm)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: applyEndTimeController,
                decoration: const InputDecoration(
                  hintText: '18:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '리뷰 시작일 오프셋 (일)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reviewStartDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '리뷰 시작 시간 (HH:mm)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reviewStartTimeController,
                decoration: const InputDecoration(
                  hintText: '08:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '리뷰 종료일 오프셋 (일)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reviewEndDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '리뷰 종료 시간 (HH:mm)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reviewEndTimeController,
                decoration: const InputDecoration(
                  hintText: '20:00',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              applyStartDaysController.dispose();
              applyStartTimeController.dispose();
              applyEndDaysController.dispose();
              applyEndTimeController.dispose();
              reviewStartDaysController.dispose();
              reviewStartTimeController.dispose();
              reviewEndDaysController.dispose();
              reviewEndTimeController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 시간 형식 검증 (HH:mm)
              final timePattern = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');

              if (!timePattern.hasMatch(applyStartTimeController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('신청 시작 시간 형식이 올바르지 않습니다 (HH:mm)'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (!timePattern.hasMatch(applyEndTimeController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('신청 종료 시간 형식이 올바르지 않습니다 (HH:mm)'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (!timePattern.hasMatch(reviewStartTimeController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('리뷰 시작 시간 형식이 올바르지 않습니다 (HH:mm)'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (!timePattern.hasMatch(reviewEndTimeController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('리뷰 종료 시간 형식이 올바르지 않습니다 (HH:mm)'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              final applyStartDays = int.tryParse(
                applyStartDaysController.text,
              );
              final applyEndDays = int.tryParse(applyEndDaysController.text);
              final reviewStartDays = int.tryParse(
                reviewStartDaysController.text,
              );
              final reviewEndDays = int.tryParse(reviewEndDaysController.text);

              if (applyStartDays == null || applyStartDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('신청 시작일 오프셋은 0 이상의 숫자여야 합니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (applyStartDays > 14) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('신청 시작일은 오늘로부터 14일 이내여야 합니다'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (applyEndDays == null || applyEndDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('신청 종료일 오프셋은 0 이상의 숫자여야 합니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (applyEndDays > 14) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('신청 종료일은 오늘로부터 14일 이내여야 합니다'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (reviewStartDays == null || reviewStartDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('리뷰 시작일 오프셋은 0 이상의 숫자여야 합니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (reviewStartDays > 14) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('리뷰 시작일은 오늘로부터 14일 이내여야 합니다'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (reviewEndDays == null || reviewEndDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('리뷰 종료일 오프셋은 0 이상의 숫자여야 합니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              if (reviewEndDays > 14) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('리뷰 종료일은 오늘로부터 14일 이내여야 합니다'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              final schedule = CampaignDefaultSchedule(
                applyStartDays: applyStartDays,
                applyStartTime: applyStartTimeController.text,
                applyEndDays: applyEndDays,
                applyEndTime: applyEndTimeController.text,
                reviewStartDays: reviewStartDays,
                reviewStartTime: reviewStartTimeController.text,
                reviewEndDays: reviewEndDays,
                reviewEndTime: reviewEndTimeController.text,
              );

              final success =
                  await CampaignDefaultScheduleService.saveDefaultSchedule(
                    schedule,
                  );

              applyStartTimeController.dispose();
              applyEndDaysController.dispose();
              applyEndTimeController.dispose();
              reviewStartDaysController.dispose();
              reviewStartTimeController.dispose();
              reviewEndDaysController.dispose();
              reviewEndTimeController.dispose();

              if (context.mounted) {
                Navigator.of(context).pop();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('기본 일정 설정이 저장되었습니다'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('기본 일정 설정 저장에 실패했습니다'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
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

  Widget _buildCostSection() {
    // 편집 화면에서는 추가 비용 변동이 없으므로 비용 섹션 제거
    // 회사 지갑 잔액만 정보성으로 표시
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
                Icon(Icons.info_outline, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text(
                  '비용 정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '편집 시에는 추가 비용이 발생하지 않습니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreateCampaign() {
    final productName = _productNameController.text.trim();
    final maxParticipants = _maxParticipantsController.text;

    // 편집 시에는 비용 체크 제거 (추가 비용 변동 없음)
    return productName.isNotEmpty &&
        _applyStartDateTime != null &&
        _applyEndDateTime != null &&
        _reviewStartDateTime != null &&
        _reviewEndDateTime != null &&
        (int.tryParse(maxParticipants) ?? 0) > 0 &&
        !_isCreatingCampaign; // ✅ 중복 호출 방지
  }

  // ✅ 웹에서 RepaintBoundary 조건부 처리 헬퍼
  // 웹에서는 TextField가 포함된 위젯에 RepaintBoundary를 씌우면
  // 커서가 깜빡일 때마다 전체 영역을 텍스처로 다시 굽는 과정이 발생하여 성능 저하
  Widget _buildBoundary(Widget child) {
    if (kIsWeb) return child; // 웹이면 그냥 child 반환 (커서 깜빡임 성능 이슈 방지)
    return RepaintBoundary(child: child); // 앱에서는 성능 최적화 도움됨
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
}
