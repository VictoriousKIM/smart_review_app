# 캠페인 편집 시 리뷰 키워드 에러 해결 로드맵

## 📋 문제 분석

### 현재 상황
- ✅ **캠페인 생성**: 리뷰 키워드 정상 작동
- ❌ **캠페인 편집**: 리뷰 키워드 관련 에러 발생

### 문제 원인 분석

#### 1. 프론트엔드 (편집 화면)
**파일**: `lib/screens/campaign/campaign_edit_screen.dart`

**현재 로직** (837-847줄):
```dart
reviewKeywords:
    _useReviewKeywords &&
        _reviewKeywordsController.text.trim().isNotEmpty
    ? (() {
        final normalized = KeywordUtils.normalizeKeywords(
          _reviewKeywordsController.text.trim(),
        );
        return normalized.isNotEmpty ? normalized : null;
      })()
    : null, // null이면 서비스에서 null로 전달됨
```

**문제점**:
- 체크박스를 해제하거나 텍스트를 비울 때 `null`을 전달하지만, 서비스 레이어에서 파라미터를 생략하면 DEFAULT 값이 사용됨
- 명시적으로 `null`을 전달해야 키워드 제거가 확실함

#### 2. 서비스 레이어
**파일**: `lib/services/campaign_service.dart`

**현재 로직** (1019-1025줄):
```dart
// ✅ reviewKeywords는 값이 있을 때만 파라미터 추가
// null이면 파라미터를 생략하여 함수의 DEFAULT 값(NULL::text[]) 사용
if (reviewKeywordsArray != null && reviewKeywordsArray.isNotEmpty) {
  params['p_review_keywords'] = reviewKeywordsArray;
}
```

**문제점**:
- `null`을 전달하려고 할 때 파라미터를 생략하면 DEFAULT 값이 사용됨
- 키워드를 제거하려고 할 때 명시적으로 `null`을 전달해야 함
- 하지만 Supabase Dart 클라이언트가 `null`을 JSON으로 변환하려고 시도할 수 있음

#### 3. 백엔드 RPC 함수
**파일**: `supabase/migrations/20251222162212_fix_update_campaign_v2_review_keywords_json.sql`

**현재 상태**:
- `p_review_keywords`는 `text[]` 타입, DEFAULT는 `NULL::text[]` (71줄)
- UPDATE 문에서 `review_keywords = p_review_keywords`로 직접 할당 (310줄)

**문제점**:
- 파라미터가 생략되면 DEFAULT 값(NULL)이 사용되지만, 명시적으로 `null`을 전달하는 것이 더 안전함

## 🔧 해결 방안

### Phase 1: 프론트엔드 수정 (우선순위: 높음)

#### 1.1 편집 화면에서 리뷰 키워드 제거 로직 개선
**파일**: `lib/screens/campaign/campaign_edit_screen.dart`

**수정 위치**: `_updateCampaign` 메서드 (837-847줄)

**변경 사항**:
```dart
// 기존 코드
reviewKeywords:
    _useReviewKeywords &&
        _reviewKeywordsController.text.trim().isNotEmpty
    ? (() {
        final normalized = KeywordUtils.normalizeKeywords(
          _reviewKeywordsController.text.trim(),
        );
        return normalized.isNotEmpty ? normalized : null;
      })()
    : null,

// 수정된 코드
reviewKeywords: () {
  // 체크박스가 활성화되어 있고 텍스트가 있으면 정규화된 키워드 반환
  if (_useReviewKeywords && 
      _reviewKeywordsController.text.trim().isNotEmpty) {
    final normalized = KeywordUtils.normalizeKeywords(
      _reviewKeywordsController.text.trim(),
    );
    return normalized.isNotEmpty ? normalized : null;
  }
  // 체크박스가 비활성화되어 있거나 텍스트가 비어있으면 명시적으로 빈 문자열 반환
  // (서비스 레이어에서 빈 문자열을 null로 변환)
  return '';
}(),
```

