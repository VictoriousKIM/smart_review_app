# 캠페인 생성 화면 성능 최적화 로드맵

**작성일**: 2025년 1월 24일  
**대상 파일**: `lib/screens/campaign/campaign_creation_screen.dart`  
**현재 상태**: 2,751줄의 단일 파일, 모든 로직이 한 화면에 집중

---

## 📊 현재 상태 분석

### ✅ 이미 적용된 최적화
1. **디바운싱**: 비용 계산에 500ms 디바운싱 적용
2. **Isolate 사용**: 이미지 리사이징/크롭 작업을 isolate에서 처리
3. **캐싱**: 이미지 캐싱 및 포맷팅 결과 캐싱
4. **단계별 초기화**: `_initializeInStages()`로 초기화 분리
5. **중복 호출 방지**: 캠페인 생성 중복 방지 로직

### ❌ 주요 문제점
1. **불필요한 리빌드**: `setState()` 호출 시 모든 섹션이 다시 그려짐
2. **과도한 RepaintBoundary**: 정적 UI에 불필요하게 사용
3. **메소드 기반 UI**: `_buildXXX()` 메소드들이 위젯 트리 최적화를 방해
4. **이미지 메모리**: 고해상도 이미지 렌더링 시 메모리 과다 사용
5. **상태 관리**: 모든 상태가 단일 State 클래스에 집중

---

## 🎯 최적화 목표

1. **리빌드 최소화**: 변경된 섹션만 리빌드되도록 개선
2. **초기 로딩 시간**: 화면 진입 시 렉 제거 (목표: < 100ms)
3. **입력 반응성**: 텍스트 입력 시 버벅임 제거 (목표: 60 FPS 유지)
4. **메모리 사용량**: 이미지 처리 시 메모리 사용량 50% 감소
5. **코드 유지보수성**: 위젯 분리로 가독성 향상

---

## 🗺️ 단계별 로드맵

### Phase 1: 위젯 분리 (최우선) ⭐⭐⭐
**예상 효과**: 리빌드 70% 감소, 입력 반응성 대폭 개선  
**예상 작업 시간**: 4-6시간

#### 1.1 섹션별 StatelessWidget 분리
- [ ] `CampaignTypeSection` - 캠페인 타입 및 플랫폼 선택
- [ ] `ImageSection` - 이미지 선택 및 자동 추출
- [ ] `ProductImageSection` - 상품 이미지 크롭
- [ ] `ProductInfoSection` - 상품 정보 입력 (가장 중요!)
- [ ] `ReviewSettingsSection` - 리뷰 설정
- [ ] `ScheduleSection` - 일정 설정
- [ ] `DuplicatePreventSection` - 중복 방지 설정
- [ ] `CostSection` - 비용 설정 (StatefulWidget 필요)
- [ ] `UploadProgressSection` - 업로드 진행률

#### 1.2 const 생성자 활용
- 모든 StatelessWidget에 `const` 생성자 적용
- 변경되지 않는 위젯은 `const`로 선언하여 리빌드 방지

#### 1.3 콜백 패턴 적용
- 부모에서 자식으로 데이터 전달
- 자식에서 부모로 변경사항 전달 (콜백 함수)

**예시 코드**:
```dart
// 기존
Widget _buildProductInfoSection() {
  return Card(...);
}

// 변경 후
class ProductInfoSection extends StatelessWidget {
  final TextEditingController keywordController;
  final TextEditingController productNameController;
  // ... 기타 컨트롤러들
  
  const ProductInfoSection({
    super.key,
    required this.keywordController,
    required this.productNameController,
    // ...
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(...);
  }
}
```

---

### Phase 2: RepaintBoundary 최적화 ⭐⭐
**예상 효과**: 스크롤 성능 30% 개선  
**예상 작업 시간**: 1시간

#### 2.1 불필요한 RepaintBoundary 제거
- [ ] 정적 텍스트/입력 필드 섹션: RepaintBoundary 제거
- [ ] 이미지 업로드 프로그레스 바: 유지 (자주 변경됨)
- [ ] 이미지 크롭 에디터: 유지 (드래그 시 픽셀 변경 많음)

#### 2.2 전략적 RepaintBoundary 배치
- 동적으로 변경되는 위젯만 감싸기
- 비용 계산 결과 표시 영역만 RepaintBoundary 적용

---

### Phase 3: 이미지 메모리 최적화 ⭐⭐
**예상 효과**: 메모리 사용량 50% 감소  
**예상 작업 시간**: 2시간

#### 3.1 Image.memory에 cacheWidth/cacheHeight 추가
```dart
// 기존
Image.memory(_capturedImage!, fit: BoxFit.contain)

// 변경 후
Image.memory(
  _capturedImage!,
  fit: BoxFit.contain,
  cacheWidth: 1080, // 렌더링 해상도 제한
  cacheHeight: 1080,
)
```

#### 3.2 썸네일 생성 및 표시
- 큰 이미지는 썸네일로 표시
- 원본 이미지는 필요 시에만 로드

#### 3.3 이미지 디코딩 최적화
- 이미지 표시 시점에 디코딩 (지연 로딩)
- 메모리에서 제거 가능한 이미지는 즉시 해제

---

### Phase 4: 화면 진입 최적화 ⭐
**예상 효과**: 초기 로딩 시간 50% 감소  
**예상 작업 시간**: 1-2시간

#### 4.1 네비게이션 애니메이션 대기
```dart
@override
void initState() {
  super.initState();
  // 컨트롤러 초기화 등 가벼운 작업만
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 네비게이션 애니메이션 완료 대기 (300ms)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _initializeInStages();
    });
  });
}
```

