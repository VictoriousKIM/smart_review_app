# action 필드 JSONB 변경 마이그레이션

> 작성일: 2025-01-13  
> 목적: `campaign_action_logs.action`과 `campaign_actions.current_action` 필드를 `text`에서 `jsonb`로 변경

---

## 변경 사항 요약

### DB 스키마 변경
- ✅ `campaign_action_logs.action`: `text` → `jsonb`
- ✅ `campaign_actions.current_action`: `text` → `jsonb`
- ✅ CHECK 제약 조건 제거
- ✅ 트리거 함수 수정 (jsonb 필드 처리)

### Flutter 코드 변경
- ✅ `CampaignLog.action`: `String` → `Map<String, dynamic>`
- ✅ `CampaignLogService`: JSONB 형식으로 저장/조회
- ✅ 편의 getter 추가: `actionType`, `actionData`
- ✅ 리뷰/방문/기사 상세 정보를 `action.data`에 저장

---

## 마이그레이션 파일

**파일:** `supabase/migrations/20251113183321_change_action_to_jsonb.sql`

### 주요 작업
1. 트리거 함수 임시 비활성화
2. CHECK 제약 조건 제거
3. 기존 데이터 마이그레이션 (text → jsonb)
4. 트리거 함수 재작성 (jsonb 처리)
5. 코멘트 업데이트

### 데이터 마이그레이션
기존 `text` 값을 다음 형식으로 변환:
```json
{"type": "기존값"}
```

예:
- `'join'` → `{"type": "join"}`
- `'진행상황_저장'` → `{"type": "진행상황_저장"}`

---

## JSONB 구조

### 기본 구조
```json
{
  "type": "join" | "leave" | "complete" | "cancel" | "시작" | "진행상황_저장" | "완료",
  "data": {
    // 선택적 추가 데이터
  }
}
```

### 예시

**1. 캠페인 참여**
```json
{
  "type": "join"
}
```

**2. 리뷰 제출**
```json
{
  "type": "진행상황_저장",
  "data": {
    "title": "리뷰 제목",
    "content": "리뷰 내용",
    "rating": 5,
    "reviewUrl": "https://..."
  }
}
```

**3. 방문 완료**
```json
{
  "type": "진행상황_저장",
  "data": {
    "location": "서울시 강남구",
    "duration": 30,
    "notes": "메모",
    "photos": ["url1", "url2"]
  }
}
```

**4. 기사 제출**
```json
{
  "type": "진행상황_저장",
  "data": {
    "title": "기사 제목",
    "content": "기사 내용",
    "articleUrl": "https://..."
  }
}
```

---

## Flutter 모델 변경

### `CampaignLog` 모델

**변경 전:**
```dart
final String action; // text 타입
```

**변경 후:**
```dart
final Map<String, dynamic> action; // jsonb 타입

// 편의 getter
String get actionType => action['type'] as String? ?? '';
Map<String, dynamic>? get actionData => action['data'] as Map<String, dynamic>?;
```

### 편의 메서드 업데이트

**변경 전:**
```dart
@Deprecated('DB에 data 필드가 없습니다.')
String get title => '';
```

**변경 후:**
```dart
String get title => actionData?['title'] as String? ?? '';
int get rating => actionData?['rating'] as int? ?? 0;
String get reviewContent => actionData?['content'] as String? ?? '';
String get reviewUrl => actionData?['reviewUrl'] as String? ?? '';
```

---

## 서비스 코드 변경

### `CampaignLogService`

**1. 캠페인 신청**
```dart
// 변경 전
'action': 'join',

// 변경 후
'action': {'type': 'join'},
```

**2. 리뷰 제출**
```dart
// 변경 전
'action': '진행상황_저장',

// 변경 후
'action': {
  'type': '진행상황_저장',
  'data': {
    'title': title,
    'content': content,
    'rating': rating,
    if (reviewUrl != null) 'reviewUrl': reviewUrl,
  },
},
```

**3. 방문 완료**
```dart
'action': {
  'type': '진행상황_저장',
  'data': {
    'location': location,
    'duration': duration,
    if (notes != null) 'notes': notes,
    if (photos != null) 'photos': photos,
  },
},
```

