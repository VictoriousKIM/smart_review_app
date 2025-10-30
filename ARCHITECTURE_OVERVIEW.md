# Smart Review App - 아키텍처 개요

## 🎯 프로젝트 개요

리뷰어와 광고주를 연결하는 리뷰 캠페인 플랫폼입니다.

---

## 📊 데이터베이스 스키마 (Supabase PostgreSQL)

### 핵심 테이블 구조

#### 1. **users** - 사용자 프로필
```sql
- id: uuid (PK, auth.users 연동)
- display_name: text
- user_type: text (REVIEWER, MANAGER, OWNER, ADMIN, user, admin)
- created_at, updated_at: timestamp
```

**역할:** 기본 사용자 정보, Supabase Auth와 연동

---

#### 2. **companies** - 회사 정보
```sql
- id: uuid (PK)
- name: text
- business_number: text
- contact_email: text
- contact_phone: text
- address: text
- representative_name: text ✅ 추가됨
- business_type: text ✅ 추가됨
- registration_file_url: text ✅ 추가됨
- created_by: uuid (FK → users.id)
- created_at, updated_at: timestamp
```

**역할:** 광고주 회사 정보 저장
**Flutter 사용:** `lib/services/company_service.dart`

---

#### 3. **company_users** - 사용자-회사 관계 (다대다)
```sql
- id: uuid (PK)
- company_id: uuid (FK → companies.id)
- user_id: uuid (FK → users.id)
- company_role: text (owner, manager)
- created_at: timestamp
```

**역할:** 한 회사에 여러 사용자가 속할 수 있음 (회사 소유주, 관리자 등)
**Flutter 사용:** `lib/services/company_service.dart`에서 자동 생성

---

#### 4. ~~**business_registrations**~~ - ❌ **삭제됨**
```sql
-- 이 테이블은 사용되지 않아 삭제되었습니다
-- 대신 companies 테이블에 모든 정보를 저장합니다
```

---

#### 4. **campaigns** - 캠페인 정보
```sql
- id: uuid (PK)
- title: text
- description: text
- company_id: uuid (FK → companies.id)
- product_name: text
- product_price, review_cost: integer
- platform: text
- max_participants, current_participants: integer
- status: text (active, inactive, completed, cancelled)
- start_date, end_date: timestamp
- product_image_url: text
- created_by: uuid (FK → users.id)
- campaign_type: text (reviewer, journalist, visit)
- review_reward: integer
- created_at, updated_at, last_used_at: timestamp
- usage_count: integer
```

**Flutter 사용:** `lib/services/campaign_service.dart`

---

#### 5. **campaign_logs** - 캠페인 참여 로그
```sql
- id: uuid (PK)
- campaign_id: uuid (FK → campaigns.id)
- user_id: uuid (FK → users.id)
- action: text (join, leave, complete, cancel)
- application_message: text
- status: text (pending, approved, rejected, completed, cancelled)
- created_at, updated_at: timestamp
```

**역할:** 리뷰어가 캠페인에 신청/참여한 기록
**Flutter 사용:** `lib/services/campaign_log_service.dart`, `campaign_application_service.dart`

---

#### 6. ~~**reviews**~~ - ❌ **삭제됨**
```sql
-- 이 테이블은 사용되지 않아 삭제되었습니다
-- 리뷰 데이터는 campaign_logs.data (JSONB) 컬럼에 저장됩니다
```

**리뷰 데이터 저장 위치:**
- `campaign_logs.data` JSONB 컬럼에 저장
- 리뷰 제목, 내용, 평점, URL 등 모든 정보가 JSON 형태로 저장됨

---

#### 7. ~~**reviews**~~ (데이터 없음) - 리뷰 정보는 `campaign_logs.data`에 저장

---

#### 8. **point_wallets** - 포인트 지갑
```sql
- id: uuid (PK)
- owner_type: text (USER, COMPANY)
- owner_id: uuid
- current_points: integer
- created_at, updated_at: timestamp
```

**역할:** 사용자 또는 회사의 포인트 보유량
**Flutter 사용:** `lib/services/point_service.dart`

---

#### 9. **point_logs** - 포인트 거래 로그
```sql
- id: uuid (PK)
- wallet_id: uuid (FK → point_wallets.id)
- transaction_type: text (earn, spend, refund, bonus, penalty)
- amount: integer
- description: text
- related_entity_type, related_entity_id: uuid
- created_at: timestamp
```

**Flutter 사용:** `lib/services/point_service.dart`

---

#### 10. **notifications** - 알림
```sql
- id: uuid (PK)
- user_id: uuid (FK → users.id)
- title, message: text
- type: text (campaign, review, point, system)
- is_read: boolean
- related_entity_type, related_entity_id: uuid
- created_at: timestamp
```

**Flutter 사용:** `lib/services/notification_service.dart`

---

