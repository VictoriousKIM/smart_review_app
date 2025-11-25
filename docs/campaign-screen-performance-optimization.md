# 캠페인 생성/편집 화면 성능 최적화 분석 및 해결 방안

**작성일**: 2025년 11월 25일  
**대상 파일**: 
- `lib/screens/campaign/campaign_creation_screen.dart`
- `lib/screens/campaign/campaign_edit_screen.dart`

## 📋 목차

1. [문제 분석](#문제-분석)
2. [성능 병목 지점](#성능-병목-지점)
3. [해결 방안](#해결-방안)
4. [구현 가이드](#구현-가이드)
5. [예상 효과](#예상-효과)

---

## 🔍 문제 분석

### 현재 상황

캠페인 생성 화면과 편집 화면 진입 시 다음과 같은 렉 현상이 발생합니다:

1. **화면 전환 지연**: 다른 화면에서 진입 시 1-2초간 화면이 멈춤
2. **초기 로딩 지연**: 로딩 인디케이터가 나타나기 전까지 빈 화면
3. **입력 필드 반응 지연**: 초기 진입 후 입력 필드 클릭 시 반응이 느림

### 원인 분석

#### 1. 순차적 네트워크 요청

**편집 화면 (`campaign_edit_screen.dart`)**:
```dart
// 현재 구조
initState() 
  → addPostFrameCallback() 
    → _loadCampaignData() [네트워크 요청 1: 캠페인 데이터]
      → finally 
        → _initializeInStages()
          → _loadCompanyBalance() [네트워크 요청 2: 잔액 조회]
```

**생성 화면 (`campaign_creation_screen.dart`)**:
```dart
// 현재 구조
initState()
  → addPostFrameCallback()
    → _initializeInStages()
      → _loadCompanyBalance() [네트워크 요청: 잔액 조회]
```

**문제점**:
- 편집 화면: 네트워크 요청이 **순차적으로** 실행되어 총 대기 시간 = 요청1 시간 + 요청2 시간
- 각 네트워크 요청이 평균 300-500ms 소요 시, 편집 화면은 최소 600-1000ms 대기

#### 2. 동기적 무거운 작업

**컨트롤러 초기화 및 데이터 설정**:
```dart
// _loadCampaignData() 내부
_productNameController.text = campaign.productName ?? campaign.title;
_keywordController.text = campaign.keyword ?? '';
_optionController.text = campaign.option ?? '';
// ... 10개 이상의 컨트롤러에 값 설정
_updateDateTimeControllers(); // DateTime 파싱 및 포맷팅
_calculateCost(); // 비용 계산
```

**문제점**:
- 컨트롤러에 값을 설정할 때마다 리스너가 트리거됨
- `_calculateCostDebounced()`가 여러 번 호출되어 불필요한 타이머 생성
- DateTime 파싱 (KST 변환)이 동기적으로 실행되어 UI 스레드 블로킹

#### 3. 과도한 setState 호출

**현재 패턴**:
```dart
setState(() {
  _isLoadingCampaign = true; // 1번
});

// ... 네트워크 요청 ...

setState(() {
  _isLoadingCampaign = false; // 2번
  // 데이터 설정
});

// _initializeInStages() 내부
setState(() {
  _isLoadingBalance = true; // 3번
});

// ... 네트워크 요청 ...

setState(() {
  _isLoadingBalance = false; // 4번
  _currentBalance = pendingBalance;
});
```

**문제점**:
- setState가 너무 자주 호출되어 불필요한 리빌드 발생
- 각 setState마다 전체 위젯 트리 재빌드

#### 4. 위젯 빌드 시 무거운 계산

**비용 계산 및 포맷팅**:
```dart
String get _formattedBalance =>
    _cachedFormattedBalance ?? _formatNumber(_currentBalance);

String _formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}
```

**문제점**:
- getter가 호출될 때마다 정규식 매칭 실행
- 캐시가 없으면 매번 계산

---

## 🎯 성능 병목 지점

### 측정 기준 (예상)

| 작업 | 현재 소요 시간 | 최적화 후 목표 |
|------|---------------|---------------|
| 네트워크 요청 (순차) | 600-1000ms | 300-500ms (병렬) |
| 컨트롤러 초기화 | 50-100ms | 10-20ms (지연) |
| DateTime 파싱 | 20-50ms | 5-10ms (백그라운드) |
| setState 호출 | 100-200ms (누적) | 50-100ms (배치) |
| **총 초기화 시간** | **770-1350ms** | **365-630ms** |

---

## ✅ 해결 방안

### 1. 네트워크 요청 병렬화

**편집 화면**: 캠페인 데이터와 잔액을 동시에 요청

```dart
Future<void> _loadInitialData() async {
  setState(() {
    _isLoadingCampaign = true;
    _isLoadingBalance = true;
  });

  // 병렬 실행
  final results = await Future.wait([
    _campaignService.getCampaignById(widget.campaignId),
    _loadCompanyBalanceData(), // 네트워크 요청만 수행
  ]);

  final campaignResult = results[0] as ApiResponse<Campaign>;
  final balanceData = results[1] as Map<String, dynamic>;

  // 결과 처리
  if (campaignResult.success && campaignResult.data != null) {
    _populateCampaignData(campaignResult.data!);
  }

  if (balanceData['balance'] != null) {
    setState(() {
      _currentBalance = balanceData['balance'] as int;
      _isLoadingBalance = false;
    });
  }

  setState(() {
    _isLoadingCampaign = false;
  });
}
```

### 2. 컨트롤러 초기화 지연 및 배치 처리

**리스너 일시 비활성화 후 배치 설정**:

```dart
void _populateCampaignData(Campaign campaign) {
  // 리스너 일시 비활성화
  _ignoreCostListeners = true;

  // 모든 컨트롤러 값 설정 (동기)
  _productNameController.text = campaign.productName ?? campaign.title;
  _keywordController.text = campaign.keyword ?? '';
  // ... 나머지 설정

  // DateTime 설정 (비동기로 분리)
  _applyStartDateTime = campaign.applyStartDate;
  _applyEndDateTime = campaign.applyEndDate;
  _reviewStartDateTime = campaign.reviewStartDate;
  _reviewEndDateTime = campaign.reviewEndDate;

  // 리스너 재활성화 및 한 번만 계산
  _ignoreCostListeners = false;
  
  // 다음 프레임에 실행 (UI 블로킹 방지)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _updateDateTimeControllers();
      _calculateCost(); // 한 번만 실행
    }
  });
}
```

### 3. setState 배치 처리

**여러 상태 변경을 한 번에 처리**:

```dart
void _updateLoadingStates({
  bool? isLoadingCampaign,
  bool? isLoadingBalance,
  int? balance,
}) {
  if (!mounted) return;

  bool shouldUpdate = false;
  
  if (isLoadingCampaign != null && _isLoadingCampaign != isLoadingCampaign) {
    _isLoadingCampaign = isLoadingCampaign;
    shouldUpdate = true;
  }
  
  if (isLoadingBalance != null && _isLoadingBalance != isLoadingBalance) {
    _isLoadingBalance = isLoadingBalance;
    shouldUpdate = true;
  }
  
  if (balance != null && _currentBalance != balance) {
    _currentBalance = balance;
    _cachedFormattedBalance = null; // 캐시 무효화
    shouldUpdate = true;
  }

  if (shouldUpdate) {
    setState(() {}); // 한 번만 호출
  }
}
```

### 4. DateTime 파싱 최적화

**백그라운드에서 파싱 후 UI 업데이트**:

```dart
Future<void> _parseAndSetDateTimes(Campaign campaign) async {
  // 백그라운드에서 파싱 (compute 사용)
  final dateTimes = await compute(_parseCampaignDateTimes, {
    'applyStartDate': campaign.applyStartDate.toIso8601String(),
    'applyEndDate': campaign.applyEndDate.toIso8601String(),
    'reviewStartDate': campaign.reviewStartDate.toIso8601String(),
    'reviewEndDate': campaign.reviewEndDate.toIso8601String(),
  });

  if (mounted) {
    setState(() {
      _applyStartDateTime = dateTimes['applyStartDate'];
      _applyEndDateTime = dateTimes['applyEndDate'];
      _reviewStartDateTime = dateTimes['reviewStartDate'];
      _reviewEndDateTime = dateTimes['reviewEndDate'];
    });
    
    _updateDateTimeControllers();
  }
}

static Map<String, DateTime> _parseCampaignDateTimes(Map<String, String> data) {
  return {
    'applyStartDate': DateTimeUtils.parseKST(data['applyStartDate']!),
    'applyEndDate': DateTimeUtils.parseKST(data['applyEndDate']!),
    'reviewStartDate': DateTimeUtils.parseKST(data['reviewStartDate']!),
    'reviewEndDate': DateTimeUtils.parseKST(data['reviewEndDate']!),
  };
}
```

### 5. 위젯 빌드 최적화

**RepaintBoundary 활용 및 메모이제이션**:

```dart
// 이미 적용되어 있지만, 더 세밀하게 분리
Widget _buildCostSection() {
  return RepaintBoundary(
    child: _CostSectionWidget(
      balance: _currentBalance,
      totalCost: _totalCost,
      isLoading: _isLoadingBalance,
      formattedBalance: _formattedBalance,
      formattedTotalCost: _formattedTotalCost,
      formattedRemaining: _formattedRemaining,
    ),
  );
}

// 별도 StatelessWidget으로 분리하여 불필요한 리빌드 방지
class _CostSectionWidget extends StatelessWidget {
  final int balance;
  final int totalCost;
  final bool isLoading;
  final String formattedBalance;
  final String formattedTotalCost;
  final String formattedRemaining;

  const _CostSectionWidget({
    required this.balance,
    required this.totalCost,
    required this.isLoading,
    required this.formattedBalance,
    required this.formattedTotalCost,
    required this.formattedRemaining,
  });

  @override
  Widget build(BuildContext context) {
    // ... 기존 코드
  }
}
```

### 6. 초기 로딩 상태 개선

**즉시 로딩 인디케이터 표시**:

```dart
@override
Widget build(BuildContext context) {
  // 초기 로딩 상태를 즉시 표시
  if (_isLoadingCampaign || (_isInitializing && _originalCampaign == null)) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('캠페인 편집'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // ... 나머지 UI
}
```

---

## 🛠️ 구현 가이드

### 단계별 구현 순서

#### 1단계: 네트워크 요청 병렬화 (최우선)

**편집 화면 수정**:

```dart
Future<void> _loadInitialData() async {
  // 로딩 상태 즉시 표시
  setState(() {
    _isLoadingCampaign = true;
    _isLoadingBalance = true;
  });

  try {
    // 병렬 실행
    final results = await Future.wait([
      _campaignService.getCampaignById(widget.campaignId),
      _fetchCompanyBalance(), // 네트워크 요청만
    ], eagerError: false); // 하나 실패해도 다른 것 계속 진행

    // 결과 처리
    final campaignResult = results[0] as ApiResponse<Campaign>;
    final balanceResult = results[1] as int?;

    // 캠페인 데이터 처리
    if (campaignResult.success && campaignResult.data != null) {
      await _populateCampaignData(campaignResult.data!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(campaignResult.error ?? '캠페인을 불러올 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
        return;
      }
    }

    // 잔액 처리
    if (balanceResult != null) {
      setState(() {
        _currentBalance = balanceResult;
        _isLoadingBalance = false;
        _cachedFormattedBalance = null;
      });
    } else {
      setState(() {
        _isLoadingBalance = false;
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터 로딩 중 오류가 발생했습니다: $e'),
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
    }
  }
}

// 네트워크 요청만 수행 (setState 없음)
Future<int?> _fetchCompanyBalance() async {
  try {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return null;

    final wallets = await WalletService.getCompanyWallets();
    if (wallets.isNotEmpty) {
      return wallets.first.currentPoints;
    }
    return 0;
  } catch (e) {
    print('⚠️ 잔액 조회 실패: $e');
    return null;
  }
}
```

#### 2단계: 컨트롤러 초기화 최적화

```dart
Future<void> _populateCampaignData(Campaign campaign) async {
  _originalCampaign = campaign;

  // 리스너 일시 비활성화
  _ignoreCostListeners = true;

  // 모든 컨트롤러 값 설정 (동기, 빠른 작업)
  _productNameController.text = campaign.productName ?? campaign.title;
  _keywordController.text = campaign.keyword ?? '';
  _optionController.text = campaign.option ?? '';
  _quantityController.text = campaign.quantity.toString();
  _sellerController.text = campaign.seller ?? '';
  _productNumberController.text = campaign.productNumber ?? '';
  _paymentAmountController.text = (campaign.productPrice ?? 0).toString();
  _campaignRewardController.text = campaign.campaignReward.toString();
  _maxParticipantsController.text = campaign.maxParticipants?.toString() ?? '10';
  _maxPerReviewerController.text = campaign.maxPerReviewer.toString();
  _duplicateCheckDaysController.text = campaign.duplicatePreventDays.toString();

  // 선택 필드 설정
  _campaignType = campaign.campaignType.name;
  _platform = campaign.platform;
  _purchaseMethod = campaign.purchaseMethod;
  _reviewType = campaign.reviewType;
  _preventProductDuplicate = campaign.preventProductDuplicate;
  _preventStoreDuplicate = campaign.preventStoreDuplicate;

  // DateTime 설정 (파싱은 이미 Campaign.fromJson에서 완료됨)
  _applyStartDateTime = campaign.applyStartDate;
  _applyEndDateTime = campaign.applyEndDate;
  _reviewStartDateTime = campaign.reviewStartDate;
  _reviewEndDateTime = campaign.reviewEndDate;

  if (campaign.reviewType == 'star_text' || campaign.reviewType == 'star_text_image') {
    _reviewTextLengthController.text = campaign.reviewTextLength.toString();
  }
  if (campaign.reviewType == 'star_text_image') {
    _reviewImageCountController.text = campaign.reviewImageCount.toString();
  }

  // 리스너 재활성화
  _ignoreCostListeners = false;

  // 다음 프레임에 무거운 작업 실행 (UI 블로킹 방지)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _updateDateTimeControllers();
      _calculateCost(); // 한 번만 실행
    }
  });
}
```

#### 3단계: setState 배치 처리

```dart
void _batchUpdateState({
  bool? isLoadingCampaign,
  bool? isLoadingBalance,
  int? balance,
  Campaign? campaign,
}) {
  if (!mounted) return;

  bool needsUpdate = false;

  if (isLoadingCampaign != null && _isLoadingCampaign != isLoadingCampaign) {
    _isLoadingCampaign = isLoadingCampaign;
    needsUpdate = true;
  }

  if (isLoadingBalance != null && _isLoadingBalance != isLoadingBalance) {
    _isLoadingBalance = isLoadingBalance;
    needsUpdate = true;
  }

  if (balance != null && _currentBalance != balance) {
    _currentBalance = balance;
    _cachedFormattedBalance = null;
    _cachedFormattedRemaining = null;
    needsUpdate = true;
  }

  if (campaign != null) {
    _originalCampaign = campaign;
    needsUpdate = true;
  }

  if (needsUpdate) {
    setState(() {});
  }
}
```

#### 4단계: 초기화 플래그 추가

```dart
class _CampaignEditScreenState extends ConsumerState<CampaignEditScreen> {
  // ... 기존 변수들
  
  bool _isInitializing = true; // 초기화 중 플래그

  @override
  void initState() {
    super.initState();
    
    // 컨트롤러만 초기화 (가벼운 작업)
    _applyStartDateTimeController = TextEditingController();
    _applyEndDateTimeController = TextEditingController();
    _reviewStartDateTimeController = TextEditingController();
    _reviewEndDateTimeController = TextEditingController();

    // 무거운 작업은 프레임 렌더링 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData().then((_) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 초기화 중이거나 로딩 중일 때 즉시 로딩 표시
    if (_isInitializing || _isLoadingCampaign) {
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ... 나머지 UI
  }
}
```

---

## 📊 예상 효과

### 성능 개선 예상치

| 항목 | 개선 전 | 개선 후 | 개선율 |
|------|---------|---------|--------|
| 초기 로딩 시간 | 770-1350ms | 365-630ms | **약 50% 감소** |
| 네트워크 대기 시간 | 600-1000ms | 300-500ms | **약 50% 감소** |
| setState 호출 횟수 | 4-6회 | 2-3회 | **약 50% 감소** |
| UI 반응성 | 느림 | 빠름 | **체감 개선** |

### 사용자 경험 개선

1. **즉각적인 피드백**: 로딩 인디케이터가 즉시 표시되어 사용자가 대기 중임을 인지
2. **빠른 화면 전환**: 병렬 네트워크 요청으로 대기 시간 단축
3. **부드러운 인터랙션**: 불필요한 리빌드 감소로 입력 필드 반응성 향상

---

## 🔧 추가 최적화 제안

### 1. 데이터 캐싱

```dart
// 잔액 정보를 전역 상태로 관리하여 재사용
@riverpod
Future<int> companyBalance(Ref ref) async {
  final wallets = await WalletService.getCompanyWallets();
  return wallets.isNotEmpty ? wallets.first.currentPoints : 0;
}
```

### 2. 지연 로딩 (Lazy Loading)

```dart
// 초기에는 필수 필드만 로드하고, 나머지는 스크롤 시 로드
Widget _buildScheduleSection() {
  return FutureBuilder(
    future: _scheduleDataFuture,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox.shrink(); // 초기에는 숨김
      }
      // ... 스케줄 섹션 UI
    },
  );
}
```

### 3. 이미지 프리로딩 (편집 화면)

```dart
// 캠페인 이미지를 미리 로드하여 표시 지연 방지
Future<void> _preloadCampaignImage(String? imageUrl) async {
  if (imageUrl == null || imageUrl.isEmpty) return;
  
  // 백그라운드에서 이미지 프리로드
  precacheImage(NetworkImage(imageUrl), context);
}
```

---

## 📝 체크리스트

구현 시 다음 사항을 확인하세요:

- [ ] 네트워크 요청이 병렬로 실행되는가?
- [ ] setState 호출이 최소화되었는가?
- [ ] 리스너가 일시 비활성화되어 불필요한 계산이 방지되는가?
- [ ] 로딩 인디케이터가 즉시 표시되는가?
- [ ] 무거운 작업이 백그라운드에서 실행되는가?
- [ ] RepaintBoundary가 적절히 사용되는가?
- [ ] 메모리 누수가 없는가? (dispose 확인)

---

## 🎯 우선순위

1. **높음 (즉시 구현)**: 네트워크 요청 병렬화, setState 배치 처리
2. **중간 (단기)**: 컨트롤러 초기화 최적화, 초기 로딩 상태 개선
3. **낮음 (장기)**: 데이터 캐싱, 지연 로딩, 이미지 프리로딩

---

**참고**: 이 문서는 현재 코드 분석을 기반으로 작성되었으며, 실제 구현 시 프로파일링 도구를 사용하여 성능을 측정하고 추가 최적화를 진행하는 것을 권장합니다.

