# 캠페인 날짜 필드 세분화 및 구체화 로드맵

**작성일**: 2025년 11월 24일  
**목적**: 캠페인 날짜 필드의 의미를 명확히 하고, 신청 기간과 리뷰 기간을 분리하여 관리

## 📋 변경 요구사항

### 현재 상태
- **시작 일시** (`start_date`): 캠페인 신청 시작일시
- **종료 일시** (`end_date`): 캠페인 신청 종료일시  
- **만기일** (`expiration_date`): 리뷰 제출 만기일

### 변경 후 상태
- **신청 시작일시** (`apply_start_date`): 캠페인 신청 시작일시
- **신청 종료일시** (`apply_end_date`): 캠페인 신청 종료일시
- **리뷰 시작일시** (`review_start_date`): 리뷰 작성 시작일시
- **리뷰 종료일시** (`review_end_date`): 리뷰 제출 종료일시

### 날짜 순서 제약 조건
```
신청 시작일시 <= 신청 종료일시 <= 리뷰 시작일시 <= 리뷰 종료일시
```

**필드명**:
```
apply_start_date <= apply_end_date <= review_start_date <= review_end_date
```

## 🎯 작업 범위

### 1. 데이터베이스 스키마 변경
- [ ] `campaigns` 테이블에 `review_start_date` 컬럼 추가
- [ ] 기존 필드명 변경:
  - `start_date` → `apply_start_date`
  - `end_date` → `apply_end_date`
  - `expiration_date` → `review_end_date`
- [ ] 기존 데이터 마이그레이션 (필드명 변경 및 기본값 설정)
- [ ] 제약 조건 수정 (`campaigns_dates_check`)

### 2. RPC 함수 수정
- [ ] `create_campaign_with_points_v2` 함수에 `p_review_start_date` 파라미터 추가
- [ ] 날짜 검증 로직 수정 (4개 필드 간 검증)
- [ ] INSERT 문에 `review_start_date` 추가

### 3. Flutter 모델 수정
- [ ] `Campaign` 모델에 `reviewStartDate` 필드 추가
- [ ] `fromJson` 메서드 수정
- [ ] `toJson` 메서드 수정
- [ ] `copyWith` 메서드 수정

### 4. Flutter 서비스 수정
- [ ] `CampaignService.createCampaignV2` 메서드에 `reviewStartDate` 파라미터 추가
- [ ] RPC 호출 시 `p_review_start_date` 전달

### 5. UI 수정
- [ ] 캠페인 생성 화면 라벨 변경
  - "시작 일시" → "신청 시작일시"
  - "종료 일시" → "신청 종료일시"
  - "만기일" → "리뷰 종료일시"
- [ ] "리뷰 시작일시" 입력 필드 추가
- [ ] 날짜 선택 로직 수정 (4개 필드 간 자동 조정)
- [ ] 날짜 검증 로직 수정 (4개 필드 간 검증)
- [ ] 에러 메시지 업데이트

### 6. 기타 화면 확인 및 수정
- [ ] 캠페인 상세 화면 (`campaign_detail_screen.dart`)에서 날짜 필드 표시 확인
- [ ] 광고주 캠페인 상세 화면 (`advertiser_campaign_detail_screen.dart`)에서 날짜 필드 표시 확인 및 수정
- [ ] 광고주 내 캠페인 목록 화면 (`advertiser_my_campaigns_screen.dart`)에서 날짜 필드 사용 확인 및 수정
- [ ] 광고주 마이페이지 (`advertiser_mypage_screen.dart`)에서 날짜 필드 사용 확인 및 수정
- [ ] 캠페인 상태 판단 로직 확인 (신청 기간, 리뷰 기간 구분)

## 📝 상세 작업 계획

### Phase 1: 데이터베이스 스키마 변경

#### 1.1 마이그레이션 파일 생성
**파일**: `supabase/migrations/YYYYMMDDHHMMSS_add_review_start_date_to_campaigns.sql`

