# 캠페인 등록 및 표시 기능 미해결 문제 분석 및 해결책

## 📋 현재 상태 분석

로드맵(`campaign-creation-and-display-issues-roadmap.md`)에 명시된 문제들의 해결 상태를 확인한 결과, 대부분의 Critical 문제는 해결되었지만 일부 문제가 남아있습니다.

---

## ✅ 이미 해결된 문제

### Phase 1: Critical 문제
- ✅ **Task 1.1: 포인트 중복 차감 문제** - 해결됨
  - `20251116094855_fix_critical_campaign_issues.sql`에서 트랜잭션 처리 및 중복 방지 로직 추가
- ✅ **Task 1.2: 사업자 마이페이지 캠페인 표시 문제** - 해결됨
  - RPC 함수 `get_user_campaigns_safe` 수정 (company_id 기반 조회)
  - Flutter 대체 로직 추가
  - 해결책 1번 적용 (강제 새로고침)

### Phase 2: 데이터 저장 문제
- ✅ **Task 2.1: product_name, product_price 추가** - 해결됨
  - 마이그레이션 `20251116095027_add_product_name_price_remove_payment_amount.sql` 적용
  - Flutter 코드에 파라미터 추가 및 전달

### Phase 3: UI 및 UX 개선
- ✅ **Task 3.1: 구매방법 선택 UI 추가** - 해결됨
  - `DropdownButtonFormField` 추가됨
- ✅ **Task 3.3: review_type 검증 로직 추가** - 해결됨
  - `star_only`일 때 `reviewTextLength`, `reviewImageCount`를 `null`로 설정하는 로직 추가

---

## ⚠️ 부분적으로 해결된 문제

### Task 2.2: payment_amount 제거 및 product_price로 통합

**현재 상태:**
- ✅ RPC 함수에서 `p_product_price` 사용 (완료)
- ✅ Flutter 서비스에서 `productPrice` 파라미터 사용 (완료)
- ❌ Flutter UI에서 여전히 `_paymentAmountController` 사용
- ❌ Campaign 모델에 `paymentAmount` 필드가 여전히 존재
- ❌ `fromJson`에서 `payment_amount`를 읽어서 `paymentAmount`에 저장

**문제점:**
1. **모델 불일치**: DB에는 `product_price`만 저장되지만, 모델에는 `paymentAmount`와 `productPrice` 둘 다 존재
2. **필드명 혼란**: UI에서는 "상품가격"이라고 표시하지만 내부적으로는 `paymentAmountController` 사용
3. **데이터 매핑 문제**: `fromJson`에서 `payment_amount`를 읽지만, 실제 DB에는 `product_price`만 있음

**해결 필요:**
- Campaign 모델에서 `paymentAmount` 필드 제거
- `_paymentAmountController`를 `_productPriceController`로 변경 (또는 유지하되 의미 명확화)
- `fromJson`에서 `product_price`를 읽도록 수정

---

### Task 3.2: product_description 필드 제거

**현재 상태:**
- ✅ UI에서 입력 필드 제거됨 (완료)
- ✅ RPC 호출 시 `p_product_description: null`로 설정 (완료)
- ❌ Campaign 모델에 `productDescription` 필드가 여전히 존재
- ❌ `_productDescriptionController`가 선언되어 있지만 사용되지 않음

**문제점:**
1. **사용하지 않는 코드**: `_productDescriptionController`가 선언만 되어 있고 사용되지 않음
2. **모델 복잡도**: 불필요한 필드가 모델에 남아있음

**해결 필요:**
- `_productDescriptionController` 선언 제거
- Campaign 모델에서 `productDescription` 필드 제거 (또는 nullable로 유지)

---

## ❌ 아직 해결되지 않은 문제

### Task 4.1: 상품이미지 표시 문제

**현상:**
- 이미지 URL은 저장되지만 UI에서 표시되지 않음

**확인 필요:**
- 이미지 URL 형식 확인
- CORS 설정 확인
- 이미지 로딩 에러 처리 확인
- `campaign_card.dart`와 `advertiser_my_campaigns_screen.dart`에서 이미지 표시 로직 확인