#### 11. **deleted_users** - 삭제된 사용자 백업
```sql
- id: uuid (PK)
- email, display_name: text
- user_type: text
- company_id: uuid
- deletion_reason: text
- deleted_at, original_created_at: timestamp
```

**Flutter 사용:** `lib/services/account_deletion_service.dart`

---

## 🔄 Edge Functions (Supabase)

### 1. **extract-business-info**
**목적:** 사업자등록증 이미지에서 AI로 정보 추출
**입력:** base64 인코딩된 이미지
**출력:** JSON (business_name, business_number, representative_name 등)
**사용:** `business_registration_form.dart`의 `_callAIExtractionAPI()`

### 2. **upload-to-r2** ✅
**목적:** Cloudflare R2에 파일 업로드
**방식:** AWS Signature V4 사용하여 인증
**입력:** fileName, userId, contentType, fileType, fileData (base64)
**출력:** publicUrl
**사용:** `r2_upload_service.dart`의 `_uploadViaEdgeFunction()`

---

## 📱 Flutter 서비스 레이어

### `lib/services/` 디렉토리 구조

```
services/
├── auth_service.dart              # 인증 (로그인, 회원가입)
├── account_deletion_service.dart  # 계정 삭제
├── campaign_service.dart          # 캠페인 CRUD
├── campaign_application_service.dart # 캠페인 신청/관리
├── campaign_log_service.dart      # 캠페인 로그
├── company_service.dart           # 회사 정보 관리 ✅ 개선됨
├── r2_upload_service.dart         # R2 파일 업로드 ✅ 수정됨
├── official_business_number_validation_service.dart # 사업자번호 검증
├── point_service.dart             # 포인트 관리
├── review_service.dart            # 리뷰 관리
└── notification_service.dart      # 알림
```

---

## 🚨 **현재 문제점 (스파게티 코드)**

### 1. **데이터 구조 불일치** ✅ **해결됨**

#### 이전 문제:
```dart
// companies 테이블에 필드 누락
{
  'name': '포인터스',
  'business_number': '867-70-00726',
  'address': '충청남도...',
  // representative_name 없음! ❌
  // business_type 없음! ❌
}
```

#### 해결 완료:
```sql
-- companies 테이블에 필드 추가 완료
ALTER TABLE companies 
ADD COLUMN representative_name text,
ADD COLUMN business_type text,
ADD COLUMN registration_file_url text;
```

**변경사항:**
- ✅ companies 테이블에 `representative_name`, `business_type`, `registration_file_url` 추가
- ✅ `company_service.dart`에서 모든 필드 저장하도록 수정
- ✅ 데이터 손실 없음

---

### 2. **business_registrations 테이블** ✅ **삭제됨**

**변경 사항:**
- ✅ `business_registrations` 테이블 삭제
- ✅ `business_registration_service.dart` 삭제
- ✅ `get-presigned-url` Edge Function 삭제
- ✅ 모든 정보는 `companies` 테이블에 직접 저장

**현재 플로우:**
```
사업자등록증 업로드
  ↓
AI 정보 추출 (representative_name, business_type 포함)
  ↓
R2 업로드 (registration_file_url 생성)
  ↓
companies 테이블에 저장 ✅ 모든 필드 포함
  ↓
company_users 테이블에 관계 추가
```

---

### 3. **company_service.dart 중복 로직** ✅ **개선됨**

```dart
// saveCompanyInfo 함수 내부
if (existingCompany != null) {
  // 업데이트
  await supabase.from(_tableName).update({...})
} else {
  // 새 회사 생성
  await supabase.from(_tableName).insert({...})
  
  // company_users 관계 추가
  await supabase.from('company_users').insert({...})
}
```

**문제:** `business_registration_form.dart`에서 이미 트랜잭션 로직이 있음 (중복)

---

### 4. **R2 업로드 플로우 복잡성**

현재 플로우 (수정 전):
```
Flutter (R2UploadService)
  ↓
get-presigned-url Edge Function
  ↓ presigned URL 생성
Flutter가 직접 R2 업로드
  ↓ AWS Signature 문제로 실패
```

현재 플로우 (수정 후) ✅:
```
Flutter (R2UploadService)
  ↓ base64 인코딩
upload-to-r2 Edge Function
  ↓ AWS Signature V4 생성
Cloudflare R2 업로드 성공
```

**개선사항:** Edge Function에서 모든 인증 처리 → 더 안정적

---

## 💡 **리팩토링 권장사항**

### 1. **business_registrations 테이블 활용**

```dart
// 추천 구조
1. business_registrations 테이블에 먼저 저장
   - 모든 필드 포함 (representative_name, business_type)
   - status: 'pending'
   
2. 관리자가 승인하면
   - status: 'approved'
   - companies 테이블에 최종 저장
   
3. 비동기 승인 플로우
```

---

