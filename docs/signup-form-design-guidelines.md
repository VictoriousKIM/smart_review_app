# 회원가입 폼 디자인 가이드라인

## 📋 현재 상태 분석

### 1. 사업자등록폼 (`business_registration_form.dart`)

#### 프로필 모드 (마이페이지)
- ✅ **파일 업로드 섹션**: `Container` with `BoxDecoration` (라운딩 박스 있음)
  - `borderRadius: 16`
  - `boxShadow` 적용
  - 배경색: `Colors.white`
- ✅ **사업자 정보 표시**: `Container` with `BoxDecoration` (라운딩 박스 있음)
  - `_buildBusinessNumberCard()`: `borderRadius: 12`
  - `_buildInfoCard()`: `borderRadius: 12`
  - 각 정보 항목마다 개별 박스

#### 회원가입 모드
- ❌ **파일 업로드 섹션**: 라운딩 박스 없음 (직접 표시)
- ❌ **사업자 정보 표시**: 라운딩 박스 없음 (직접 표시)
- ⚠️ **일관성 문제**: 프로필 모드와 회원가입 모드의 UI가 다름

### 2. 리뷰어 회원가입 폼들

#### 프로필 폼 (`reviewer_signup_profile_form.dart`)
- ❌ 라운딩 박스 없음
- 직접 입력 필드만 표시

#### SNS 연결 폼 (`reviewer_signup_sns_form.dart`)
- ✅ **SNS 연결 항목**: `Card` 위젯 사용
  - 플랫폼 추가 버튼: `Card` with `ListTile`
  - 연결된 계정 목록: `Card` with `ListTile` (배경색: `Colors.grey[50]`)

#### 회사 선택 폼 (`reviewer_signup_company_form.dart`)
- ✅ **회사 선택 항목**: `Card` 위젯 사용
  - 선택된 회사: `Card` with 배경색 `Colors.blue[50]`
  - 선택되지 않은 회사: 기본 `Card`

### 3. 일관성 문제점

1. **사업자등록폼**: 프로필 모드와 회원가입 모드의 UI가 다름
2. **리뷰어 회원가입**: 대부분 라운딩 박스 없음 (일부만 Card 사용)
3. **광고주 회원가입**: 라운딩 박스 없음
4. **섹션별 일관성**: 파일 업로드, 정보 표시, 선택 항목 등에서 일관성 부족

---

## 🎨 디자인 옵션

### 옵션 1: 모든 회원가입 폼에서 라운딩 박스 제거 (현재 리뷰어 폼과 일치)

**장점:**
- ✅ 리뷰어 회원가입 폼과 일관성 유지
- ✅ 깔끔하고 미니멀한 디자인
- ✅ 수정 작업량 적음 (사업자등록폼 회원가입 모드만 유지)

**단점:**
- ❌ 프로필 모드와 회원가입 모드의 UI가 다름
- ❌ 정보 구분이 덜 명확할 수 있음

**적용 방법:**
- 사업자등록폼 프로필 모드의 라운딩 박스 제거
- 모든 회원가입 폼에서 라운딩 박스 제거

---

### 옵션 2: 모든 회원가입 폼에 라운딩 박스 추가 (프로필 모드와 일치)

**장점:**
- ✅ 프로필 모드와 회원가입 모드의 UI 일관성
- ✅ 정보 구분이 명확함
- ✅ 시각적 계층 구조가 잘 드러남

**단점:**
- ❌ 리뷰어 회원가입 폼 수정 필요
- ❌ 수정 작업량 많음

**적용 방법:**
- 사업자등록폼 회원가입 모드에 라운딩 박스 추가
- 리뷰어 회원가입 폼에 라운딩 박스 추가
- 모든 회원가입 폼에서 일관된 스타일 적용

**스타일 예시:**
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.1),
        spreadRadius: 1,
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Column(...),
)
```

---

### 옵션 3: 섹션별로 선택적 적용 (하이브리드)

**장점:**
- ✅ 각 섹션의 특성에 맞는 디자인
- ✅ 유연한 디자인 시스템

**단점:**
- ❌ 일관성 규칙이 복잡함
- ❌ 유지보수 어려움

**적용 규칙:**
- **파일 업로드 섹션**: 라운딩 박스 사용 (시각적 강조)
- **정보 표시 섹션**: 라운딩 박스 사용 (정보 구분)
- **입력 필드 섹션**: 라운딩 박스 없음 (깔끔한 입력 경험)
- **선택 항목 (SNS, 회사)**: `Card` 위젯 사용 (선택 가능한 항목)

**스타일 예시:**
```dart
// 파일 업로드 섹션
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [...],
  ),
  child: Column(...),
)

// 정보 표시 섹션
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey[300]!),
  ),
  child: Column(...),
)