**예상 원인:**
1. R2 Public URL 형식 문제
2. CORS 정책 문제
3. 이미지 로딩 실패 시 에러 처리 부족
4. URL이 올바르게 저장되지 않음

---

### Task 5.1: last_used_at, usage_count 제거

**현재 상태:**
- ❌ `campaign_service.dart`에서 여전히 사용 중
  - `getUserPreviousCampaigns`: `.order('last_used_at')`, `.order('usage_count')` 사용
  - `createCampaignFromPrevious`: `'last_used_at'`, `'usage_count'` 설정

**문제점:**
1. **사용하지 않는 필드 조회**: DB에서 존재하지 않거나 사용하지 않는 필드를 조회/설정
2. **쿼리 오류 가능성**: 필드가 없으면 쿼리 실패 가능

**해결 필요:**
- `getUserPreviousCampaigns`에서 `order('last_used_at')`, `order('usage_count')` 제거
- `createCampaignFromPrevious`에서 `'last_used_at'`, `'usage_count'` 제거

---

## 🛠️ 해결 방안

### 우선순위 1: payment_amount 완전 제거 (Critical)

**목표**: `paymentAmount` 필드를 완전히 제거하고 `productPrice`로 통합

**작업 내용:**

1. **Campaign 모델 수정** (`lib/models/campaign.dart`)
   ```dart
   // 제거할 필드
   final int paymentAmount;  // ❌ 제거
   
   // 유지할 필드
   final int? productPrice;  // ✅ 유지
   
   // fromJson 수정
   productPrice: json['product_price'] ?? json['payment_amount'] ?? null,  // 하위 호환성
   // 또는
   productPrice: json['product_price'],  // product_price만 사용
   
   // toJson 수정
   'product_price': productPrice,  // payment_amount 제거
   ```

2. **UI 컨트롤러 이름 변경** (선택사항)
   ```dart
   // 옵션 1: 이름 변경 (권장)
   final _productPriceController = TextEditingController();  // _paymentAmountController 대신
   
   // 옵션 2: 이름 유지하되 주석 추가
   final _paymentAmountController = TextEditingController();  // 실제로는 product_price 저장
   ```

3. **모든 참조 업데이트**
   - `campaign_creation_screen.dart`: `_paymentAmountController` → `_productPriceController` (또는 유지)
   - `campaign_service.dart`: `paymentAmount` 참조 제거
   - 기타 파일에서 `paymentAmount` 사용 확인 및 제거

**예상 시간**: 1-2시간

---

### 우선순위 2: product_description 완전 제거 (Important)

**목표**: 사용하지 않는 `productDescription` 관련 코드 제거

**작업 내용:**

1. **Campaign 모델 수정** (`lib/models/campaign.dart`)
   ```dart
   // 제거할 필드 (또는 nullable로 유지)
   final String? productDescription;  // ❌ 제거 또는 nullable 유지
   ```

2. **UI에서 컨트롤러 제거** (`lib/screens/campaign/campaign_creation_screen.dart`)
   ```dart
   // 제거
   final _productDescriptionController = TextEditingController();  // ❌ 제거
   
   // dispose에서도 제거
   _productDescriptionController.dispose();  // ❌ 제거
   ```

**예상 시간**: 30분

---

### 우선순위 3: 상품이미지 표시 문제 해결 (Important)

**목표**: 저장된 이미지 URL이 UI에서 정상적으로 표시되도록 수정

**작업 내용:**

1. **이미지 URL 검증**
   - 저장된 URL 형식 확인
   - R2 Public URL 형식 확인 (`SupabaseConfig.r2PublicUrl`)

2. **이미지 표시 로직 개선**
   - `campaign_card.dart`: 이미지 로딩 에러 처리 개선
   - `advertiser_my_campaigns_screen.dart`: 이미지 표시 로직 확인
   - `campaign_detail_screen.dart`: 이미지 표시 로직 확인

3. **디버깅 로그 추가**
   ```dart
   debugPrint('🖼️ 이미지 URL: ${campaign.productImageUrl}');
   ```

