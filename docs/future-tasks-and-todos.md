# 향후 개발 작업 및 TODO 목록

> 작성일: 2025-01-13  
> 기반 문서: [schema-and-logic-analysis.md](./schema-and-logic-analysis.md)  
> 목적: 앞으로 구현해야 할 기능 및 개선 사항 정리

---

## 목차

1. [우선순위별 작업 목록](#1-우선순위별-작업-목록)
2. [데이터베이스 스키마 변경](#2-데이터베이스-스키마-변경)
3. [Flutter 모델 및 서비스 개선](#3-flutter-모델-및-서비스-개선)
4. [UI/UX 기능 구현](#4-uiux-기능-구현)
5. [성능 및 최적화](#5-성능-및-최적화)
6. [보안 및 권한 관리](#6-보안-및-권한-관리)

---

## 1. 우선순위별 작업 목록

### P0 (즉시 필요)

1. **캠페인 테이블 비용지급 주체 필드 추가** ⭐
   - [ ] Supabase 마이그레이션 파일 생성
   - [ ] Flutter `Campaign` 모델 업데이트
   - [ ] 관련 서비스 로직 수정

### P1 (단기)

2. **AdminService RPC 함수 전환**
   - [ ] `admin_get_users` RPC 함수 생성
   - [ ] `AdminService.getUsers()` 메서드 수정

3. **공지사항 관리 기능**
   - [ ] 공지사항 테이블 스키마 설계
   - [ ] 공지사항 CRUD API 구현
   - [ ] 관리자 화면 구현

### P2 (중기)

4. **시스템 점검 모드**
   - [ ] 점검 모드 설정 테이블/설정 추가
   - [ ] 점검 모드 체크 로직 구현
   - [ ] 점검 화면 UI 구현

5. **리뷰 작성 기능 완성**
   - [ ] 리뷰 작성 화면 구현
   - [ ] 리뷰 수정 기능 구현

### P3 (장기)

6. **성능 최적화**
   - [ ] 쿼리 최적화
   - [ ] 캐싱 전략 개선
   - [ ] 페이지네이션 개선

---

## 2. 데이터베이스 스키마 변경

### 2.1 캠페인 테이블 비용지급 주체 필드 추가 ⭐

**목적:** 캠페인 비용을 플랫폼이 지급하는지, 회사가 자체 지급하는지 구분

**변경 사항:**

#### 2.1.1 Supabase 마이그레이션

```sql
-- 새 마이그레이션 파일: YYYYMMDDHHMMSS_add_payment_source_to_campaigns.sql

-- campaigns 테이블에 payment_source 필드 추가
ALTER TABLE "public"."campaigns"
ADD COLUMN IF NOT EXISTS "payment_source" text DEFAULT 'platform'::text NOT NULL;

-- CHECK 제약조건 추가
ALTER TABLE "public"."campaigns"
ADD CONSTRAINT "campaigns_payment_source_check" 
CHECK (("payment_source" = ANY (ARRAY['platform'::text, 'company'::text])));

-- 코멘트 추가
COMMENT ON COLUMN "public"."campaigns"."payment_source" IS '비용지급 주체: platform(플랫폼지급) | company(자체지급)';
```

**필드 설명:**
- `payment_source`: `'platform'` (플랫폼지급) 또는 `'company'` (자체지급)
- 기본값: `'platform'`
- NOT NULL 제약조건

**영향받는 로직:**
- 포인트 지급 로직: `payment_source`에 따라 지급 주체 결정
- 캠페인 생성 시 기본값 설정
- 캠페인 수정 시 필드 업데이트

#### 2.1.2 기존 데이터 마이그레이션

```sql
-- 기존 캠페인은 모두 플랫폼 지급으로 설정 (기본값)
-- 이미 DEFAULT 값이 설정되어 있으므로 별도 업데이트 불필요
```

---

## 3. Flutter 모델 및 서비스 개선

### 3.1 Campaign 모델 업데이트

**파일:** `lib/models/campaign.dart`

**변경 사항:**

```dart
class Campaign {
  // ... 기존 필드들 ...
  
  // 비용지급 주체 필드 추가
  final PaymentSource paymentSource; // 'platform' | 'company'
  
  Campaign({
    // ... 기존 파라미터들 ...
    this.paymentSource = PaymentSource.platform, // 기본값: 플랫폼지급
  });
  
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      // ... 기존 필드 매핑 ...
      paymentSource: _mapPaymentSource(json['payment_source'] as String?),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      // ... 기존 필드들 ...
      'payment_source': _mapPaymentSourceToDb(paymentSource),
    };
  }
  
  // Enum 매핑 함수
  static PaymentSource _mapPaymentSource(String? source) {
    switch (source) {
      case 'company':
        return PaymentSource.company;
      case 'platform':
      default:
        return PaymentSource.platform;
    }
  }
  
  static String _mapPaymentSourceToDb(PaymentSource source) {
    switch (source) {
      case PaymentSource.company:
        return 'company';
      case PaymentSource.platform:
        return 'platform';
    }
  }
}

// Enum 추가
enum PaymentSource {
  platform, // 플랫폼지급
  company,  // 자체지급
}
```

### 3.2 CampaignService 업데이트

**파일:** `lib/services/campaign_service.dart`

**변경 사항:**

```dart
class CampaignService {
  // 캠페인 생성 시 payment_source 필드 포함
  Future<Campaign> createCampaign({
    // ... 기존 파라미터들 ...
    PaymentSource paymentSource = PaymentSource.platform,
  }) async {
    final response = await _supabase
        .from('campaigns')
        .insert({
          // ... 기존 필드들 ...
          'payment_source': _mapPaymentSourceToDb(paymentSource),
        })
        .select()
        .single();
    
    return Campaign.fromJson(response);
  }
  
  // 캠페인 수정 시 payment_source 필드 업데이트 가능
  Future<Campaign> updateCampaign({
    required String campaignId,
    // ... 기존 파라미터들 ...
    PaymentSource? paymentSource,
  }) async {
    final updateData = <String, dynamic>{};
    
    if (paymentSource != null) {
      updateData['payment_source'] = _mapPaymentSourceToDb(paymentSource);
    }
    
    // ... 기존 업데이트 로직 ...
  }
}
```

### 3.3 포인트 지급 로직 수정

**파일:** `lib/services/point_service.dart` 또는 `lib/services/campaign_log_service.dart`

**변경 사항:**

```dart
// 캠페인 완료 시 포인트 지급 로직
Future<void> processCampaignPayment(String campaignLogId) async {
  // 1. 캠페인 정보 조회
  final campaignLog = await getCampaignLog(campaignLogId);
  final campaign = campaignLog.campaign;
  
  if (campaign == null) {
    throw Exception('캠페인 정보를 찾을 수 없습니다.');
  }
  
  // 2. payment_source에 따라 지급 주체 결정
  if (campaign.paymentSource == PaymentSource.platform) {
    // 플랫폼 지급: 사용자 지갑에 포인트 지급
    await _pointService.earnPoints(
      userId: campaignLog.userId,
      amount: campaign.reviewCost,
      campaignId: campaign.id,
      description: '캠페인 완료 보상',
    );
  } else if (campaign.paymentSource == PaymentSource.company) {
    // 자체 지급: 회사가 직접 지급 (별도 프로세스 필요)
    // TODO: 회사 자체 지급 프로세스 구현
    // 예: 회사 지갑에서 차감 후 사용자에게 지급
    // 또는 외부 결제 시스템 연동
  }
}
```

---

## 4. UI/UX 기능 구현

### 4.1 캠페인 생성 화면 업데이트

**파일:** `lib/screens/campaign/create_campaign_screen.dart`

**추가할 UI 요소:**

```dart
// 비용지급 주체 선택 위젯
DropdownButtonFormField<PaymentSource>(
  value: _paymentSource,
  decoration: InputDecoration(
    labelText: '비용지급 주체',
    hintText: '비용을 누가 지급할지 선택하세요',
  ),
  items: [
    DropdownMenuItem(
      value: PaymentSource.platform,
      child: Text('플랫폼 지급'),
    ),
    DropdownMenuItem(
      value: PaymentSource.company,
      child: Text('자체 지급'),
    ),
  ],
  onChanged: (value) {
    setState(() {
      _paymentSource = value;
    });
  },
)
```

### 4.2 캠페인 상세 화면 업데이트

**파일:** `lib/screens/campaign/campaign_detail_screen.dart`

**추가할 표시:**

```dart
// 비용지급 주체 표시
Row(
  children: [
    Icon(
      campaign.paymentSource == PaymentSource.platform
          ? Icons.account_balance
          : Icons.business,
      size: 16,
    ),
    SizedBox(width: 4),
    Text(
      campaign.paymentSource == PaymentSource.platform
          ? '플랫폼 지급'
          : '자체 지급',
      style: TextStyle(fontSize: 14),
    ),
  ],
)
```

### 4.3 AdminService RPC 함수 전환

**현재 상태:**
- `AdminService.getUsers()`에서 직접 JOIN 쿼리 사용
- TODO 주석으로 RPC 함수 전환 권장

**작업 내용:**

1. **Supabase RPC 함수 생성**

```sql
CREATE OR REPLACE FUNCTION "public"."admin_get_users"(
  "p_search_query" text DEFAULT NULL::text,
  "p_user_type_filter" text DEFAULT NULL::text,
  "p_status_filter" text DEFAULT NULL::text,
  "p_limit" integer DEFAULT 50,
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- 관리자 권한 확인
  -- 검색, 필터링, 페이지네이션 로직
  -- users, company_users, sns_connections JOIN
  -- 결과를 JSONB로 반환
END;
$$;
```

2. **Flutter 서비스 수정**

```dart
// lib/services/admin_service.dart
Future<List<app_user.User>> getUsers({
  String? searchQuery,
  String? userTypeFilter,
  String? statusFilter,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final response = await _supabase.rpc(
      'admin_get_users',
      params: {
        'p_search_query': searchQuery,
        'p_user_type_filter': userTypeFilter,
        'p_status_filter': statusFilter,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    
    // JSONB 배열을 User 리스트로 변환
    return (response as List)
        .map((data) => app_user.User.fromJson(data as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('사용자 목록 조회 실패: $e');
    rethrow;
  }
}
```

### 4.4 공지사항 관리 기능

**필요한 작업:**

1. **데이터베이스 스키마**

```sql
CREATE TABLE "public"."notices" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "title" text NOT NULL,
  "content" text NOT NULL,
  "is_important" boolean DEFAULT false NOT NULL,
  "target_user_type" text, -- 'all' | 'user' | 'admin' | 'company'
  "status" text DEFAULT 'active'::text NOT NULL, -- 'active' | 'inactive'
  "created_by" uuid, -- FK → users.id
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY ("id")
);
```

2. **Flutter 모델**

```dart
// lib/models/notice.dart
class Notice {
  final String id;
  final String title;
  final String content;
  final bool isImportant;
  final String? targetUserType;
  final String status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

3. **서비스**

```dart
// lib/services/notice_service.dart
class NoticeService {
  Future<List<Notice>> getNotices({String? userType});
  Future<Notice> createNotice(Notice notice);
  Future<Notice> updateNotice(String noticeId, Notice notice);
  Future<void> deleteNotice(String noticeId);
}
```

4. **화면**

- `lib/screens/common/notices_screen.dart` - 공지사항 목록 (이미 존재, 실제 API 연동 필요)
- `lib/screens/admin/admin_notices_screen.dart` - 관리자 공지사항 관리 화면 (신규 생성)

### 4.5 시스템 점검 모드

**필요한 작업:**

1. **설정 테이블 또는 환경 변수**

```sql
-- 옵션 1: 설정 테이블
CREATE TABLE "public"."system_settings" (
  "key" text NOT NULL PRIMARY KEY,
  "value" jsonb NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

-- 옵션 2: 환경 변수 또는 Supabase 설정 사용
```

2. **점검 모드 체크 로직**

```dart
// lib/services/system_service.dart
class SystemService {
  Future<bool> isMaintenanceMode() async {
    // 설정 조회
    // 점검 모드 여부 반환
  }
  
  Future<void> setMaintenanceMode(bool enabled) async {
    // 관리자 권한 확인
    // 점검 모드 설정 업데이트
  }
}
```

3. **점검 화면**

```dart
// lib/screens/common/maintenance_screen.dart
class MaintenanceScreen extends StatelessWidget {
  // 점검 안내 화면
}
```

### 4.6 리뷰 작성 기능 완성

**현재 상태:**
- `reviewer_reviews_screen.dart`에 TODO 주석 존재
- 리뷰 작성 화면으로 이동하는 기능 미구현

**필요한 작업:**

1. **리뷰 작성 화면 구현**

```dart
// lib/screens/review/create_review_screen.dart
class CreateReviewScreen extends StatefulWidget {
  final String campaignId;
  final String campaignLogId;
  
  // 리뷰 작성 UI
  // - 제목 입력
  // - 별점 선택
  // - 내용 입력
  // - 이미지 업로드
  // - 리뷰 URL 입력
}
```

2. **리뷰 수정 기능**

```dart
// lib/screens/review/edit_review_screen.dart
class EditReviewScreen extends StatefulWidget {
  final String campaignLogId;
  // 기존 리뷰 데이터 로드
  // 수정 후 저장
}
```

---

## 5. 성능 및 최적화

### 5.1 쿼리 최적화

**작업 내용:**

1. **인덱스 추가 검토**
   - 자주 조회되는 필드에 인덱스 추가
   - JOIN 성능 개선

2. **불필요한 JOIN 제거**
   - 필요한 필드만 SELECT
   - 페이지네이션 최적화

### 5.2 캐싱 전략 개선

**현재 상태:**
- `UserService`에 5분 캐싱 적용
- 사용자 프로필은 세션 동안 캐싱

**개선 사항:**

1. **캠페인 목록 캐싱**
   - 인기 캠페인 캐싱
   - 필터별 캐싱

2. **공지사항 캐싱**
   - 공지사항 목록 캐싱
   - 중요 공지사항 우선 표시

### 5.3 페이지네이션 개선

**작업 내용:**

1. **무한 스크롤 구현**
   - 리스트 화면에 무한 스크롤 적용
   - 로딩 상태 표시 개선

2. **가상 스크롤링 고려**
   - 대량 데이터 처리 시 가상 스크롤링 적용

---

## 6. 보안 및 권한 관리

### 6.1 RPC 함수 보안 강화

**작업 내용:**

1. **모든 관리자 기능을 RPC 함수로 전환**
   - `AdminService`의 모든 메서드
   - 서버 측 권한 검증

2. **RLS (Row Level Security) 정책 검토**
   - 모든 테이블에 적절한 RLS 정책 적용
   - 권한별 접근 제어

### 6.2 입력 검증 강화

**작업 내용:**

1. **클라이언트 측 검증**
   - 폼 입력 검증
   - 파일 업로드 검증

2. **서버 측 검증**
   - RPC 함수 내 입력 검증
   - SQL Injection 방지

---

## 7. 테스트 및 문서화

### 7.1 테스트 코드 작성

**작업 내용:**

1. **단위 테스트**
   - 모델 변환 로직 테스트
   - 서비스 메서드 테스트

2. **통합 테스트**
   - API 연동 테스트
   - E2E 테스트

### 7.2 문서화

**작업 내용:**

1. **API 문서**
   - RPC 함수 문서화
   - 요청/응답 예시

2. **개발 가이드**
   - 새로운 기능 추가 가이드
   - 코딩 컨벤션

---

## 8. 변경 이력

| 날짜 | 작업 내용 | 우선순위 | 상태 |
|------|----------|---------|------|
| 2025-01-13 | 문서 초기 작성 | - | 완료 |
| - | 캠페인 테이블 비용지급 주체 필드 추가 | P0 | 대기 |
| - | AdminService RPC 함수 전환 | P1 | 대기 |
| - | 공지사항 관리 기능 | P1 | 대기 |
| - | 시스템 점검 모드 | P2 | 대기 |
| - | 리뷰 작성 기능 완성 | P2 | 대기 |

---

**문서 버전:** 1.0  
**최종 업데이트:** 2025-01-13


