# 캠페인 생성 프로세스 개선 작업 목록

**작성일**: 2024년 12월  
**버전**: 1.0  
**목적**: 캠페인 생성 프로세스 개선을 위한 진행 가능한 작업 목록

---

## 📋 목차

1. [개요](#개요)
2. [작업 목록](#작업-목록)
3. [상세 구현 가이드](#상세-구현-가이드)
4. [참고사항](#참고사항)

---

## 개요

이 문서는 캠페인 생성 프로세스 개선을 위해 진행 가능한 작업들을 정리한 것입니다. 이미 완료된 항목(캠페인 생성 후 목록 반영 등)은 제외하고, 실제로 구현이 필요한 항목만 포함했습니다.

### 작업 우선순위

- **높음**: 로그 관리 개선, 신청 제한 기능 구현, 데이터 무결성 강화
- **중간**: 에러 처리 개선
- **낮음**: 성능 최적화, 모니터링 및 알림

---

## 작업 목록

### 1. 로그 관리 개선 ⭐ 우선순위: 높음

#### 1.1 `campaign_logs` 테이블 생성

**목적**: 캠페인 생성, 수정, 삭제 등의 모든 액션을 추적하기 위한 로그 테이블

**작업 내용**:
- [ ] `campaign_logs` 테이블 생성 (마이그레이션 파일)
- [ ] 인덱스 생성
- [ ] RLS 정책 설정
- [ ] 테이블 코멘트 추가

**예상 소요 시간**: 1-2시간

#### 1.2 RPC 함수에 로그 기록 로직 추가

**목적**: 캠페인 생성 성공/실패 시 자동으로 로그 기록

**작업 내용**:
- [ ] `create_campaign_with_points_v2` 함수에 성공 로그 기록 추가
- [ ] `create_campaign_with_points_v2` 함수에 실패 로그 기록 추가 (EXCEPTION 핸들러)

**예상 소요 시간**: 1-2시간

#### 1.3 생성 실패 시 상세 에러 로그 기록

**목적**: 캠페인 생성 실패 원인을 추적하기 위한 상세 로그

**작업 내용**:
- [ ] 에러 메시지 기록
- [ ] 실패 시점의 상태 정보 기록
- [ ] 포인트 잔액 정보 기록 (실패 시에도)

**예상 소요 시간**: 1시간

---

### 2. 신청 제한 기능 구현 ⭐ 우선순위: 높음

#### 2.1 데이터베이스 스키마 변경

**목적**: 리뷰어당 신청 가능 개수를 저장할 컬럼 추가

**작업 내용**:
- [ ] `campaigns` 테이블에 `max_per_reviewer` 컬럼 추가 (INTEGER, DEFAULT 1, NOT NULL)
- [ ] 제약 조건 추가: `max_per_reviewer >= 1`
- [ ] 컬럼 코멘트 추가

**마이그레이션 예시**:
```sql
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS max_per_reviewer INTEGER DEFAULT 1 NOT NULL;

ALTER TABLE public.campaigns
ADD CONSTRAINT campaigns_max_per_reviewer_check 
CHECK (max_per_reviewer >= 1);

COMMENT ON COLUMN public.campaigns.max_per_reviewer IS 
'리뷰어당 신청 가능 개수 (한 리뷰어가 해당 캠페인에 신청할 수 있는 최대 횟수)';
```

**예상 소요 시간**: 30분

#### 2.2 RPC 함수 수정

**목적**: 캠페인 생성 시 `max_per_reviewer` 값을 받아서 저장

**작업 내용**:
- [ ] `create_campaign_with_points_v2` 함수에 `p_max_per_reviewer` 파라미터 추가
- [ ] INSERT 문에 `max_per_reviewer` 컬럼 추가
- [ ] 기본값 처리 (NULL인 경우 1로 설정)

**파라미터 추가 예시**:
```sql
CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points_v2"(
    -- ... 기존 파라미터들 ...
    "p_max_per_reviewer" integer DEFAULT 1
) RETURNS "jsonb"
```

**INSERT 수정 예시**:
```sql
INSERT INTO public.campaigns (
    -- ... 기존 컬럼들 ...
    max_per_reviewer,
    -- ... 기타 컬럼들 ...
) VALUES (
    -- ... 기존 값들 ...
    COALESCE(p_max_per_reviewer, 1),
    -- ... 기타 값들 ...
);
```

**예상 소요 시간**: 1시간

#### 2.3 Flutter 서비스 레이어 수정

**목적**: RPC 함수 호출 시 `max_per_reviewer` 파라미터 전달

**작업 내용**:
- [ ] `lib/services/campaign_service.dart`의 `createCampaignV2` 메서드에 `maxPerReviewer` 파라미터 추가
- [ ] RPC 호출 시 `p_max_per_reviewer` 파라미터 추가

**예상 소요 시간**: 30분

#### 2.4 Flutter UI 수정

**목적**: 사용자가 리뷰어당 신청 가능 개수를 입력할 수 있도록 UI 추가

**작업 내용**:
- [ ] `lib/screens/campaign/campaign_creation_screen.dart`에 입력 필드 추가
- [ ] 기본값 1로 설정
- [ ] 유효성 검증 추가 (1 이상)
- [ ] 비용 계산에 영향 없음 (참고용)

**예상 소요 시간**: 1-2시간

#### 2.5 캠페인 신청 로직 구현

**목적**: 캠페인 신청 시 `max_per_reviewer` 제한 확인

**작업 내용**:
- [ ] 캠페인 신청 RPC 함수에서 `max_per_reviewer` 확인 로직 추가
- [ ] 현재 신청 횟수 조회
- [ ] 제한 초과 시 에러 메시지 반환
- [ ] 에러 메시지: "이 캠페인에는 최대 N회까지 신청할 수 있습니다."

**예상 소요 시간**: 2-3시간

---

### 3. 데이터 무결성 강화 ⭐ 우선순위: 높음

#### 3.1 제약 조건 추가

**목적**: 데이터베이스 레벨에서 데이터 무결성 보장

**작업 내용**:
- [ ] `max_per_reviewer >= 1` 제약 조건 추가 (2.1에서 함께 진행)
- [ ] 기존 데이터 검증 (기존 캠페인의 `max_per_reviewer`가 NULL이거나 0인 경우 업데이트)

**예상 소요 시간**: 30분

---

### 4. 에러 처리 개선 ⚠️ 우선순위: 중간

#### 4.1 구체적인 에러 코드 정의

**목적**: 에러 타입별로 구체적인 코드를 정의하여 클라이언트에서 처리 가능하도록

**작업 내용**:
- [ ] 에러 코드 체계 정의
  - `UNAUTHORIZED`: 인증 실패
  - `NO_COMPANY`: 회사 소속 없음
  - `NO_WALLET`: 지갑 없음
  - `INSUFFICIENT_POINTS`: 포인트 부족
  - `POINT_DEDUCTION_FAILED`: 포인트 차감 실패
  - `INVALID_PARAMETERS`: 잘못된 파라미터
- [ ] RPC 함수에서 에러 코드 반환하도록 수정

**예상 소요 시간**: 2-3시간

#### 4.2 에러 메시지 사용자 친화적 개선

**목적**: 사용자가 이해하기 쉬운 에러 메시지 제공

**작업 내용**:
- [ ] 기술적 에러 메시지를 사용자 친화적 메시지로 변환
- [ ] Flutter에서 에러 코드에 따라 적절한 메시지 표시
- [ ] 다국어 지원 고려 (선택)

**예상 소요 시간**: 1-2시간

---

### 5. 선택적 개선사항 (우선순위: 낮음)

#### 5.1 로그 조회 API 추가

**목적**: 관리자가 캠페인 생성 로그를 조회할 수 있도록

**작업 내용**:
- [ ] RPC 함수 `get_campaign_logs_safe` 생성
- [ ] 회사별, 사용자별, 캠페인별 필터링 지원
- [ ] 페이지네이션 지원

**예상 소요 시간**: 2-3시간

#### 5.2 로그 분석 대시보드

**목적**: 캠페인 생성 통계 및 분석

**작업 내용**:
- [ ] 일별/월별 생성 통계
- [ ] 생성 실패율 분석
- [ ] 생성 소요 시간 추적

**예상 소요 시간**: 4-6시간

---

## 상세 구현 가이드

### 1. `campaign_logs` 테이블 생성

#### 테이블 구조

```sql
CREATE TABLE IF NOT EXISTS public.campaign_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID,  -- NULL 가능 (생성 실패 시)
    company_id UUID NOT NULL,
    user_id UUID NOT NULL,  -- 생성자
    
    -- 로그 타입
    log_type TEXT NOT NULL,  -- 'creation', 'update', 'status_change', 'deletion'
    action TEXT NOT NULL,  -- 'create', 'update', 'activate', 'deactivate', 'delete'
    
    -- 이전/이후 값 (JSONB)
    previous_data JSONB,  -- 변경 전 데이터
    new_data JSONB,  -- 변경 후 데이터
    
    -- 결과
    status TEXT NOT NULL,  -- 'success', 'failed', 'pending'
    error_message TEXT,  -- 실패 시 에러 메시지
    
    -- 메타데이터
    ip_address TEXT,
    user_agent TEXT,
    request_id UUID,  -- 요청 추적용
    
    -- 비용 정보
    points_spent INTEGER,
    points_before INTEGER,
    points_after INTEGER,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- 제약 조건
    CONSTRAINT campaign_logs_log_type_check CHECK (
        log_type IN ('creation', 'update', 'status_change', 'deletion')
    ),
    CONSTRAINT campaign_logs_action_check CHECK (
        action IN ('create', 'update', 'activate', 'deactivate', 'delete', 'cancel')
    ),
    CONSTRAINT campaign_logs_status_check CHECK (
        status IN ('success', 'failed', 'pending')
    ),
    
    -- 외래 키
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### 인덱스

```sql
-- 빠른 조회를 위한 인덱스
CREATE INDEX idx_campaign_logs_campaign_id ON campaign_logs(campaign_id);
CREATE INDEX idx_campaign_logs_company_id ON campaign_logs(company_id);
CREATE INDEX idx_campaign_logs_user_id ON campaign_logs(user_id);
CREATE INDEX idx_campaign_logs_log_type ON campaign_logs(log_type);
CREATE INDEX idx_campaign_logs_status ON campaign_logs(status);
CREATE INDEX idx_campaign_logs_created_at ON campaign_logs(created_at DESC);
CREATE INDEX idx_campaign_logs_company_created ON campaign_logs(company_id, created_at DESC);
```

#### RLS 정책

```sql
-- RLS 활성화
ALTER TABLE campaign_logs ENABLE ROW LEVEL SECURITY;

-- 회사 멤버는 자신의 회사 로그 조회 가능
CREATE POLICY "Company members can view their company campaign logs"
ON campaign_logs FOR SELECT
USING (
    company_id IN (
        SELECT company_id FROM company_users
        WHERE user_id = auth.uid() AND status = 'active'
    )
);

-- 시스템만 INSERT 가능 (RPC 함수에서)
CREATE POLICY "System can insert campaign logs"
ON campaign_logs FOR INSERT
WITH CHECK (true);  -- RPC 함수에서만 사용
```

#### RPC 함수 수정 예시

```sql
-- 캠페인 생성 성공 후 로그 기록
INSERT INTO public.campaign_logs (
    campaign_id, company_id, user_id,
    log_type, action, status,
    new_data, points_spent, points_before, points_after,
    created_at
) VALUES (
    v_campaign_id, v_company_id, v_user_id,
    'creation', 'create', 'success',
    jsonb_build_object(
        'title', p_title,
        'campaign_type', p_campaign_type,
        'total_cost', v_total_cost,
        'max_participants', p_max_participants,
        'max_per_reviewer', COALESCE(p_max_per_reviewer, 1)
    ),
    v_total_cost, v_points_before_deduction, v_points_after_deduction,
    NOW()
);

-- 실패 시에도 로그 기록
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO public.campaign_logs (
            company_id, user_id,
            log_type, action, status,
            error_message, points_spent, points_before,
            created_at
        ) VALUES (
            v_company_id, v_user_id,
            'creation', 'create', 'failed',
            SQLERRM, v_total_cost, v_points_before_deduction,
            NOW()
        );
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
```

### 2. `max_per_reviewer` 기능 구현

#### 마이그레이션 파일 예시

```sql
-- campaigns 테이블에 max_per_reviewer 컬럼 추가
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS max_per_reviewer INTEGER DEFAULT 1 NOT NULL;

-- 제약 조건 추가
ALTER TABLE public.campaigns
ADD CONSTRAINT campaigns_max_per_reviewer_check 
CHECK (max_per_reviewer >= 1);

-- 컬럼 코멘트 추가
COMMENT ON COLUMN public.campaigns.max_per_reviewer IS 
'리뷰어당 신청 가능 개수 (한 리뷰어가 해당 캠페인에 신청할 수 있는 최대 횟수)';

-- 기존 데이터 업데이트 (NULL 또는 0인 경우)
UPDATE public.campaigns 
SET max_per_reviewer = 1 
WHERE max_per_reviewer IS NULL OR max_per_reviewer < 1;
```

#### RPC 함수 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points_v2"(
    "p_title" "text",
    "p_description" "text",
    "p_campaign_type" "text",
    "p_campaign_reward" integer,
    "p_max_participants" integer,
    "p_start_date" timestamp with time zone,
    "p_end_date" timestamp with time zone,
    "p_platform" "text" DEFAULT NULL::"text",
    "p_keyword" "text" DEFAULT NULL::"text",
    "p_option" "text" DEFAULT NULL::"text",
    "p_quantity" integer DEFAULT 1,
    "p_seller" "text" DEFAULT NULL::"text",
    "p_product_number" "text" DEFAULT NULL::"text",
    "p_product_image_url" "text" DEFAULT NULL::"text",
    "p_product_name" "text" DEFAULT NULL::"text",
    "p_product_price" integer DEFAULT NULL::integer,
    "p_purchase_method" "text" DEFAULT 'mobile'::"text",
    "p_product_description" "text" DEFAULT NULL::"text",
    "p_review_type" "text" DEFAULT 'star_only'::"text",
    "p_review_text_length" integer DEFAULT NULL::integer,
    "p_review_image_count" integer DEFAULT NULL::integer,
    "p_prevent_product_duplicate" boolean DEFAULT false,
    "p_prevent_store_duplicate" boolean DEFAULT false,
    "p_duplicate_prevent_days" integer DEFAULT 0,
    "p_payment_method" "text" DEFAULT 'platform'::"text",
    "p_expiration_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
    "p_max_per_reviewer" integer DEFAULT 1  -- ✅ 추가
) RETURNS "jsonb"
```

#### INSERT 문 수정

```sql
INSERT INTO public.campaigns (
    title, description, company_id, user_id,
    campaign_type, platform,
    keyword, option, quantity, seller, product_number,
    product_image_url, product_name, product_price,
    purchase_method,
    review_type, review_text_length, review_image_count,
    campaign_reward, max_participants, current_participants,
    max_per_reviewer,  -- ✅ 추가
    start_date, end_date, expiration_date,
    prevent_product_duplicate, prevent_store_duplicate, duplicate_prevent_days,
    payment_method, total_cost,
    status, created_at, updated_at
) VALUES (
    p_title, p_description, v_company_id, v_user_id,
    p_campaign_type, p_platform,
    p_keyword, p_option, p_quantity, p_seller, p_product_number,
    p_product_image_url, p_product_name, p_product_price,
    p_purchase_method,
    p_review_type, p_review_text_length, p_review_image_count,
    p_campaign_reward, p_max_participants, 0,
    COALESCE(p_max_per_reviewer, 1),  -- ✅ 추가 (기본값: 1)
    p_start_date, p_end_date, 
    COALESCE(p_expiration_date, p_end_date + INTERVAL '30 days'),
    p_prevent_product_duplicate, p_prevent_store_duplicate, p_duplicate_prevent_days,
    p_payment_method, v_total_cost,
    'active', NOW(), NOW()
) RETURNING id INTO v_campaign_id;
```

#### Flutter 서비스 수정 예시

```dart
// lib/services/campaign_service.dart
Future<ApiResponse<Campaign>> createCampaignV2({
  required String title,
  required String description,
  required String campaignType,
  required String platform,
  required int campaignReward,
  required int maxParticipants,
  required int maxPerReviewer,  // ✅ 추가
  required DateTime startDate,
  required DateTime endDate,
  required DateTime expirationDate,
  // ... 기타 파라미터
}) async {
  // ...
  final response = await _supabase.rpc(
    'create_campaign_with_points_v2',
    params: {
      // ... 기존 파라미터들 ...
      'p_max_per_reviewer': maxPerReviewer,  // ✅ 추가
    },
  );
  // ...
}
```

#### Flutter UI 수정 예시

```dart
// lib/screens/campaign/campaign_creation_screen.dart
final _maxPerReviewerController = TextEditingController(text: '1');

// 유효성 검증
String? _validateMaxPerReviewer(String? value) {
  if (value == null || value.isEmpty) {
    return '리뷰어당 신청 가능 개수를 입력해주세요';
  }
  final count = int.tryParse(value);
  if (count == null || count < 1) {
    return '1 이상의 숫자를 입력해주세요';
  }
  return null;
}

// UI 위젯
TextFormField(
  controller: _maxPerReviewerController,
  decoration: InputDecoration(
    labelText: '리뷰어당 신청 가능 개수',
    hintText: '1',
    helperText: '한 리뷰어가 이 캠페인에 신청할 수 있는 최대 횟수',
  ),
  keyboardType: TextInputType.number,
  validator: _validateMaxPerReviewer,
)
```

---

## 참고사항

### 이미 완료된 항목

다음 항목들은 이미 구현되어 있어 이 문서에 포함하지 않았습니다:

1. **캠페인 생성 후 목록 반영 문제**
   - `advertiser_my_campaigns_screen.dart`에서 Campaign 객체를 직접 받아 추가하는 로직 구현됨
   - 폴링 fallback도 구현됨

### 작업 순서 권장사항

1. **1단계**: `campaign_logs` 테이블 생성 및 RPC 함수 수정
   - 로그 기록 인프라를 먼저 구축하여 이후 작업 추적 가능

2. **2단계**: `max_per_reviewer` 기능 구현
   - 데이터베이스 스키마 변경 → RPC 함수 수정 → Flutter 서비스 수정 → UI 수정 → 신청 로직 구현 순서로 진행

3. **3단계**: 에러 처리 개선 (선택)
   - 로그 시스템이 구축된 후 에러 추적이 용이해짐

### 마이그레이션 파일 명명 규칙

새 마이그레이션 파일은 다음 형식을 따릅니다:
```
supabase/migrations/YYYYMMDDHHMMSS_description.sql
```

예시:
- `20241225120000_add_campaign_logs_table.sql`
- `20241225120100_add_max_per_reviewer_to_campaigns.sql`
- `20241225120200_update_create_campaign_rpc_with_logging.sql`

### 테스트 체크리스트

각 작업 완료 후 다음을 테스트해야 합니다:

- [ ] 마이그레이션 파일이 정상적으로 적용되는지 확인
- [ ] RPC 함수가 정상적으로 동작하는지 확인
- [ ] Flutter 앱에서 정상적으로 동작하는지 확인
- [ ] 에러 케이스 처리 확인
- [ ] RLS 정책이 정상적으로 동작하는지 확인

---

**문서 작성자**: AI Assistant  
**최종 수정일**: 2024년 12월  
**다음 검토 예정일**: 작업 완료 후

