# "리뷰어" → "스토어" 변경 작업 결과 보고서

## 📋 작업 개요
- **작업 일시**: 2025년 11월 28일
- **작업 목적**: 캠페인 타입/카테고리에서 "리뷰어"를 "스토어"로 변경
- **작업 범위**: Flutter 코드, 데이터베이스 스키마, 마이그레이션
- **마이그레이션 상태**: ✅ 프로덕션 적용 완료

---

## ✅ 완료된 작업

### Phase 1: Flutter 코드 변경

#### 1.1 Enum 정의 변경
- **파일**: `lib/models/campaign.dart`
- **변경 내용**: 
  - `enum CampaignCategory { all, reviewer, press, visit }` 
  - → `enum CampaignCategory { all, store, press, visit }`

#### 1.2 Enum 매핑 함수 변경
- **파일**: `lib/models/campaign.dart`
- **변경 내용**:
  - `mapCampaignType()`: `case 'reviewer'` → `case 'store'`
  - 기본값: `CampaignCategory.reviewer` → `CampaignCategory.store`
  - `mapCampaignTypeToDb()`: `case CampaignCategory.reviewer` → `case CampaignCategory.store`
  - `CampaignCategory.all` 기본값: `'reviewer'` → `'store'`

#### 1.3 UI 텍스트 변경
- **캠페인 화면 카테고리 필터** (`lib/screens/campaign/campaigns_screen.dart`)
  - `{'key': 'reviewer', 'label': '리뷰어', 'icon': Icons.rate_review}`
  - → `{'key': 'store', 'label': '스토어', 'icon': Icons.store}`

- **캠페인 생성 화면** (`lib/screens/campaign/campaign_creation_screen.dart`)
  - `DropdownMenuItem(value: 'reviewer', child: Text('리뷰어'))`
  - → `DropdownMenuItem(value: 'store', child: Text('스토어'))`
  - 기본값: `String _campaignType = 'reviewer'` → `'store'`

- **캠페인 편집 화면** (`lib/screens/campaign/campaign_edit_screen.dart`)
  - `DropdownMenuItem(value: 'reviewer', child: Text('리뷰어'))`
  - → `DropdownMenuItem(value: 'store', child: Text('스토어'))`
  - 기본값: `String _campaignType = 'reviewer'` → `'store'`

- **캠페인 상세 화면** (`lib/screens/campaign/campaign_detail_screen.dart`)
  - `case CampaignCategory.reviewer: return '리뷰어';`
  - → `case CampaignCategory.store: return '스토어';`

- **광고주 캠페인 상세 화면** (`lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`)
  - `case CampaignCategory.reviewer: return '리뷰어';`
  - → `case CampaignCategory.store: return '스토어';`

---

### Phase 2: 데이터베이스 마이그레이션

#### 2.1 새 마이그레이션 파일 생성
- **파일**: `supabase/migrations/20251128163223_change_reviewer_to_store.sql`
- **내용**:
  ```sql
  -- 1. 기존 데이터 업데이트
  UPDATE campaigns SET campaign_type = 'store' WHERE campaign_type = 'reviewer';
  
  -- 2. CHECK 제약조건 변경
  ALTER TABLE campaigns DROP CONSTRAINT IF EXISTS campaigns_campaign_type_check;
  ALTER TABLE campaigns ADD CONSTRAINT campaigns_campaign_type_check 
    CHECK (campaign_type = ANY (ARRAY['store'::text, 'journalist'::text, 'visit'::text]));
  
  -- 3. 기본값 변경
  ALTER TABLE campaigns ALTER COLUMN campaign_type SET DEFAULT 'store'::text;
  ```

---

### Phase 3: RPC 함수 업데이트

#### 3.1 RPC 함수 검토 결과
- **결과**: RPC 함수 내에서 `campaign_type`에 대한 명시적인 검증 로직이 없음
- **이유**: 데이터베이스 CHECK 제약조건이 이미 검증을 수행하므로 별도 검증 불필요
- **조치**: RPC 함수 수정 불필요