4. **에러 처리 개선**
   - `Image.network`의 `errorBuilder` 개선
   - 로딩 상태 표시
   - CORS 에러 감지 및 처리

**예상 시간**: 1-2시간

---

### 우선순위 4: last_used_at, usage_count 제거 (Nice to Have)

**목표**: 사용하지 않는 필드 관련 코드 제거

**작업 내용:**

1. **campaign_service.dart 수정**
   ```dart
   // getUserPreviousCampaigns 메서드
   // 제거
   .order('last_used_at', ascending: false)  // ❌ 제거
   .order('usage_count', ascending: false)   // ❌ 제거
   
   // 대신
   .order('created_at', ascending: false)    // ✅ 사용
   
   // createCampaignFromPrevious 메서드
   // 제거
   'last_used_at': ...,  // ❌ 제거
   'usage_count': ...,   // ❌ 제거
   ```

2. **Campaign 모델 확인**
   - 모델에 `lastUsedAt`, `usageCount` 필드가 있는지 확인
   - 있으면 제거

**예상 시간**: 30분

---

## 📝 상세 구현 가이드

### 1. payment_amount 완전 제거

**파일:** `lib/models/campaign.dart`

```dart
class Campaign {
  // ... 기존 필드들 ...
  
  // ❌ 제거
  // final int paymentAmount;
  
  // ✅ 유지
  final int? productPrice;
  
  Campaign({
    // ... 기존 파라미터들 ...
    // this.paymentAmount = 0,  // ❌ 제거
    this.productPrice,  // ✅ 유지
  });
  
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      // ... 기존 필드들 ...
      // paymentAmount: json['payment_amount'] ?? 0,  // ❌ 제거
      productPrice: json['product_price'],  // ✅ product_price만 사용
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      // ... 기존 필드들 ...
      // 'payment_amount': paymentAmount,  // ❌ 제거
      'product_price': productPrice,  // ✅ product_price만 사용
    };
  }
  
  Campaign copyWith({
    // ... 기존 파라미터들 ...
    // int? paymentAmount,  // ❌ 제거
    int? productPrice,  // ✅ 유지
  }) {
    return Campaign(
      // ... 기존 필드들 ...
      // paymentAmount: paymentAmount ?? this.paymentAmount,  // ❌ 제거
      productPrice: productPrice ?? this.productPrice,  // ✅ 유지
    );
  }
}
```

**파일:** `lib/screens/campaign/campaign_creation_screen.dart`

```dart
// 옵션 1: 컨트롤러 이름 변경 (권장)
final _productPriceController = TextEditingController();  // _paymentAmountController 대신

// 또는 옵션 2: 이름 유지하되 주석 추가
final _paymentAmountController = TextEditingController();  // 실제로는 product_price 저장

// 사용 부분
productPrice: int.tryParse(_productPriceController.text) ?? 0,  // 또는 _paymentAmountController
```

**파일:** `lib/services/campaign_image_service.dart`

```dart
// paymentAmount 참조 제거 또는 productPrice로 변경
if (data['productPrice'] == null || data['productPrice'] <= 0) {  // paymentAmount 대신
  // ...
}
```

---

### 2. product_description 완전 제거

**파일:** `lib/screens/campaign/campaign_creation_screen.dart`

```dart
// 제거
// final _productDescriptionController = TextEditingController();  // ❌ 제거

@override
void dispose() {
  // ... 기존 dispose 코드 ...
  // _productDescriptionController.dispose();  // ❌ 제거
  super.dispose();
}
```

**파일:** `lib/models/campaign.dart`

```dart
class Campaign {
  // ... 기존 필드들 ...
  
  // ❌ 제거 (또는 nullable로 유지)
  // final String? productDescription;
  
  Campaign({
    // ... 기존 파라미터들 ...
    // this.productDescription,  // ❌ 제거
  });
  
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      // ... 기존 필드들 ...
      // productDescription: json['product_description'],  // ❌ 제거
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      // ... 기존 필드들 ...
      // 'product_description': productDescription,  // ❌ 제거
    };
  }
}
```

