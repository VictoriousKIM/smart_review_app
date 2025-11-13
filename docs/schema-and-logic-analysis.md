# 플러터와 수파베이스 스키마 및 로직 분석 자료

> 작성일: 2025-01-13  
> 최종 업데이트: 2025-01-13  
> 목적: Supabase 데이터베이스 스키마와 Flutter 애플리케이션의 모델 및 서비스 로직 간의 관계를 종합적으로 분석

---

## 목차

1. [전체 아키텍처 개요](#1-전체-아키텍처-개요)
2. [Supabase 데이터베이스 스키마](#2-supabase-데이터베이스-스키마)
3. [Flutter 모델 구조](#3-flutter-모델-구조)
4. [스키마 매핑 관계](#4-스키마-매핑-관계)
5. [JOIN 로직 및 관계 데이터 처리](#5-join-로직-및-관계-데이터-처리)
6. [RPC 함수 활용](#6-rpc-함수-활용)
7. [주요 비즈니스 로직](#7-주요-비즈니스-로직)
8. [데이터 흐름도](#8-데이터-흐름도)
9. [주요 사항 및 제약사항](#9-주요-사항-및-제약사항)

---

## 1. 전체 아키텍처 개요

### 1.1 시스템 구조

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Models     │  │   Services   │  │   Screens    │     │
│  │  (Dart)      │  │  (Dart)      │  │  (Dart)      │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
│                    ┌───────▼────────┐                        │
│                    │ Supabase Client│                        │
│                    │  (PostgREST)   │                        │
│                    └───────┬────────┘                        │
└────────────────────────────┼─────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │  Supabase Cloud  │
                    │  ┌─────────────┐ │
                    │  │ PostgreSQL  │ │
                    │  │  Database   │ │
                    │  └─────────────┘ │
                    │  ┌─────────────┐ │
                    │  │   RPC       │ │
                    │  │  Functions  │ │
                    │  └─────────────┘ │
                    └──────────────────┘
```

### 1.2 데이터 흐름

1. **Flutter → Supabase**: Supabase Client를 통해 PostgREST API 호출
2. **Supabase → Flutter**: JSON 응답을 Flutter 모델로 변환
3. **보안**: RPC 함수를 통한 보안 강화된 데이터 접근

---

## 2. Supabase 데이터베이스 스키마

### 2.1 핵심 테이블 구조

#### 2.1.1 `users` 테이블
```sql
CREATE TABLE "public"."users" (
    "id" uuid NOT NULL,                    -- PK, auth.users.id와 동일
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now(),
    "display_name" text,
    "user_type" text DEFAULT 'user'::text, -- 'user' | 'admin'
    "status" text DEFAULT 'active'::text NOT NULL
);
```

**특징:**
- `auth.users`와 별도로 관리되는 프로필 정보
- `email`은 `auth.users`에서 가져옴
- `company_id`, `company_role`은 `company_users` 테이블에서 JOIN 필요
- `sns_connections`는 별도 테이블에서 JOIN 필요

#### 2.1.2 `company_users` 테이블
```sql
CREATE TABLE "public"."company_users" (
    "company_id" uuid NOT NULL,            -- FK → companies.id
    "user_id" uuid NOT NULL,               -- FK → users.id
    "company_role" text NOT NULL,          -- 'owner' | 'manager'
    "status" text DEFAULT 'active'::text,  -- 'active' | 'inactive' | 'pending' | 'suspended' | 'rejected'
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY ("company_id", "user_id")
);
```

**특징:**
- 복합 기본 키 (company_id + user_id)
- 한 사용자는 한 회사에 대해 하나의 역할만 가질 수 있음
- `status='active'`인 레코드만 유효

#### 2.1.3 `sns_connections` 테이블
```sql
CREATE TABLE "public"."sns_connections" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "user_id" uuid NOT NULL,               -- FK → users.id
    "platform" text NOT NULL,              -- 'coupang', 'smartstore', 'blog', 'instagram' 등
    "platform_account_id" text NOT NULL,
    "platform_account_name" text NOT NULL,
    "phone" text NOT NULL,
    "address" text,                        -- 스토어 플랫폼만 필수
    "return_address" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
```

**특징:**
- 한 사용자가 여러 플랫폼에 연결 가능 (1:N 관계)
- 플랫폼별로 별도의 레코드로 저장

#### 2.1.4 `campaigns` 테이블
```sql
CREATE TABLE "public"."campaigns" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "title" text NOT NULL,
    "description" text,
    "company_id" uuid NOT NULL,            -- FK → companies.id
    "product_name" text,
    "product_price" integer,
    "review_cost" integer NOT NULL,        -- 리뷰어에게 지급할 포인트
    "platform" text,
    "campaign_type" text DEFAULT 'reviewer'::text, -- 'reviewer' | 'journalist' | 'visit'
    "max_participants" integer DEFAULT 100 NOT NULL,
    "current_participants" integer DEFAULT 0 NOT NULL,
    "status" text DEFAULT 'active'::text NOT NULL,
    "start_date" timestamp with time zone,
    "end_date" timestamp with time zone,
    "user_id" uuid,                        -- 캠페인 생성자
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    -- ... 기타 필드들
);
```

**특징:**
- `campaign_type` 값: DB는 `'journalist'`, Flutter는 `'press'`로 매핑
- `review_cost`: 리뷰어에게 지급할 포인트 (OP)

#### 2.1.5 `campaign_action_logs` 테이블
```sql
CREATE TABLE "public"."campaign_action_logs" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "campaign_id" uuid NOT NULL,           -- FK → campaigns.id
    "user_id" uuid NOT NULL,               -- FK → users.id
    "action" jsonb NOT NULL,               -- JSONB: {"type": "join", "data": {...}}
    "application_message" text,
    "status" text DEFAULT 'pending'::text NOT NULL, -- 'pending' | 'approved' | 'rejected' | 'completed' | 'cancelled'
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
```

**특징:**
- `action` 필드는 JSONB 타입: `{"type": "join", "data": {...}}` 형식
- `action.type`: 행동 유형 ('join', 'leave', 'complete', 'cancel', '시작', '진행상황_저장', '완료')
- `action.data`: 추가 데이터 (리뷰 내용, 방문 정보, 기사 내용 등)
- 상태 전환은 `status` 필드로 관리
- 리뷰/방문/기사 상세 정보는 `action.data`에 저장 가능

#### 2.1.5-1 `campaign_actions` 테이블

```sql
CREATE TABLE "public"."campaign_actions" (
    "campaign_id" uuid NOT NULL,
    "user_id" uuid NOT NULL,
    "current_action" jsonb NOT NULL,        -- JSONB: {"type": "join", "data": {...}}
    "last_updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY ("campaign_id", "user_id")
);
```

**특징:**
- `current_action` 필드는 JSONB 타입: `campaign_action_logs.action`과 동일한 구조
- 사용자의 캠페인별 현재 상태 요약 테이블 (빠른 조회용)
- `campaign_action_logs`에 새 이벤트가 INSERT될 때 트리거로 자동 동기화
- `sync_campaign_actions_on_event` 트리거 함수로 관리

#### 2.1.6 `wallets` 테이블
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
- `company_name`은 `companies` 테이블에서 JOIN 필요

#### 2.1.7 `point_transactions` 테이블
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
- `wallet_id`를 통해 `wallets` 테이블에서 `user_id` 또는 `company_id` 조회 필요

#### 2.1.8 `cash_transactions` 테이블
```sql
CREATE TABLE "public"."cash_transactions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "wallet_id" uuid NOT NULL,             -- FK → wallets.id
    "transaction_type" text NOT NULL,      -- 'deposit' | 'withdraw'
    "amount" integer NOT NULL,
    "cash_amount" numeric,                 -- 실제 현금 금액
    "payment_method" text,
    "bank_name" text,
    "account_number" text,
    "account_holder" text,
    "status" text DEFAULT 'pending'::text, -- 'pending' | 'approved' | 'rejected' | 'completed'
    "approved_by" uuid,
    "rejected_by" uuid,
    "rejection_reason" text,
    "description" text,
    "created_by_user_id" uuid,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    "completed_at" timestamp with time zone
);
```

**특징:**
- 현금 입출금 거래만 저장
- `status`, `approved_by`, `rejected_by` 등 승인 프로세스 필드 포함

### 2.2 테이블 관계도

```
┌─────────────┐
│   users     │
│  (auth)     │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
┌──────▼──────────┐  ┌───▼──────────────┐
│  users          │  │ company_users    │
│  (public)       │  │                  │
└──────┬──────────┘  └───┬──────────────┘
       │                 │
       │                 │
       │            ┌────▼──────┐
       │            │ companies │
       │            └────┬──────┘
       │                 │
       │            ┌────▼──────┐
       │            │  wallets  │
       │            └────┬──────┘
       │                 │
       │            ┌────▼──────────────┐
       │            │ point_transactions│
       │            └───────────────────┘
       │
┌──────▼──────────────┐
│ sns_connections     │
└─────────────────────┘

┌─────────────┐
│  campaigns  │
└──────┬──────┘
       │
┌──────▼──────────────┐
│campaign_action_logs │
└──────┬──────────────┘
       │
       │ (트리거로 동기화)
       ▼
┌──────▼──────────────┐
│  campaign_actions   │
│  (현재 상태 요약)    │
└─────────────────────┘
```

---

## 3. Flutter 모델 구조

### 3.1 주요 모델

#### 3.1.1 `User` 모델 (`lib/models/user.dart`)

```dart
class User {
  final String uid;                        // users.id
  final String email;                      // auth.users.email (JOIN 필요)
  final String? displayName;               // users.display_name
  final DateTime createdAt;                // users.created_at
  final DateTime updatedAt;                // users.updated_at
  final int? level;                        // 계산 필드 (UserService)
  final int? reviewCount;                  // 계산 필드 (UserService)
  final UserType userType;                 // users.user_type
  final String? companyId;                 // company_users.company_id (JOIN 필요)
  final CompanyRole? companyRole;          // company_users.company_role (JOIN 필요)
  final SNSConnections? snsConnections;    // sns_connections 테이블 (JOIN 필요)
  final String? status;                    // users.status
}
```

**특징:**
- `companyId`, `companyRole`, `snsConnections`는 JOIN으로 가져옴
- `level`, `reviewCount`는 UserService에서 계산됨

#### 3.1.2 `Campaign` 모델 (`lib/models/campaign.dart`)

```dart
class Campaign {
  final String id;                         // campaigns.id
  final String title;                      // campaigns.title
  final String description;                // campaigns.description
  final String companyId;                  // campaigns.company_id
  final String? productName;               // campaigns.product_name
  final int reviewCost;                    // campaigns.review_cost
  final String? userId;                    // campaigns.user_id
  final CampaignCategory campaignType;     // campaigns.campaign_type (매핑 필요)
  // ... 기타 필드들
}
```

**특징:**
- `campaignType` enum 매핑:
  - Flutter: `CampaignCategory.press`
  - DB: `'journalist'`
  - 변환 로직: `mapCampaignType()`, `mapCampaignTypeToDb()`

#### 3.1.3 `CampaignLog` 모델 (`lib/models/campaign_log.dart`)

```dart
class CampaignLog {
  final String id;                         // campaign_action_logs.id
  final String campaignId;                 // campaign_action_logs.campaign_id
  final String userId;                     // campaign_action_logs.user_id
  final Map<String, dynamic> action;       // campaign_action_logs.action (JSONB)
  final String? applicationMessage;        // campaign_action_logs.application_message
  final String status;                     // campaign_action_logs.status
  final DateTime createdAt;                // campaign_action_logs.created_at
  final DateTime updatedAt;                // campaign_action_logs.updated_at
  final Campaign? campaign;                // campaigns 테이블 (JOIN)
  final User? user;                        // users 테이블 (JOIN)
  
  // 편의 getter
  String get actionType => action['type'] as String? ?? '';
  Map<String, dynamic>? get actionData => action['data'] as Map<String, dynamic>?;
  
  // action.data에서 가져오는 편의 메서드
  String get title => actionData?['title'] as String? ?? '';
  int get rating => actionData?['rating'] as int? ?? 0;
  String get reviewContent => actionData?['content'] as String? ?? '';
  String get reviewUrl => actionData?['reviewUrl'] as String? ?? '';
  
  // activityAt은 createdAt을 사용
  DateTime get activityAt => createdAt;
}
```

**특징:**
- `action` 필드는 JSONB 타입: `Map<String, dynamic>`으로 저장
- `action.type`: 행동 유형 ('join', 'leave', 'complete' 등)
- `action.data`: 추가 데이터 (리뷰 내용, 방문 정보, 기사 내용 등)
- 리뷰/방문/기사 상세 정보는 `action.data`에 저장됨
- 편의 getter로 `title`, `rating`, `reviewContent` 등 접근 가능

#### 3.1.4 `SNSConnection` 모델 (`lib/models/user.dart`)

```dart
class SNSConnection {
  final String id;                         // sns_connections.id
  final String userId;                     // sns_connections.user_id
  final String platform;                   // sns_connections.platform
  final String platformAccountId;          // sns_connections.platform_account_id
  final String platformAccountName;        // sns_connections.platform_account_name
  final String phone;                      // sns_connections.phone
  final String? address;                   // sns_connections.address
  final String? returnAddress;             // sns_connections.return_address
  final DateTime createdAt;                // sns_connections.created_at
  final DateTime updatedAt;                // sns_connections.updated_at
}

class SNSConnections {
  final List<SNSConnection> connections;   // 여러 플랫폼 연결
  // 플랫폼별 getter: google, instagram, youtube, naver, blog
}
```

**특징:**
- 1:N 관계 (한 사용자가 여러 플랫폼 연결)
- `SNSConnections`는 리스트를 플랫폼별로 그룹화한 래퍼

#### 3.1.5 `CompanyWallet` 모델 (`lib/models/wallet_models.dart`)

```dart
class CompanyWallet {
  final String id;                         // wallets.id
  final String companyId;                  // wallets.company_id
  final String companyName;                // companies.business_name (JOIN 필요)
  final int currentPoints;                 // wallets.current_points
  final String userRole;                   // company_users.company_role (JOIN 필요)
  final String status;                     // company_users.status (JOIN 필요)
  final String? withdrawBankName;          // wallets.withdraw_bank_name
  final String? withdrawAccountNumber;     // wallets.withdraw_account_number
  final String? withdrawAccountHolder;     // wallets.withdraw_account_holder
}
```

**특징:**
- `companyName`, `userRole`, `status`는 JOIN으로 가져옴

#### 3.1.6 `UserService` (`lib/services/user_service.dart`)

```dart
class UserService {
  // 사용자 통계 한 번에 가져오기
  Future<Map<String, int>> getUserStats(String userId);
  
  // 사용자 레벨 계산 (완료된 캠페인 수 / 10 + 1)
  Future<int> getUserLevel(String userId);
  
  // 사용자 리뷰 수 계산
  Future<int> getUserReviewCount(String userId);
}
```

**특징:**
- 사용자 통계 계산 서비스
- `User.level`: 완료된 캠페인 수 기반 계산 (완료된 캠페인 수 / 10 + 1)
- `User.reviewCount`: `campaign_action_logs`에서 `review_submitted` 또는 `review_approved` 상태 개수
- 캐싱 전략 적용 (5분간 유효)
- `AuthService`에 통합되어 사용자 프로필 조회 시 자동 계산

**참고:**
- `UserPointLog`와 `CompanyPointLog` 모델 사용

---

## 4. 스키마 매핑 관계

### 4.1 직접 매핑 (1:1)

| Flutter 모델 | Flutter 필드 | Supabase 테이블 | DB 컬럼 | 비고 |
|-------------|-------------|----------------|---------|------|
| `User` | `uid` | `users` | `id` | PK |
| `User` | `displayName` | `users` | `display_name` | |
| `User` | `userType` | `users` | `user_type` | enum 변환 |
| `Campaign` | `id` | `campaigns` | `id` | PK |
| `Campaign` | `companyId` | `campaigns` | `company_id` | |
| `Campaign` | `reviewCost` | `campaigns` | `review_cost` | |
| `CampaignLog` | `action` | `campaign_action_logs` | `action` | JSONB 타입 (Map<String, dynamic>) |
| `CampaignLog` | `applicationMessage` | `campaign_action_logs` | `application_message` | |

### 4.2 JOIN 필요 필드

| Flutter 모델 | Flutter 필드 | JOIN 테이블 | JOIN 조건 | 비고 |
|-------------|-------------|------------|----------|------|
| `User` | `email` | `auth.users` | `users.id = auth.users.id` | RPC 함수 사용 |
| `User` | `companyId` | `company_users` | `users.id = company_users.user_id AND status='active'` | RPC 함수 사용 |
| `User` | `companyRole` | `company_users` | `users.id = company_users.user_id AND status='active'` | RPC 함수 사용 |
| `User` | `snsConnections` | `sns_connections` | `users.id = sns_connections.user_id` | RPC 함수 사용 |
| `CompanyWallet` | `companyName` | `companies` | `wallets.company_id = companies.id` | 서비스에서 JOIN |
| `CompanyWallet` | `userRole` | `company_users` | `wallets.company_id = company_users.company_id AND user_id=현재사용자` | 서비스에서 JOIN |
| `CompanyWallet` | `status` | `company_users` | `wallets.company_id = company_users.company_id AND user_id=현재사용자` | 서비스에서 JOIN |

### 4.3 Enum 매핑

#### 4.3.1 `CampaignCategory` 매핑

| Flutter Enum | DB 값 | 변환 함수 |
|-------------|-------|----------|
| `CampaignCategory.reviewer` | `'reviewer'` | `mapCampaignType()` |
| `CampaignCategory.press` | `'journalist'` | `mapCampaignType()` |
| `CampaignCategory.visit` | `'visit'` | `mapCampaignType()` |
| `CampaignCategory.all` | `'reviewer'` (기본값) | Flutter 전용 |

**변환 로직:**
```dart
// DB → Flutter
CampaignCategory mapCampaignType(String? type) {
  switch (type) {
    case 'journalist': return CampaignCategory.press;
    case 'reviewer': return CampaignCategory.reviewer;
    case 'visit': return CampaignCategory.visit;
    default: return CampaignCategory.reviewer;
  }
}

// Flutter → DB
String mapCampaignTypeToDb(CampaignCategory type) {
  switch (type) {
    case CampaignCategory.press: return 'journalist';
    case CampaignCategory.reviewer: return 'reviewer';
    case CampaignCategory.visit: return 'visit';
    case CampaignCategory.all: return 'reviewer';
  }
}
```

#### 4.3.2 `UserType` 매핑

| Flutter Enum | DB 값 |
|-------------|-------|
| `UserType.user` | `'user'` |
| `UserType.admin` | `'admin'` |

#### 4.3.3 `CompanyRole` 매핑

| Flutter Enum | DB 값 |
|-------------|-------|
| `CompanyRole.owner` | `'owner'` |
| `CompanyRole.manager` | `'manager'` |

### 4.4 계산 필드 및 대체 필드

| Flutter 모델 | 필드 | 비고 |
|-------------|------|------|
| `CampaignLog` | `activityAt` | `createdAt` 사용 |
| `User` | `level` | 계산 필드 (UserService) |
| `User` | `reviewCount` | 계산 필드 (UserService) |

---

## 5. JOIN 로직 및 관계 데이터 처리

### 5.1 RPC 함수를 통한 JOIN

#### 5.1.1 `get_user_profile_safe` RPC 함수

**목적:** 사용자 프로필 조회 시 `company_users`와 `sns_connections` JOIN

**Supabase 함수:**
```sql
CREATE OR REPLACE FUNCTION "public"."get_user_profile_safe"(
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
```

**반환 구조:**
```json
{
  "id": "uuid",
  "created_at": "timestamp",
  "updated_at": "timestamp",
  "display_name": "text",
  "user_type": "text",
  "status": "text",
  "company_id": "uuid",        // company_users에서 JOIN
  "company_role": "text",      // company_users에서 JOIN
  "sns_connections": [         // sns_connections에서 JOIN
    {
      "id": "uuid",
      "user_id": "uuid",
      "platform": "text",
      "platform_account_id": "text",
      "platform_account_name": "text",
      "phone": "text",
      "address": "text",
      "return_address": "text",
      "created_at": "timestamp",
      "updated_at": "timestamp"
    }
  ]
}
```

**Flutter 사용:**
```dart
// lib/services/auth_service.dart
final profileResponse = await _supabase.rpc(
  'get_user_profile_safe',
  params: {'p_user_id': session.user.id},
);
final user = app_user.User.fromDatabaseProfile(profileResponse, session.user);

// 사용자 통계 계산 (level, reviewCount)
final stats = await _userService.getUserStats(user.uid);

return user.copyWith(
  level: stats['level'],
  reviewCount: stats['reviewCount'],
);
```

### 5.2 서비스 레이어에서의 JOIN

#### 5.2.1 `AdminService.getUsers()` - 사용자 목록 조회

**JOIN 쿼리:**
```dart
final response = await _supabase
  .from('users')
  .select('''
    *,
    company_users!left(company_id, company_role, status),
    sns_connections!left(*)
  ''')
  .order('created_at', ascending: false);
```

**파싱 로직:**
```dart
final companyUsers = userData['company_users'] as List?;
final companyUser = companyUsers?.isNotEmpty == true 
  ? companyUsers!.first 
  : null;

final snsConnectionsList = userData['sns_connections'] as List?;
final snsConnections = snsConnectionsList != null
  ? SNSConnections.fromJson(snsConnectionsList)
  : null;
```

#### 5.2.2 `WalletService.getCompanyWallets()` - 회사 지갑 조회

**JOIN 쿼리:**
```dart
final walletsResponse = await _supabase
  .from('wallets')
  .select('''
    id,
    company_id,
    current_points,
    withdraw_bank_name,
    withdraw_account_number,
    withdraw_account_holder,
    companies!inner(id, business_name)
  ''')
  .inFilter('company_id', companyIds);
```

**파싱 로직:**
```dart
final company = walletData['companies'] as Map<String, dynamic>;
final companyUser = companyUsers.firstWhere(
  (cu) => cu['company_id'] == companyId,
);

wallets.add(CompanyWallet(
  id: walletData['id'],
  companyId: companyId,
  companyName: company['business_name'],  // JOIN으로 가져옴
  currentPoints: walletData['current_points'],
  userRole: companyUser['company_role'],  // JOIN으로 가져옴
  status: companyUser['status'],          // JOIN으로 가져옴
  // ...
));
```

#### 5.2.3 `CampaignLogService.getUserCampaignLogs()` - 캠페인 로그 조회

**JOIN 쿼리:**
```dart
final response = await _supabase
  .from('campaign_action_logs')
  .select('''
    *,
    campaigns(*),
    users(*)
  ''')
  .eq('user_id', userId);
```

**파싱 로직:**
```dart
return CampaignLog.fromJson({
  ...logData,
  'campaigns': logData['campaigns'],
  'users': logData['users'],
});

// action 필드는 JSONB로 자동 파싱됨
// {"type": "join", "data": {...}} → Map<String, dynamic>
```

---

## 6. RPC 함수 활용

### 6.1 주요 RPC 함수 목록

| RPC 함수명 | 목적 | 사용 서비스 |
|-----------|------|------------|
| `get_user_profile_safe` | 사용자 프로필 조회 (JOIN 포함) | `AuthService` |
| `create_user_profile_safe` | 사용자 프로필 생성 | `AuthService` |
| `get_user_wallet_safe` | 개인 지갑 조회 | `WalletService` |
| `get_user_company_wallets` | 회사 지갑 목록 조회 | `WalletService` |
| `get_user_point_history_unified` | 통합 포인트 내역 조회 | `WalletService` |
| `get_company_point_history_unified` | 회사 포인트 내역 조회 | `WalletService` |
| `join_campaign_safe` | 캠페인 참여 | `CampaignLogService` |
| `leave_campaign_safe` | 캠페인 탈퇴 | `CampaignLogService` |
| `create_point_transaction` | 포인트 거래 생성 | `PointService` |
| `create_cash_transaction` | 현금 거래 생성 | `PointService` |

### 6.2 RPC 함수 사용 예시

#### 6.2.1 사용자 프로필 조회

```dart
// lib/services/auth_service.dart
final profileResponse = await _supabase.rpc(
  'get_user_profile_safe',
  params: {'p_user_id': session.user.id},
);

// 반환값: JSONB
// {
//   "id": "...",
//   "company_id": "...",
//   "company_role": "owner",
//   "sns_connections": [...]
// }
```

#### 6.2.2 통합 포인트 내역 조회

```dart
// lib/services/wallet_service.dart
final response = await _supabase.rpc(
  'get_user_point_history_unified',
  params: {
    'p_user_id': userId,
    'p_limit': limit,
    'p_offset': offset,
  },
);

// 반환값: JSONB 배열
// [
//   {
//     "id": "...",
//     "transaction_type": "earn",
//     "transaction_category": "campaign",
//     "amount": 1000,
//     ...
//   }
// ]
```

---

## 7. 주요 비즈니스 로직

### 7.1 캠페인 신청 프로세스

```
1. 사용자가 캠페인 신청
   ↓
2. CampaignLogService.applyToCampaign()
   - campaign_action_logs 테이블에 INSERT
   - action: {"type": "join"} (JSONB)
   - status: 'pending'
   - application_message: 사용자 메시지
   ↓
3. 관리자 승인/거절
   - CampaignLogService.updateStatus()
   - status: 'approved' | 'rejected'
   - action: {"type": "join"} (승인 시)
   ↓
4. 리뷰어 작업 진행
   - status 전환: 'purchased' → 'review_submitted' → 'review_approved' → 'payment_completed'
   - 각 단계마다 action 업데이트
   - 리뷰 제출 시: action.data에 리뷰 내용 저장
     {"type": "진행상황_저장", "data": {"title": "...", "content": "...", "rating": 5}}
```

**상태 전환 규칙:**
```dart
// lib/services/campaign_log_service.dart
bool _isValidStatusTransition(String currentStatus, String newStatus, String campaignType) {
  // 상태 전환 유효성 검증 로직
  // 예: 'pending' → 'approved' → 'purchased' → 'review_submitted' → ...
}

// action 필드는 JSONB 형식으로 저장
// 예: {"type": "join", "data": {...}}
```

### 7.2 포인트 거래 프로세스

#### 7.2.1 캠페인 포인트 적립

```
1. 리뷰 승인 완료
   ↓
2. PointService.earnPoints()
   - create_point_transaction RPC 호출
   - transaction_type: 'earn'
   - wallet_id: 사용자 지갑 ID
   - amount: Campaign.reviewCost
   - campaign_id: 캠페인 ID
   ↓
3. wallets.current_points 업데이트 (트리거)
   ↓
4. point_transaction_logs에 로그 기록 (트리거)
```

#### 7.2.2 현금 충전 프로세스

```
1. 사용자가 포인트 충전 요청
   ↓
2. PointService.requestPointCharge()
   - create_cash_transaction RPC 호출
   - transaction_type: 'deposit'
   - status: 'pending'
   - cash_amount: 실제 현금 금액
   ↓
3. 관리자 승인
   - cash_transactions.status: 'approved'
   - wallets.current_points 업데이트
   ↓
4. 완료
   - cash_transactions.status: 'completed'
   - cash_transaction_logs에 로그 기록
```

### 7.3 사용자 프로필 관리

```
1. 회원가입
   ↓
2. AuthService.signUpWithEmail()
   - auth.users에 사용자 생성
   - create_user_profile_safe RPC 호출
   - users 테이블에 프로필 생성
   - create_user_wallet_on_signup 트리거
   - wallets 테이블에 개인 지갑 생성
   ↓
3. 프로필 조회
   - get_user_profile_safe RPC 호출
   - company_users JOIN (company_id, company_role)
   - sns_connections JOIN (sns_connections 리스트)
   - UserService.getUserStats() 호출
   - level, reviewCount 계산 및 설정
```

### 7.4 회사 지갑 조회 프로세스

```
1. WalletService.getCompanyWallets()
   ↓
2. company_users 테이블에서 접근 가능한 회사 조회
   - user_id = 현재 사용자
   - status = 'active'
   - company_role IN ('owner', 'manager')
   ↓
3. wallets 테이블에서 회사 지갑 조회
   - companies 테이블 JOIN (company_name)
   - company_users 정보와 결합
   ↓
4. CompanyWallet 모델로 변환
   - companyName: companies.business_name
   - userRole: company_users.company_role
   - status: company_users.status
```

---

## 8. 데이터 흐름도

### 8.1 사용자 프로필 조회 흐름

```
┌─────────────┐
│   Screen    │
└──────┬──────┘
       │
       │ AuthService.currentUser
       ▼
┌──────────────────┐
│  AuthService     │
└──────┬───────────┘
       │
       │ _supabase.rpc('get_user_profile_safe')
       ▼
┌──────────────────┐
│  Supabase RPC    │
│  Function        │
└──────┬───────────┘
       │
       │ SQL JOIN
       ▼
┌─────────────────────────────────────┐
│  users                              │
│  LEFT JOIN company_users            │
│  LEFT JOIN sns_connections          │
└──────┬──────────────────────────────┘
       │
       │ JSONB 반환
       ▼
┌──────────────────┐
│  User.fromJson() │
└──────┬───────────┘
       │
       │ UserService.getUserStats()
       ▼
┌──────────────────┐
│  UserService     │
│  (level, reviewCount 계산) │
└──────┬───────────┘
       │
       │ User 객체 (통계 포함)
       ▼
┌─────────────┐
│   Screen    │
└─────────────┘
```

### 8.2 캠페인 신청 흐름

```
┌─────────────┐
│   Screen    │
└──────┬──────┘
       │
       │ CampaignLogService.applyToCampaign()
       ▼
┌──────────────────────┐
│ CampaignLogService   │
└──────┬───────────────┘
       │
       │ INSERT INTO campaign_action_logs
       ▼
┌──────────────────────┐
│ campaign_action_logs │
│ - action: {"type": "join"} (JSONB) │
│ - status: 'pending'  │
└──────┬───────────────┘
       │
       │ 성공 응답
       ▼
┌─────────────┐
│   Screen    │
└─────────────┘
```

### 8.3 포인트 적립 흐름

```
┌─────────────┐
│   Screen    │
└──────┬──────┘
       │
       │ PointService.earnPoints()
       ▼
┌──────────────────┐
│  PointService    │
└──────┬───────────┘
       │
       │ _supabase.rpc('create_point_transaction')
       ▼
┌──────────────────┐
│  Supabase RPC    │
│  Function        │
└──────┬───────────┘
       │
       │ 트랜잭션 처리
       ▼
┌──────────────────────────────┐
│ 1. point_transactions INSERT │
│ 2. wallets.current_points    │
│    UPDATE (트리거)            │
│ 3. point_transaction_logs    │
│    INSERT (트리거)            │
└──────┬───────────────────────┘
       │
       │ 성공 응답
       ▼
┌─────────────┐
│   Screen    │
└─────────────┘
```

---

## 9. 주요 사항 및 제약사항

### 9.1 action 필드 JSONB 구조

#### 9.1.1 JSONB 구조

`campaign_action_logs.action`과 `campaign_actions.current_action` 필드는 JSONB 타입입니다.

**JSONB 구조:**
```json
{
  "type": "join" | "leave" | "complete" | "cancel" | "시작" | "진행상황_저장" | "완료",
  "data": {
    // 선택적 추가 데이터
    "title": "리뷰 제목",
    "content": "리뷰 내용",
    "rating": 5,
    "reviewUrl": "https://...",
    // 또는 방문 정보, 기사 정보 등
  }
}
```

**사용 방법:**
- `CampaignLog.action`: `Map<String, dynamic>` 타입
- `log.actionType`: action.type 값 반환
- `log.actionData`: action.data 값 반환
- `log.title`, `log.rating` 등: action.data에서 자동 추출

### 9.2 JOIN 필수 필드

다음 필드들은 반드시 JOIN으로 가져와야 하며, 직접 쿼리 시 NULL일 수 있음:

| 모델 | 필드 | JOIN 테이블 | 필수 여부 |
|-----|------|------------|----------|
| `User` | `companyId` | `company_users` | 선택 |
| `User` | `companyRole` | `company_users` | 선택 |
| `User` | `snsConnections` | `sns_connections` | 선택 |
| `CompanyWallet` | `companyName` | `companies` | 필수 |
| `CompanyWallet` | `userRole` | `company_users` | 필수 |
| `CompanyWallet` | `status` | `company_users` | 필수 |

### 9.3 RPC 함수 사용 권장

다음 작업은 RPC 함수를 사용하는 것을 권장:

1. **사용자 프로필 조회**: `get_user_profile_safe`
   - 이유: 보안 강화, JOIN 자동 처리

2. **포인트 거래 생성**: `create_point_transaction`, `create_cash_transaction`
   - 이유: 트랜잭션 처리, 지갑 잔액 자동 업데이트

3. **캠페인 참여/탈퇴**: `join_campaign_safe`, `leave_campaign_safe`
   - 이유: 비즈니스 로직 검증, 중복 방지

### 9.4 Enum 값 매핑

#### 9.4.1 `CampaignCategory.press` ↔ `'journalist'`

- Flutter: `CampaignCategory.press`
- DB: `'journalist'`
- 변환 로직: `mapCampaignType()`, `mapCampaignTypeToDb()`

#### 9.4.2 `CampaignCategory.all`

- Flutter 전용 enum 값 (DB에 없음)
- DB 저장 시 `'reviewer'`로 변환됨

### 9.5 트리거 및 자동화

다음 작업은 DB 트리거로 자동 처리됨:

1. **지갑 생성**: `create_user_wallet_on_signup`, `create_company_wallet_on_registration`
2. **포인트 거래 로그**: `log_point_transaction_change`
3. **현금 거래 로그**: `log_cash_transaction_change`
4. **지갑 계좌 변경 로그**: `log_wallet_account_change`
5. **캠페인 액션 동기화**: `sync_campaign_actions_on_event` (campaign_action_logs → campaign_actions)

### 9.6 성능 고려사항

1. **JOIN 쿼리 최적화**
   - 필요한 필드만 SELECT
   - 인덱스 활용 (FK 자동 인덱스)

2. **RPC 함수 사용**
   - 서버 측에서 최적화된 쿼리 실행
   - 네트워크 트래픽 감소

3. **캐싱 전략**
   - 사용자 프로필: 세션 동안 캐싱
   - 사용자 통계: UserService에서 5분간 캐싱
   - 캠페인 목록: 페이지네이션 활용

---

## 10. 참고 자료

### 10.1 관련 문서

- [action 필드 JSONB 마이그레이션 가이드](./action-field-jsonb-migration.md)

### 10.2 주요 파일 경로

#### Supabase
- 마이그레이션: `supabase/migrations/20251112105337_drop_point_transfer_logs.sql`
- 시드 데이터: `supabase/seed.sql`

#### Flutter 모델
- `lib/models/user.dart`
- `lib/models/campaign.dart`
- `lib/models/campaign_log.dart`
- `lib/models/wallet_models.dart`

#### Flutter 서비스
- `lib/services/auth_service.dart`
- `lib/services/campaign_log_service.dart`
- `lib/services/wallet_service.dart`
- `lib/services/admin_service.dart`
- `lib/services/user_service.dart` (신규)

---

## 11. 변경 이력

| 날짜 | 변경 내용 | 관련 파일 |
|------|----------|----------|
| 2025-01-13 | 스키마 동기화 완료 | 모든 모델 및 서비스 |
| 2025-01-13 | `campaign_action_logs.action` 필드를 `text`에서 `jsonb`로 변경 | 마이그레이션 파일, `campaign_log.dart`, `campaign_log_service.dart` |
| 2025-01-13 | `CampaignLog.action` 필드를 `String`에서 `Map<String, dynamic>`으로 변경 | `campaign_log.dart` |
| 2025-01-13 | 리뷰/방문/기사 상세 정보를 `action.data`에 저장하도록 수정 | `campaign_log_service.dart` |
| 2025-01-13 | `UserService` 생성 및 `User.level`, `User.reviewCount` 계산 로직 구현 | `user_service.dart`, `auth_service.dart` |
| 2025-01-13 | `UnifiedPointTransaction` 모델 삭제 | `wallet_models.dart`, `wallet_service.dart` |
| 2025-01-13 | `User` 모델 JOIN 필드 추가 | `user.dart`, `auth_service.dart` |
| 2025-01-13 | `Campaign` 모델 필드 추가 | `campaign.dart` |
| 2025-01-13 | `SNSConnection` 모델 재작성 | `user.dart` |

---

**문서 버전:** 2.0  
**최종 업데이트:** 2025-01-13