---

## 📊 변경 통계

### 변경된 파일
- **Flutter 코드**: 6개 파일
  - `lib/models/campaign.dart`
  - `lib/screens/campaign/campaigns_screen.dart`
  - `lib/screens/campaign/campaign_creation_screen.dart`
  - `lib/screens/campaign/campaign_edit_screen.dart`
  - `lib/screens/campaign/campaign_detail_screen.dart`
  - `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`

- **데이터베이스 마이그레이션**: 1개 파일
  - `supabase/migrations/20251128163223_change_reviewer_to_store.sql`

### 변경 내용 요약
- **Enum 값**: 1개 변경 (`reviewer` → `store`)
- **UI 텍스트**: 5곳 변경 ("리뷰어" → "스토어")
- **코드 값**: 6곳 변경 (`'reviewer'` → `'store'`)
- **기본값**: 3곳 변경

---

## ⚠️ 변경하지 않은 항목 (의도적)

### 사용자 역할 관련
- ✅ 리뷰어 마이페이지 (`/mypage/reviewer`)
- ✅ 리뷰어 전환 버튼
- ✅ 사용자 타입으로서의 "리뷰어"
- ✅ `wallet_type = 'reviewer'` (사용자 지갑 타입)
- ✅ `company_users.company_role = 'reviewer'` (회사 내 역할)
- ✅ `onlyAllowedReviewers` 관련 ("사업자가 허용한 리뷰어만 가능")

---

## 🔄 다음 단계

### 1. 데이터베이스 마이그레이션 적용
- ✅ **프로덕션 마이그레이션 적용 완료** (2025-11-28)
- ⚠️ **로컬 마이그레이션**: 마이그레이션 히스토리 불일치로 인해 수동 적용 필요

### 2. 테스트 항목
- [ ] 캠페인 생성 시 "스토어" 타입 선택 가능
- [ ] 캠페인 편집 시 "스토어" 타입 표시 및 변경 가능
- [ ] 캠페인 목록에서 "스토어" 필터 작동
- [ ] 캠페인 상세 화면에서 "스토어" 표시
- [ ] 기존 데이터 조회 정상 작동

### 3. 검증 사항
- [ ] 기존 'reviewer' 타입 캠페인이 'store'로 변경되었는지 확인
- [ ] 새로 생성되는 캠페인의 기본 타입이 'store'인지 확인
- [ ] 모든 화면에서 "스토어" 텍스트가 올바르게 표시되는지 확인

---

## 📝 주의사항

1. **데이터베이스 마이그레이션 적용 전**
   - 기존 데이터 백업 권장
   - 로컬 환경에서 먼저 테스트

2. **하위 호환성**
   - 기존 'reviewer' 값을 가진 데이터는 마이그레이션으로 'store'로 변경됨
   - Flutter 코드는 이미 새로운 값으로 처리하도록 변경됨

3. **변수명 유지**
   - `maxPerReviewer` 변수명은 유지 (UI 텍스트만 변경 가능)
   - `onlyAllowedReviewers` 관련은 변경하지 않음 (사용자 역할 관련)

---

## ✅ 완료 체크리스트

- [x] Flutter Enum 변경 완료
- [x] Enum 매핑 함수 변경 완료
- [x] UI 텍스트 변경 완료
- [x] 기본값 변경 완료
- [x] 데이터베이스 마이그레이션 파일 생성 완료
- [x] 데이터베이스 마이그레이션 적용 완료 (프로덕션)
- [ ] 테스트 완료 (수동 테스트 필요)

---

## 📌 참고 파일

- **로드맵**: `docs/reviewer-to-store-migration-roadmap.md`
- **마이그레이션 파일**: `supabase/migrations/20251128163223_change_reviewer_to_store.sql`