---

### 3. 상품이미지 표시 문제 해결

**파일:** `lib/widgets/campaign_card.dart`

```dart
// 이미지 표시 개선
if (campaign.productImageUrl.isNotEmpty) {
  Image.network(
    campaign.productImageUrl,
    width: 140,
    height: 140,
    fit: BoxFit.cover,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        width: 140,
        height: 140,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) {
      debugPrint('🖼️ 이미지 로딩 실패: ${campaign.productImageUrl}');
      debugPrint('에러: $error');
      return Container(
        width: 140,
        height: 140,
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 40,
            ),
            const SizedBox(height: 4),
            Text(
              '이미지\n로딩 실패',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    },
  );
}
```

**확인 사항:**
1. R2 Public URL 형식 확인
2. CORS 설정 확인
3. 이미지 URL이 올바르게 저장되는지 확인
4. 네트워크 에러 로그 확인

---

### 4. last_used_at, usage_count 제거

**파일:** `lib/services/campaign_service.dart`

```dart
// getUserPreviousCampaigns 메서드
Future<ApiResponse<List<Campaign>>> getUserPreviousCampaigns() async {
  // ... 기존 코드 ...
  
  final response = await _supabase
      .from('campaigns')
      .select()
      .eq('company_id', companyId)
      .order('created_at', ascending: false)  // ✅ last_used_at 대신
      .limit(10);
  
  // ... 나머지 코드 ...
}

// createCampaignFromPrevious 메서드
Future<ApiResponse<Campaign>> createCampaignFromPrevious({
  required Campaign previousCampaign,
  // ... 기존 파라미터들 ...
}) async {
  // ... 기존 코드 ...
  
  final response = await _campaignService.createCampaignV2(
    // ... 기존 파라미터들 ...
    // last_used_at, usage_count 제거됨
  );
  
  // ... 나머지 코드 ...
}
```

---

## 🎯 우선순위 및 작업 순서

### 🔴 Critical (즉시 해결 필요)
1. **payment_amount 완전 제거** (1-2시간)
   - 모델에서 `paymentAmount` 필드 제거
   - 모든 참조 업데이트
   - 하위 호환성 고려

### 🟡 Important (빠른 시일 내 해결)
2. **상품이미지 표시 문제 해결** (1-2시간)
   - 이미지 URL 검증
   - 에러 처리 개선
   - 디버깅 로그 추가

3. **product_description 완전 제거** (30분)
   - 사용하지 않는 컨트롤러 제거
   - 모델에서 필드 제거 (또는 nullable 유지)

### 🟢 Nice to Have (여유 있을 때)
4. **last_used_at, usage_count 제거** (30분)
   - 서비스에서 사용하지 않는 필드 제거

**총 예상 시간**: 3-5시간

---

## 🧪 테스트 계획

### payment_amount 제거 테스트
- [ ] 캠페인 생성 후 DB에서 `product_price` 확인
- [ ] `payment_amount` 필드가 없거나 사용되지 않는지 확인
- [ ] 캠페인 목록에서 가격 표시 확인
- [ ] 기존 캠페인 데이터와의 호환성 확인

### 상품이미지 표시 테스트
- [ ] 캠페인 생성 후 이미지 URL 저장 확인
- [ ] 캠페인 목록에서 이미지 표시 확인
- [ ] 캠페인 상세 페이지에서 이미지 표시 확인
- [ ] 이미지 로딩 실패 시 에러 처리 확인
- [ ] CORS 에러 확인

### product_description 제거 테스트
- [ ] `_productDescriptionController`가 제거되었는지 확인
- [ ] Campaign 모델에서 필드가 제거되었는지 확인
- [ ] 컴파일 에러 없이 빌드되는지 확인

### last_used_at, usage_count 제거 테스트
- [ ] `getUserPreviousCampaigns`가 정상 작동하는지 확인
- [ ] `createCampaignFromPrevious`가 정상 작동하는지 확인
- [ ] 쿼리 에러가 없는지 확인

---

## 📅 작성일

2025-11-16

