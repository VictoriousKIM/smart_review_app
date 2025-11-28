# "리뷰어" → "스토어" 변경 로드맵

## 📋 개요
캠페인 타입/카테고리에서 "리뷰어"를 "스토어"로 변경하는 작업 계획

## ⚠️ 주의사항
- **사용자 역할(user role)로서의 "리뷰어"는 변경하지 않음** (예: 리뷰어 마이페이지, 리뷰어 전환 등)
- **캠페인 타입/카테고리와 관련된 "리뷰어"만 변경**
- 데이터베이스 마이그레이션 필요 (기존 데이터 업데이트)

---

## 📝 변경 대상 항목

### 1. UI 텍스트 변경 (한글 표시)

#### 1.1 캠페인 화면 카테고리 필터
- **파일**: `lib/screens/campaign/campaigns_screen.dart`
- **위치**: Line 30
- **변경 전**: `{'key': 'reviewer', 'label': '리뷰어', 'icon': Icons.rate_review}`
- **변경 후**: `{'key': 'store', 'label': '스토어', 'icon': Icons.store}`

#### 1.2 캠페인 생성 화면
- **파일**: `lib/screens/campaign/campaign_creation_screen.dart`
- **위치**: Line 1818
- **변경 전**: `DropdownMenuItem(value: 'reviewer', child: Text('리뷰어'))`
- **변경 후**: `DropdownMenuItem(value: 'store', child: Text('스토어'))`

#### 1.3 캠페인 편집 화면
- **파일**: `lib/screens/campaign/campaign_edit_screen.dart`
- **위치**: Line 711
- **변경 전**: `DropdownMenuItem(value: 'reviewer', child: Text('리뷰어'))`
- **변경 후**: `DropdownMenuItem(value: 'store', child: Text('스토어'))`

#### 1.4 캠페인 상세 화면
- **파일**: `lib/screens/campaign/campaign_detail_screen.dart`
- **위치**: Line 370-371
- **변경 전**: 
  ```dart
  case CampaignCategory.reviewer:
    return '리뷰어';
  ```
- **변경 후**: 
  ```dart
  case CampaignCategory.store:
    return '스토어';
  ```

#### 1.5 광고주 캠페인 상세 화면
- **파일**: `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`
- **위치**: Line 441-442
- **변경 전**: 
  ```dart
  case CampaignCategory.reviewer:
    return '리뷰어';
  ```
- **변경 후**: 
  ```dart
  case CampaignCategory.store:
    return '스토어';
  ```

---

### 2. 코드 값 변경 (영문 키/값)

#### 2.1 Flutter Enum
- **파일**: `lib/models/campaign.dart`
- **위치**: Line 321
- **변경 전**: `enum CampaignCategory { all, reviewer, press, visit }`
- **변경 후**: `enum CampaignCategory { all, store, press, visit }`

#### 2.2 Enum 매핑 함수
- **파일**: `lib/models/campaign.dart`
- **위치**: Line 92-103 (mapCampaignType 함수)
- **변경 전**:
  ```dart
  case 'reviewer':
    return CampaignCategory.reviewer;
  ```
- **변경 후**:
  ```dart
  case 'store':
    return CampaignCategory.store;
  ```

#### 2.3 Enum → DB 변환 함수
- **파일**: `lib/models/campaign.dart`
- **위치**: Line 176-187 (mapCampaignTypeToDb 함수)
- **변경 전**:
  ```dart
  case CampaignCategory.reviewer:
    return 'reviewer';
  case CampaignCategory.all:
    return 'reviewer'; // 기본값
  ```
- **변경 후**:
  ```dart
  case CampaignCategory.store:
    return 'store';
  case CampaignCategory.all:
    return 'store'; // 기본값
  ```

#### 2.4 기본값 변경
- **파일**: `lib/models/campaign.dart`
- **위치**: Line 101 (기본값)
- **변경 전**: `return CampaignCategory.reviewer; // 기본값`
- **변경 후**: `return CampaignCategory.store; // 기본값`

#### 2.5 캠페인 생성/편집 화면 기본값
- **파일**: 
  - `lib/screens/campaign/campaign_creation_screen.dart` (Line 72)
  - `lib/screens/campaign/campaign_edit_screen.dart` (Line 50)
- **변경 전**: `String _campaignType = 'reviewer';`
- **변경 후**: `String _campaignType = 'store';`

#### 2.6 CampaignCategory.all 기본값
- **파일**: `lib/models/campaign.dart`
- **위치**: Line 185 (mapCampaignTypeToDb 함수 내)
- **변경 전**: `return 'reviewer'; // 기본값`
- **변경 후**: `return 'store'; // 기본값`

---

### 3. 데이터베이스 스키마 변경

#### 3.1 campaigns 테이블 CHECK 제약조건
- **파일**: `supabase/migrations/20251125143016_create_update_campaign_v2_rpc.sql`
- **위치**: Line 5971
- **변경 전**: 
  ```sql
  CONSTRAINT "campaigns_campaign_type_check" CHECK (("campaign_type" = ANY (ARRAY['reviewer'::"text", 'journalist'::"text", 'visit'::"text"])))
  ```