**4. 기사 제출**
```dart
'action': {
  'type': '진행상황_저장',
  'data': {
    'title': title,
    'content': content,
    if (articleUrl != null) 'articleUrl': articleUrl,
  },
},
```

---

## 트리거 함수 변경

### `sync_campaign_actions_on_event`

**변경 전:**
```sql
IF (NEW."action" IN ('완료', 'complete') AND NEW."status" = 'completed') THEN
```

**변경 후:**
```sql
IF (
  (NEW."action"->>'type' IN ('완료', 'complete')) 
  AND NEW."status" = 'completed'
) THEN
```

**변경 사항:**
- `NEW."action"` → `NEW."action"->>'type'` (jsonb에서 type 추출)
- `ce."action"` → `ce."action"->>'type'` (서브쿼리에서도 동일)

---

## 하위 호환성

### `CampaignLog.fromJson()`

문자열 형식의 action도 처리 가능 (하위 호환성):
```dart
if (json['action'] is Map) {
  actionData = Map<String, dynamic>.from(json['action'] as Map);
} else if (json['action'] is String) {
  // 하위 호환성: 문자열인 경우 {"type": "문자열"} 형식으로 변환
  actionData = {'type': json['action'] as String};
}
```

---

## 마이그레이션 실행 방법

### 1. Supabase CLI 사용
```bash
supabase migration up
```

### 2. Supabase Dashboard 사용
1. Supabase Dashboard → SQL Editor
2. 마이그레이션 파일 내용 복사
3. 실행

### 3. 주의사항
- ⚠️ 기존 데이터가 있는 경우 마이그레이션 실행
- ⚠️ 트리거 함수가 일시적으로 비활성화됨
- ⚠️ 마이그레이션 중에는 새 이벤트 생성 불가

---

## 테스트 체크리스트

### DB 테스트
- [ ] `campaign_action_logs.action` 필드가 jsonb 타입인지 확인
- [ ] `campaign_actions.current_action` 필드가 jsonb 타입인지 확인
- [ ] 기존 데이터가 올바르게 변환되었는지 확인
- [ ] 트리거 함수가 정상 작동하는지 확인

### Flutter 테스트
- [ ] 캠페인 신청 시 action 필드가 올바르게 저장되는지 확인
- [ ] 리뷰 제출 시 action.data에 리뷰 정보가 저장되는지 확인
- [ ] 방문 완료 시 action.data에 방문 정보가 저장되는지 확인
- [ ] 기사 제출 시 action.data에 기사 정보가 저장되는지 확인
- [ ] `log.title`, `log.rating` 등 getter가 올바르게 작동하는지 확인

---

## 롤백 방법

롤백이 필요한 경우:

1. **마이그레이션 롤백**
```sql
-- action 필드를 다시 text로 변경
ALTER TABLE "public"."campaign_action_logs" 
  ALTER COLUMN "action" TYPE text USING ("action"->>'type');

ALTER TABLE "public"."campaign_actions" 
  ALTER COLUMN "current_action" TYPE text USING ("current_action"->>'type');
```

2. **Flutter 코드 롤백**
- `CampaignLog.action`을 `String`으로 변경
- `CampaignLogService`에서 문자열 형식으로 저장

---

## 장점

1. **유연성**: action 필드에 추가 데이터 저장 가능
2. **확장성**: 새로운 action 타입 추가 시 data 구조 변경 가능
3. **데이터 보존**: 리뷰/방문/기사 상세 정보를 action.data에 저장 가능
4. **성능**: JSONB 인덱싱 및 쿼리 최적화 가능

---

## 참고 자료

- [PostgreSQL JSONB 문서](https://www.postgresql.org/docs/current/datatype-json.html)
- [Supabase JSONB 가이드](https://supabase.com/docs/guides/database/extensions/postgis#jsonb)
- 마이그레이션 파일: `supabase/migrations/20251113183321_change_action_to_jsonb.sql`

---

**작업 완료일:** 2025-01-13  
**작업자:** AI Assistant