// 입력 필드 섹션
Column(
  children: [
    TextFormField(...),
    TextFormField(...),
  ],
)

// 선택 항목
Card(
  child: ListTile(...),
)
```

---

## 💡 추천 옵션

### 추천: **옵션 2 (모든 회원가입 폼에 라운딩 박스 추가)**

**이유:**
1. **일관성**: 프로필 모드와 회원가입 모드의 UI가 동일하여 사용자 경험 향상
2. **명확성**: 섹션별 구분이 명확하여 정보 인지가 쉬움
3. **전문성**: 시각적 계층 구조가 잘 드러나 전문적인 느낌
4. **확장성**: 향후 새로운 회원가입 폼 추가 시 일관된 스타일 적용 가능

### 대안: **옵션 3 (섹션별 선택적 적용)**

**이유:**
- 파일 업로드, 정보 표시 등 특정 섹션에만 라운딩 박스를 적용하여 시각적 강조
- 입력 필드는 깔끔하게 유지하여 입력 경험 향상
- 선택 항목은 `Card` 위젯으로 일관성 유지

---

## 📐 디자인 시스템 규칙 (옵션 2 기준)

### 1. 라운딩 박스 스타일

#### 주요 섹션 (파일 업로드, 정보 표시)
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.1),
        spreadRadius: 1,
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Column(...),
)
```

#### 정보 카드 (사업자 정보 항목)
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.grey[50], // 또는 Colors.white
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.grey[300]!,
    ),
  ),
  child: Column(...),
)
```

#### 선택 항목 (SNS, 회사)
```dart
Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: ListTile(...),
)
```

### 2. 간격 규칙

- 섹션 간 간격: `SizedBox(height: 24)`
- 카드 간 간격: `SizedBox(height: 16)`
- 내부 패딩: `EdgeInsets.all(20)` (주요 섹션), `EdgeInsets.all(16)` (카드)

### 3. 색상 규칙

- 배경색: `Colors.white` (주요 섹션), `Colors.grey[50]` (정보 카드)
- 테두리: `Colors.grey[300]` (기본), `Colors.blue[200]` (강조)
- 그림자: `Colors.grey.withValues(alpha: 0.1)`

---

## 🔧 적용 방법

### 단계 1: 사업자등록폼 회원가입 모드 수정

1. `_buildFileUploadSection()`을 프로필 모드와 동일하게 수정
2. `_buildBusinessInfoForm()`을 프로필 모드와 동일하게 수정
3. 회원가입 모드에서도 라운딩 박스 적용

### 단계 2: 리뷰어 회원가입 폼 수정

1. `reviewer_signup_profile_form.dart`: 입력 필드 섹션에 라운딩 박스 추가
2. `reviewer_signup_sns_form.dart`: 이미 `Card` 사용 중 (유지)
3. `reviewer_signup_company_form.dart`: 이미 `Card` 사용 중 (유지)

### 단계 3: 일관성 검증

1. 모든 회원가입 폼에서 동일한 스타일 적용 확인
2. 프로필 모드와 회원가입 모드의 UI 일관성 확인
3. 사용자 테스트 진행

---

## 📝 참고사항

- 현재 프로필 모드의 디자인이 더 완성도가 높음
- 회원가입 모드도 프로필 모드와 동일한 스타일을 적용하는 것이 좋음
- 선택 항목(SNS, 회사)은 `Card` 위젯 사용이 적절함
- 입력 필드는 라운딩 박스 내부에 배치하여 일관성 유지

---

## ✅ 최종 결정 및 적용 완료

**선택된 옵션: 옵션 1 - 모든 회원가입 폼에서 라운딩 박스 제거**

### 적용 완료 내역

1. ✅ **사업자등록폼 프로필 모드**: 
   - `_buildFileUploadSection()`: 라운딩 박스 제거, 배경색 흰색 유지
   - `_buildBusinessNumberCard()`: 라운딩 박스 제거, 배경색 흰색 유지
   - `_buildInfoCard()`: 라운딩 박스 제거, 배경색 흰색 유지

2. ✅ **일관성**: 
   - 프로필 모드와 회원가입 모드 모두 라운딩 박스 없음
   - 모든 섹션에서 배경색 흰색으로 통일

### 적용된 스타일

```dart
// 라운딩 박스 제거, 배경색 흰색 유지
Container(
  padding: const EdgeInsets.all(20),
  color: Colors.white, // decoration 대신 color 사용
  child: Column(...),
)
```

**변경 전:**
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [...],
  ),
  child: Column(...),
)
```

**변경 후:**
```dart
Container(
  padding: const EdgeInsets.all(20),
  color: Colors.white,
  child: Column(...),
)
```