- **변경 후**: 
  ```sql
  CONSTRAINT "campaigns_campaign_type_check" CHECK (("campaign_type" = ANY (ARRAY['store'::"text", 'journalist'::"text", 'visit'::"text"])))
  ```

#### 3.2 campaigns 테이블 기본값
- **파일**: `supabase/migrations/20251125143016_create_update_campaign_v2_rpc.sql`
- **위치**: Line 5948
- **변경 전**: `"campaign_type" "text" DEFAULT 'reviewer'::"text"`
- **변경 후**: `"campaign_type" "text" DEFAULT 'store'::"text"`

#### 3.3 기존 데이터 업데이트 마이그레이션
- **새 마이그레이션 파일 생성 필요**
- **내용**:
  ```sql
  -- 기존 'reviewer' 값을 'store'로 변경
  UPDATE campaigns SET campaign_type = 'store' WHERE campaign_type = 'reviewer';
  ```

---

### 4. RPC 함수 변경

#### 4.1 create_campaign_with_points_v2
- **파일**: `supabase/migrations/20251125143016_create_update_campaign_v2_rpc.sql`
- **위치**: 여러 곳
- **변경 내용**: 
  - 파라미터 타입 검증 로직에서 'reviewer' → 'store' 변경
  - 주석 및 에러 메시지 업데이트

#### 4.2 update_campaign_v2
- **파일**: `supabase/migrations/20251125143016_create_update_campaign_v2_rpc.sql`
- **위치**: 여러 곳
- **변경 내용**: 
  - 파라미터 타입 검증 로직에서 'reviewer' → 'store' 변경

---

### 5. 변수명 및 필드명 (선택사항)

#### 5.1 maxPerReviewer 관련
- **주의**: "리뷰어당 신청 가능 개수"는 의미상 "스토어당 신청 가능 개수"로 변경 가능
- **하지만**: 변수명 변경은 큰 영향이 있으므로 신중히 결정 필요
- **제안**: 
  - UI 텍스트만 변경: "스토어당 신청 가능 개수"
  - 변수명은 유지: `maxPerReviewer` (또는 `maxPerStore`로 변경)


---

## 🔄 변경 순서 (권장)

### Phase 1: Flutter 코드 변경
1. ✅ Enum 정의 변경 (`CampaignCategory.reviewer` → `CampaignCategory.store`)
2. ✅ Enum 매핑 함수 변경
3. ✅ UI 텍스트 변경 (한글)
4. ✅ 기본값 변경

### Phase 2: 데이터베이스 마이그레이션
1. ✅ 새 마이그레이션 파일 생성
2. ✅ CHECK 제약조건 변경
3. ✅ 기본값 변경
4. ✅ 기존 데이터 업데이트 (`UPDATE campaigns SET campaign_type = 'store' WHERE campaign_type = 'reviewer'`)

### Phase 3: RPC 함수 업데이트
1. ✅ RPC 함수 내부 검증 로직 변경
2. ✅ 주석 및 에러 메시지 업데이트

### Phase 4: 테스트 및 검증
1. ✅ 캠페인 생성 테스트
2. ✅ 캠페인 편집 테스트
3. ✅ 캠페인 목록 필터링 테스트
4. ✅ 기존 데이터 조회 테스트

---

## 📌 변경하지 않을 항목

### 사용자 역할 관련
- ❌ 리뷰어 마이페이지 (`/mypage/reviewer`)
- ❌ 리뷰어 전환 버튼
- ❌ 사용자 타입으로서의 "리뷰어"
- ❌ `wallet_type = 'reviewer'` (사용자 지갑 타입)

### 기타
- ❌ `company_users.company_role = 'reviewer'` (회사 내 역할)
- ❌ `onlyAllowedReviewers` 관련 ("사업자가 허용한 리뷰어만 가능" - 사용자 역할 관련이므로 변경하지 않음)

---

## 🎯 최종 확인 체크리스트

- [ ] Flutter Enum 변경 완료
- [ ] UI 텍스트 변경 완료
- [ ] 데이터베이스 마이그레이션 생성 및 적용
- [ ] RPC 함수 업데이트 완료
- [ ] 기존 데이터 업데이트 완료
- [ ] 모든 화면에서 테스트 완료
- [ ] Git 커밋 및 푸시

---

## 📝 참고사항

1. **데이터베이스 마이그레이션은 신중하게 진행**
   - 기존 데이터 백업 권장
   - 단계별로 테스트

2. **변수명 변경은 선택사항**
   - `maxPerReviewer` → `maxPerStore` 변경 시 많은 파일 수정 필요
   - UI 텍스트만 변경하는 것도 충분히 가능

3. **아이콘 변경 고려**
   - 현재: `Icons.rate_review`
   - 제안: `Icons.store` 또는 `Icons.shop`

