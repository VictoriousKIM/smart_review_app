# 캠페인 날짜 필드 세분화 및 구체화 구현 보고서

**작성일**: 2025년 11월 24일  
**작업 기간**: 2025년 11월 24일  
**작업자**: AI Assistant

## 📋 작업 개요

캠페인 날짜 필드의 의미를 명확히 하고, 신청 기간과 리뷰 기간을 분리하여 관리할 수 있도록 시스템을 개선했습니다.

### 변경 목표
- 기존 3개 날짜 필드를 4개로 확장
- 필드명을 더 직관적이고 명확하게 변경
- 신청 기간과 리뷰 기간을 명확히 구분

## ✅ 완료된 작업

### Phase 1: 데이터베이스 스키마 변경 ✅

#### 1.1 마이그레이션 파일 생성
**파일**: `supabase/migrations/20251124155341_add_review_start_date_and_rename_date_fields.sql`

**작업 내용**:
- `review_start_date` 컬럼 추가
- 새 필드명 컬럼 추가: `apply_start_date`, `apply_end_date`, `review_end_date`
- 기존 데이터 마이그레이션 (기존 필드에서 새 필드로 복사)
- `review_start_date` 기본값: `end_date` (신청 종료일시 = 리뷰 시작일시)
- NOT NULL 제약 조건 추가
- 제약 조건 수정: 4개 필드 간 순서 검증
  ```sql
  apply_start_date <= apply_end_date <= review_start_date <= review_end_date
  ```

#### 1.2 RPC 함수 수정
**파일**: `supabase/migrations/20251124155342_update_create_campaign_rpc_with_new_date_fields.sql`

**작업 내용**:
- `create_campaign_with_points_v2` 함수 파라미터 변경:
  - `p_start_date` → `p_apply_start_date`
  - `p_end_date` → `p_apply_end_date`
  - `p_expiration_date` → `p_review_end_date`
  - `p_review_start_date` 추가
- 날짜 검증 로직 추가 (4개 필드 간 순서 검증)
- INSERT 문에 새 필드명 사용
- 기본값 처리:
  - `p_review_start_date`가 NULL인 경우: `p_apply_end_date + 1일`
  - `p_review_end_date`가 NULL인 경우: `review_start_date + 30일`

### Phase 2: Flutter 모델 수정 ✅

**파일**: `lib/models/campaign.dart`

**작업 내용**:
- 필드명 변경:
  - `startDate` → `applyStartDate`
  - `endDate` → `applyEndDate`
  - `expirationDate` → `reviewEndDate`
- `reviewStartDate` 필드 추가 (DateTime 타입)
- 생성자 파라미터 변경
- `fromJson` 메서드 수정:
  - 새 필드명 파싱
  - 하위 호환성 유지 (기존 필드명도 지원)
- `toJson` 메서드 수정: 새 필드명 직렬화
- `copyWith` 메서드 파라미터 변경

### Phase 3: Flutter 서비스 수정 ✅

**파일**: `lib/services/campaign_service.dart`

**작업 내용**:
- `createCampaignV2` 메서드 파라미터 변경:
  - `startDate` → `applyStartDate`
  - `endDate` → `applyEndDate`
  - `expirationDate` → `reviewEndDate`
  - `reviewStartDate` 추가
- 날짜 검증 로직 수정 (4개 필드 간 검증)
- RPC 호출 시 새 파라미터명 사용
- 쿼리 SELECT 문에 새 필드명 추가
- 날짜 필터링 로직 수정 (신청 기간 기준)

### Phase 4: UI 수정 ✅

**파일**: `lib/screens/campaign/campaign_creation_screen.dart`

**작업 내용**:

1. **상태 변수 추가**:
   - `DateTime? _applyStartDateTime` (기존: `_startDateTime`)
   - `DateTime? _applyEndDateTime` (기존: `_endDateTime`)
   - `DateTime? _reviewStartDateTime` (신규)
   - `DateTime? _reviewEndDateTime` (기존: `_expirationDateTime`)

2. **컨트롤러 추가**:
   - `TextEditingController _applyStartDateTimeController`
   - `TextEditingController _applyEndDateTimeController`
   - `TextEditingController _reviewStartDateTimeController` (신규)
   - `TextEditingController _reviewEndDateTimeController`

3. **라벨 변경**:
   - "시작 일시 *" → "신청 시작일시 *"
   - "종료 일시 *" → "신청 종료일시 *"
   - "만기일 *" → "리뷰 종료일시 *"
   - "리뷰 시작일시 *" 추가

