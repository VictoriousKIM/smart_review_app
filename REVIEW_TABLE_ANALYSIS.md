# reviews 테이블 삭제 가능성 분석

## 📊 **현재 reviews 테이블 사용 현황**

### 실제 코드 분석 결과

#### 1. **reviews 테이블 정의**
```sql
CREATE TABLE reviews (
  id uuid PRIMARY KEY,
  campaign_id uuid REFERENCES campaigns(id),
  user_id uuid REFERENCES users(id),
  title, content text,
  rating integer (1-5),
  platform, review_url text,
  status text (draft, published, rejected),
  created_at, updated_at timestamp
)
```

#### 2. **실제로 reviews 테이블을 사용하는 코드**

**❌ 사용하지 않음:**
- `reviews` 테이블에 직접 INSERT하는 코드: **없음**
- `reviews` 테이블에서 SELECT하는 코드: **없음**
- `reviews` 테이블을 참조하는 foreign key: **없음**

#### 3. **리뷰 데이터는 campaign_logs 테이블에 저장됨**

**✅ 실제 구현:**
```dart
// lib/services/campaign_log_service.dart
class CampaignLog {
  final Map<String, dynamic> data;  // JSONB 컬럼
  
  // 편의 메서드
  String get title => data['title'] ?? '';  // 리뷰 제목
  int get rating => data['rating'] ?? 0;    // 리뷰 평점
  String get reviewContent => data['review_content'] ?? '';  // 리뷰 내용
  String get reviewUrl => data['review_url'] ?? '';  // 리뷰 URL
}
```

**리뷰 데이터는 campaign_logs.data JSONB 컬럼에 저장:**
```dart
// submitReview 함수 (campaign_log_service.dart line 297-342)
final currentData = Map<String, dynamic>.from(currentLog['data'] ?? {});
currentData.addAll({
  'title': title,                    // 리뷰 제목
  'review_content': content,         // 리뷰 내용
  'rating': rating,                  // 평점
  'review_url': reviewUrl,           // 리뷰 URL
  'review_submitted_at': DateTime.now().toIso8601String(),
});

await _supabase
  .from('campaign_logs')
  .update({
    'data': currentData,  // JSONB 컬럼에 저장
    'status': 'review_submitted',
  })
  .eq('id', campaignLogId);
```

#### 4. **review_service.dart는 campaign_logs를 조회**

**✅ 실제 구현:**
```dart
// lib/services/review_service.dart
Future<ApiResponse<List<Map<String, dynamic>>>> getUserReviews() {
  // CampaignLogService를 사용하여 로그 조회
  final result = await _campaignLogService.getUserCampaignLogs(
    userId: user.id,
    status: status,
  );

  // 리뷰가 있는 로그만 필터링
  final reviews = result.data!
      .where((log) => log.title.isNotEmpty || log.reviewContent.isNotEmpty)
      .map((log) => {
        'title': log.title,              // CampaignLog.data['title']
        'content': log.reviewContent,     // CampaignLog.data['review_content']
        'rating': log.rating,             // CampaignLog.data['rating']
        'review_url': log.reviewUrl,       // CampaignLog.data['review_url']
        // ...
      })
      .toList();
}
```

**중요:** `review_service.dart`는 `reviews` 테이블을 사용하지 않음!

---

## ⚠️ **삭제 시 발생할 문제**

### 문제점 1: 중복된 테이블 구조 ❌
```sql
-- reviews 테이블 (사용 안 함)
CREATE TABLE reviews (
  id, campaign_id, user_id, title, content, rating, ...
)

-- 실제 사용: campaign_logs 테이블
CREATE TABLE campaign_logs (
  id, campaign_id, user_id, data (JSONB), status, ...
  -- data 컬럼에 리뷰 내용 저장
)
```

**결과:** 두 테이블이 같은 목적을 위해 존재하지만 하나는 사용 안 함

### 문제점 2: 데이터 구조가 비정규화됨
```dart
// 현재 구조
campaign_logs.data = {
  'title': '제품 리뷰',
  'review_content': '좋은 제품입니다',
  'rating': 5,
  'review_url': 'https://...',
  'review_submitted_at': '2025-10-29',
  'purchase_date': '2025-10-20',
  'purchase_amount': 100000,
  // ... 다양한 데이터가 섞여있음
}
```