**이유**:
- 빈 문자열을 전달하면 서비스 레이어에서 `null`로 변환되어 명시적으로 키워드 제거를 표현할 수 있음

### Phase 2: 서비스 레이어 수정 (우선순위: 높음)

#### 2.1 `_parseReviewKeywords` 메서드 개선
**파일**: `lib/services/campaign_service.dart`

**수정 위치**: `_parseReviewKeywords` 메서드 (35-48줄)

**변경 사항**:
```dart
// 기존 코드
List<String>? _parseReviewKeywords(String? reviewKeywords) {
  if (reviewKeywords == null || reviewKeywords.trim().isEmpty) {
    return null;
  }

  final keywordsArray = reviewKeywords
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  return keywordsArray.isEmpty ? null : keywordsArray;
}

// 수정된 코드
List<String>? _parseReviewKeywords(String? reviewKeywords) {
  // null이거나 빈 문자열이면 null 반환 (키워드 제거)
  if (reviewKeywords == null || reviewKeywords.trim().isEmpty) {
    return null;
  }

  final keywordsArray = reviewKeywords
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  // 빈 배열이면 null 반환 (키워드 제거)
  return keywordsArray.isEmpty ? null : keywordsArray;
}
```

**이유**:
- 빈 문자열도 `null`로 변환하여 명시적으로 키워드 제거를 표현

#### 2.2 `updateCampaignV2` 메서드의 파라미터 처리 로직 개선
**파일**: `lib/services/campaign_service.dart`

**수정 위치**: `updateCampaignV2` 메서드 (1019-1025줄)

**변경 사항**:
```dart
// 기존 코드
// ✅ reviewKeywords는 값이 있을 때만 파라미터 추가
// null이면 파라미터를 생략하여 함수의 DEFAULT 값(NULL::text[]) 사용
if (reviewKeywordsArray != null && reviewKeywordsArray.isNotEmpty) {
  params['p_review_keywords'] = reviewKeywordsArray;
}

// 수정된 코드
// ✅ reviewKeywords 처리:
// 1. 배열이 있고 비어있지 않으면 배열 전달
// 2. null이면 명시적으로 빈 배열 [] 전달 (키워드 제거)
// 3. 빈 배열을 전달하면 백엔드에서 NULL로 처리됨
if (reviewKeywordsArray != null && reviewKeywordsArray.isNotEmpty) {
  params['p_review_keywords'] = reviewKeywordsArray;
} else {
  // 키워드 제거를 명시적으로 표현하기 위해 빈 배열 전달
  // 백엔드에서 빈 배열을 NULL로 변환하도록 처리 필요
  params['p_review_keywords'] = <String>[];
}
```

**이유**:
- 빈 배열을 전달하면 백엔드에서 NULL로 변환하여 키워드 제거를 명시적으로 표현할 수 있음

### Phase 3: 백엔드 RPC 함수 수정 (우선순위: 중간)

#### 3.1 `update_campaign_v2` 함수에서 빈 배열 처리
**파일**: `supabase/migrations/20251222162212_fix_update_campaign_v2_review_keywords_json.sql`

**수정 위치**: UPDATE 문 (310줄)

**변경 사항**:
```sql
-- 기존 코드
review_keywords = p_review_keywords,  -- ✅ text[] 직접 사용

-- 수정된 코드
review_keywords = CASE 
  WHEN p_review_keywords IS NULL THEN NULL
  WHEN array_length(p_review_keywords, 1) IS NULL THEN NULL  -- 빈 배열 처리
  ELSE p_review_keywords
END,
```

**이유**:
- 빈 배열을 NULL로 변환하여 키워드 제거를 명시적으로 처리

## 📝 구현 단계

### Step 1: 프론트엔드 수정 (예상 시간: 30분)
1. `lib/screens/campaign/campaign_edit_screen.dart`의 `_updateCampaign` 메서드 수정
2. 리뷰 키워드 제거 시 빈 문자열 전달하도록 변경

