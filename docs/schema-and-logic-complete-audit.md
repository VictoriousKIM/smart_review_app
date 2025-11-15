# 데이터베이스 스키마 및 로직 전체 점검 문서

> 작성일: 2025-01-15  
> 최종 업데이트: 2025-01-15  
> 목적: Supabase 데이터베이스의 모든 스키마, RPC 함수, 트리거를 점검하고 문제점을 해결

---

## 목차

1. [전체 개요](#1-전체-개요)
2. [테이블 스키마](#2-테이블-스키마)
3. [RPC 함수 목록 및 점검](#3-rpc-함수-목록-및-점검)
4. [트리거 목록 및 점검](#4-트리거-목록-및-점검)
5. [search_path 문제 및 해결](#5-search_path-문제-및-해결)
6. [데이터 흐름 및 비즈니스 로직](#6-데이터-흐름-및-비즈니스-로직)
7. [발견된 문제 및 해결](#7-발견된-문제-및-해결)
8. [테스트 체크리스트](#8-테스트-체크리스트)

---

## 1. 전체 개요

### 1.1 데이터베이스 통계

- **총 테이블 수**: 16개
- **총 RPC 함수 수**: 61개
- **총 트리거 수**: 13개

### 1.2 주요 테이블 카테고리

1. **사용자 관련**: `users`, `company_users`, `sns_connections`
2. **회사 관련**: `companies`
3. **캠페인 관련**: `campaigns`, `campaign_action_logs`, `campaign_actions`
4. **지갑 관련**: `wallets`
5. **거래 관련**: `point_transactions`, `cash_transactions`
6. **로그 관련**: `point_transaction_logs`, `cash_transaction_logs`
7. **기타**: `notifications`, `deleted_users`

---

## 2. 테이블 스키마

### 2.1 핵심 테이블 상세

#### 2.1.1 `wallets` 테이블

```sql
CREATE TABLE "public"."wallets" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "company_id" uuid,                     -- FK → companies.id (회사 지갑)
    "user_id" uuid,                        -- FK → users.id (개인 지갑)
    "current_points" integer DEFAULT 0 NOT NULL,
    "withdraw_bank_name" text,
    "withdraw_account_number" text,
    "withdraw_account_holder" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "wallets_owner_check" CHECK (
        (("company_id" IS NOT NULL) AND ("user_id" IS NULL)) OR 
        (("company_id" IS NULL) AND ("user_id" IS NOT NULL))
    )
);
```

**특징:**
- 통합 지갑 테이블 (회사 지갑 + 개인 지갑)
- `company_id`와 `user_id` 중 하나만 NULL이 아님
- 트리거로 자동 생성: `create_user_wallet_on_signup`, `create_company_wallet_on_registration`

#### 2.1.2 `cash_transactions` 테이블

```sql
CREATE TABLE "public"."cash_transactions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "wallet_id" uuid NOT NULL,             -- FK → wallets.id
    "transaction_type" text NOT NULL,      -- 'deposit' | 'withdraw'
    "amount" integer NOT NULL,
    "cash_amount" numeric(10,2),
    "payment_method" text,
    "bank_name" text,
    "account_number" text,
    "account_holder" text,
    "status" text DEFAULT 'pending'::text, -- 'pending' | 'approved' | 'rejected' | 'completed' | 'cancelled'
    "approved_by" uuid,
    "rejected_by" uuid,
    "rejection_reason" text,
    "description" text,
    "created_by_user_id" uuid,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "cash_transactions_amount_check" CHECK (("amount" <> 0)),
    CONSTRAINT "cash_transactions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'completed'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "cash_transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['deposit'::"text", 'withdraw'::"text"]))),
    CONSTRAINT "cash_transactions_withdraw_account_check" CHECK (((("transaction_type" = 'withdraw'::"text") AND ("bank_name" IS NOT NULL) AND ("account_number" IS NOT NULL) AND ("account_holder" IS NOT NULL)) OR ("transaction_type" <> 'withdraw'::"text")))
);
```

**특징:**
- 현금 입출금 거래만 저장
- `status`, `approved_by`, `rejected_by` 등 승인 프로세스 필드 포함
- 출금 시 계좌 정보 필수 (CHECK 제약조건)

#### 2.1.3 `cash_transaction_logs` 테이블

```sql
CREATE TABLE "public"."cash_transaction_logs" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "transaction_id" uuid NOT NULL,        -- FK → cash_transactions.id
    "action" text NOT NULL,                -- 'created' | 'updated' | 'status_changed' | 'approved' | 'rejected' | 'cancelled' | 'completed'
    "changed_by" uuid,                     -- FK → users.id
    "change_reason" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "cash_transaction_logs_action_check" CHECK (("action" = ANY (ARRAY['created'::"text", 'updated'::"text", 'status_changed'::"text", 'approved'::"text", 'rejected'::"text", 'cancelled'::"text", 'completed'::"text"])))
);
```

**특징:**
- 현금 거래 진행 이력 로그 (적산 방식)
- 트리거로 자동 생성: `log_cash_transaction_change`

#### 2.1.4 `point_transactions` 테이블

```sql
CREATE TABLE "public"."point_transactions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "wallet_id" uuid NOT NULL,             -- FK → wallets.id
    "transaction_type" text NOT NULL,      -- 'earn' | 'spend'
    "amount" integer NOT NULL,
    "campaign_id" uuid,                    -- FK → campaigns.id
    "related_entity_type" text,
    "related_entity_id" uuid,
    "description" text,
    "created_by_user_id" uuid,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "completed_at" timestamp with time zone DEFAULT now()
);
```

**특징:**
- 캠페인 관련 포인트 거래만 저장
- 트리거로 자동 잔액 업데이트: `update_wallet_balance_on_transaction`

#### 2.1.5 `point_transaction_logs` 테이블

```sql
CREATE TABLE "public"."point_transaction_logs" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "transaction_id" uuid NOT NULL,        -- FK → point_transactions.id
    "action" text NOT NULL,                -- 'created' | 'updated'
    "changed_by" uuid,                     -- FK → users.id
    "change_reason" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
```

**특징:**
- 포인트 거래 진행 이력 로그
- 트리거로 자동 생성: `log_point_transaction_change`

---

## 3. RPC 함수 목록 및 점검

### 3.1 현금 거래 관련 함수

#### 3.1.1 `create_cash_transaction`

**목적**: 현금 거래 생성 (포인트 충전/출금 요청)

**파라미터:**
- `p_wallet_id` (uuid): 지갑 ID
- `p_transaction_type` (text): 'deposit' | 'withdraw'
- `p_amount` (integer): 포인트 금액
- `p_cash_amount` (numeric): 실제 현금 금액
- `p_payment_method` (text, optional): 결제 방법
- `p_bank_name` (text, optional): 은행명 (출금 시 필수)
- `p_account_number` (text, optional): 계좌번호 (출금 시 필수)
- `p_account_holder` (text, optional): 예금주 (출금 시 필수)
- `p_description` (text, optional): 설명
- `p_created_by_user_id` (uuid, optional): 생성자 ID

**반환값**: `uuid` (거래 ID)

**검증 로직:**
1. 지갑 존재 확인
2. 거래 타입 검증 ('deposit' | 'withdraw')
3. 출금 시 계좌 정보 필수 검증

**트리거 연동:**
- `cash_transactions_log_trigger`: 로그 자동 생성
- `cash_transactions_wallet_balance_trigger`: 완료 시 잔액 업데이트

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets`, `public.cash_transactions` 명시

### 3.2 포인트 거래 관련 함수

#### 3.2.1 `create_point_transaction`

**목적**: 포인트 거래 생성 (캠페인 관련)

**파라미터:**
- `p_wallet_id` (uuid): 지갑 ID
- `p_transaction_type` (text): 'earn' | 'spend'
- `p_amount` (integer): 포인트 금액
- `p_campaign_id` (uuid, optional): 캠페인 ID
- `p_related_entity_type` (text, optional): 관련 엔티티 타입
- `p_related_entity_id` (uuid, optional): 관련 엔티티 ID
- `p_description` (text, optional): 설명
- `p_created_by_user_id` (uuid, optional): 생성자 ID

**반환값**: `uuid` (거래 ID)

**검증 로직:**
1. 지갑 존재 확인
2. 거래 타입 검증 ('earn' | 'spend')
3. 회사 지갑의 spend 거래는 campaign_id 필수

**트리거 연동:**
- `point_transactions_log_trigger`: 로그 자동 생성
- `point_transactions_wallet_balance_trigger`: 잔액 자동 업데이트

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets`, `public.point_transactions` 명시

### 3.3 지갑 관련 함수

#### 3.3.1 `create_user_wallet_on_signup` (트리거 함수)

**목적**: 사용자 가입 시 개인 지갑 자동 생성

**트리거**: `create_user_wallet_trigger` (AFTER INSERT ON users)

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets` 명시

#### 3.3.2 `create_company_wallet_on_registration` (트리거 함수)

**목적**: 회사 등록 시 회사 지갑 자동 생성

**트리거**: `create_company_wallet_trigger` (AFTER INSERT ON companies)

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets` 명시

#### 3.3.3 `ensure_user_wallet`

**목적**: 사용자 지갑이 없으면 생성

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets` 명시

#### 3.3.4 `ensure_company_wallet`

**목적**: 회사 지갑이 없으면 생성

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets` 명시

### 3.4 로그 관련 함수

#### 3.4.1 `log_cash_transaction_change` (트리거 함수)

**목적**: 현금 거래 변경 시 로그 자동 생성

**트리거**: `cash_transactions_log_trigger` (AFTER INSERT OR UPDATE ON cash_transactions)

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.cash_transaction_logs` 명시

#### 3.4.2 `log_point_transaction_change` (트리거 함수)

**목적**: 포인트 거래 변경 시 로그 자동 생성

**트리거**: `point_transactions_log_trigger` (AFTER INSERT OR UPDATE ON point_transactions)

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.point_transaction_logs` 명시

### 3.5 잔액 업데이트 함수

#### 3.5.1 `update_wallet_balance_on_cash_transaction` (트리거 함수)

**목적**: 현금 거래 완료 시 지갑 잔액 업데이트

**트리거**: `cash_transactions_wallet_balance_trigger` (AFTER INSERT OR UPDATE ON cash_transactions WHEN status = 'completed')

**로직:**
- `status`가 'completed'로 변경될 때만 잔액 업데이트
- `current_points = current_points + amount`

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets` 명시

#### 3.5.2 `update_wallet_balance_on_transaction` (트리거 함수)

**목적**: 포인트 거래 시 지갑 잔액 업데이트

**트리거**: `point_transactions_wallet_balance_trigger` (AFTER INSERT ON point_transactions)

**로직:**
- 포인트 거래 생성 시 즉시 잔액 업데이트
- `current_points = current_points + amount`

**수정 사항:**
- ✅ `SET "search_path" TO ''` 사용 시 `public.wallets` 명시

---

## 4. 트리거 목록 및 점검

### 4.1 지갑 생성 트리거

| 트리거명 | 테이블 | 이벤트 | 함수 | 상태 |
|---------|--------|--------|------|------|
| `create_user_wallet_trigger` | `users` | AFTER INSERT | `create_user_wallet_on_signup` | ✅ 정상 |
| `create_company_wallet_trigger` | `companies` | AFTER INSERT | `create_company_wallet_on_registration` | ✅ 정상 |

### 4.2 거래 로그 트리거

| 트리거명 | 테이블 | 이벤트 | 함수 | 상태 |
|---------|--------|--------|------|------|
| `cash_transactions_log_trigger` | `cash_transactions` | AFTER INSERT OR UPDATE | `log_cash_transaction_change` | ✅ 수정 완료 |
| `point_transactions_log_trigger` | `point_transactions` | AFTER INSERT OR UPDATE | `log_point_transaction_change` | ✅ 수정 완료 |

### 4.3 잔액 업데이트 트리거

| 트리거명 | 테이블 | 이벤트 | 조건 | 함수 | 상태 |
|---------|--------|--------|------|------|------|
| `cash_transactions_wallet_balance_trigger` | `cash_transactions` | AFTER INSERT OR UPDATE | `status = 'completed'` | `update_wallet_balance_on_cash_transaction` | ✅ 수정 완료 |
| `point_transactions_wallet_balance_trigger` | `point_transactions` | AFTER INSERT | - | `update_wallet_balance_on_transaction` | ✅ 수정 완료 |

---

## 5. search_path 문제 및 해결

### 5.1 문제 상황

PostgreSQL에서 `SET "search_path" TO ''`를 사용하는 함수는 보안상의 이유로 스키마를 명시적으로 지정해야 합니다. 그렇지 않으면 테이블을 찾지 못하는 오류가 발생합니다.

**오류 예시:**
```
PostgrestException(message: relation "wallets" does not exist, code: 42P01)
PostgrestException(message: relation "cash_transaction_logs" does not exist, code: 42P01)
```

### 5.2 해결 방법

모든 `SET "search_path" TO ''`를 사용하는 함수에서 테이블 참조 시 `public.` 스키마를 명시적으로 지정해야 합니다.

**수정 전:**
```sql
INSERT INTO wallets (...)
FROM wallets
UPDATE wallets
```

**수정 후:**
```sql
INSERT INTO public.wallets (...)
FROM public.wallets
UPDATE public.wallets
```

### 5.3 수정된 함수 목록

1. ✅ `create_cash_transaction`: `public.wallets`, `public.cash_transactions`
2. ✅ `create_point_transaction`: `public.wallets`, `public.point_transactions`
3. ✅ `create_user_wallet_on_signup`: `public.wallets`
4. ✅ `create_company_wallet_on_registration`: `public.wallets`
5. ✅ `ensure_user_wallet`: `public.wallets`
6. ✅ `ensure_company_wallet`: `public.wallets`
7. ✅ `log_cash_transaction_change`: `public.cash_transaction_logs`
8. ✅ `log_point_transaction_change`: `public.point_transaction_logs`
9. ✅ `update_wallet_balance_on_cash_transaction`: `public.wallets`
10. ✅ `update_wallet_balance_on_transaction`: `public.wallets`
11. ✅ `get_user_point_history_unified`: `public.point_transactions`, `public.cash_transactions`, `public.wallets`
12. ✅ `get_company_point_history_unified`: `public.point_transactions`, `public.cash_transactions`, `public.wallets`

---

## 6. 데이터 흐름 및 비즈니스 로직

### 6.1 포인트 충전 프로세스

```
1. 사용자가 포인트 충전 요청
   ↓
2. WalletService.createPointCashTransaction()
   - create_cash_transaction RPC 호출
   - transaction_type: 'deposit'
   - status: 'pending' (기본값)
   ↓
3. cash_transactions 테이블에 INSERT
   ↓
4. cash_transactions_log_trigger 트리거 실행
   - log_cash_transaction_change 함수 호출
   - cash_transaction_logs에 'created' 로그 INSERT
   ↓
5. 관리자 승인
   - cash_transactions.status: 'approved' → 'completed'
   ↓
6. cash_transactions_wallet_balance_trigger 트리거 실행
   - update_wallet_balance_on_cash_transaction 함수 호출
   - wallets.current_points 업데이트
   ↓
7. cash_transactions_log_trigger 트리거 실행
   - cash_transaction_logs에 'completed' 로그 INSERT
```

### 6.2 포인트 출금 프로세스

```
1. 사용자가 포인트 출금 요청
   ↓
2. WalletService.createPointCashTransaction()
   - create_cash_transaction RPC 호출
   - transaction_type: 'withdraw'
   - bank_name, account_number, account_holder 필수
   - status: 'pending' (기본값)
   ↓
3. cash_transactions 테이블에 INSERT
   ↓
4. cash_transactions_log_trigger 트리거 실행
   - log_cash_transaction_change 함수 호출
   - cash_transaction_logs에 'created' 로그 INSERT
   ↓
5. 관리자 승인
   - cash_transactions.status: 'approved' → 'completed'
   ↓
6. cash_transactions_wallet_balance_trigger 트리거 실행
   - update_wallet_balance_on_cash_transaction 함수 호출
   - wallets.current_points 업데이트 (차감)
   ↓
7. cash_transactions_log_trigger 트리거 실행
   - cash_transaction_logs에 'completed' 로그 INSERT
```

### 6.3 포인트 적립 프로세스 (캠페인)

```
1. 리뷰 승인 완료
   ↓
2. WalletService.createPointTransaction()
   - create_point_transaction RPC 호출
   - transaction_type: 'earn'
   - amount: Campaign.reviewCost
   ↓
3. point_transactions 테이블에 INSERT
   ↓
4. point_transactions_wallet_balance_trigger 트리거 실행
   - update_wallet_balance_on_transaction 함수 호출
   - wallets.current_points 업데이트 (증가)
   ↓
5. point_transactions_log_trigger 트리거 실행
   - log_point_transaction_change 함수 호출
   - point_transaction_logs에 'created' 로그 INSERT
```

---

## 7. 발견된 문제 및 해결

### 7.1 문제 1: `cash_transaction_logs` 테이블을 찾을 수 없음

**증상:**
```
PostgrestException(message: relation "cash_transaction_logs" does not exist, code: 42P01)
```

**원인:**
- `log_cash_transaction_change` 함수에서 `SET "search_path" TO ''` 사용
- 테이블 참조 시 `public.` 스키마 미명시

**해결:**
- ✅ `INSERT INTO cash_transaction_logs` → `INSERT INTO public.cash_transaction_logs`로 수정

### 7.2 문제 2: `wallets` 테이블을 찾을 수 없음

**증상:**
```
PostgrestException(message: relation "wallets" does not exist, code: 42P01)
```

**원인:**
- 여러 함수에서 `SET "search_path" TO ''` 사용
- 테이블 참조 시 `public.` 스키마 미명시

**해결:**
- ✅ 모든 함수에서 `wallets` → `public.wallets`로 수정
- ✅ `point_transactions` → `public.point_transactions`로 수정
- ✅ `cash_transactions` → `public.cash_transactions`로 수정
- ✅ `point_transaction_logs` → `public.point_transaction_logs`로 수정

### 7.3 문제 3: 통합 포인트 내역 조회 함수의 테이블 참조

**원인:**
- `get_user_point_history_unified`, `get_company_point_history_unified` 함수에서 JOIN 시 스키마 미명시

**해결:**
- ✅ 모든 테이블 참조에 `public.` 스키마 명시

---

## 8. 테스트 체크리스트

### 8.1 포인트 충전 테스트

- [ ] 사업자 계정으로 포인트 충전 요청
- [ ] `cash_transactions` 테이블에 'pending' 상태로 INSERT 확인
- [ ] `cash_transaction_logs` 테이블에 'created' 로그 확인
- [ ] 관리자 계정으로 승인
- [ ] `cash_transactions.status`가 'completed'로 변경 확인
- [ ] `wallets.current_points` 증가 확인
- [ ] `cash_transaction_logs` 테이블에 'completed' 로그 확인

### 8.2 포인트 출금 테스트

- [ ] 리뷰어 계정으로 포인트 출금 요청
- [ ] 계좌 정보 필수 검증 확인
- [ ] `cash_transactions` 테이블에 'pending' 상태로 INSERT 확인
- [ ] `cash_transaction_logs` 테이블에 'created' 로그 확인
- [ ] 관리자 계정으로 승인
- [ ] `cash_transactions.status`가 'completed'로 변경 확인
- [ ] `wallets.current_points` 감소 확인
- [ ] `cash_transaction_logs` 테이블에 'completed' 로그 확인

### 8.3 포인트 적립 테스트 (캠페인)

- [ ] 리뷰 승인 완료 후 포인트 적립
- [ ] `point_transactions` 테이블에 INSERT 확인
- [ ] `wallets.current_points` 증가 확인
- [ ] `point_transaction_logs` 테이블에 'created' 로그 확인

### 8.4 지갑 생성 테스트

- [ ] 사용자 가입 시 개인 지갑 자동 생성 확인
- [ ] 회사 등록 시 회사 지갑 자동 생성 확인

---

## 9. 참고 자료

### 9.1 관련 문서

- [스키마 및 로직 분석](./schema-and-logic-analysis.md)
- [최근 변경 사항 요약](./recent-changes-summary.md)

### 9.2 주요 파일 경로

- 마이그레이션: `supabase/migrations/20251112105337_drop_point_transfer_logs.sql`
- Flutter 서비스: `lib/services/wallet_service.dart`

---

**문서 버전:** 1.0  
**최종 업데이트:** 2025-01-15