**작업 내용**:
```sql
-- 1. review_start_date 컬럼 추가 (NULL 허용)
ALTER TABLE public.campaigns 
ADD COLUMN review_start_date TIMESTAMPTZ;

-- 2. 기존 필드명 변경을 위한 새 컬럼 추가
ALTER TABLE public.campaigns 
ADD COLUMN apply_start_date TIMESTAMPTZ,
ADD COLUMN apply_end_date TIMESTAMPTZ,
ADD COLUMN review_end_date TIMESTAMPTZ;

-- 3. 기존 데이터 복사
UPDATE public.campaigns 
SET 
    apply_start_date = start_date,
    apply_end_date = end_date,
    review_start_date = end_date,  -- 기본값: 신청 종료일시 = 리뷰 시작일시
    review_end_date = expiration_date;

-- 4. NOT NULL 제약 조건 추가
ALTER TABLE public.campaigns 
ALTER COLUMN apply_start_date SET NOT NULL,
ALTER COLUMN apply_end_date SET NOT NULL,
ALTER COLUMN review_start_date SET NOT NULL,
ALTER COLUMN review_end_date SET NOT NULL;

-- 5. 기존 제약 조건 삭제
ALTER TABLE public.campaigns 
DROP CONSTRAINT IF EXISTS campaigns_dates_check;

-- 6. 새로운 제약 조건 추가 (4개 필드 간 검증)
ALTER TABLE public.campaigns 
ADD CONSTRAINT campaigns_dates_check CHECK (
    apply_start_date <= apply_end_date 
    AND apply_end_date <= review_start_date 
    AND review_start_date <= review_end_date
);

-- 7. 기존 컬럼 삭제 (데이터 검증 후)
-- 주의: 모든 코드가 새 필드명을 사용하는지 확인 후 실행
-- ALTER TABLE public.campaigns 
-- DROP COLUMN start_date,
-- DROP COLUMN end_date,
-- DROP COLUMN expiration_date;

-- 8. 제약 조건 코멘트 업데이트
COMMENT ON CONSTRAINT campaigns_dates_check ON public.campaigns IS 
'캠페인 날짜 순서 검증: 신청 시작일시 <= 신청 종료일시 <= 리뷰 시작일시 <= 리뷰 종료일시';
```

#### 1.2 RPC 함수 수정
**파일**: `supabase/migrations/YYYYMMDDHHMMSS_update_create_campaign_rpc_with_review_start_date.sql`

**작업 내용**:
- `create_campaign_with_points_v2` 함수 파라미터 변경:
  - `p_start_date` → `p_apply_start_date`
  - `p_end_date` → `p_apply_end_date`
  - `p_expiration_date` → `p_review_end_date`
  - `p_review_start_date` 추가
- 날짜 검증 로직 수정
- INSERT 문에 새 필드명 사용
- 기본값 처리: `p_review_start_date`가 NULL인 경우 `p_apply_end_date + 1일`로 설정

### Phase 2: Flutter 모델 수정

#### 2.1 Campaign 모델 수정
**파일**: `lib/models/campaign.dart`

**작업 내용**:
- 필드명 변경:
  - `startDate` → `applyStartDate`
  - `endDate` → `applyEndDate`
  - `expirationDate` → `reviewEndDate`
- `reviewStartDate` 필드 추가 (DateTime 타입)
- 생성자 파라미터 변경
- `fromJson` 메서드에서 새 필드명 파싱 (하위 호환성을 위해 기존 필드명도 지원)
- `toJson` 메서드에서 새 필드명 직렬화
- `copyWith` 메서드 파라미터 변경

### Phase 3: Flutter 서비스 수정

#### 3.1 CampaignService 수정
**파일**: `lib/services/campaign_service.dart`

**작업 내용**:
- `createCampaignV2` 메서드 파라미터 변경:
  - `startDate` → `applyStartDate`
  - `endDate` → `applyEndDate`
  - `expirationDate` → `reviewEndDate`
  - `reviewStartDate` 추가
- RPC 호출 시 새 파라미터명 사용
- 날짜 검증 로직 확인 및 수정

### Phase 4: UI 수정

#### 4.1 캠페인 생성 화면 수정
**파일**: `lib/screens/campaign/campaign_creation_screen.dart`

**작업 내용**:

1. **상태 변수 추가**:
   - `DateTime? _reviewStartDateTime` 추가
   - `TextEditingController _reviewStartDateTimeController` 추가

2. **라벨 변경**:
   - "시작 일시 *" → "신청 시작일시 *"
   - "종료 일시 *" → "신청 종료일시 *"
   - "만기일 *" → "리뷰 종료일시 *"

3. **리뷰 시작일시 입력 필드 추가**:
   - "리뷰 시작일시 *" 입력 필드 추가
   - 날짜 선택 핸들러 추가 (`_selectReviewStartDateTime`)

4. **날짜 선택 로직 수정**:
   - `_selectDateTime`: 신청 시작일시/종료일시 선택 시 리뷰 시작일시 자동 조정
   - `_selectReviewStartDateTime`: 리뷰 시작일시 선택 시 리뷰 종료일시 자동 조정
   - `_selectExpirationDateTime`: 리뷰 종료일시 선택 시 검증

5. **날짜 검증 로직 수정**:
   - 4개 필드 간 순서 검증
   - 에러 메시지 업데이트