**문제:**
- JSONB 컬럼에 모든 데이터가 혼재
- 검색, 인덱싱 어려움
- 타입 안전성 없음

### 문제점 3: 코드 복잡성 증가
```dart
// CampaignLog 모델의 편의 메서드가 많음
String get title => data['title'] ?? '';
int get rating => data['rating'] ?? 0;
String get reviewContent => data['review_content'] ?? '';
// ... 20개 이상의 편의 메서드

// 타입 안전성 없음 (runtime 에러 가능성)
```

---

## ✅ **reviews 테이블을 사용하는 경우의 장점**

### 1. **정규화된 데이터 구조**
```sql
-- 명확한 관계
reviews (id, campaign_id, user_id)
  - title, content, rating, review_url
  - status (draft, published, rejected)
  - created_at, updated_at

campaign_logs (id, campaign_id, user_id)
  - action (join, complete, cancel)
  - status (pending, approved, completed)
  - 참여 기록만 관리
```

### 2. **타입 안전성**
```dart
// 명확한 타입
class Review {
  final String id;
  final String campaignId;
  final String userId;
  final String title;
  final String content;
  final int rating;  // 타입 검증 가능
  final ReviewStatus status;
  
  Review({
    required this.rating,  // 필수 값
    // ...
  });
}
```

### 3. **쉬운 쿼리**
```sql
-- 리뷰 통계 조회
SELECT 
  AVG(rating) as avg_rating,
  COUNT(*) as review_count
FROM reviews
WHERE campaign_id = 'xxx' AND status = 'published';

-- 사용자 리뷰 조회
SELECT * FROM reviews
WHERE user_id = 'xxx'
ORDER BY created_at DESC;

-- 현재는 campaign_logs.data에서 필터링 필요 (느림)
SELECT * FROM campaign_logs
WHERE data->>'title' IS NOT NULL;  -- 인덱스 사용 불가
```

### 4. **별도 인덱스 가능**
```sql
-- 리뷰별 인덱스
CREATE INDEX idx_reviews_campaign_id ON reviews(campaign_id);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_status ON reviews(status);
CREATE INDEX idx_reviews_rating ON reviews(rating);

-- 현재는 campaign_logs.data JSONB에 인덱스 불가
```

---

## 🎯 **결론 및 권장사항**

### ✅ **reviews 테이블 삭제 시 해결되는 문제**

1. **중복 제거**
   - 현재 reviews 테이블은 생성되었지만 **실제로 사용되지 않음**
   - campaign_logs.data에 모든 리뷰 정보가 저장됨

2. **명확한 데이터 흐름**
   ```
   현재 (혼란):
   - reviews 테이블: 존재하나 미사용
   - campaign_logs.data: 실제 리뷰 데이터 저장
   
   삭제 후 (명확):
   - campaign_logs.data: 리뷰 데이터만 저장
   - 단일 소스 오브 트루스
   ```

3. **코드 단순화**
   - `review_service.dart`는 사실상 `campaign_log_service.dart` wrapper
   - 중간 레이어 제거 가능

---

### ⚠️ **reviews 테이블 삭제 시 발생할 문제**

1. **검색 성능 저하**
   ```sql
   -- 현재: JSONB 쿼리 (인덱스 불가능)
   SELECT * FROM campaign_logs
   WHERE data->>'rating' > '3';  -- 느림
   
   -- reviews 테이블 사용 시: 인덱스 가능
   SELECT * FROM reviews
   WHERE rating > 3;  -- 빠름
   ```

2. **타입 안전성 부족**
   - JSONB는 런타임 에러 가능성
   - 데이터 무결성 보장 어려움

3. **확장성 문제**
   - 리뷰 관련 필드 추가 시 JSONB 복잡도 증가
   - 다른 시스템과 연동 시 데이터 추출 어려움

---

## 💡 **최종 권장사항**

### Option 1: reviews 테이블 삭제 (현재 기준 권장)

**장점:**
- ✅ 중복 제거
- ✅ 코드 단순화
- ✅ 리뷰 = 캠페인 로그의 일부라는 개념 명확화

**단점:**
- ❌ 검색 성능 저하 가능 (데이터 양이 적으면 문제없음)
- ❌ JSONB 필드 접근 시 타입 안전성 부족