### Step 2: 서비스 레이어 수정 (예상 시간: 30분)
1. `lib/services/campaign_service.dart`의 `updateCampaignV2` 메서드 수정
2. `reviewKeywordsArray`가 null이거나 빈 배열일 때 빈 배열 전달하도록 변경

### Step 3: 백엔드 RPC 함수 수정 (예상 시간: 20분)
1. 새 마이그레이션 파일 생성: `supabase/migrations/YYYYMMDDHHMMSS_fix_update_campaign_v2_empty_keywords.sql`
2. `update_campaign_v2` 함수에서 빈 배열을 NULL로 변환하는 로직 추가

### Step 4: 테스트 (예상 시간: 30분)
1. 캠페인 생성 시 리뷰 키워드 추가 테스트
2. 캠페인 편집 시 리뷰 키워드 수정 테스트
3. 캠페인 편집 시 리뷰 키워드 제거 테스트 (체크박스 해제)
4. 캠페인 편집 시 리뷰 키워드 제거 테스트 (텍스트 비움)

## 🧪 테스트 시나리오

### 시나리오 1: 리뷰 키워드 추가
1. 캠페인 편집 화면 진입
2. "리뷰 키워드 사용" 체크박스 활성화
3. 키워드 입력: "키워드1, 키워드2, 키워드3"
4. 저장 버튼 클릭
5. **예상 결과**: 저장 성공, 리뷰 키워드가 정상적으로 저장됨

### 시나리오 2: 리뷰 키워드 수정
1. 리뷰 키워드가 있는 캠페인 편집 화면 진입
2. 기존 키워드 수정: "키워드1, 키워드2" → "새키워드1, 새키워드2"
3. 저장 버튼 클릭
4. **예상 결과**: 저장 성공, 리뷰 키워드가 정상적으로 수정됨

### 시나리오 3: 리뷰 키워드 제거 (체크박스 해제)
1. 리뷰 키워드가 있는 캠페인 편집 화면 진입
2. "리뷰 키워드 사용" 체크박스 비활성화
3. 저장 버튼 클릭
4. **예상 결과**: 저장 성공, 리뷰 키워드가 NULL로 설정됨

### 시나리오 4: 리뷰 키워드 제거 (텍스트 비움)
1. 리뷰 키워드가 있는 캠페인 편집 화면 진입
2. 키워드 텍스트 필드의 모든 내용 삭제
3. 저장 버튼 클릭
4. **예상 결과**: 저장 성공, 리뷰 키워드가 NULL로 설정됨

## ⚠️ 주의사항

1. **데이터 일관성**: 기존 캠페인의 리뷰 키워드가 정상적으로 로드되는지 확인 필요
2. **에러 처리**: 빈 배열을 전달할 때 Supabase Dart 클라이언트가 정상적으로 처리하는지 확인 필요
3. **마이그레이션 순서**: 백엔드 수정 전에 프론트엔드와 서비스 레이어 수정을 먼저 완료해야 함

## 🔍 디버깅 팁

1. **프론트엔드 디버깅**: `_updateCampaign` 메서드에 `debugPrint` 추가하여 전달되는 `reviewKeywords` 값 확인
2. **서비스 레이어 디버깅**: `updateCampaignV2` 메서드에 이미 있는 `debugPrint` 활용하여 파라미터 확인
3. **백엔드 디버깅**: Supabase Studio에서 RPC 함수 직접 호출하여 테스트

## 📚 참고 자료

- `lib/screens/campaign/campaign_edit_screen.dart`: 편집 화면 코드
- `lib/services/campaign_service.dart`: 서비스 레이어 코드
- `supabase/migrations/20251222162212_fix_update_campaign_v2_review_keywords_json.sql`: 백엔드 RPC 함수
- `lib/utils/keyword_utils.dart`: 키워드 유틸리티 (참고용)