#### 4.2 지연 로딩 적용
- 잔액 조회: 즉시 필요하지 않으면 지연
- 초기 비용 계산: 사용자가 입력하기 전까지 지연

---

### Phase 5: Riverpod 상태 관리 도입 (선택사항) ⭐
**예상 효과**: 상태 관리 일관성, 테스트 용이성 향상  
**예상 작업 시간**: 6-8시간

#### 5.1 CampaignCreationNotifier 생성
- 폼 상태를 Riverpod Notifier로 관리
- 각 섹션별로 Provider 분리 가능

#### 5.2 장점
- 상태 변경 시 필요한 위젯만 리빌드
- 테스트 용이성 향상
- 코드 재사용성 향상

#### 5.3 단점
- 기존 코드 대폭 수정 필요
- 학습 곡선 존재

**결론**: Phase 1-4 완료 후 성능이 충분하지 않을 때만 고려

---

## 📋 우선순위별 작업 체크리스트

### 🔴 최우선 (즉시 적용)
- [ ] Phase 1: 위젯 분리 (특히 ProductInfoSection)
- [ ] Phase 3.1: Image.memory cacheWidth 추가

### 🟡 중요 (1주일 내)
- [ ] Phase 2: RepaintBoundary 최적화
- [ ] Phase 3.2: 썸네일 생성
- [ ] Phase 4: 화면 진입 최적화

### 🟢 선택사항 (필요 시)
- [ ] Phase 5: Riverpod 상태 관리 도입
- [ ] Phase 3.3: 이미지 디코딩 최적화

---

## 📈 예상 성능 개선 효과

| 항목 | 현재 | Phase 1-2 | Phase 1-4 | Phase 1-5 |
|------|------|-----------|-----------|-----------|
| 초기 로딩 시간 | ~500ms | ~400ms | ~250ms | ~200ms |
| 텍스트 입력 FPS | 30-45 | 55-60 | 60 | 60 |
| 메모리 사용량 | 100% | 100% | 50% | 50% |
| 리빌드 횟수 | 100% | 30% | 25% | 20% |
| 코드 가독성 | 낮음 | 중간 | 중간 | 높음 |

---

## 🛠️ 구현 가이드

### 위젯 분리 예시: ProductInfoSection

**파일 위치**: `lib/widgets/campaign/product_info_section.dart`

```dart
import 'package:flutter/material.dart';
import '../../widgets/custom_text_field.dart';

class ProductInfoSection extends StatelessWidget {
  final TextEditingController keywordController;
  final TextEditingController productNameController;
  final TextEditingController optionController;
  final TextEditingController quantityController;
  final TextEditingController sellerController;
  final TextEditingController productNumberController;
  final TextEditingController paymentAmountController;
  final TextEditingController productProvisionOtherController;
  final String purchaseMethod;
  final String productProvisionType;
  final ValueChanged<String?> onPurchaseMethodChanged;
  final ValueChanged<String?> onProductProvisionTypeChanged;
  final ValueChanged<String> onProductProvisionOtherChanged;

  const ProductInfoSection({
    super.key,
    required this.keywordController,
    required this.productNameController,
    required this.optionController,
    required this.quantityController,
    required this.sellerController,
    required this.productNumberController,
    required this.paymentAmountController,
    required this.productProvisionOtherController,
    required this.purchaseMethod,
    required this.productProvisionType,
    required this.onPurchaseMethodChanged,
    required this.onProductProvisionTypeChanged,
    required this.onProductProvisionOtherChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              controller: keywordController,
              labelText: '키워드',
            ),
            // ... 나머지 필드들
          ],
        ),
      ),
    );
  }
}
```

**사용 예시**:
```dart
// CampaignCreationScreen의 build 메소드
ProductInfoSection(
  keywordController: _keywordController,
  productNameController: _productNameController,
  // ... 기타 컨트롤러들
  purchaseMethod: _purchaseMethod,
  productProvisionType: _productProvisionType,
  onPurchaseMethodChanged: (value) {
    setState(() => _purchaseMethod = value!);
  },
  onProductProvisionTypeChanged: (value) {
    setState(() {
      _productProvisionType = value!;
      if (value != 'other') {
        _productProvisionOther = '';
      }
    });
  },
  onProductProvisionOtherChanged: (value) {
    setState(() => _productProvisionOther = value);
  },
)
```

---

## ⚠️ 주의사항

1. **점진적 적용**: 한 번에 모든 섹션을 분리하지 말고, 하나씩 테스트하며 진행
2. **기능 검증**: 각 Phase 완료 후 반드시 전체 기능 테스트
3. **성능 측정**: 각 Phase 전후로 성능 측정하여 개선 효과 확인
4. **백업**: 큰 변경 전에 반드시 커밋

---

## 📝 참고 자료

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter Widget Optimization](https://docs.flutter.dev/perf/rendering/best-practices)

---

## ✅ 검증 방법

### 성능 측정 도구
1. **Flutter DevTools Performance Tab**: FPS 및 리빌드 횟수 확인
2. **Flutter DevTools Memory Tab**: 메모리 사용량 확인
3. **수동 테스트**: 실제 사용 시나리오로 버벅임 체감

### 테스트 시나리오
1. 화면 진입 시 초기 로딩 시간 측정
2. 텍스트 필드에 빠르게 입력하며 FPS 확인
3. 이미지 선택 및 크롭 시 메모리 사용량 확인
4. 비용 계산 시 다른 섹션 리빌드 여부 확인

---

**다음 단계**: Phase 1.1부터 시작하여 위젯 분리 작업을 진행하세요.