**적합한 경우:**
- 리뷰 검색 요구사항이 단순한 경우
- 현재처럼 모든 기능이 campaign_logs로 동작하는 경우
- 빠른 개발이 우선인 경우

---

### Option 2: reviews 테이블 활용 (리팩토링 권장)

**장점:**
- ✅ 정규화된 데이터 구조
- ✅ 검색 성능 우수
- ✅ 타입 안전성
- ✅ 확장성

**단점:**
- ❌ 리팩토링 필요
- ❌ 데이터 마이그레이션 필요
- ❌ 개발 시간 증가

**구현 방법:**
```sql
-- 1. campaign_logs.data에서 리뷰 데이터 추출
-- 2. reviews 테이블에 저장
INSERT INTO reviews (campaign_id, user_id, title, content, rating, review_url, status)
SELECT 
  campaign_id, user_id, 
  data->>'title', 
  data->>'review_content', 
  (data->>'rating')::int,
  data->>'review_url',
  'published'
FROM campaign_logs
WHERE data->>'title' IS NOT NULL;
```

---

## 📊 **현재 vs 리팩토링 후 비교**

| 항목 | 현재 구조 | 리팩토링 후 |
|------|-----------|------------|
| 리뷰 데이터 저장 | `campaign_logs.data` (JSONB) | `reviews` 테이블 |
| 리뷰 조회 | JSONB 필터링 | 테이블 쿼리 |
| 검색 성능 | 느림 (인덱스 불가) | 빠름 (인덱스 가능) |
| 타입 안전성 | 낮음 | 높음 |
| 코드 복잡도 | 높음 (wrapper 많음) | 낮음 |
| 개발 시간 | 짧음 | 길음 |

---

## 🎯 **권장 방안**

### **즉시: reviews 테이블 삭제** ✅

**이유:**
1. 현재 reviews 테이블은 **사용되지 않음**
2. 모든 기능이 campaign_logs.data로 동작 중
3. 삭제해도 현재 기능에 영향 없음
4. 코드 단순화 및 혼란 제거

**삭제 코드:**
```sql
-- reviews 테이블 관련 삭제
DROP TABLE IF EXISTS reviews CASCADE;

-- RLS 정책 삭제
DROP POLICY IF EXISTS "Reviews are insertable by participants" ON reviews;
DROP POLICY IF EXISTS "Reviews are updatable by author" ON reviews;
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON reviews;

-- Foreign key constraint는 이미 CASCADE 처리됨
```

### **나중에: 필요 시 reviews 테이블로 리팩토링**

**조건:**
- 리뷰 수가 많아져서 검색 성능 문제 발생
- 리뷰 관련 복잡한 기능 추가 필요
- 외부 시스템과 연동 필요

**리팩토링 방법:**
1. `campaign_logs.data`에서 리뷰 데이터 추출
2. `reviews` 테이블에 저장
3. `review_service.dart` 수정하여 reviews 테이블 사용

---

## 📝 **실행 계획**

### Phase 1: 검증
1. ✅ reviews 테이블이 실제로 사용되지 않음을 확인
2. ✅ campaign_logs.data에 리뷰 데이터가 저장됨을 확인
3. ✅ 코드에 직접 INSERT/UPDATE/SELECT 없음 확인

### Phase 2: 삭제 (안전)
```sql
-- 마이그레이션 생성
CREATE TABLE TEMP BACKUP reviews 데이터 (예방적 백업)

DROP TABLE reviews CASCADE;
```

### Phase 3: 코드 정리
- `review.dart` 모델 제거 가능 (사용 안 함)
- `review_service.dart`는 유지 (campaign_logs wrapper)
- 혹은 review_service.dart도 제거하고 campaign_log_service 직접 사용

---

## ✅ **최종 결론**

**reviews 테이블 삭제는 안전함 ✅**

**이유:**
1. 현재 reviews 테이블은 **미사용**
2. 모든 리뷰 데이터는 `campaign_logs.data`에 저장됨
3. 코드에서 직접 참조 없음
4. 삭제해도 기능에 영향 없음

**권장사항:**
- ✅ reviews 테이블 삭제
- ✅ 코드 단순화
- ⚠️ 나중에 성능 문제 발생 시 reviews 테이블로 리팩토링

