# 캠페인 Status 및 탭 분류 로직 개선 작업 보고서

## 📋 작업 개요

**작업 일자:** 2025-01-16  
**작업 목적:** 캠페인 Status를 `active`와 `inactive`만 사용하도록 단순화하고, 만료기간 필드를 추가하여 탭 분류 로직을 개선

---

## ✅ 완료된 작업

### Phase 1: 데이터베이스 스키마 변경

#### 1.1 마이그레이션 파일 생성
- **파일:** `supabase/migrations/20250116120000_update_campaign_status_and_add_expiration_date.sql`
- **작업 내용:**
  - 기존 데이터 마이그레이션: `completed`, `cancelled` → `inactive`
  - Status 제약 조건 변경: `active`, `inactive`만 허용
  - `expiration_date` 필드 추가
  - 기존 데이터의 `expiration_date` 기본값 설정 (end_date + 30일)

#### 1.2 변경 사항
```sql
-- Status 제약 조건 변경
ALTER TABLE campaigns 
DROP CONSTRAINT IF EXISTS campaigns_status_check;

ALTER TABLE campaigns 
ADD CONSTRAINT campaigns_status_check 
CHECK (status = ANY (ARRAY['active'::text, 'inactive'::text]));

-- expiration_date 필드 추가
ALTER TABLE campaigns 
ADD COLUMN IF NOT EXISTS expiration_date timestamp with time zone;
```

---

### Phase 2: Flutter 모델 업데이트

#### 2.1 CampaignStatus Enum 수정
- **파일:** `lib/models/campaign.dart`
- **변경 전:** `enum CampaignStatus { active, completed, upcoming }`
- **변경 후:** `enum CampaignStatus { active, inactive }`

#### 2.2 Campaign 모델에 expirationDate 필드 추가
- 필드 추가: `final DateTime? expirationDate;`
- `fromJson` 메서드 업데이트: `expiration_date` 파싱 추가
- `toJson` 메서드 업데이트: `expiration_date` 직렬화 추가
- `copyWith` 메서드 업데이트: `expirationDate` 파라미터 추가

---

### Phase 3: 탭 분류 로직 개선

#### 3.1 새로운 탭 분류 규칙 구현
- **파일:** `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`

**변경된 탭 분류:**

1. **모집 (대기중)**
   - 조건: `start_date`가 현재 시간보다 미래인 경우
   - 설명: 시작기간이 되지 않았을 때

2. **모집중**
   - 조건:
     - `status = 'active'`
     - `start_date <= 현재 시간 < end_date`
     - `current_participants < max_participants`
   - 설명: 시작기간과 종료기간 사이면서 참여자가 다 차지 않은 경우

3. **선정완료**
   - 조건:
     - `status = 'active'`
     - `start_date <= 현재 시간 < end_date`
     - `current_participants >= max_participants`
   - 설명: 시작기간과 종료기간 사이면서 참여자가 다 찬 경우

4. **등록기간**
   - 조건:
     - `status = 'active'`
     - `end_date <= 현재 시간 < expiration_date`
   - 설명: 종료기간과 만료기간 사이에 있는 경우

5. **종료**
   - 조건:
     - `status = 'inactive'` 또는
     - `expiration_date`가 현재 시간보다 과거인 경우
   - 설명: 만료기간이 지나거나 status가 inactive

#### 3.2 관련 화면 업데이트
- `advertiser_my_campaigns_screen.dart`: 탭 분류 로직 재작성
- `advertiser_mypage_screen.dart`: 통계 카운트 로직 업데이트
- `_buildCampaignCard`: Status 표시 로직 개선 (날짜 기반 상태 계산)

---

### Phase 4: RPC 함수 업데이트

#### 4.1 create_campaign_with_points_v2 함수 업데이트
- **파일:** `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql`
- **변경 사항:**
  - `p_expiration_date` 파라미터 추가 (기본값: NULL)
  - INSERT 문에 `expiration_date` 필드 추가
  - 기본값 로직: `COALESCE(p_expiration_date, p_end_date + INTERVAL '30 days')`

