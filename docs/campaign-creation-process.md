# 캠페인 생성 프로세스 상세 문서

**작성일**: 2024년 12월  
**버전**: 1.0  
**목적**: 캠페인 생성 프로세스의 전체 플로우, 데이터베이스 구조, 로그 관리 방안을 정리

---

## 📋 목차

1. [개요](#개요)
2. [현재 캠페인 생성 프로세스](#현재-캠페인-생성-프로세스)
3. [데이터베이스 스키마](#데이터베이스-스키마)
4. [로그 관리 현황 및 개선 방안](#로그-관리-현황-및-개선-방안)
5. [필요한 개선사항](#필요한-개선사항)
6. [API 및 RPC 함수](#api-및-rpc-함수)

---

## 개요

캠페인 생성은 광고주(advertiser)가 리뷰어를 모집하기 위해 캠페인을 등록하는 프로세스입니다. 이 프로세스는 포인트 차감, 캠페인 데이터 저장, 로그 기록 등 여러 단계로 구성되어 있습니다.

### 주요 특징

- **원자적 처리**: RPC 함수를 통해 포인트 차감과 캠페인 생성을 트랜잭션으로 처리
- **비용 계산**: 제품 가격, 리뷰어 보상, 모집 인원에 따라 자동 계산
- **권한 검증**: 회사 소속 및 권한 확인
- **포인트 검증**: 잔액 확인 및 차감

---

## 현재 캠페인 생성 프로세스

### 1. UI 단계 (Frontend)

**파일**: `lib/screens/campaign/campaign_creation_screen.dart`

#### 1.1 사용자 입력 수집

사용자가 다음 정보를 입력합니다:

- **기본 정보**
  - 제품명 (`product_name`)
  - 제품 이미지 (`product_image_url`)
  - 제품 가격 (`product_price`)
  - 캠페인 타입 (`campaign_type`: reviewer/journalist/visit)
  - 플랫폼 (`platform`: coupang/naver/11st 등)

- **캠페인 설정**
  - 모집 인원 (`max_participants`)
  - 리뷰어 보상 (`campaign_reward`)
  - 리뷰어당 신청 가능 개수 (`max_per_reviewer`) - 한 리뷰어가 해당 캠페인에 신청할 수 있는 최대 횟수
  - 시작일 (`start_date`)
  - 종료일 (`end_date`)
  - 만료일 (`expiration_date`)

- **제품 정보**
  - 검색 키워드 (`keyword`)
  - 제품 옵션 (`option`)
  - 구매 개수 (`quantity`)
  - 판매자명 (`seller`)
  - 상품번호 (`product_number`)

- **리뷰 요구사항**
  - 리뷰 타입 (`review_type`: star_only/star_text/star_text_image)
  - 텍스트 리뷰 길이 (`review_text_length`)
  - 이미지 리뷰 개수 (`review_image_count`)

- **중복 방지 설정**
  - 상품 중복 금지 (`prevent_product_duplicate`) - 동일한 제품명(title)에 대한 중복 참여 방지
  - 스토어 중복 금지 (`prevent_store_duplicate`) - 업계 용어로 "스토어 중복(스중)"이라고 불리며, 실제로는 판매자(`seller`) 필드를 비교하여 동일한 판매자에 대한 중복 참여를 방지합니다.
  - 중복 금지 기간 (`duplicate_prevent_days`)

- **신청 제한 설정**
  - 리뷰어당 신청 가능 개수 (`max_per_reviewer`) - 한 리뷰어가 해당 캠페인에 신청할 수 있는 최대 횟수 (기본값: 1)

- **결제 설정**
  - 지급 방법 (`payment_method`: platform/direct)
  - 구매 방법 (`purchase_method`: mobile/pc)

#### 1.2 비용 계산

실시간으로 총 비용을 계산합니다:

```dart
// 비용 계산 로직
_totalCost = calculateCampaignCost(
  paymentMethod: _paymentType,
  productPrice: productPrice,
  campaignReward: campaignReward,
  maxParticipants: maxParticipants,
);
```

#### 1.3 유효성 검증

- 필수 필드 확인
- 날짜 유효성 검증 (시작일 < 종료일 < 만료일)
- 포인트 잔액 확인
- 이미지 업로드 (선택)

#### 1.4 API 호출

```dart
final response = await _campaignService.createCampaignV2(
  title: _productNameController.text.trim(),
  description: '',
  campaignType: _campaignType,
  platform: _platform,
  campaignReward: int.tryParse(_campaignRewardController.text) ?? 0,
  maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 10,
  maxPerReviewer: int.tryParse(_maxPerReviewerController.text) ?? 1,
  startDate: _startDateTime!,
  endDate: _endDateTime!,
  expirationDate: _expirationDateTime!,
  // ... 기타 파라미터
);
```

### 2. 서비스 레이어 (Service Layer)

**파일**: `lib/services/campaign_service.dart`

#### 2.1 `createCampaignV2()` 메서드

```dart
Future<ApiResponse<Campaign>> createCampaignV2({
  required String title,
  required String description,
  required String campaignType,
  required String platform,
  required int campaignReward,
  required int maxParticipants,
  required int maxPerReviewer,  // 리뷰어당 신청 가능 개수
  required DateTime startDate,
  required DateTime endDate,
  required DateTime expirationDate,
  // ... 기타 파라미터
}) async {
  // 1. 사용자 인증 확인
  // 2. RPC 함수 호출
  // 3. 결과 처리
}
```

### 3. 데이터베이스 단계 (Backend)

**RPC 함수**: `create_campaign_with_points_v2`

#### 3.1 프로세스 플로우

```
1. 사용자 인증 확인
   ↓
2. 회사 소속 확인 (company_users 테이블)
   ↓
3. 총 비용 계산 (calculate_campaign_cost 함수)
   ↓
4. 회사 지갑 조회 및 잠금 (FOR UPDATE NOWAIT)
   ↓
5. 잔액 확인
   ↓
6. 캠페인 생성 (campaigns 테이블 INSERT)
   ↓
7. 포인트 거래 기록 (point_transactions 테이블 INSERT)
   ↓
8. 지갑 잔액 업데이트 (트리거 자동 처리)
   ↓
9. 결과 반환
```

#### 3.2 상세 단계

**Step 1: 사용자 인증**
```sql
v_user_id := (SELECT auth.uid());
IF v_user_id IS NULL THEN
  RAISE EXCEPTION 'Unauthorized';
END IF;
```

**Step 2: 회사 소속 확인**
```sql
SELECT cu.company_id INTO v_company_id
FROM public.company_users cu
WHERE cu.user_id = v_user_id
  AND cu.status = 'active'
  AND cu.company_role IN ('owner', 'manager')
LIMIT 1;
```

**Step 3: 총 비용 계산**
```sql
v_total_cost := public.calculate_campaign_cost(
  p_payment_method,
  COALESCE(p_product_price, 0),
  p_campaign_reward,
  p_max_participants
);
```

**Step 4: 지갑 조회 및 잠금**
```sql
SELECT cw.id, cw.current_points 
INTO v_wallet_id, v_current_points
FROM public.wallets AS cw
WHERE cw.company_id = v_company_id
  AND cw.user_id IS NULL
FOR UPDATE NOWAIT;
```

**Step 5: 잔액 확인**
```sql
IF v_current_points < v_total_cost THEN
  RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
    v_total_cost, v_current_points;
END IF;
```

**Step 6: 캠페인 생성**
```sql
INSERT INTO public.campaigns (
  title, description, company_id, user_id,
  campaign_type, platform,
  keyword, option, quantity, seller, product_number,
  product_image_url, product_name, product_price,
  purchase_method,
  review_type, review_text_length, review_image_count,
  campaign_reward, max_participants, current_participants,
  max_per_reviewer,  -- 리뷰어당 신청 가능 개수
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
  COALESCE(p_max_per_reviewer, 1),  -- 기본값: 1
  p_start_date, p_end_date, 
  COALESCE(p_expiration_date, p_end_date + INTERVAL '30 days'),
  p_prevent_product_duplicate, p_prevent_store_duplicate, p_duplicate_prevent_days,
  p_payment_method, v_total_cost,
  'active', NOW(), NOW()
) RETURNING id INTO v_campaign_id;
```

**Step 7: 포인트 거래 기록**
```sql
INSERT INTO public.point_transactions (
  wallet_id, transaction_type, amount,
  campaign_id, description,
  created_by_user_id, created_at
) VALUES (
  v_wallet_id, 'spend', -v_total_cost,
  v_campaign_id, '캠페인 생성: ' || p_title,
  v_user_id, NOW()
);
```

**Step 8: 잔액 검증**
```sql
SELECT current_points INTO v_points_after_deduction
FROM public.wallets
WHERE id = v_wallet_id;

IF v_points_after_deduction != (v_points_before_deduction - v_total_cost) THEN
  RAISE EXCEPTION '포인트 차감이 정확하지 않습니다.';
END IF;
```

---

## 데이터베이스 스키마

### 1. campaigns 테이블

**목적**: 캠페인 기본 정보 저장

```sql
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    company_id UUID NOT NULL,
    user_id UUID,  -- 생성자
    product_name TEXT,
    product_price INTEGER,
    platform TEXT,
    campaign_type TEXT DEFAULT 'reviewer',
    max_participants INTEGER DEFAULT 100 NOT NULL,
    current_participants INTEGER DEFAULT 0 NOT NULL,
    completed_applicants_count INTEGER DEFAULT 0 NOT NULL,
    max_per_reviewer INTEGER DEFAULT 1 NOT NULL,  -- 리뷰어당 신청 가능 개수
    status TEXT DEFAULT 'active',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    expiration_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- 제품 정보
    product_image_url TEXT,
    keyword TEXT,
    option TEXT,
    quantity INTEGER DEFAULT 1,
    seller TEXT,
    product_number TEXT,
    purchase_method TEXT DEFAULT 'mobile',
    
    -- 리뷰 요구사항
    review_type TEXT DEFAULT 'star_only',
    review_text_length INTEGER DEFAULT 100,
    review_image_count INTEGER DEFAULT 0,
    
    -- 중복 방지
    prevent_product_duplicate BOOLEAN DEFAULT false,  -- 상품 중복 금지 (제품명 기준)
    prevent_store_duplicate BOOLEAN DEFAULT false,  -- 스토어 중복 금지 (업계 용어: "스중", 실제로는 seller 필드 비교)
    duplicate_prevent_days INTEGER DEFAULT 0,
    
    -- 결제 정보
    payment_method TEXT DEFAULT 'platform',
    campaign_reward INTEGER DEFAULT 0 NOT NULL,
    total_cost INTEGER DEFAULT 0 NOT NULL,
    
    -- 제약 조건
    CONSTRAINT campaigns_campaign_type_check CHECK (
        campaign_type IN ('reviewer', 'journalist', 'visit')
    ),
    CONSTRAINT campaigns_dates_check CHECK (
        start_date <= end_date AND end_date <= expiration_date
    ),
    CONSTRAINT campaigns_payment_method_check CHECK (
        payment_method IN ('platform', 'direct')
    ),
    CONSTRAINT campaigns_purchase_method_check CHECK (
        purchase_method IN ('mobile', 'pc')
    ),
    CONSTRAINT campaigns_review_type_check CHECK (
        review_type IN ('star_only', 'star_text', 'star_text_image')
    ),
    CONSTRAINT campaigns_status_check CHECK (
        status IN ('active', 'inactive')
    ),
    
    -- 외래 키
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
```

### 2. campaign_action_logs 테이블

**목적**: 캠페인 관련 사용자 액션 로그 (참여, 완료 등)

```sql
CREATE TABLE IF NOT EXISTS public.campaign_action_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    campaign_id UUID NOT NULL,
    user_id UUID NOT NULL,
    action JSONB NOT NULL,  -- 행동 정보
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    CONSTRAINT campaign_action_logs_status_check CHECK (
        status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')
    ),
    
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**인덱스**:
- `idx_campaign_action_logs_campaign_id`
- `idx_campaign_action_logs_user_id`
- `idx_campaign_action_logs_campaign_user`
- `idx_campaign_action_logs_status`
- `idx_campaign_action_logs_created_at`

### 3. campaign_actions 테이블

**목적**: 사용자의 캠페인별 현재 상태 요약 (빠른 조회용)

```sql
CREATE TABLE IF NOT EXISTS public.campaign_actions (
    campaign_id UUID NOT NULL,
    user_id UUID NOT NULL,
    current_action JSONB,
    last_updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    PRIMARY KEY (campaign_id, user_id),
    
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**트리거**: `sync_campaign_actions_on_event`
- `campaign_action_logs`에 새 이벤트가 INSERT될 때 자동으로 `campaign_actions`와 `campaigns.completed_applicants_count`를 동기화

### 4. point_transactions 테이블

**목적**: 포인트 거래 기록 (캠페인 생성 시 포인트 차감 기록)

```sql
CREATE TABLE IF NOT EXISTS public.point_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    wallet_id UUID NOT NULL,
    transaction_type TEXT NOT NULL,
    amount INTEGER NOT NULL,
    campaign_id UUID,
    description TEXT,
    created_by_user_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);
```

---

## 로그 관리 현황 및 개선 방안

### 현재 로그 관리 현황

#### ✅ 존재하는 로그 테이블

1. **campaign_action_logs**
   - **목적**: 사용자의 캠페인 참여/완료 액션 로그
   - **기록 시점**: 리뷰어가 캠페인에 참여하거나 완료할 때
   - **한계**: 캠페인 생성 자체에 대한 로그는 기록되지 않음

2. **point_transactions**
   - **목적**: 포인트 거래 기록
   - **기록 시점**: 캠페인 생성 시 포인트 차감 기록
   - **한계**: 캠페인 생성 실패나 변경 이력은 기록되지 않음

#### ❌ 부족한 부분

1. **캠페인 생성 로그**
   - 생성 성공/실패 기록 없음
   - 생성 시도 이력 없음
   - 생성 실패 원인 기록 없음

2. **캠페인 변경 이력**
   - 캠페인 수정 이력 없음
   - 상태 변경 이력 없음
   - 변경 전/후 값 비교 불가

3. **캠페인 생성 통계**
   - 일별/월별 생성 통계 추적 어려움
   - 생성 실패율 분석 불가
   - 생성 소요 시간 추적 불가

### 제안: campaign_logs 테이블 생성

#### 1. 테이블 구조

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

#### 2. 인덱스

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

#### 3. RLS 정책

```sql
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

#### 4. RPC 함수 수정

`create_campaign_with_points_v2` 함수에 로그 기록 추가:

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
        'max_participants', p_max_participants
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

### 추가 제안: campaign_creation_attempts 테이블

생성 시도 자체를 별도로 추적하고 싶다면:

```sql
CREATE TABLE IF NOT EXISTS public.campaign_creation_attempts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID NOT NULL,
    user_id UUID NOT NULL,
    
    -- 입력 데이터 (전체)
    input_data JSONB NOT NULL,
    
    -- 결과
    status TEXT NOT NULL,  -- 'success', 'failed', 'cancelled'
    campaign_id UUID,  -- 성공 시 생성된 캠페인 ID
    error_message TEXT,
    error_code TEXT,
    
    -- 성능 메트릭
    processing_time_ms INTEGER,  -- 처리 소요 시간 (밀리초)
    
    -- 메타데이터
    ip_address TEXT,
    user_agent TEXT,
    session_id TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL
);
```

---

## 필요한 개선사항

### 1. 로그 관리 개선

#### 우선순위: 높음

- [ ] `campaign_logs` 테이블 생성
- [ ] RPC 함수에 로그 기록 로직 추가
- [ ] 생성 실패 시 상세 에러 로그 기록
- [ ] 생성 성공 시 메타데이터 기록

#### 우선순위: 중간

- [ ] `campaign_creation_attempts` 테이블 생성 (선택)
- [ ] 로그 조회 API 추가
- [ ] 로그 분석 대시보드

### 2. 에러 처리 개선

#### 우선순위: 높음

- [ ] 구체적인 에러 코드 정의
- [ ] 에러 메시지 사용자 친화적 개선
- [ ] 에러 발생 시 롤백 보장

### 3. 성능 최적화

#### 우선순위: 중간

- [ ] 비용 계산 캐싱
- [ ] 이미지 업로드 최적화
- [ ] 대량 생성 시 배치 처리

### 4. 모니터링 및 알림

#### 우선순위: 낮음

- [ ] 생성 실패율 모니터링
- [ ] 생성 소요 시간 추적
- [ ] 이상 패턴 감지 알림

### 5. 데이터 무결성

#### 우선순위: 높음

- [ ] 트랜잭션 롤백 보장
- [ ] 동시성 제어 강화
- [ ] 데이터 검증 강화
- [ ] 리뷰어당 신청 가능 개수 제약 조건 추가 (1 이상)

### 6. 신청 제한 기능 구현

#### 우선순위: 높음

- [ ] `max_per_reviewer` 컬럼 추가 (campaigns 테이블)
- [ ] RPC 함수에 `p_max_per_reviewer` 파라미터 추가
- [ ] 캠페인 신청 시 신청 가능 개수 확인 로직 구현
- [ ] UI에 리뷰어당 신청 가능 개수 입력 필드 추가
- [ ] 신청 가능 개수 초과 시 에러 메시지 표시

### 7. 스토어 중복 기능 설명

#### 현재 상태: ✅ 적절함

**용어 설명**:
- **업계 용어**: "스토어 중복(스중)" - 광고 실행 업계에서 널리 사용되는 용어
- **기술적 구현**: 실제로는 `seller`(판매자) 필드를 비교하여 동일한 판매자에 대한 중복 참여를 방지
- **필드명**: `prevent_store_duplicate` - 업계 용어와 일치하므로 적절함

**결론**: 필드명과 용어는 업계 관행에 맞게 유지하고, 기술적으로는 seller 필드를 비교한다는 점만 문서에 명시하면 됩니다.

### 8. 캠페인 생성 후 목록 반영 문제

#### 문제점: ⚠️ 해결 필요

**현상**: 캠페인 생성 완료 후 "나의 캠페인" 페이지(`/mypage/advertiser/my-campaigns`)에 새로 생성된 캠페인 카드가 즉시 반영되지 않음

**원인 분석**:

1. **Eventual Consistency (최종 일관성)**
   - 데이터베이스 트랜잭션 커밋과 조회 사이의 지연
   - RLS(Row Level Security) 정책 적용 지연
   - RPC 함수 `get_user_campaigns_safe`의 캐싱 또는 지연

2. **현재 구현 방식**
   ```dart
   // campaign_creation_screen.dart
   context.pop(campaignId); // 생성된 캠페인 ID 반환
   
   // advertiser_my_campaigns_screen.dart
   context.pushNamed('advertiser-my-campaigns-create').then((result) {
     if (result != null && result is String) {
       _addCampaignByIdDirectly(campaignId); // 직접 조회 시도
     }
   });
   ```

3. **문제점**
   - `_addCampaignByIdDirectly`가 300ms 지연 후 `getCampaignById` 호출
   - 트랜잭션 커밋이 완료되지 않았을 수 있음
   - RLS 정책으로 인해 즉시 조회되지 않을 수 있음
   - 직접 조회 실패 시 `_loadCampaigns()`를 호출하지만, RPC 함수도 동일한 문제 발생 가능

**권장 해결책**:

#### 1단계: 생성된 캠페인 객체 직접 전달 (주 방법)

캠페인 생성 성공 시 생성된 캠페인 객체 전체를 반환하여 즉시 목록에 추가:

```dart
// campaign_creation_screen.dart
if (response.success) {
  final campaign = response.data!; // Campaign 객체
  context.pop(campaign); // ID 대신 객체 전체 반환
}

// advertiser_my_campaigns_screen.dart
context.pushNamed('advertiser-my-campaigns-create').then((result) {
  if (result != null && result is Campaign) {
    // 생성된 캠페인 객체를 직접 목록에 추가
    setState(() {
      _allCampaigns.insert(0, result);
      _updateFilteredCampaigns();
    });
  } else if (result != null && result is String) {
    // fallback: ID만 반환된 경우 폴링 방식으로 조회
    _addCampaignByIdWithPolling(result);
  }
});
```

#### 2단계: 폴링 방식 fallback (보조 방법)

객체 직접 전달이 실패한 경우를 대비한 폴링 방식:

```dart
/// 생성된 캠페인을 폴링 방식으로 조회
Future<void> _addCampaignByIdWithPolling(String campaignId) async {
  if (!mounted) return;
  
  const maxAttempts = 5;
  const initialDelay = Duration(milliseconds: 300);
  const maxDelay = Duration(milliseconds: 2000);
  
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    // 지수 백오프 (exponential backoff)
    final delay = Duration(
      milliseconds: (initialDelay.inMilliseconds * (1 << attempt))
          .clamp(initialDelay.inMilliseconds, maxDelay.inMilliseconds),
    );
    
    await Future.delayed(delay);
    
    if (!mounted) return;
    
    try {
      final result = await _campaignService.getCampaignById(campaignId);
      
      if (result.success && result.data != null) {
        final campaign = result.data!;
        
        // 중복 체크
        if (!_allCampaigns.any((c) => c.id == campaignId)) {
          if (mounted) {
            setState(() {
              _allCampaigns.insert(0, campaign);
              _updateFilteredCampaigns();
              _isLoading = false;
            });
            debugPrint('✅ 캠페인 조회 성공 (시도 ${attempt + 1}/${maxAttempts})');
            return; // 성공 시 종료
          }
        } else {
          debugPrint('ℹ️ 캠페인이 이미 목록에 있습니다');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 캠페인 조회 실패 (시도 ${attempt + 1}/${maxAttempts}): $e');
    }
  }
  
  // 모든 시도 실패 시 일반 새로고침
  debugPrint('❌ 폴링 실패 - 일반 새로고침 실행');
  if (mounted) {
    _loadCampaigns();
  }
}
```

**구현 전략**:
- 1단계(객체 직접 전달)로 대부분의 경우 즉시 반영
- 2단계(폴링)로 fallback 처리하여 안정성 확보

**구현 체크리스트**:
- [ ] 캠페인 생성 성공 시 Campaign 객체 전체 반환하도록 수정 (`campaign_creation_screen.dart`)
- [ ] 나의 캠페인 화면에서 객체 직접 추가 로직 구현 (`advertiser_my_campaigns_screen.dart`)
- [ ] `_addCampaignByIdWithPolling` 메서드 구현 (fallback용)
- [ ] 폴링 실패 시 일반 새로고침 fallback 유지
- [ ] 사용자 피드백 개선 (로딩 인디케이터, 성공 메시지)

---

## API 및 RPC 함수

### 1. RPC 함수: `create_campaign_with_points_v2`

**목적**: 캠페인 생성 및 포인트 차감을 원자적으로 처리

**파라미터**:
- `p_title`: 캠페인 제목
- `p_description`: 설명
- `p_campaign_type`: 캠페인 타입
- `p_campaign_reward`: 리뷰어 보상
- `p_max_participants`: 최대 모집 인원
- `p_max_per_reviewer`: 리뷰어당 신청 가능 개수 (기본값: 1)
- `p_start_date`: 시작일
- `p_end_date`: 종료일
- `p_expiration_date`: 만료일
- `p_platform`: 플랫폼
- `p_keyword`: 검색 키워드
- `p_option`: 제품 옵션
- `p_quantity`: 구매 개수
- `p_seller`: 판매자명
- `p_product_number`: 상품번호
- `p_product_image_url`: 제품 이미지 URL
- `p_product_name`: 제품명
- `p_product_price`: 제품 가격
- `p_purchase_method`: 구매 방법
- `p_review_type`: 리뷰 타입
- `p_review_text_length`: 텍스트 리뷰 길이
- `p_review_image_count`: 이미지 리뷰 개수
- `p_prevent_product_duplicate`: 상품 중복 금지
- `p_prevent_store_duplicate`: 스토어 중복 금지 (업계 용어: "스중", 실제로는 seller 필드 비교)
- `p_duplicate_prevent_days`: 중복 금지 기간
- `p_payment_method`: 지급 방법

**반환값**:
```json
{
  "success": true,
  "campaign_id": "uuid",
  "points_spent": 100000
}
```

**에러 처리**:
- `Unauthorized`: 로그인되지 않음
- `회사에 소속되지 않았습니다`: 회사 소속 확인 실패
- `회사 지갑이 없습니다`: 지갑 없음
- `포인트가 부족합니다`: 잔액 부족
- `포인트 차감이 정확하지 않습니다`: 차감 검증 실패

### 2. 함수: `calculate_campaign_cost`

**목적**: 캠페인 총 비용 계산

**파라미터**:
- `p_payment_method`: 지급 방법
- `p_product_price`: 제품 가격
- `p_campaign_reward`: 리뷰어 보상
- `p_max_participants`: 최대 모집 인원

**반환값**: 총 비용 (INTEGER)

---

## 결론

현재 캠페인 생성 프로세스는 기본적인 기능은 잘 구현되어 있으나, 로그 관리와 추적 기능이 부족합니다. 특히:

1. **캠페인 생성 로그 테이블이 없어** 생성 이력 추적이 어렵습니다.
2. **생성 실패 시 상세 로그가 없어** 문제 분석이 어렵습니다.
3. **캠페인 변경 이력이 없어** 감사(audit)가 어렵습니다.

**권장 사항**:
- `campaign_logs` 테이블을 생성하여 모든 캠페인 관련 액션을 기록
- RPC 함수에 로그 기록 로직 추가
- 필요시 `campaign_creation_attempts` 테이블 추가 고려

이를 통해 캠페인 생성 프로세스의 투명성과 추적 가능성을 크게 향상시킬 수 있습니다.

---

**문서 작성자**: AI Assistant  
**최종 수정일**: 2024년 12월  
**다음 검토 예정일**: 2025년 1월

