import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/campaign_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../config/supabase_config.dart';
import '../../utils/date_time_utils.dart';
import '../../models/campaign.dart';

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
  String _campaignType = 'reviewer';
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

  // 비용 및 잔액
  int _totalCost = 0;
  int _currentBalance = 0;
  bool _isLoadingBalance = false;

  String? _errorMessage;

  // ✅ 5. 비용 계산 디바운싱
  Timer? _costCalculationTimer;
  bool _ignoreCostListeners = false;

  // DateTime 컨트롤러
  late final TextEditingController _applyStartDateTimeController;
  late final TextEditingController _applyEndDateTimeController;
  late final TextEditingController _reviewStartDateTimeController;
  late final TextEditingController _reviewEndDateTimeController;

  // ✅ 5. 포맷팅 캐싱
  String? _cachedFormattedBalance;
  String? _cachedFormattedTotalCost;
  String? _cachedFormattedRemaining;

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
        _ignoreCostListeners = true;

        // 기존 캠페인 데이터로 필드 초기화
        _productNameController.text = campaign.productName ?? campaign.title;
        _keywordController.text = campaign.keyword ?? '';
        _optionController.text = campaign.option ?? '';
        _quantityController.text = campaign.quantity.toString();
        _sellerController.text = campaign.seller ?? '';
        _productNumberController.text = campaign.productNumber ?? '';
        _paymentAmountController.text = (campaign.productPrice ?? 0).toString();
        _campaignRewardController.text = campaign.campaignReward.toString();
        _maxParticipantsController.text =
            campaign.maxParticipants?.toString() ?? '10';
        _maxPerReviewerController.text = campaign.maxPerReviewer.toString();
        _duplicateCheckDaysController.text = campaign.duplicatePreventDays
            .toString();

        _campaignType = campaign.campaignType.name;
        _platform = campaign.platform;
        _purchaseMethod = campaign.purchaseMethod;
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

        // ✅ [중요] 데이터 세팅 완료 후 플래그 해제 및 비용 1회 계산
        _ignoreCostListeners = false;
        _updateDateTimeControllers();
        _calculateCost(); // 여기서 딱 한 번만 계산
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? '캠페인을 불러올 수 없습니다.'),
              backgroundColor: Colors.red,
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
        _calculateCost(); // 초기 비용 계산
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
    _paymentAmountController.addListener(_calculateCostDebounced);
    _campaignRewardController.addListener(_calculateCostDebounced);
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

  Future<void> _updateCampaign() async {
    // ✅ 즉시 체크 (setState 전에) - 중복 호출 방지
    if (_isCreatingCampaign) {
      debugPrint('⚠️ 캠페인 수정이 이미 진행 중입니다.');
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
      if (_applyStartDateTime == null) {
        setState(() {
          _errorMessage = '신청 시작일시를 선택해주세요';
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

      if (_reviewStartDateTime == null) {
        setState(() {
          _errorMessage = '리뷰 시작일시를 선택해주세요';
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

      // 기존 이미지 URL 사용 (이미지 변경 불가)
      final finalImageUrl = _originalCampaign?.productImageUrl;

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
        seller: _sellerController.text.trim(),
        productNumber: _productNumberController.text.trim(),
        productName: _productNameController.text.trim(),
        productPrice: int.tryParse(_paymentAmountController.text) ?? 0,
        reviewType: _reviewType,
        reviewTextLength: reviewTextLength,
        reviewImageCount: reviewImageCount,
        preventProductDuplicate: _preventProductDuplicate,
        preventStoreDuplicate: _preventStoreDuplicate,
        duplicatePreventDays:
            int.tryParse(_duplicateCheckDaysController.text) ?? 0,
        paymentMethod: _paymentType,
        productImageUrl: finalImageUrl,
        purchaseMethod: _purchaseMethod,
      );

      if (response.success) {
        // ✅ 성공 시 즉시 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '캠페인이 수정되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          final campaign = response.data;
          if (campaign != null) {
            debugPrint(
              '✅ 캠페인 수정 성공 - campaignId: ${campaign.id}, title: ${campaign.title}',
            );
            context.pop(campaign);
          } else {
            debugPrint('⚠️ Campaign 객체가 null입니다. 일반 새로고침으로 대체합니다.');
            context.pop(true);
          }
        }
      } else {
        // ✅ 에러 시에도 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        setState(() {
          _errorMessage = response.error ?? '캠페인 수정에 실패했습니다.';
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
                              onPressed: () =>
                                  setState(() => _errorMessage = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                        absorbing: !_canCreateCampaign() || _isCreatingCampaign,
                        child: Opacity(
                          opacity:
                              (_canCreateCampaign() && !_isCreatingCampaign)
                              ? 1.0
                              : 0.6,
                          child: CustomButton(
                            text: '캠페인 수정하기',
                            onPressed:
                                _canCreateCampaign() && !_isCreatingCampaign
                                ? () {
                                    // 중복 호출 방지: 즉시 체크
                                    if (_isCreatingCampaign) {
                                      debugPrint('⚠️ 캠페인 수정이 이미 진행 중입니다.');
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
              controller: _campaignRewardController,
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
            const SizedBox(height: 16),
            CustomTextField(
              controller: _maxPerReviewerController,
              labelText: '리뷰어당 신청 가능 개수',
              hintText: '1',
              keyboardType: TextInputType.number,
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
      lastDate: nowKST.add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _applyStartDateTime != null
            ? TimeOfDay.fromDateTime(_applyStartDateTime!)
            : TimeOfDay.fromDateTime(nowKST),
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
          _applyStartDateTime = dateTime;
          // 신청 종료일시 자동 조정 (종료일이 시작일보다 앞이거나 같으면 조정)
          if (_applyEndDateTime == null ||
              _applyEndDateTime!.isBefore(_applyStartDateTime!) ||
              _applyEndDateTime!.isAtSameMomentAs(_applyStartDateTime!)) {
            // 같은 날이지만 시간을 1시간 뒤로 설정
            if (_applyStartDateTime!.hour < 23) {
              _applyEndDateTime = _applyStartDateTime!.copyWith(
                hour: _applyStartDateTime!.hour + 1,
              );
            } else {
              // 23시인 경우 다음 날 0시로 설정 (분은 유지)
              _applyEndDateTime = _applyStartDateTime!.copyWith(
                day: _applyStartDateTime!.day + 1,
                hour: 0,
              );
            }
          }
          // 리뷰 시작일시 자동 조정
          if (_reviewStartDateTime == null ||
              _applyEndDateTime!.isAfter(_reviewStartDateTime!) ||
              _applyEndDateTime!.isAtSameMomentAs(_reviewStartDateTime!)) {
            _reviewStartDateTime = _applyEndDateTime!.add(
              const Duration(days: 1),
            );
          }
          // 리뷰 종료일시 자동 조정
          if (_reviewEndDateTime == null ||
              _reviewStartDateTime!.isAfter(_reviewEndDateTime!) ||
              _reviewStartDateTime!.isAtSameMomentAs(_reviewEndDateTime!)) {
            _reviewEndDateTime = _reviewStartDateTime!.add(
              const Duration(days: 30),
            );
          }
          _updateDateTimeControllers();
        });
      }
    }
  }

  Future<void> _selectApplyEndDateTime(BuildContext context) async {
    if (_applyStartDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 신청 시작일시를 선택해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final startDate = _applyStartDateTime!;
    final nowKST = DateTimeUtils.nowKST();
    final date = await showDatePicker(
      context: context,
      initialDate:
          _applyEndDateTime ??
          (_applyStartDateTime?.add(const Duration(days: 7)) ??
              nowKST.add(const Duration(days: 7))),
      firstDate: DateTime(startDate.year, startDate.month, startDate.day),
      lastDate: nowKST.add(const Duration(days: 365)),
    );

    if (date != null) {
      // 같은 날인 경우 시작일시의 시간보다 뒤로만 선택 가능
      final isSameDay =
          date.year == startDate.year &&
          date.month == startDate.month &&
          date.day == startDate.day;

      TimeOfDay initialTime;
      if (_applyEndDateTime != null) {
        initialTime = TimeOfDay.fromDateTime(_applyEndDateTime!);
      } else if (isSameDay) {
        // 같은 날이면 시작일시의 시간 + 1시간 (분은 유지)
        initialTime = TimeOfDay(
          hour: (startDate.hour + 1) % 24,
          minute: startDate.minute,
        );
      } else {
        initialTime = TimeOfDay.fromDateTime(nowKST);
      }

      final time = await showTimePicker(
        context: context,
        initialTime: initialTime,
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

        // 같은 날인 경우 시간 검증
        if (isSameDay && dateTime.isBefore(startDate) ||
            dateTime.isAtSameMomentAs(startDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청 종료일시는 시작일시보다 뒤여야 합니다.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _applyEndDateTime = dateTime;
          // 리뷰 시작일시 자동 조정
          if (_reviewStartDateTime == null ||
              _applyEndDateTime!.isAfter(_reviewStartDateTime!) ||
              _applyEndDateTime!.isAtSameMomentAs(_reviewStartDateTime!)) {
            _reviewStartDateTime = _applyEndDateTime!.add(
              const Duration(days: 1),
            );
          }
          // 리뷰 종료일시 자동 조정
          if (_reviewEndDateTime == null ||
              _reviewStartDateTime!.isAfter(_reviewEndDateTime!) ||
              _reviewStartDateTime!.isAtSameMomentAs(_reviewEndDateTime!)) {
            _reviewEndDateTime = _reviewStartDateTime!.add(
              const Duration(days: 30),
            );
          }
          _updateDateTimeControllers();
        });
      }
    }
  }

  Future<void> _selectReviewStartDateTime(BuildContext context) async {
    final nowKST = DateTimeUtils.nowKST();
    final date = await showDatePicker(
      context: context,
      initialDate:
          _reviewStartDateTime ??
          (_applyEndDateTime?.add(const Duration(days: 1)) ??
              nowKST.add(const Duration(days: 8))),
      firstDate:
          _applyEndDateTime?.add(const Duration(days: 1)) ??
          nowKST.add(const Duration(days: 1)),
      lastDate: nowKST.add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _reviewStartDateTime != null
            ? TimeOfDay.fromDateTime(_reviewStartDateTime!)
            : TimeOfDay.fromDateTime(nowKST),
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
          _reviewStartDateTime = dateTime;
          // 리뷰 종료일시 자동 조정
          if (_reviewEndDateTime == null ||
              _reviewStartDateTime!.isAfter(_reviewEndDateTime!) ||
              _reviewStartDateTime!.isAtSameMomentAs(_reviewEndDateTime!)) {
            _reviewEndDateTime = _reviewStartDateTime!.add(
              const Duration(days: 30),
            );
          }
          _updateDateTimeControllers();
        });
      }
    }
  }

  Future<void> _selectReviewEndDateTime(BuildContext context) async {
    final nowKST = DateTimeUtils.nowKST();
    final initialDate =
        _reviewEndDateTime ??
        (_reviewStartDateTime?.add(const Duration(days: 30)) ??
            nowKST.add(const Duration(days: 38)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _reviewStartDateTime?.add(const Duration(days: 1)) ?? nowKST,
      lastDate: nowKST.add(const Duration(days: 365)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
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
        _applyStartDateTime != null &&
        _applyEndDateTime != null &&
        _reviewStartDateTime != null &&
        _reviewEndDateTime != null &&
        _totalCost <= _currentBalance &&
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