4. **날짜 선택 메서드 분리**:
   - `_selectApplyStartDateTime()`: 신청 시작일시 선택
   - `_selectApplyEndDateTime()`: 신청 종료일시 선택
   - `_selectReviewStartDateTime()`: 리뷰 시작일시 선택 (신규)
   - `_selectReviewEndDateTime()`: 리뷰 종료일시 선택 (기존: `_selectExpirationDateTime`)

5. **날짜 자동 조정 로직**:
   - 신청 시작일시 선택 시 → 신청 종료일시, 리뷰 시작일시, 리뷰 종료일시 자동 조정
   - 신청 종료일시 선택 시 → 리뷰 시작일시, 리뷰 종료일시 자동 조정
   - 리뷰 시작일시 선택 시 → 리뷰 종료일시 자동 조정

6. **날짜 검증 로직 수정**:
   - 4개 필드 간 순서 검증
   - 에러 메시지 업데이트

7. **캠페인 생성 로직 수정**:
   - `_createCampaign` 메서드에서 새 필드명 사용

### Phase 5: 기타 화면 수정 ✅

#### 5.1 광고주 캠페인 상세 화면
**파일**: `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`

**작업 내용**:
- 날짜 필드 라벨 변경:
  - "시작일" → "신청 시작일시"
  - "종료일" → "신청 종료일시"
  - "만료일" → "리뷰 종료일시"
- "리뷰 시작일시" 필드 표시 추가
- 필드명 변경: `startDate` → `applyStartDate`, `endDate` → `applyEndDate`, `expirationDate` → `reviewEndDate`

#### 5.2 광고주 내 캠페인 목록 화면
**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`

**작업 내용**:
- 캠페인 상태 판단 로직 수정:
  - **모집 (대기중)**: `applyStartDate > now`
  - **모집중**: `applyStartDate <= now AND applyEndDate >= now`
  - **선정완료**: `applyStartDate <= now AND applyEndDate >= now AND currentParticipants >= maxParticipants`
  - **등록기간**: `reviewStartDate <= now AND reviewEndDate >= now` ✅ **변경됨**
  - **종료**: `reviewEndDate < now OR status == inactive` ✅ **변경됨**
- 날짜 필드 표시 부분 수정
- 필드명 변경

#### 5.3 광고주 마이페이지
**파일**: `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`

**작업 내용**:
- 캠페인 상태 판단 로직 수정 (등록기간, 종료 탭 로직)
- 필드명 변경

#### 5.4 캠페인 상세 화면
**파일**: `lib/screens/campaign/campaign_detail_screen.dart`

**작업 내용**:
- 날짜 필드 표시 부분 수정
- 필드명 변경: `endDate` → `applyEndDate`

## 📊 변경 사항 요약

### 데이터베이스 필드명 변경
| 기존 필드명 | 새 필드명 | 설명 |
|------------|----------|------|
| `start_date` | `apply_start_date` | 신청 시작일시 |
| `end_date` | `apply_end_date` | 신청 종료일시 |
| `expiration_date` | `review_end_date` | 리뷰 종료일시 |
| - | `review_start_date` | 리뷰 시작일시 (신규) |

### Flutter 모델 필드명 변경
| 기존 필드명 | 새 필드명 | 설명 |
|------------|----------|------|
| `startDate` | `applyStartDate` | 신청 시작일시 |
| `endDate` | `applyEndDate` | 신청 종료일시 |
| `expirationDate` | `reviewEndDate` | 리뷰 종료일시 |
| - | `reviewStartDate` | 리뷰 시작일시 (신규) |

### RPC 함수 파라미터 변경
| 기존 파라미터 | 새 파라미터 | 설명 |
|-------------|-----------|------|
| `p_start_date` | `p_apply_start_date` | 신청 시작일시 |
| `p_end_date` | `p_apply_end_date` | 신청 종료일시 |
| `p_expiration_date` | `p_review_end_date` | 리뷰 종료일시 |
| - | `p_review_start_date` | 리뷰 시작일시 (신규) |

### UI 라벨 변경
| 기존 라벨 | 새 라벨 |
|----------|--------|
| "시작 일시 *" | "신청 시작일시 *" |
| "종료 일시 *" | "신청 종료일시 *" |
| "만기일 *" | "리뷰 종료일시 *" |
| - | "리뷰 시작일시 *" (신규) |

## 🔍 주요 변경 로직

### 날짜 순서 제약 조건
```
신청 시작일시 <= 신청 종료일시 <= 리뷰 시작일시 <= 리뷰 종료일시
```

### 캠페인 상태 판단 로직 변경

#### 등록기간 탭
- **기존**: `endDate < now AND expirationDate >= now` (신청 종료 후 ~ 리뷰 종료 전)
- **변경**: `reviewStartDate <= now AND reviewEndDate >= now` (리뷰 시작일시 ~ 리뷰 종료일시)

#### 종료 탭
- **기존**: `expirationDate < now OR status == inactive`
- **변경**: `reviewEndDate < now OR status == inactive`

## 📁 수정된 파일 목록

### 데이터베이스 마이그레이션
1. `supabase/migrations/20251124155341_add_review_start_date_and_rename_date_fields.sql` (신규)
2. `supabase/migrations/20251124155342_update_create_campaign_rpc_with_new_date_fields.sql` (신규)

### Flutter 모델
3. `lib/models/campaign.dart`

### Flutter 서비스
4. `lib/services/campaign_service.dart`

### Flutter UI
5. `lib/screens/campaign/campaign_creation_screen.dart`
6. `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
7. `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`
8. `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`
9. `lib/screens/campaign/campaign_detail_screen.dart`