6. **컨트롤러 업데이트**:
   - `_updateDateTimeControllers` 메서드에 리뷰 시작일시 추가

7. **캠페인 생성 로직 수정**:
   - `_createCampaign` 메서드에서 `reviewStartDate` 전달

### Phase 5: 기타 화면 수정

#### 5.1 광고주 캠페인 상세 화면
**파일**: `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`

**작업 내용**:
- 날짜 필드 표시 부분 확인
- "신청 시작일시", "신청 종료일시", "리뷰 시작일시", "리뷰 종료일시" 라벨로 변경
- `reviewStartDate` 필드 표시 추가

#### 5.2 광고주 내 캠페인 목록 화면
**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`

**작업 내용**:
- 캠페인 상태 판단 로직 확인 및 수정
- **등록기간 탭 로직 변경**:
  - 기존: `endDate < now AND expirationDate >= now` (신청 종료 후 ~ 리뷰 종료 전)
  - 변경: `reviewStartDate <= now AND reviewEndDate >= now` (리뷰 시작일시 ~ 리뷰 종료일시)
- **종료 탭 로직 변경**:
  - 기존: `expirationDate < now OR status == inactive`
  - 변경: `reviewEndDate < now OR status == inactive`
- 신청 기간과 리뷰 기간을 구분하여 상태 판단
- 날짜 필드 표시 부분 확인 및 수정

#### 5.3 광고주 마이페이지
**파일**: `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`

**작업 내용**:
- 캠페인 상태 판단 로직 확인
- 신청 기간과 리뷰 기간을 구분하여 상태 판단

#### 5.4 캠페인 상세 화면
**파일**: `lib/screens/campaign/campaign_detail_screen.dart`

**작업 내용**:
- 날짜 필드 표시 부분 확인
- 필요 시 라벨 변경 및 `reviewStartDate` 필드 표시 추가

### Phase 6: 테스트 및 검증

#### 6.1 기능 테스트
- [ ] 캠페인 생성 시 4개 날짜 필드 모두 입력 가능한지 확인
- [ ] 날짜 순서 검증이 올바르게 동작하는지 확인
- [ ] 자동 조정 로직이 올바르게 동작하는지 확인
- [ ] 기존 캠페인 조회 시 `review_start_date`가 올바르게 표시되는지 확인

#### 6.2 데이터 무결성 확인
- [ ] 기존 데이터 마이그레이션이 올바르게 수행되었는지 확인
- [ ] 제약 조건이 올바르게 적용되었는지 확인
- [ ] RPC 함수가 올바르게 동작하는지 확인

## ⚠️ 주의사항

### 1. 하위 호환성
- 기존 데이터의 경우 `review_start_date`를 `end_date`로 설정하여 마이그레이션
- 기존 API 호출 시 `review_start_date`가 없으면 기본값으로 처리

### 2. 날짜 검증
- 4개 필드 간 순서 검증이 필수
- UI 레이어와 DB 레이어 모두에서 검증 필요

### 3. 자동 조정 로직
- 사용자 경험을 위해 날짜 선택 시 자동으로 다음 날짜를 조정
- 하지만 사용자가 수동으로 변경할 수 있어야 함

### 4. 에러 메시지
- 명확하고 이해하기 쉬운 에러 메시지 제공
- 어떤 날짜가 문제인지 명확히 표시

## 📅 예상 작업 시간

- Phase 1 (데이터베이스): 2-3시간
- Phase 2 (모델): 1시간
- Phase 3 (서비스): 1시간
- Phase 4 (UI - 캠페인 생성): 3-4시간
- Phase 5 (기타 화면 수정): 2-3시간
- Phase 6 (테스트 및 검증): 2-3시간

**총 예상 시간**: 11-15시간

## 🔄 롤백 계획

만약 문제가 발생할 경우:

1. 마이그레이션 롤백: `review_start_date` 컬럼 제거
2. 제약 조건 복원: 기존 3개 필드 제약 조건으로 복원
3. RPC 함수 롤백: 이전 버전으로 복원
4. Flutter 코드 롤백: Git을 통한 이전 버전으로 복원

## 📊 필드명 정의

### 데이터베이스 필드명
- `apply_start_date`: 신청 시작일시
- `apply_end_date`: 신청 종료일시
- `review_start_date`: 리뷰 시작일시
- `review_end_date`: 리뷰 종료일시

### Flutter 모델 필드명
```dart
campaign.applyStartDate     // 신청 시작일시
campaign.applyEndDate       // 신청 종료일시
campaign.reviewStartDate    // 리뷰 시작일시
campaign.reviewEndDate      // 리뷰 종료일시
```

### RPC 함수 파라미터명
- `p_apply_start_date`: 신청 시작일시
- `p_apply_end_date`: 신청 종료일시
- `p_review_start_date`: 리뷰 시작일시
- `p_review_end_date`: 리뷰 종료일시

## 📚 참고 자료

### 데이터베이스
- 현재 스키마: `supabase/migrations/20251124000400_remove_campaign_id_from_refund_description.sql`
- RPC 함수: `supabase/migrations/20251124120200_update_create_campaign_rpc_with_logging_and_max_per_reviewer.sql`

### Flutter 코드
- Campaign 모델: `lib/models/campaign.dart`
- Campaign 서비스: `lib/services/campaign_service.dart`
- 캠페인 생성 화면: `lib/screens/campaign/campaign_creation_screen.dart`
- 광고주 캠페인 상세: `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`
- 광고주 내 캠페인 목록: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- 광고주 마이페이지: `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`
- 캠페인 상세 화면: `lib/screens/campaign/campaign_detail_screen.dart`

## 🔍 추가 고려사항

### 캠페인 상태 판단 로직

#### 현재 상태 판단 로직 (`advertiser_my_campaigns_screen.dart`)
현재 캠페인 상태는 다음과 같이 판단됩니다:
- **모집 (대기중)**: `startDate > now` (신청 시작 전)
- **모집중**: `startDate <= now AND endDate >= now` (신청 기간)
- **선정완료**: `startDate <= now AND endDate >= now AND currentParticipants >= maxParticipants` (신청 기간 중 인원 마감)
- **등록기간**: `endDate < now AND expirationDate >= now` (신청 종료 후 ~ 리뷰 종료 전) ⚠️ **수정 필요**
- **종료**: `expirationDate < now OR status == inactive` (리뷰 종료 후) ⚠️ **수정 필요**

#### 변경 후 상태 판단 로직
변경 후에는 다음과 같이 구분합니다:
- **모집 (대기중)**: `applyStartDate > now` (신청 시작 전)
- **모집중**: `applyStartDate <= now AND applyEndDate >= now` (신청 기간)
- **선정완료**: `applyStartDate <= now AND applyEndDate >= now AND currentParticipants >= maxParticipants` (신청 기간 중 인원 마감)
- **등록기간**: `reviewStartDate <= now AND reviewEndDate >= now` (리뷰 시작일시 ~ 리뷰 종료일시) ✅ **변경됨**
- **종료**: `reviewEndDate < now OR status == inactive` (리뷰 종료일시 지남 또는 inactive 상태) ✅ **변경됨**

**주요 변경 사항**:
- **등록기간**: 기존에는 `endDate < now AND expirationDate >= now` (신청 종료 후 ~ 리뷰 종료 전)였으나, 변경 후에는 **리뷰 시작일시부터 리뷰 종료일시까지**로 변경
- **종료**: 기존에는 `expirationDate < now OR status == inactive`였으나, 변경 후에는 **`reviewEndDate < now OR status == inactive`**로 명확화

#### 수정이 필요한 파일

1. **`lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`**
   - `_categorizeCampaigns()` 메서드 수정
   - **등록기간 탭 로직 변경**:
     ```dart
     // 기존: endDate < now AND expirationDate >= now
     // 변경: reviewStartDate <= now AND reviewEndDate >= now
     _registeredCampaigns = _allCampaigns.where((campaign) {
       if (campaign.status != CampaignStatus.active) return false;
       if (campaign.reviewStartDate.isAfter(now)) return false;
       if (campaign.reviewEndDate.isBefore(now)) return false;
       return true;
     }).toList();
     ```
   - **종료 탭 로직 변경**:
     ```dart
     // 기존: expirationDate < now OR status == inactive
     // 변경: reviewEndDate < now OR status == inactive
     _completedCampaigns = _allCampaigns.where((campaign) {
       if (campaign.status == CampaignStatus.inactive) return true;
       return campaign.reviewEndDate.isBefore(now);
     }).toList();
     ```
   
2. **`lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`**
   - 캠페인 상태 판단 로직 수정
   - 동일한 로직 적용 (등록기간, 종료 탭 로직)

### 날짜 필드 표시 라벨 변경
다음 화면에서 날짜 필드 라벨을 변경해야 합니다:
- `advertiser_campaign_detail_screen.dart`:
  - "시작일" → "신청 시작일시"
  - "종료일" → "신청 종료일시"
  - "만료일" → "리뷰 종료일시"
  - "리뷰 시작일시" 추가

이 로직을 사용하는 모든 화면에서 확인 및 수정이 필요합니다.

