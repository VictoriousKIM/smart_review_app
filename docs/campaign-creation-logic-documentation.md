# 캠페인 생성 로직 전체 문서

## 📋 목차

1. [전체 플로우 개요](#전체-플로우-개요)
2. [단계별 상세 설명](#단계별-상세-설명)
3. [주요 컴포넌트](#주요-컴포넌트)
4. [데이터 흐름](#데이터-흐름)
5. [리팩토링 필요 사항](#리팩토링-필요-사항)
6. [성능 최적화](#성능-최적화)

---

## 전체 플로우 개요

```
[사용자 입력]
    ↓
[1. 폼 검증]
    ↓
[2. 잔액 확인]
    ↓
[3. 이미지 업로드 (선택)]
    ├─ Presigned URL 요청
    ├─ R2에 직접 업로드
    └─ Public URL 생성
    ↓
[4. 입력값 검증 및 변환]
    ├─ review_type에 따른 값 설정
    └─ 필수 필드 검증
    ↓
[5. RPC 함수 호출]
    ├─ 사용자 인증
    ├─ 회사 조회
    ├─ 비용 계산
    ├─ 지갑 잠금 (FOR UPDATE NOWAIT)
    ├─ 잔액 확인
    ├─ 캠페인 생성
    ├─ 포인트 거래 기록
    └─ 트리거로 포인트 차감
    ↓
[6. 결과 처리]
    ├─ 성공: 마이캠페인 페이지로 이동
    └─ 실패: 에러 메시지 표시
```

---

## 단계별 상세 설명

### 1. 폼 검증 (`_createCampaign`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:973`

**로직**:
```dart
if (!_formKey.currentState!.validate()) return;
```

**검증 항목**:
- 제품명 (필수)
- 시작일/종료일 (필수)
- 모집 인원 (필수, 1명 이상)
- 리뷰 타입별 필수 필드
  - `star_text`: 리뷰 텍스트 최소 글자 수
  - `star_text_image`: 리뷰 텍스트 최소 글자 수 + 사진 최소 개수

**리팩토링 필요**:
- ❌ 검증 로직이 UI 레이어에 분산되어 있음
- ✅ 별도의 `CampaignFormValidator` 클래스로 분리 필요

---

### 2. 잔액 확인

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:982`

**로직**:
```dart
if (_totalCost > _currentBalance) {
  setState(() {
    _errorMessage = '잔액이 부족합니다. 필요: ${_totalCost}P, 현재: ${_currentBalance}P';
  });
  return;
}
```

**비용 계산** (`_calculateCost`):
```dart
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
  // ...
}
```

**문제점**:
- ❌ 클라이언트와 서버의 비용 계산 로직이 다를 수 있음
- ❌ `calculate_campaign_cost` RPC 함수와 로직이 분리되어 있음

**리팩토링 필요**:
- ✅ 비용 계산 로직을 서버에서만 수행하도록 변경
- ✅ 클라이언트는 서버에서 계산된 비용을 표시만 하도록 변경

---

### 3. 중복 호출 방지

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:974-999`

**로직**:
```dart
// 1. 즉시 체크 (setState 전에)
if (_isCreatingCampaign) {
  debugPrint('⚠️ 캠페인 생성이 이미 진행 중입니다.');
  return;
}

// 2. 생성 시도 ID 생성 (중복 방지용)
final creationId = DateTime.now().millisecondsSinceEpoch.toString();
if (_lastCampaignCreationId == creationId) {
  debugPrint('⚠️ 동일한 생성 시도가 감지되었습니다.');
  return;
}
_lastCampaignCreationId = creationId;

// 3. 즉시 플래그 설정 (setState 전에)
_isCreatingCampaign = true;
```

**UI 레벨 보호**:
```dart
AbsorbPointer(
  absorbing: !_canCreateCampaign() || _isCreatingCampaign || _isUploadingImage,
  child: Opacity(
    opacity: (_canCreateCampaign() && !_isCreatingCampaign && !_isUploadingImage) ? 1.0 : 0.6,
    child: CustomButton(...),
  ),
),
```

**리팩토링 필요**:
- ✅ 중복 호출 방지 로직을 별도의 `CampaignCreationGuard` 클래스로 분리
- ✅ Idempotency Key를 서버로 전달하여 서버 레벨에서도 중복 방지

---

### 4. 이미지 업로드 (`_uploadProductImage`)

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:753`

**플로우**:
```
1. Presigned URL 요청 (Cloudflare Workers API)
   └─ POST /api/presigned-url
      ├─ fileName: product_{timestamp}.jpg
      ├─ userId: 현재 사용자 ID
      ├─ contentType: image/jpeg
      ├─ fileType: campaign-images
      └─ method: PUT

2. R2에 직접 업로드 (Presigned URL 사용)
   └─ PUT {presignedUrl}
      └─ Body: imageBytes

3. Public URL 생성
   └─ https://smart-review-api.nightkille.workers.dev/api/files/{filePath}
```

**재시도 로직**:
- 최대 3회 재시도
- 지수 백오프 (attempt * 2초)
- 재시도 불가능한 에러 감지 (인증 에러, 잘못된 요청)
- 사용자 확인 다이얼로그

**에러 처리**:
```dart
final errorType = ErrorHandler.detectErrorType(e);
ErrorHandler.handleNetworkError(e, context: {...});
final userFriendlyMessage = ErrorHandler.getUserFriendlyMessage(errorType, e.toString());
```

**리팩토링 필요**:
- ✅ 이미지 업로드 로직을 별도의 `ImageUploadService`로 분리
- ✅ 재시도 로직을 재사용 가능한 `RetryHandler`로 분리
- ✅ 업로드 진행률 표시를 별도 위젯으로 분리

---

### 5. 입력값 검증 및 변환

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:1028-1062`

**로직**:
```dart
// review_type에 따른 값 설정
if (_reviewType == 'star_only') {
  reviewTextLength = null;
  reviewImageCount = null;
} else if (_reviewType == 'star_text') {
  reviewTextLength = int.tryParse(_reviewTextLengthController.text);
  if (reviewTextLength == null || reviewTextLength <= 0) {
    // 에러 처리
  }
  reviewImageCount = null;
} else if (_reviewType == 'star_text_image') {
  reviewTextLength = int.tryParse(_reviewTextLengthController.text);
  reviewImageCount = int.tryParse(_reviewImageCountController.text);
  // 검증...
}
```

**리팩토링 필요**:
- ❌ 검증 로직이 UI 레이어에 있음
- ✅ `ReviewTypeValidator` 클래스로 분리
- ✅ 서버 레벨에서도 동일한 검증 수행

---

### 6. RPC 함수 호출 (`createCampaignV2`)

**위치**: `lib/services/campaign_service.dart:612`

**플로우**:
```
1. 사용자 인증 확인
2. 입력값 검증
   ├─ 제품명 필수
   ├─ 시작일 < 종료일
   └─ 모집 인원 > 0
3. RPC 함수 호출
   └─ create_campaign_with_points_v2
4. 생성된 캠페인 조회
5. 결과 반환
```

**RPC 함수 파라미터**:
```dart
{
  'p_title': title,
  'p_description': description,
  'p_campaign_type': campaignType,
  'p_review_reward': reviewReward,
  'p_max_participants': maxParticipants,
  'p_start_date': startDate.toIso8601String(),
  'p_end_date': endDate.toIso8601String(),
  'p_platform': platform,
  'p_keyword': keyword,
  'p_option': option,
  'p_quantity': quantity ?? 1,
  'p_seller': seller,
  'p_product_number': productNumber,
  'p_product_image_url': productImageUrl,
  'p_product_name': productName,
  'p_product_price': productPrice,
  'p_purchase_method': purchaseMethod ?? 'mobile',
  'p_product_description': null,
  'p_review_type': reviewType ?? 'star_only',
  'p_review_text_length': reviewTextLength,
  'p_review_image_count': reviewImageCount,
  'p_prevent_product_duplicate': preventProductDuplicate ?? false,
  'p_prevent_store_duplicate': preventStoreDuplicate ?? false,
  'p_duplicate_prevent_days': duplicatePreventDays ?? 0,
  'p_payment_method': paymentMethod ?? 'platform',
}
```

**리팩토링 필요**:
- ❌ 파라미터가 너무 많음 (20개 이상)
- ✅ `CampaignCreationRequest` DTO 클래스로 묶기
- ✅ 서버에서도 동일한 DTO 사용

---

### 7. 데이터베이스 RPC 함수 (`create_campaign_with_points_v2`)

**위치**: `supabase/migrations/20251116130000_fix_duplicate_point_deduction_trigger.sql`

**플로우**:
```
1. 사용자 인증 확인
   └─ auth.uid()

2. 사용자의 활성 회사 조회
   └─ company_users 테이블
      ├─ status = 'active'
      └─ company_role IN ('owner', 'manager')

3. 총 비용 계산
   └─ calculate_campaign_cost(p_payment_method, p_product_price, p_review_reward, p_max_participants)

4. 회사 지갑 조회 및 잠금
   └─ FOR UPDATE NOWAIT
      ├─ company_id로 조회
      └─ user_id IS NULL (회사 지갑)

5. 잔액 확인
   └─ current_points >= v_total_cost

6. 캠페인 생성
   └─ INSERT INTO campaigns

7. 포인트 거래 기록
   └─ INSERT INTO point_transactions
      └─ 트리거가 자동으로 wallets 잔액 업데이트

8. 차감 후 잔액 검증
   └─ points_after == points_before - total_cost

9. 결과 반환
```

**중요 사항**:
- ✅ `FOR UPDATE NOWAIT`: 데드락 방지
- ✅ 트리거만 사용하여 포인트 차감 (중복 차감 방지)
- ✅ 트랜잭션으로 원자성 보장

**리팩토링 필요**:
- ❌ RPC 함수가 너무 길고 복잡함 (200줄 이상)
- ✅ 단계별로 별도 함수로 분리
- ✅ 에러 메시지 상수화

---

## 주요 컴포넌트

### 1. UI 컴포넌트

**파일**: `lib/screens/campaign/campaign_creation_screen.dart`

**주요 상태 변수**:
```dart
// 이미지 관련
Uint8List? _capturedImage;
Uint8List? _productImage;
bool _isAnalyzing = false;
bool _isLoadingImage = false;
bool _isEditingImage = false;
bool _isUploadingImage = false;
double _uploadProgress = 0.0;

// 캠페인 생성 관련
bool _isCreatingCampaign = false;
String? _lastCampaignCreationId;

// 입력 필드
final _productNameController = TextEditingController();
final _paymentAmountController = TextEditingController();
final _reviewRewardController = TextEditingController();
// ... (총 15개 컨트롤러)

// 선택 필드
String _campaignType = 'reviewer';
String _platform = 'coupang';
String _paymentType = 'platform';
String _purchaseMethod = 'mobile';
String _reviewType = 'star_only';

// 비용 및 잔액
int _totalCost = 0;
int _currentBalance = 0;
```

**리팩토링 필요**:
- ❌ 상태 변수가 너무 많음 (30개 이상)
- ✅ `CampaignCreationState` 클래스로 묶기
- ✅ Riverpod 또는 Provider로 상태 관리

---

### 2. 서비스 레이어

#### CampaignService

**파일**: `lib/services/campaign_service.dart`

**주요 메서드**:
- `createCampaignV2`: 캠페인 생성 (V2)
- `getUserCampaigns`: 사용자 캠페인 조회
- `getUserPreviousCampaigns`: 이전 캠페인 조회

**리팩토링 필요**:
- ❌ 에러 처리가 중복됨
- ✅ 공통 에러 처리 로직 분리

#### CloudflareWorkersService

**파일**: `lib/services/cloudflare_workers_service.dart`

**주요 메서드**:
- `getPresignedUrl`: Presigned URL 생성
- `uploadToPresignedUrl`: Presigned URL로 업로드
- `getPresignedUrlForViewing`: 조회용 Presigned URL 생성

**리팩토링 필요**:
- ✅ 현재 구조는 양호

---

### 3. 데이터베이스 레이어

#### RPC 함수

**파일**: `supabase/migrations/20251116130000_fix_duplicate_point_deduction_trigger.sql`

**주요 함수**:
- `create_campaign_with_points_v2`: 캠페인 생성 및 포인트 차감

**트리거**:
- `point_transactions_wallet_balance_trigger`: 포인트 거래 시 지갑 잔액 자동 업데이트

**리팩토링 필요**:
- ❌ 함수가 너무 길고 복잡함
- ✅ 단계별로 별도 함수로 분리
- ✅ 에러 메시지 상수화

---

## 데이터 흐름

### 1. 이미지 업로드 플로우

```
[Flutter UI]
    ↓
[CloudflareWorkersService.getPresignedUrl]
    ↓
[Cloudflare Workers API]
    ├─ Presigned URL 생성 (AWS Signature V4)
    └─ filePath 반환
    ↓
[CloudflareWorkersService.uploadToPresignedUrl]
    ↓
[R2 Storage] (직접 업로드)
    ↓
[Public URL 생성]
    └─ https://smart-review-api.nightkille.workers.dev/api/files/{filePath}
```

### 2. 캠페인 생성 플로우

```
[Flutter UI]
    ├─ 입력값 수집
    ├─ 이미지 업로드 (선택)
    └─ 검증
    ↓
[CampaignService.createCampaignV2]
    ├─ 입력값 검증
    └─ RPC 호출
    ↓
[Supabase RPC: create_campaign_with_points_v2]
    ├─ 사용자 인증
    ├─ 회사 조회
    ├─ 비용 계산
    ├─ 지갑 잠금
    ├─ 잔액 확인
    ├─ 캠페인 생성
    └─ 포인트 거래 기록
    ↓
[트리거: point_transactions_wallet_balance_trigger]
    └─ 지갑 잔액 자동 업데이트
    ↓
[결과 반환]
    └─ Flutter UI로 전달
```

---

## 미해결 문제

### 🔴 Critical (즉시 해결 필요)

#### 1. payment_amount 완전 제거

**현재 상태**:
- ✅ RPC 함수에서 `p_product_price` 사용 (완료)
- ✅ Flutter 서비스에서 `productPrice` 파라미터 사용 (완료)
- ❌ Flutter UI에서 여전히 `_paymentAmountController` 사용
- ❌ Campaign 모델에 `paymentAmount` 필드가 여전히 존재
- ❌ `fromJson`에서 `payment_amount`를 읽어서 `paymentAmount`에 저장

**문제점**:
1. **모델 불일치**: DB에는 `product_price`만 저장되지만, 모델에는 `paymentAmount`와 `productPrice` 둘 다 존재
2. **필드명 혼란**: UI에서는 "상품가격"이라고 표시하지만 내부적으로는 `paymentAmountController` 사용
3. **데이터 매핑 문제**: `fromJson`에서 `payment_amount`를 읽지만, 실제 DB에는 `product_price`만 있음

**해결 필요**:
- Campaign 모델에서 `paymentAmount` 필드 제거
- `_paymentAmountController`를 `_productPriceController`로 변경 (또는 유지하되 의미 명확화)
- `fromJson`에서 `product_price`를 읽도록 수정
- `campaign_image_service.dart`에서 `paymentAmount` 참조 제거

**관련 파일**:
- `lib/models/campaign.dart`
- `lib/screens/campaign/campaign_creation_screen.dart`
- `lib/services/campaign_image_service.dart`

**예상 시간**: 1-2시간

---

### 🟡 Important (빠른 시일 내 해결)

#### 2. product_description 완전 제거

**현재 상태**:
- ✅ UI에서 입력 필드 제거됨 (완료)
- ✅ RPC 호출 시 `p_product_description: null`로 설정 (완료)
- ❌ Campaign 모델에 `productDescription` 필드가 여전히 존재
- ❌ `_productDescriptionController`가 선언되어 있지만 사용되지 않음

**문제점**:
1. **사용하지 않는 코드**: `_productDescriptionController`가 선언만 되어 있고 사용되지 않음
2. **모델 복잡도**: 불필요한 필드가 모델에 남아있음

**해결 필요**:
- `_productDescriptionController` 선언 제거
- Campaign 모델에서 `productDescription` 필드 제거 (또는 nullable로 유지)

**관련 파일**:
- `lib/screens/campaign/campaign_creation_screen.dart`
- `lib/models/campaign.dart`

**예상 시간**: 30분

---

#### 3. 상품이미지 표시 문제

**현상**:
- 이미지 URL은 저장되지만 UI에서 표시되지 않음
- 이미지 로딩 실패 에러 발생

**확인 필요**:
- 이미지 URL 형식 확인 (Workers URL 사용 여부)
- CORS 설정 확인
- 이미지 로딩 에러 처리 확인
- `campaign_card.dart`와 `advertiser_my_campaigns_screen.dart`에서 이미지 표시 로직 확인

**예상 원인**:
1. R2 Public URL 직접 접근 불가 (CORS 문제) - 이미 Workers URL로 변경됨
2. 이미지 로딩 실패 시 에러 처리 부족
3. URL이 올바르게 저장되지 않음

**해결 필요**:
- 이미지 표시 로직 개선 (`loadingBuilder`, `errorBuilder` 추가)
- 디버깅 로그 추가
- CORS 에러 감지 및 처리

**관련 파일**:
- `lib/widgets/campaign_card.dart`
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- `lib/screens/campaign/campaign_detail_screen.dart`

**예상 시간**: 1-2시간

---

### 🟢 Nice to Have (여유 있을 때)

#### 4. last_used_at, usage_count 제거

**현재 상태**:
- ❌ `campaign_service.dart`에서 여전히 사용 중
  - `getUserPreviousCampaigns`: `.order('last_used_at')`, `.order('usage_count')` 사용
  - `createCampaignFromPrevious`: `'last_used_at'`, `'usage_count'` 설정

**문제점**:
1. **사용하지 않는 필드 조회**: DB에서 존재하지 않거나 사용하지 않는 필드를 조회/설정
2. **쿼리 오류 가능성**: 필드가 없으면 쿼리 실패 가능

**해결 필요**:
- `getUserPreviousCampaigns`에서 `order('last_used_at')`, `order('usage_count')` 제거
- `createCampaignFromPrevious`에서 `'last_used_at'`, `'usage_count'` 제거
- Campaign 모델에서 필드 확인 및 제거

**관련 파일**:
- `lib/services/campaign_service.dart`
- `lib/models/campaign.dart`

**예상 시간**: 30분

---

## 리팩토링 필요 사항

### 🔴 Critical (즉시 필요)

#### 1. payment_amount 완전 제거

**현재 문제**:
- RPC 함수와 서비스에서는 `productPrice`를 사용하지만, UI에서는 여전히 `_paymentAmountController` 사용
- Campaign 모델에 `paymentAmount`와 `productPrice` 둘 다 존재하여 혼란
- `fromJson`에서 `payment_amount`를 읽지만, 실제 DB에는 `product_price`만 있음

**해결 방안**:
```dart
// Campaign 모델 수정
class Campaign {
  // ❌ 제거
  // final int paymentAmount;
  
  // ✅ 유지
  final int? productPrice;
  
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      // ❌ 제거
      // paymentAmount: json['payment_amount'] ?? 0,
      
      // ✅ product_price만 사용
      productPrice: json['product_price'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      // ❌ 제거
      // 'payment_amount': paymentAmount,
      
      // ✅ product_price만 사용
      'product_price': productPrice,
    };
  }
}

// UI 컨트롤러 이름 변경 (선택사항)
final _productPriceController = TextEditingController();  // _paymentAmountController 대신
```

**관련 파일**:
- `lib/models/campaign.dart`
- `lib/screens/campaign/campaign_creation_screen.dart`
- `lib/services/campaign_image_service.dart`

**예상 시간**: 1-2시간

---

#### 2. 상태 관리 개선

**현재 문제**:
- 30개 이상의 상태 변수가 하나의 클래스에 있음
- 상태 변경이 복잡하고 추적이 어려움

**해결 방안**:
```dart
// 리팩토링 후
class CampaignCreationState {
  // 이미지 관련
  final ImageState imageState;
  
  // 입력 필드
  final FormFields formFields;
  
  // 선택 필드
  final SelectionFields selectionFields;
  
  // 비용 및 잔액
  final CostState costState;
  
  // 로딩 상태
  final LoadingState loadingState;
}

// Riverpod 사용
final campaignCreationStateProvider = StateNotifierProvider<CampaignCreationNotifier, CampaignCreationState>((ref) {
  return CampaignCreationNotifier();
});
```

**예상 시간**: 4-6시간

---

#### 3. 검증 로직 분리

**현재 문제**:
- 검증 로직이 UI 레이어에 분산되어 있음
- 클라이언트와 서버의 검증 로직이 다를 수 있음

**해결 방안**:
```dart
// 리팩토링 후
class CampaignFormValidator {
  static ValidationResult validateForm(CampaignFormData data) {
    final errors = <String>[];
    
    if (data.productName.isEmpty) {
      errors.add('제품명을 입력해주세요');
    }
    
    if (data.startDate.isAfter(data.endDate)) {
      errors.add('시작일은 종료일보다 빠를 수 없습니다');
    }
    
    // review_type 검증
    final reviewValidation = ReviewTypeValidator.validate(
      data.reviewType,
      data.reviewTextLength,
      data.reviewImageCount,
    );
    errors.addAll(reviewValidation.errors);
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

class ReviewTypeValidator {
  static ValidationResult validate(
    String reviewType,
    int? reviewTextLength,
    int? reviewImageCount,
  ) {
    final errors = <String>[];
    
    if (reviewType == 'star_text' || reviewType == 'star_text_image') {
      if (reviewTextLength == null || reviewTextLength <= 0) {
        errors.add('리뷰 텍스트 최소 글자 수를 입력해주세요');
      }
    }
    
    if (reviewType == 'star_text_image') {
      if (reviewImageCount == null || reviewImageCount <= 0) {
        errors.add('사진 최소 개수를 입력해주세요');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
```

**예상 시간**: 2-3시간

---

#### 4. RPC 함수 파라미터 정리

**현재 문제**:
- RPC 함수에 20개 이상의 파라미터가 있음
- 파라미터 순서가 중요하고 실수하기 쉬움

**해결 방안**:
```dart
// 리팩토링 후
class CampaignCreationRequest {
  // 기본 정보
  final String title;
  final String description;
  final String campaignType;
  final String platform;
  
  // 일정
  final DateTime startDate;
  final DateTime endDate;
  
  // 상품 정보
  final ProductInfo productInfo;
  
  // 리뷰 설정
  final ReviewSettings reviewSettings;
  
  // 중복 방지
  final DuplicatePrevention duplicatePrevention;
  
  // 비용
  final CostSettings costSettings;
  
  Map<String, dynamic> toRpcParams() {
    return {
      'p_title': title,
      'p_description': description,
      // ...
    };
  }
}
```

**예상 시간**: 2-3시간

---

### 🟡 Important (빠른 시일 내)

#### 5. product_description 완전 제거

**현재 문제**:
- UI에서 입력 필드는 제거되었지만, `_productDescriptionController`가 선언만 되어 있음
- Campaign 모델에 `productDescription` 필드가 여전히 존재
- RPC 호출 시 `null`로 설정하지만, 모델에서는 필드가 남아있음

**해결 방안**:
```dart
// UI에서 컨트롤러 제거
// ❌ 제거
// final _productDescriptionController = TextEditingController();

@override
void dispose() {
  // ❌ 제거
  // _productDescriptionController.dispose();
  super.dispose();
}

// Campaign 모델에서 필드 제거 (또는 nullable로 유지)
class Campaign {
  // ❌ 제거 (또는 nullable로 유지)
  // final String? productDescription;
  
  Campaign({
    // ❌ 제거
    // this.productDescription,
  });
  
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      // ❌ 제거
      // productDescription: json['product_description'],
    );
  }
}
```

**관련 파일**:
- `lib/screens/campaign/campaign_creation_screen.dart`
- `lib/models/campaign.dart`

**예상 시간**: 30분

---

#### 6. 상품이미지 표시 문제 해결

**현재 문제**:
- 이미지 URL은 저장되지만 UI에서 표시되지 않음
- R2 Public URL 직접 접근이 안 될 수 있음 (CORS 문제)
- 이미지 로딩 실패 시 에러 처리 부족

**해결 방안**:
```dart
// 이미지 URL을 Cloudflare Workers를 통해 제공 (이미 적용됨)
final publicUrl = '${SupabaseConfig.workersApiUrl}/api/files/${presignedUrlResponse.filePath}';

// 이미지 표시 로직 개선
Image.network(
  campaign.productImageUrl,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
      child: CircularProgressIndicator(
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
            : null,
      ),
    );
  },
  errorBuilder: (context, error, stackTrace) {
    debugPrint('🖼️ 이미지 로딩 실패: ${campaign.productImageUrl}');
    debugPrint('에러: $error');
    return Container(
      child: Column(
        children: [
          Icon(Icons.broken_image),
          Text('이미지 로딩 실패'),
        ],
      ),
    );
  },
);
```

**확인 사항**:
1. 이미지 URL 형식 확인 (Workers URL 사용)
2. CORS 설정 확인
3. 이미지 로딩 에러 처리 확인
4. `campaign_card.dart`, `advertiser_my_campaigns_screen.dart`, `campaign_detail_screen.dart`에서 이미지 표시 로직 확인

**관련 파일**:
- `lib/widgets/campaign_card.dart`
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- `lib/screens/campaign/campaign_detail_screen.dart`

**예상 시간**: 1-2시간

---

#### 7. 이미지 업로드 로직 분리

**현재 문제**:
- 이미지 업로드 로직이 UI 레이어에 있음
- 재시도 로직이 복잡함

**해결 방안**:
```dart
// 리팩토링 후
class ImageUploadService {
  final RetryHandler _retryHandler;
  
  Future<String> uploadCampaignImage({
    required Uint8List imageBytes,
    required String userId,
    ProgressCallback? onProgress,
  }) async {
    return _retryHandler.execute(
      () => _uploadImage(imageBytes, userId, onProgress),
      maxRetries: 3,
      onRetry: (attempt, error) {
        // 재시도 로직
      },
    );
  }
  
  Future<String> _uploadImage(
    Uint8List imageBytes,
    String userId,
    ProgressCallback? onProgress,
  ) async {
    // 1. Presigned URL 요청
    final presignedUrl = await CloudflareWorkersService.getPresignedUrl(...);
    onProgress?.call(0.1);
    
    // 2. 업로드
    await CloudflareWorkersService.uploadToPresignedUrl(...);
    onProgress?.call(1.0);
    
    // 3. Public URL 생성
    return '${SupabaseConfig.workersApiUrl}/api/files/${presignedUrl.filePath}';
  }
}
```

**예상 시간**: 2-3시간

---

#### 8. 비용 계산 로직 통합

**현재 문제**:
- 클라이언트와 서버의 비용 계산 로직이 분리되어 있음
- 불일치 가능성

**해결 방안**:
```dart
// 리팩토링 후
class CampaignCostService {
  // 서버에서 비용 계산
  static Future<int> calculateCost({
    required String paymentMethod,
    required int productPrice,
    required int reviewReward,
    required int maxParticipants,
  }) async {
    final response = await SupabaseConfig.client.rpc(
      'calculate_campaign_cost',
      params: {
        'p_payment_method': paymentMethod,
        'p_product_price': productPrice,
        'p_review_reward': reviewReward,
        'p_max_participants': maxParticipants,
      },
    );
    return response as int;
  }
  
  // 클라이언트에서는 서버 결과만 표시
}
```

**예상 시간**: 1-2시간

---

#### 9. RPC 함수 분리

**현재 문제**:
- RPC 함수가 200줄 이상으로 너무 길고 복잡함

**해결 방안**:
```sql
-- 리팩토링 후
-- 1. 사용자 및 회사 조회
CREATE OR REPLACE FUNCTION get_user_company_info(p_user_id UUID)
RETURNS TABLE(company_id UUID, wallet_id UUID, current_points INTEGER)
AS $$
  -- ...
$$;

-- 2. 비용 계산 (이미 존재)
CREATE OR REPLACE FUNCTION calculate_campaign_cost(...)
-- ...

-- 3. 캠페인 생성 (간소화)
CREATE OR REPLACE FUNCTION create_campaign_with_points_v2(...)
AS $$
DECLARE
  v_company_info RECORD;
  v_total_cost INTEGER;
BEGIN
  -- 1. 사용자 및 회사 정보 조회
  SELECT * INTO v_company_info FROM get_user_company_info(auth.uid());
  
  -- 2. 비용 계산
  v_total_cost := calculate_campaign_cost(...);
  
  -- 3. 잔액 확인 및 잠금
  -- ...
  
  -- 4. 캠페인 생성
  -- ...
  
  -- 5. 포인트 거래 기록
  -- ...
END;
$$;
```

**예상 시간**: 3-4시간

---

### 🟢 Nice to Have (여유 있을 때)

#### 10. last_used_at, usage_count 제거

**현재 문제**:
- `campaign_service.dart`에서 사용하지 않는 필드를 조회/설정
- `getUserPreviousCampaigns`: `.order('last_used_at')`, `.order('usage_count')` 사용
- `createCampaignFromPrevious`: `'last_used_at'`, `'usage_count'` 설정
- 필드가 없으면 쿼리 실패 가능

**해결 방안**:
```dart
// getUserPreviousCampaigns 메서드
Future<ApiResponse<List<Campaign>>> getUserPreviousCampaigns() async {
  // ... 기존 코드 ...
  
  final response = await _supabase
      .from('campaigns')
      .select()
      .eq('company_id', companyId)
      // ❌ 제거
      // .order('last_used_at', ascending: false)
      // .order('usage_count', ascending: false)
      
      // ✅ created_at 사용
      .order('created_at', ascending: false)
      .limit(10);
  
  // ... 나머지 코드 ...
}

// createCampaignFromPrevious 메서드
Future<ApiResponse<Campaign>> createCampaignFromPrevious({
  required Campaign previousCampaign,
  // ...
}) async {
  // ... 기존 코드 ...
  
  final response = await _campaignService.createCampaignV2(
    // ... 기존 파라미터들 ...
    // ❌ 제거
    // 'last_used_at': ...,
    // 'usage_count': ...,
  );
  
  // ... 나머지 코드 ...
}
```

**관련 파일**:
- `lib/services/campaign_service.dart`
- `lib/models/campaign.dart` (필드 확인)

**예상 시간**: 30분

---

#### 11. 에러 처리 개선

**현재 문제**:
- 에러 메시지가 하드코딩되어 있음
- 에러 타입별 처리가 일관되지 않음

**해결 방안**:
```dart
// 리팩토링 후
enum CampaignCreationError {
  insufficientBalance,
  invalidForm,
  imageUploadFailed,
  networkError,
  serverError,
}

class CampaignCreationErrorHandler {
  static String getMessage(CampaignCreationError error) {
    switch (error) {
      case CampaignCreationError.insufficientBalance:
        return '포인트가 부족합니다. 충전 후 다시 시도해주세요.';
      // ...
    }
  }
}
```

**예상 시간**: 1-2시간

---

#### 12. 테스트 코드 작성

**현재 문제**:
- 테스트 코드가 없음

**해결 방안**:
```dart
// 리팩토링 후
// test/campaign_creation_test.dart
void main() {
  group('CampaignFormValidator', () {
    test('제품명이 비어있으면 에러', () {
      final data = CampaignFormData(productName: '');
      final result = CampaignFormValidator.validateForm(data);
      expect(result.isValid, false);
      expect(result.errors, contains('제품명을 입력해주세요'));
    });
    
    // ...
  });
}
```

**예상 시간**: 4-6시간

---

## 성능 최적화

### 현재 적용된 최적화

1. **비용 계산 디바운싱**
   ```dart
   void _calculateCostDebounced() {
     _costCalculationTimer?.cancel();
     _costCalculationTimer = Timer(const Duration(milliseconds: 300), () {
       if (mounted) _calculateCost();
     });
   }
   ```

2. **포맷팅 캐싱**
   ```dart
   String? _cachedFormattedBalance;
   String? _cachedFormattedTotalCost;
   String? _cachedFormattedRemaining;
   ```

3. **이미지 캐싱**
   ```dart
   final Map<String, Uint8List> _imageCache = {};
   ```

4. **값 변경 시에만 setState**
   ```dart
   if (_totalCost != cost) {
     _totalCost = cost;
     setState(() {});
   }
   ```

### 추가 최적화 가능 사항

1. **이미지 리사이징 최적화**
   - 백그라운드 스레드에서 처리 (`compute` 사용)
   - 이미 적용됨

2. **폼 필드 최적화**
   - 불필요한 리빌드 방지 (`RepaintBoundary` 사용)
   - 이미 적용됨

3. **네트워크 요청 최적화**
   - 요청 취소 기능 추가
   - 타임아웃 설정
   - 이미 적용됨

---

## 파일 구조

```
lib/
├── screens/
│   └── campaign/
│       └── campaign_creation_screen.dart (2319줄) ⚠️ 너무 김
├── services/
│   ├── campaign_service.dart
│   ├── cloudflare_workers_service.dart
│   └── campaign_image_service.dart
├── widgets/
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   └── image_crop_editor.dart
└── utils/
    └── error_handler.dart

supabase/
└── migrations/
    └── 20251116130000_fix_duplicate_point_deduction_trigger.sql
```

---

## 리팩토링 후 예상 구조

```
lib/
├── screens/
│   └── campaign/
│       └── campaign_creation_screen.dart (500줄 이하)
├── services/
│   ├── campaign_service.dart
│   ├── campaign_creation_service.dart (새로 생성)
│   ├── image_upload_service.dart (새로 생성)
│   └── campaign_cost_service.dart (새로 생성)
├── models/
│   ├── campaign_creation_request.dart (새로 생성)
│   └── campaign_creation_state.dart (새로 생성)
├── validators/
│   ├── campaign_form_validator.dart (새로 생성)
│   └── review_type_validator.dart (새로 생성)
├── widgets/
│   └── campaign_creation/
│       ├── image_upload_section.dart (새로 생성)
│       ├── form_section.dart (새로 생성)
│       └── cost_section.dart (새로 생성)
└── utils/
    ├── error_handler.dart
    └── retry_handler.dart (새로 생성)
```

---

## 우선순위별 리팩토링 계획

### Phase 1: Critical (1-2주)
1. payment_amount 완전 제거 (1-2시간) ⚠️ **즉시 필요**
2. 상태 관리 개선 (Riverpod 도입) (4-6시간)
3. 검증 로직 분리 (2-3시간)
4. RPC 함수 파라미터 정리 (2-3시간)

### Phase 2: Important (2-3주)
5. product_description 완전 제거 (30분)
6. 상품이미지 표시 문제 해결 (1-2시간)
7. 이미지 업로드 로직 분리 (2-3시간)
8. 비용 계산 로직 통합 (1-2시간)
9. RPC 함수 분리 (3-4시간)

### Phase 3: Nice to Have (1-2주)
10. last_used_at, usage_count 제거 (30분)
11. 에러 처리 개선 (1-2시간)
12. 테스트 코드 작성 (4-6시간)

**총 예상 시간**: 4-7주

---

## 참고 사항

### 현재 사용 중인 기술 스택
- Flutter (Dart)
- Supabase (PostgreSQL)
- Cloudflare Workers (R2 Storage)
- Riverpod (상태 관리 - 부분적 사용)

### 의존성
- `supabase_flutter`: Supabase 클라이언트
- `go_router`: 라우팅
- `image_picker`: 이미지 선택
- `image_cropper`: 이미지 크롭
- `image`: 이미지 처리
- `http`: HTTP 요청

---

**작성일**: 2025-11-16  
**작성자**: AI Assistant  
**버전**: 1.0