## ⚠️ 주의사항

### 하위 호환성
- `Campaign.fromJson` 메서드에서 기존 필드명도 지원하여 하위 호환성 유지
- 기존 데이터는 마이그레이션 시 자동으로 새 필드로 복사됨
- 기존 컬럼(`start_date`, `end_date`, `expiration_date`)은 아직 삭제하지 않음 (데이터 검증 후 삭제 예정)

### 마이그레이션 순서
1. 먼저 스키마 변경 마이그레이션 실행
2. 그 다음 RPC 함수 수정 마이그레이션 실행
3. Flutter 코드 배포
4. 데이터 검증 후 기존 컬럼 삭제 (별도 마이그레이션)

### 테스트 필요 항목
- [ ] 캠페인 생성 시 4개 날짜 필드 모두 입력 가능한지 확인
- [ ] 날짜 순서 검증이 올바르게 동작하는지 확인
- [ ] 자동 조정 로직이 올바르게 동작하는지 확인
- [ ] 기존 캠페인 조회 시 새 필드명이 올바르게 표시되는지 확인
- [ ] 등록기간 탭이 리뷰 기간을 올바르게 표시하는지 확인
- [ ] 종료 탭이 올바르게 동작하는지 확인

## 🐛 알려진 이슈

1. **린터 경고**: `lib/screens/campaign/campaign_creation_screen.dart:74` - `_productProvisionOther` 필드 미사용 경고 (기존 코드, 작업 범위 외)

## 📝 다음 단계

1. **데이터베이스 마이그레이션 실행**
   - 로컬 환경에서 마이그레이션 테스트
   - 프로덕션 환경에 마이그레이션 적용

2. **기존 컬럼 삭제** (데이터 검증 후)
   - 모든 코드가 새 필드명을 사용하는지 확인
   - 기존 컬럼 삭제 마이그레이션 생성 및 실행

3. **테스트 및 검증**
   - 기능 테스트
   - 데이터 무결성 확인
   - UI/UX 테스트

4. **문서 업데이트**
   - API 문서 업데이트
   - 사용자 가이드 업데이트 (필요 시)

## ✅ 작업 완료 체크리스트

- [x] Phase 1: 데이터베이스 스키마 변경
- [x] Phase 2: Flutter 모델 수정
- [x] Phase 3: Flutter 서비스 수정
- [x] Phase 4: 캠페인 생성 화면 UI 수정
- [x] Phase 5: 기타 화면 수정
- [x] 결과 보고서 작성

## 📈 작업 통계

- **수정된 파일**: 9개
- **신규 마이그레이션 파일**: 2개
- **추가된 필드**: 1개 (`review_start_date`)
- **변경된 필드명**: 3개
- **수정된 화면**: 5개

## 🎯 결론

캠페인 날짜 필드를 성공적으로 세분화하고 구체화했습니다. 신청 기간과 리뷰 기간을 명확히 구분할 수 있게 되어, 사용자가 더 직관적으로 캠페인 일정을 관리할 수 있게 되었습니다.

모든 코드 변경이 완료되었으며, 데이터베이스 마이그레이션 실행 후 테스트를 진행하면 됩니다.