### 2. **company_service.dart 단순화**

```dart
// 현재: 너무 많은 책임
class CompanyService {
  - companies 테이블 CRUD
  - company_users 관계 관리
  - 중복 검사
  - 트랜잭션 관리
}

// 권장: 단일 책임 원칙
class CompanyService {
  - companies 테이블만 CRUD
}

class CompanyUserService {
  - company_users 관계만 관리
}

class BusinessRegistrationService {
  - business_registrations 승인 플로우
}
```

---

### 3. **테이블 스키마 보완**

```sql
-- companies 테이블에 누락된 필드 추가
ALTER TABLE companies ADD COLUMN IF NOT EXISTS
  representative_name text,
  business_type text,
  registration_file_url text;

-- 또는 별도 테이블로 관리
CREATE TABLE company_details (
  id uuid PRIMARY KEY,
  company_id uuid REFERENCES companies(id),
  representative_name text,
  business_type text,
  registration_file_url text,
  created_at timestamp DEFAULT now()
);
```

---

### 4. **데이터 검증 계층 추가**

현재: Flutter에서만 검증  
권장: Database Trigger + Flutter Validation

```sql
-- 사업자번호 중복 체크
CREATE OR REPLACE FUNCTION check_unique_business_number()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM companies 
    WHERE business_number = NEW.business_number 
    AND id != NEW.id
  ) THEN
    RAISE EXCEPTION 'Business number already exists';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## 🔄 **현재 데이터 흐름 (사업자등록증 업로드)**

```
1. 사용자가 사업자등록증 이미지 선택
   ↓
2. business_registration_form.dart
   ↓
3. R2UploadService.uploadBusinessRegistration()
   ↓ base64 인코딩
4. upload-to-r2 Edge Function
   ↓ AWS Signature V4 생성
5. Cloudflare R2 업로드 성공 ✅
   ↓
6. CompanyService.saveCompanyInfo()
   ↓
7. companies 테이블에 저장 ✅ 모든 필드 포함
   - name, business_number, address
   - representative_name ✅
   - business_type ✅
   - registration_file_url ✅
   ↓
8. company_users 테이블에 관계 추가
```

**개선사항:**
- ✅ representative_name, business_type 저장됨
- ✅ registration_file_url 저장됨
- ✅ 데이터 손실 없음

---

## 📈 **데이터 관계도**

```
users (사용자)
  ↓
  ├→ company_users (다대다)
  ↓
companies (회사)
  ↓
  ├→ campaigns (캠페인)
      ↓
      └→ campaign_logs (참여 로그 + 리뷰 데이터)

users
  ↓
point_wallets (포인트 지갑)
  ↓
  └→ point_logs (거래 내역)

users
  ↓
  └→ notifications (알림)

users
  ↓
  └→ companies (회사 정보, 모든 필드 포함) ✅
```

---

## ✅ **완료된 개선 항목**

### ✅ 완료 1: companies 테이블 스키마 보완
```sql
-- 마이그레이션 완료
ALTER TABLE companies 
ADD COLUMN representative_name text,
ADD COLUMN business_type text,
ADD COLUMN registration_file_url text;
```

### ✅ 완료 2: company_service.dart 개선
```dart
// 모든 필드를 저장하도록 수정됨
static Future<void> saveCompanyInfo({
  required String representativeName,
  required String businessType,
  required String registrationFileUrl,
  // ...
}) async {
  final data = {
    'name': businessName,
    'representative_name': representativeName,
    'business_type': businessType,
    'registration_file_url': registrationFileUrl,
    // ...
  };
  await supabase.from(_tableName).insert(data);
}
```

### ✅ 완료 3: 미사용 코드 삭제
- ❌ `business_registrations` 테이블 삭제
- ❌ `business_registration_service.dart` 삭제
- ❌ `get-presigned-url` Edge Function 삭제
- ❌ Deprecated 코드 제거 (`r2_upload_service.dart`)

---

## 📝 **결론**

**현재 상태:**
- ✅ R2 업로드: 정상 작동
- ✅ AI 정보 추출: 정상 작동
- ✅ 데이터 저장: 모든 필드 정상 저장
- ✅ business_registrations 테이블: 삭제됨 (사용하지 않음)
- ✅ 코드 정리: 미사용 파일 삭제 완료

**완료된 개선 사항:**
1. ✅ companies 테이블 스키마 보완 (representative_name, business_type, registration_file_url 추가)
2. ✅ company_service.dart 개선 (모든 필드 저장)
3. ✅ 미사용 테이블 삭제 (business_registrations, reviews)
4. ✅ 미사용 Edge Function 삭제 (get-presigned-url)
5. ✅ deprecated 코드 제거 (r2_upload_service.dart)

**시스템 안정성:**
- ✅ 데이터 손실 없음
- ✅ 코드 단순화 완료
- ✅ 유지보수성 향상