#### 4.2 Flutter 서비스 업데이트
- **파일:** `lib/services/campaign_service.dart`
- **변경 사항:**
  - `createCampaignV2` 함수에 `expirationDate` 파라미터 추가
  - RPC 호출에 `p_expiration_date` 파라미터 전달

---

## 📊 변경된 파일 목록

### 데이터베이스
1. `supabase/migrations/20250116120000_update_campaign_status_and_add_expiration_date.sql` (신규)
2. `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql` (수정)

### Flutter 모델
3. `lib/models/campaign.dart` (수정)

### Flutter 화면
4. `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart` (수정)
5. `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart` (수정)

### Flutter 서비스
6. `lib/services/campaign_service.dart` (수정)

---

## 🔍 주요 개선 사항

### 1. Status 단순화
- **이전:** `active`, `inactive`, `completed`, `cancelled`, `upcoming` (5개)
- **이후:** `active`, `inactive` (2개)
- **효과:** Status 관리 단순화, 탭 분류는 주로 날짜 기반으로 처리

### 2. 만료기간 필드 추가
- **필드:** `expiration_date` (timestamp with time zone)
- **용도:** 종료일 이후 리뷰 등록 기간 관리
- **기본값:** `end_date + 30일` (RPC 함수에서 자동 설정)

### 3. 탭 분류 로직 개선
- **이전:** Status와 날짜를 혼용한 복잡한 로직
- **이후:** 명확한 날짜 기반 분류 규칙
- **효과:** 코드 가독성 향상, 유지보수 용이

---

## ⚠️ 주의사항

### 1. 데이터 마이그레이션
- 기존 `completed`, `cancelled` 상태의 캠페인은 `inactive`로 변경됨
- `expiration_date`가 NULL인 경우 자동으로 `end_date + 30일`로 설정됨

### 2. 호환성
- 기존 코드에서 `CampaignStatus.completed`, `CampaignStatus.upcoming`을 사용하는 경우 컴파일 오류 발생
- 모든 사용처를 수정 완료

### 3. 테스트 필요 사항
- 캠페인 생성 시 `expiration_date` 설정 확인
- 탭 분류 로직 정확성 검증
- 날짜 경계값 테스트 (start_date, end_date, expiration_date)

---

## 🚀 다음 단계

### 즉시 필요
1. **마이그레이션 실행**
   ```bash
   npx supabase migration up
   ```

2. **로컬 테스트**
   - 캠페인 생성 테스트
   - 탭 분류 정확성 확인
   - 날짜 경계값 테스트

### 향후 개선 사항
1. **캠페인 생성 화면 업데이트**
   - `expiration_date` 입력 필드 추가
   - 기본값 설정 UI (end_date + 30일)

2. **자동 Status 업데이트**
   - `expiration_date`가 지나면 자동으로 `inactive`로 변경하는 트리거 추가 검토

3. **문서 업데이트**
   - API 문서 업데이트
   - 사용자 가이드 업데이트

---

## 📝 코드 변경 요약

### 데이터베이스
- ✅ Status 제약 조건 변경
- ✅ `expiration_date` 필드 추가
- ✅ 기존 데이터 마이그레이션
- ✅ RPC 함수 업데이트

### Flutter
- ✅ CampaignStatus Enum 수정
- ✅ Campaign 모델에 `expirationDate` 추가
- ✅ 탭 분류 로직 재작성
- ✅ Status 표시 로직 개선
- ✅ 서비스 함수 업데이트

---

## ✅ 검증 완료

- [x] 데이터베이스 마이그레이션 파일 생성
- [x] Flutter 모델 업데이트
- [x] 탭 분류 로직 개선
- [x] RPC 함수 업데이트
- [x] 서비스 함수 업데이트
- [x] 관련 화면 업데이트
- [x] 컴파일 오류 확인 (린터 경고 1개 - 사용하지 않는 메서드)

---

## 📌 참고 자료

- 원본 분석 문서: `docs/campaign-status-and-display-issue-analysis.md`
- 로드맵: `docs/campaign-status-and-display-issue-analysis.md` (로드맵 섹션)

---

**작업 완료 일시:** 2025-01-16  
**작업자:** AI Assistant  
**상태:** ✅ 완료

