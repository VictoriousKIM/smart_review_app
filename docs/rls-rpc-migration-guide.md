# RLS 및 RPC 마이그레이션 가이드

> 작성일: 2025-01-15  
> 목적: Flutter 서비스 레이어에서 직접 테이블 접근을 RLS로 보호하고, 복잡한 로직을 RPC 함수로 마이그레이션하기 위한 가이드

---

## 목차

1. [개요](#1-개요)
2. [RLS 정책 필요 항목](#2-rls-정책-필요-항목)
3. [RPC 함수로 변경 필요 항목](#3-rpc-함수로-변경-필요-항목)
4. [우선순위별 마이그레이션 계획](#4-우선순위별-마이그레이션-계획)
5. [구현 가이드](#5-구현-가이드)

---

## 1. 개요

### 1.1 현재 상태

- **직접 테이블 접근**: 많은 서비스 메서드가 `.from('table_name')`을 통해 직접 테이블에 접근
- **클라이언트 사이드 로직**: 통계 계산, 복잡한 필터링 등이 Flutter 클라이언트에서 수행
- **보안 취약점**: RLS 정책이 없거나 불완전한 테이블 접근
- **성능 이슈**: 여러 번의 쿼리로 인한 네트워크 오버헤드

### 1.2 목표

1. **보안 강화**: 모든 테이블 접근에 RLS 정책 적용
2. **로직 중앙화**: 비즈니스 로직을 데이터베이스 RPC 함수로 이동
3. **성능 최적화**: 단일 RPC 호출로 복잡한 작업 수행
4. **유지보수성 향상**: 로직 변경 시 데이터베이스만 수정

---

## 2. RLS 정책 필요 항목

### 2.1 `wallets` 테이블

#### 현재 상태
- `wallet_service.dart`: `getUserWallet()`, `getCompanyWallets()` 등에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 개인 지갑 조회: 본인 지갑만 조회 가능
CREATE POLICY "Users can view own wallet"
ON wallets FOR SELECT
USING (user_id = auth.uid() AND company_id IS NULL);

-- 회사 지갑 조회: company_users에서 active인 owner/manager만 조회 가능
CREATE POLICY "Company owners/managers can view company wallet"
ON wallets FOR SELECT
USING (
  company_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM company_users
    WHERE company_users.company_id = wallets.company_id
    AND company_users.user_id = auth.uid()
    AND company_users.status = 'active'
    AND company_users.company_role IN ('owner', 'manager')
  )
);

-- 지갑 업데이트: 본인 지갑만 업데이트 가능 (계좌정보 등)
CREATE POLICY "Users can update own wallet"
ON wallets FOR UPDATE
USING (user_id = auth.uid() AND company_id IS NULL)
WITH CHECK (user_id = auth.uid() AND company_id IS NULL);

-- 회사 지갑 업데이트: owner만 업데이트 가능
CREATE POLICY "Company owners can update company wallet"
ON wallets FOR UPDATE
USING (
  company_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM company_users
    WHERE company_users.company_id = wallets.company_id
    AND company_users.user_id = auth.uid()
    AND company_users.status = 'active'
    AND company_users.company_role = 'owner'
  )
);
```

**영향받는 메서드:**
- `WalletService.getUserWallet()` ✅ RLS로 보호됨
- `WalletService.getCompanyWallets()` ✅ RLS로 보호됨
- `WalletService.updateUserWalletAccount()` ⚠️ RPC로 변경 권장 (fallback 제거)
- `WalletService.updateCompanyWalletAccount()` ⚠️ RPC로 변경 권장 (fallback 제거)

---

### 2.2 `point_transactions` 테이블

#### 현재 상태
- `wallet_service.dart`: `getUserPointHistory()`에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 포인트 거래 조회: 본인 지갑의 거래만 조회 가능
CREATE POLICY "Users can view own point transactions"
ON point_transactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM wallets
    WHERE wallets.id = point_transactions.wallet_id
    AND wallets.user_id = auth.uid()
  )
);

-- 회사 포인트 거래 조회: company_users에서 active인 owner/manager만 조회 가능
CREATE POLICY "Company owners/managers can view company point transactions"
ON point_transactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM wallets
    JOIN company_users ON company_users.company_id = wallets.company_id
    WHERE wallets.id = point_transactions.wallet_id
    AND wallets.company_id IS NOT NULL
    AND company_users.user_id = auth.uid()
    AND company_users.status = 'active'
    AND company_users.company_role IN ('owner', 'manager')
  )
);
```

**영향받는 메서드:**
- `WalletService.getUserPointHistory()` ✅ RLS로 보호됨

---

### 2.3 `campaigns` 테이블

#### 현재 상태
- `campaign_service.dart`: `getCampaigns()`, `getCampaignById()`, `searchCampaigns()` 등에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 활성 캠페인 조회: 모든 사용자가 조회 가능
CREATE POLICY "Anyone can view active campaigns"
ON campaigns FOR SELECT
USING (status = 'active');

-- 본인이 생성한 캠페인 조회: 모든 상태 조회 가능
CREATE POLICY "Users can view own campaigns"
ON campaigns FOR SELECT
USING (user_id = auth.uid());

-- 캠페인 생성: 로그인한 사용자만 가능
CREATE POLICY "Authenticated users can create campaigns"
ON campaigns FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- 캠페인 업데이트: 본인이 생성한 캠페인만 업데이트 가능
CREATE POLICY "Users can update own campaigns"
ON campaigns FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

**영향받는 메서드:**
- `CampaignService.getCampaigns()` ✅ RLS로 보호됨
- `CampaignService.getCampaignById()` ✅ RLS로 보호됨
- `CampaignService.getPopularCampaigns()` ✅ RLS로 보호됨
- `CampaignService.getNewCampaigns()` ✅ RLS로 보호됨
- `CampaignService.searchCampaigns()` ✅ RLS로 보호됨
- `CampaignService.getUserPreviousCampaigns()` ✅ RLS로 보호됨
- `CampaignService.searchUserCampaigns()` ✅ RLS로 보호됨
- `CampaignService.createCampaignFromPrevious()` ⚠️ RPC로 변경 권장

---

### 2.4 `campaign_action_logs` 테이블

#### 현재 상태
- `campaign_log_service.dart`: `applyToCampaign()`, `updateStatus()`, `getUserCampaignLogs()` 등에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 본인의 캠페인 로그 조회
CREATE POLICY "Users can view own campaign logs"
ON campaign_action_logs FOR SELECT
USING (user_id = auth.uid());

-- 캠페인 소유자가 신청자 로그 조회
CREATE POLICY "Campaign owners can view campaign logs"
ON campaign_action_logs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM campaigns
    WHERE campaigns.id = campaign_action_logs.campaign_id
    AND campaigns.user_id = auth.uid()
  )
);

-- 캠페인 신청: 로그인한 사용자만 가능
CREATE POLICY "Authenticated users can apply to campaigns"
ON campaign_action_logs FOR INSERT
WITH CHECK (user_id = auth.uid());

-- 본인의 캠페인 로그 업데이트
CREATE POLICY "Users can update own campaign logs"
ON campaign_action_logs FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 캠페인 소유자가 신청자 로그 업데이트 (승인/거절 등)
CREATE POLICY "Campaign owners can update campaign logs"
ON campaign_action_logs FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM campaigns
    WHERE campaigns.id = campaign_action_logs.campaign_id
    AND campaigns.user_id = auth.uid()
  )
);
```

**영향받는 메서드:**
- `CampaignLogService.applyToCampaign()` ✅ RLS로 보호됨
- `CampaignLogService.updateStatus()` ✅ RLS로 보호됨
- `CampaignLogService.getUserCampaignLogs()` ⚠️ RPC로 변경 권장 (복잡한 JOIN)
- `CampaignLogService.getCampaignLogs()` ⚠️ RPC로 변경 권장 (복잡한 JOIN)

---

### 2.5 `users` 테이블

#### 현재 상태
- `admin_service.dart`: `getUsers()`, `getUsersCount()`, `updateUserStatus()`에서 직접 접근
- `account_deletion_service.dart`: `checkDeletionEligibility()`, `backupUserData()`에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 본인 프로필 조회
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (id = auth.uid());

-- 본인 프로필 업데이트
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 관리자만 모든 사용자 조회 (admin RPC 함수 사용 권장)
-- RLS는 최소한으로 설정하고, 실제 권한 체크는 RPC 함수에서 수행
```

**영향받는 메서드:**
- `AdminService.getUsers()` ⚠️ RPC로 변경 필수 (복잡한 JOIN, 관리자 권한)
- `AdminService.getUsersCount()` ⚠️ RPC로 변경 권장
- `AdminService.updateUserStatus()` ⚠️ RPC로 변경 권장 (관리자 권한)
- `AccountDeletionService.checkDeletionEligibility()` ⚠️ RPC로 변경 권장
- `AccountDeletionService.backupUserData()` ⚠️ RPC로 변경 권장

---

### 2.6 `company_users` 테이블

#### 현재 상태
- `company_user_service.dart`: 모든 메서드에서 직접 접근
- `wallet_service.dart`: `getCompanyWallets()`에서 JOIN으로 접근

#### 필요한 RLS 정책

```sql
-- 본인의 company_users 레코드 조회
CREATE POLICY "Users can view own company_users"
ON company_users FOR SELECT
USING (user_id = auth.uid());

-- 같은 회사의 company_users 조회 (owner/manager만)
CREATE POLICY "Company owners/managers can view company members"
ON company_users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM company_users cu2
    WHERE cu2.company_id = company_users.company_id
    AND cu2.user_id = auth.uid()
    AND cu2.status = 'active'
    AND cu2.company_role IN ('owner', 'manager')
  )
);
```

**영향받는 메서드:**
- `CompanyUserService.canConvertToAdvertiser()` ✅ RLS로 보호됨
- `CompanyUserService.getUserCompanyRole()` ✅ RLS로 보호됨
- `CompanyUserService.isUserInCompany()` ✅ RLS로 보호됨
- `CompanyUserService.getUserCompanyId()` ✅ RLS로 보호됨

---

### 2.7 `sns_connections` 테이블

#### 현재 상태
- `sns_platform_connection_service.dart`: `getConnections()`, `getConnectionsByPlatform()`에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 본인의 SNS 연결 조회
CREATE POLICY "Users can view own sns_connections"
ON sns_connections FOR SELECT
USING (user_id = auth.uid());

-- 본인의 SNS 연결 생성
CREATE POLICY "Users can create own sns_connections"
ON sns_connections FOR INSERT
WITH CHECK (user_id = auth.uid());

-- 본인의 SNS 연결 업데이트
CREATE POLICY "Users can update own sns_connections"
ON sns_connections FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 본인의 SNS 연결 삭제
CREATE POLICY "Users can delete own sns_connections"
ON sns_connections FOR DELETE
USING (user_id = auth.uid());
```

**영향받는 메서드:**
- `SNSPlatformConnectionService.getConnections()` ✅ RLS로 보호됨
- `SNSPlatformConnectionService.getConnectionsByPlatform()` ✅ RLS로 보호됨
- `SNSPlatformConnectionService.createConnection()` ✅ 이미 RPC 사용 중
- `SNSPlatformConnectionService.updateConnection()` ✅ 이미 RPC 사용 중
- `SNSPlatformConnectionService.deleteConnection()` ✅ 이미 RPC 사용 중

---

### 2.8 `notifications` 테이블

#### 현재 상태
- `notification_service.dart`: 모든 메서드에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 본인의 알림 조회
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (user_id = auth.uid());

-- 본인의 알림 업데이트 (읽음 처리)
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 본인의 알림 삭제
CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
USING (user_id = auth.uid());

-- 시스템 알림 생성 (RPC 함수에서만 가능하도록)
-- RLS는 최소한으로 설정하고, 실제 권한 체크는 RPC 함수에서 수행
```

**영향받는 메서드:**
- `NotificationService.getUserNotifications()` ✅ RLS로 보호됨
- `NotificationService.markAsRead()` ✅ RLS로 보호됨
- `NotificationService.markAllAsRead()` ✅ RLS로 보호됨
- `NotificationService.getUnreadCount()` ✅ RLS로 보호됨
- `NotificationService.deleteNotification()` ✅ RLS로 보호됨
- `NotificationService.createNotification()` ⚠️ RPC로 변경 권장 (시스템용)

---

### 2.9 `companies` 테이블

#### 현재 상태
- `company_service.dart`: `getCompanyByUserId()`, `getPendingManagerRequest()`에서 직접 접근

#### 필요한 RLS 정책

```sql
-- 본인이 소속된 회사 조회
CREATE POLICY "Users can view own company"
ON companies FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM company_users
    WHERE company_users.company_id = companies.id
    AND company_users.user_id = auth.uid()
    AND company_users.status = 'active'
  )
);
```

**영향받는 메서드:**
- `CompanyService.getCompanyByUserId()` ⚠️ RPC로 변경 권장 (JOIN 포함)
- `CompanyService.getPendingManagerRequest()` ⚠️ RPC로 변경 권장 (복잡한 조회)
- `CompanyService.cancelManagerRequest()` ⚠️ RPC로 변경 권장

---

## 3. RPC 함수로 변경 필요 항목

### 3.1 우선순위: 높음 (보안/비즈니스 로직)

#### 3.1.1 `admin_get_users` - 관리자 사용자 목록 조회

**현재 상태:**
- `admin_service.dart`: `getUsers()` - 복잡한 JOIN (users, auth.users, company_users, sns_connections)

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION admin_get_users(
  p_search_query TEXT DEFAULT NULL,
  p_user_type_filter TEXT DEFAULT NULL,
  p_status_filter TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  display_name TEXT,
  user_type TEXT,
  status TEXT,
  company_id UUID,
  company_role TEXT,
  sns_connections JSONB,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 관리자 권한 확인
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND user_type = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    au.email,
    u.display_name,
    u.user_type,
    u.status,
    cu.company_id,
    cu.company_role,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', sc.id,
          'platform', sc.platform,
          'platform_account_id', sc.platform_account_id,
          'platform_account_name', sc.platform_account_name
        )
      ) FILTER (WHERE sc.id IS NOT NULL),
      '[]'::jsonb
    ) AS sns_connections,
    u.created_at,
    u.updated_at
  FROM users u
  LEFT JOIN auth.users au ON au.id = u.id
  LEFT JOIN company_users cu ON cu.user_id = u.id AND cu.status = 'active'
  LEFT JOIN sns_connections sc ON sc.user_id = u.id
  WHERE
    (p_search_query IS NULL OR 
     u.display_name ILIKE '%' || p_search_query || '%' OR
     au.email ILIKE '%' || p_search_query || '%')
    AND (p_user_type_filter IS NULL OR u.user_type = p_user_type_filter)
    AND (p_status_filter IS NULL OR u.status = p_status_filter)
  GROUP BY u.id, au.email, cu.company_id, cu.company_role
  ORDER BY u.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
```

**Flutter 변경:**

```dart
// lib/services/admin_service.dart
Future<List<app_user.User>> getUsers({...}) async {
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
    ) as List;

    return response.map<app_user.User>((data) {
      // 응답 데이터를 User 객체로 변환
      // ...
    }).toList();
  } catch (e) {
    // 에러 처리
  }
}
```

---

#### 3.1.2 `admin_update_user_status` - 사용자 상태 변경

**현재 상태:**
- `admin_service.dart`: `updateUserStatus()` - 직접 UPDATE

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION admin_update_user_status(
  p_user_id UUID,
  p_status TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 관리자 권한 확인
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND user_type = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- 상태 유효성 검증
  IF p_status NOT IN ('active', 'inactive', 'suspended', 'deleted') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  UPDATE users
  SET status = p_status,
      updated_at = NOW()
  WHERE id = p_user_id;

  RETURN FOUND;
END;
$$;
```

---

#### 3.1.3 `get_user_campaign_logs_safe` - 사용자 캠페인 로그 조회

**현재 상태:**
- `campaign_log_service.dart`: `getUserCampaignLogs()` - 복잡한 JOIN

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_user_campaign_logs_safe(
  p_user_id UUID,
  p_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  campaign_id UUID,
  user_id UUID,
  status TEXT,
  action JSONB,
  application_message TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  campaign JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 본인 또는 관리자만 조회 가능
  IF p_user_id != auth.uid() AND NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND user_type = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Can only view own campaign logs';
  END IF;

  RETURN QUERY
  SELECT
    cal.id,
    cal.campaign_id,
    cal.user_id,
    cal.status,
    cal.action,
    cal.application_message,
    cal.created_at,
    cal.updated_at,
    jsonb_build_object(
      'id', c.id,
      'title', c.title,
      'campaign_type', c.campaign_type,
      'product_image_url', c.product_image_url,
      'platform_logo_url', c.platform_logo_url,
      'platform', c.platform,
      'company', jsonb_build_object(
        'id', comp.id,
        'name', comp.business_name,
        'logo_url', comp.logo_url
      )
    ) AS campaign
  FROM campaign_action_logs cal
  INNER JOIN campaigns c ON c.id = cal.campaign_id
  INNER JOIN companies comp ON comp.id = c.company_id
  WHERE cal.user_id = p_user_id
    AND (p_status IS NULL OR cal.status = p_status)
  ORDER BY cal.updated_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
```

---

#### 3.1.4 `get_campaign_logs_safe` - 캠페인별 로그 조회 (광고주용)

**현재 상태:**
- `campaign_log_service.dart`: `getCampaignLogs()` - 복잡한 JOIN

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_campaign_logs_safe(
  p_campaign_id UUID,
  p_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  campaign_id UUID,
  user_id UUID,
  status TEXT,
  action JSONB,
  application_message TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  user JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 캠페인 소유자만 조회 가능
  IF NOT EXISTS (
    SELECT 1 FROM campaigns
    WHERE id = p_campaign_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Can only view logs of own campaigns';
  END IF;

  RETURN QUERY
  SELECT
    cal.id,
    cal.campaign_id,
    cal.user_id,
    cal.status,
    cal.action,
    cal.application_message,
    cal.created_at,
    cal.updated_at,
    jsonb_build_object(
      'id', u.id,
      'display_name', u.display_name,
      'email', au.email
    ) AS user
  FROM campaign_action_logs cal
  INNER JOIN users u ON u.id = cal.user_id
  LEFT JOIN auth.users au ON au.id = u.id
  WHERE cal.campaign_id = p_campaign_id
    AND (p_status IS NULL OR cal.status = p_status)
  ORDER BY cal.updated_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
```

---

#### 3.1.5 `get_user_stats` - 사용자 통계 조회

**현재 상태:**
- `user_service.dart`: `getUserStats()` - 클라이언트에서 통계 계산

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_user_stats(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_completed_count INTEGER;
  v_review_count INTEGER;
  v_level INTEGER;
BEGIN
  -- 본인 또는 관리자만 조회 가능
  IF p_user_id != auth.uid() AND NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND user_type = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Can only view own stats';
  END IF;

  -- 완료된 캠페인 수
  SELECT COUNT(*)
  INTO v_completed_count
  FROM campaign_action_logs
  WHERE user_id = p_user_id
    AND status = 'payment_completed';

  -- 리뷰 수
  SELECT COUNT(*)
  INTO v_review_count
  FROM campaign_action_logs
  WHERE user_id = p_user_id
    AND status IN ('review_submitted', 'review_approved');

  -- 레벨 계산 (완료된 캠페인 수 / 10 + 1)
  v_level := (v_completed_count / 10) + 1;

  RETURN jsonb_build_object(
    'level', v_level,
    'reviewCount', v_review_count,
    'completedCampaigns', v_completed_count
  );
END;
$$;
```

**Flutter 변경:**

```dart
// lib/services/user_service.dart
Future<Map<String, int>> getUserStats(String userId, {bool forceRefresh = false}) async {
  try {
    final response = await _supabase.rpc(
      'get_user_stats',
      params: {'p_user_id': userId},
    ) as Map<String, dynamic>;

    return {
      'level': response['level'] as int,
      'reviewCount': response['reviewCount'] as int,
      'completedCampaigns': response['completedCampaigns'] as int,
    };
  } catch (e) {
    // 에러 처리
    return {'level': 1, 'reviewCount': 0, 'completedCampaigns': 0};
  }
}
```

---

### 3.2 우선순위: 중간 (성능 최적화)

#### 3.2.1 `get_user_monthly_stats` - 개인 포인트 월별 통계

**현재 상태:**
- `wallet_service.dart`: `getUserMonthlyStats()` - 클라이언트에서 통계 계산

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_user_monthly_stats(
  p_user_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE (
  month TEXT,
  total_amount INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 본인만 조회 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only view own stats';
  END IF;

  RETURN QUERY
  SELECT
    TO_CHAR(created_at, 'YYYY-MM') AS month,
    SUM(amount) AS total_amount
  FROM point_transactions
  WHERE wallet_id IN (
    SELECT id FROM wallets
    WHERE user_id = p_user_id
    AND company_id IS NULL
  )
  AND created_at >= p_start_date
  AND created_at < p_end_date + INTERVAL '1 day'
  GROUP BY TO_CHAR(created_at, 'YYYY-MM')
  ORDER BY month;
END;
$$;
```

---

#### 3.2.2 `get_company_user_stats` - 회사 포인트 사용자별 통계

**현재 상태:**
- `wallet_service.dart`: `getCompanyUserStats()` - 클라이언트에서 통계 계산

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_company_user_stats(
  p_company_id UUID
)
RETURNS TABLE (
  user_name TEXT,
  total_amount INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 회사 소유자/매니저만 조회 가능
  IF NOT EXISTS (
    SELECT 1 FROM company_users
    WHERE company_id = p_company_id
    AND user_id = auth.uid()
    AND status = 'active'
    AND company_role IN ('owner', 'manager')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Company access required';
  END IF;

  RETURN QUERY
  SELECT
    u.display_name AS user_name,
    SUM(ABS(pt.amount)) AS total_amount
  FROM point_transactions pt
  INNER JOIN wallets w ON w.id = pt.wallet_id
  INNER JOIN users u ON u.id = w.user_id
  WHERE w.company_id = p_company_id
  GROUP BY u.display_name
  ORDER BY total_amount DESC;
END;
$$;
```

---

#### 3.2.3 `get_campaign_status_stats` - 캠페인 상태별 통계

**현재 상태:**
- `campaign_log_service.dart`: `getStatusStats()` - 클라이언트에서 통계 계산

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_campaign_status_stats(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 본인만 조회 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only view own stats';
  END IF;

  RETURN (
    SELECT jsonb_object_agg(status, count)
    FROM (
      SELECT status, COUNT(*) AS count
      FROM campaign_action_logs
      WHERE user_id = p_user_id
      GROUP BY status
    ) AS stats
  );
END;
$$;
```

---

#### 3.2.4 `check_deletion_eligibility` - 계정 삭제 가능 여부 확인

**현재 상태:**
- `account_deletion_service.dart`: `checkDeletionEligibility()` - 여러 테이블 조회

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION check_deletion_eligibility(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_type TEXT;
  v_company_id UUID;
  v_personal_points INTEGER;
  v_company_points INTEGER;
  v_active_campaigns INTEGER;
  v_other_owners_count INTEGER;
  v_has_deletion_request BOOLEAN;
BEGIN
  -- 본인만 조회 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only check own eligibility';
  END IF;

  -- 사용자 정보 조회
  SELECT user_type INTO v_user_type
  FROM users
  WHERE id = p_user_id;

  -- 회사 정보 조회
  SELECT company_id INTO v_company_id
  FROM company_users
  WHERE user_id = p_user_id
    AND status = 'active'
  LIMIT 1;

  -- 포인트 조회
  SELECT COALESCE(SUM(current_points), 0) INTO v_personal_points
  FROM wallets
  WHERE user_id = p_user_id
    AND company_id IS NULL;

  IF v_company_id IS NOT NULL THEN
    SELECT COALESCE(SUM(current_points), 0) INTO v_company_points
    FROM wallets
    WHERE company_id = v_company_id;

    -- 다른 오너 수 확인
    SELECT COUNT(*) INTO v_other_owners_count
    FROM company_users
    WHERE company_id = v_company_id
      AND user_id != p_user_id
      AND company_role = 'owner'
      AND status = 'active';
  END IF;

  -- 활성 캠페인 수
  SELECT COUNT(*) INTO v_active_campaigns
  FROM campaigns
  WHERE user_id = p_user_id
    AND status = 'active';

  -- 삭제 요청 여부
  SELECT EXISTS(
    SELECT 1 FROM deleted_users
    WHERE id = p_user_id
  ) INTO v_has_deletion_request;

  RETURN jsonb_build_object(
    'canDelete', true,
    'hasDeletionRequest', v_has_deletion_request,
    'userType', v_user_type,
    'companyId', v_company_id,
    'personalPoints', v_personal_points,
    'companyPoints', COALESCE(v_company_points, 0),
    'activeCampaigns', v_active_campaigns,
    'otherOwnersCount', COALESCE(v_other_owners_count, 0),
    'warnings', ARRAY[]::TEXT[],
    'errors', ARRAY[]::TEXT[]
  );
END;
$$;
```

---

#### 3.2.5 `backup_user_data` - 사용자 데이터 백업

**현재 상태:**
- `account_deletion_service.dart`: `backupUserData()` - 여러 테이블 조회

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION backup_user_data(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_backup JSONB;
BEGIN
  -- 본인만 백업 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only backup own data';
  END IF;

  SELECT jsonb_build_object(
    'user', (SELECT row_to_json(u.*) FROM users u WHERE u.id = p_user_id),
    'wallets', (
      SELECT jsonb_agg(row_to_json(w.*))
      FROM wallets w
      WHERE w.user_id = p_user_id
    ),
    'pointLogs', (
      SELECT jsonb_agg(row_to_json(pt.*))
      FROM point_transactions pt
      WHERE pt.wallet_id IN (
        SELECT id FROM wallets WHERE user_id = p_user_id
      )
    ),
    'campaigns', (
      SELECT jsonb_agg(row_to_json(c.*))
      FROM campaigns c
      WHERE c.user_id = p_user_id
    ),
    'campaignLogs', (
      SELECT jsonb_agg(row_to_json(cal.*))
      FROM campaign_action_logs cal
      WHERE cal.user_id = p_user_id
    ),
    'notifications', (
      SELECT jsonb_agg(row_to_json(n.*))
      FROM notifications n
      WHERE n.user_id = p_user_id
    ),
    'backupDate', NOW()
  ) INTO v_backup;

  RETURN v_backup;
END;
$$;
```

---

#### 3.2.6 `get_company_by_user_id` - 사용자 ID로 회사 정보 조회

**현재 상태:**
- `company_service.dart`: `getCompanyByUserId()` - JOIN 포함

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_company_by_user_id(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_company JSONB;
BEGIN
  -- 본인만 조회 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only view own company';
  END IF;

  SELECT jsonb_build_object(
    'id', c.id,
    'business_name', c.business_name,
    'business_number', c.business_number,
    'logo_url', c.logo_url,
    'status', cu.status,
    'company_role', cu.company_role
  )
  INTO v_company
  FROM companies c
  INNER JOIN company_users cu ON cu.company_id = c.id
  WHERE cu.user_id = p_user_id
    AND cu.status = 'active'
  LIMIT 1;

  RETURN v_company;
END;
$$;
```

---

#### 3.2.7 `get_pending_manager_request` - 매니저 등록 요청 상태 조회

**현재 상태:**
- `company_service.dart`: `getPendingManagerRequest()` - 복잡한 조회

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION get_pending_manager_request(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_request JSONB;
BEGIN
  -- 본인만 조회 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only view own request';
  END IF;

  SELECT jsonb_build_object(
    'id', c.id,
    'business_name', c.business_name,
    'business_number', c.business_number,
    'status', cu.status,
    'requested_at', cu.created_at
  )
  INTO v_request
  FROM companies c
  INNER JOIN company_users cu ON cu.company_id = c.id
  WHERE cu.user_id = p_user_id
    AND cu.company_role = 'manager'
    AND cu.status IN ('pending', 'rejected')
  LIMIT 1;

  RETURN v_request;
END;
$$;
```

---

#### 3.2.8 `cancel_manager_request` - 매니저 등록 요청 취소

**현재 상태:**
- `company_service.dart`: `cancelManagerRequest()` - 직접 DELETE

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION cancel_manager_request(
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 본인만 취소 가능
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only cancel own request';
  END IF;

  DELETE FROM company_users
  WHERE user_id = p_user_id
    AND status = 'pending'
    AND company_role = 'manager';

  RETURN FOUND;
END;
$$;
```

---

#### 3.2.9 `create_notification` - 알림 생성 (시스템용)

**현재 상태:**
- `notification_service.dart`: `createNotification()` - 직접 INSERT

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_related_campaign_id UUID DEFAULT NULL,
  p_related_campaign_log_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  -- 시스템 또는 관리자만 생성 가능
  -- (실제 구현 시 service_role 또는 관리자 권한 확인 필요)

  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    is_read,
    related_campaign_id,
    related_campaign_log_id,
    created_at
  )
  VALUES (
    p_user_id,
    p_type,
    p_title,
    p_message,
    false,
    p_related_campaign_id,
    p_related_campaign_log_id,
    NOW()
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;
```

---

### 3.3 우선순위: 낮음 (기존 RPC fallback 제거)

#### 3.3.1 `update_user_wallet_account` - 개인 지갑 계좌정보 업데이트

**현재 상태:**
- `wallet_service.dart`: `updateUserWalletAccount()` - RPC 시도 후 fallback

**변경 사항:**
- Fallback 로직 제거, RPC만 사용

---

#### 3.3.2 `update_company_wallet_account` - 회사 지갑 계좌정보 업데이트

**현재 상태:**
- `wallet_service.dart`: `updateCompanyWalletAccount()` - RPC 시도 후 fallback

**변경 사항:**
- Fallback 로직 제거, RPC만 사용

---

#### 3.3.3 `update_user_profile_safe` - 사용자 프로필 업데이트

**현재 상태:**
- `auth_service.dart`: `_ensureUserProfile()` - display_name 업데이트 부분 직접 UPDATE

**변경 사항:**
- `update_user_profile_safe` RPC 함수에 display_name 업데이트 로직 추가

---

### 3.4 버그 수정

#### 3.4.1 `cancel_application` - 신청 취소

**현재 상태:**
- `campaign_application_service.dart`: `cancelApplication()` - 잘못된 테이블 참조 (`campaign_events`)

**필요한 RPC 함수:**

```sql
CREATE OR REPLACE FUNCTION cancel_application(
  p_application_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 본인만 취소 가능
  IF NOT EXISTS (
    SELECT 1 FROM campaign_action_logs
    WHERE id = p_application_id
    AND user_id = auth.uid()
    AND status = 'applied'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Can only cancel own pending applications';
  END IF;

  -- 신청 삭제 (또는 상태 변경)
  DELETE FROM campaign_action_logs
  WHERE id = p_application_id
    AND user_id = auth.uid()
    AND status = 'applied';

  RETURN FOUND;
END;
$$;
```

---

## 4. 우선순위별 마이그레이션 계획

### 4.1 Phase 1: 보안 강화 (즉시)

1. **RLS 정책 추가**
   - `wallets` 테이블
   - `point_transactions` 테이블
   - `campaigns` 테이블
   - `campaign_action_logs` 테이블
   - `users` 테이블
   - `company_users` 테이블
   - `sns_connections` 테이블
   - `notifications` 테이블
   - `companies` 테이블

2. **관리자 기능 RPC 함수 생성**
   - `admin_get_users`
   - `admin_update_user_status`

### 4.2 Phase 2: 복잡한 조회 RPC화 (1주일 내)

1. **캠페인 로그 조회**
   - `get_user_campaign_logs_safe`
   - `get_campaign_logs_safe`

2. **통계 조회**
   - `get_user_stats`
   - `get_user_monthly_stats`
   - `get_company_user_stats`
   - `get_campaign_status_stats`

3. **계정 관리**
   - `check_deletion_eligibility`
   - `backup_user_data`

### 4.3 Phase 3: 기타 최적화 (2주일 내)

1. **회사 관련**
   - `get_company_by_user_id`
   - `get_pending_manager_request`
   - `cancel_manager_request`

2. **알림**
   - `create_notification`

3. **Fallback 제거**
   - `update_user_wallet_account` fallback 제거
   - `update_company_wallet_account` fallback 제거

4. **버그 수정**
   - `cancel_application` 테이블 참조 수정

---

## 5. 구현 가이드

### 5.1 RLS 정책 추가 방법

1. **마이그레이션 파일 생성**

```bash
npx supabase migration new add_rls_policies
```

2. **RLS 정책 작성**

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_rls_policies.sql

-- wallets 테이블 RLS 활성화
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- RLS 정책 추가
CREATE POLICY "Users can view own wallet"
ON wallets FOR SELECT
USING (user_id = auth.uid() AND company_id IS NULL);

-- ... (나머지 정책들)
```

3. **마이그레이션 적용**

```bash
npx supabase db reset
```

### 5.2 RPC 함수 생성 방법

1. **마이그레이션 파일 생성**

```bash
npx supabase migration new add_rpc_functions
```

2. **RPC 함수 작성**

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_rpc_functions.sql

CREATE OR REPLACE FUNCTION admin_get_users(...)
RETURNS TABLE (...)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 함수 로직
END;
$$;
```

3. **마이그레이션 적용**

```bash
npx supabase db reset
```

### 5.3 Flutter 서비스 수정 방법

1. **기존 메서드 수정**

```dart
// Before
Future<List<User>> getUsers({...}) async {
  final response = await _supabase
    .from('users')
    .select('...')
    .eq('...', '...');
  // ...
}

// After
Future<List<User>> getUsers({...}) async {
  final response = await _supabase.rpc(
    'admin_get_users',
    params: {
      'p_search_query': searchQuery,
      // ...
    },
  ) as List;
  // ...
}
```

2. **에러 처리 추가**

```dart
try {
  final response = await _supabase.rpc(...);
} catch (e) {
  if (e.toString().contains('Unauthorized')) {
    throw Exception('권한이 없습니다');
  }
  rethrow;
}
```

### 5.4 테스트 방법

1. **로컬 환경에서 테스트**

```bash
# Supabase 로컬 시작
npx supabase start

# 마이그레이션 적용
npx supabase db reset

# Flutter 앱 실행
flutter run -d chrome
```

2. **RLS 정책 테스트**

- 다른 사용자로 로그인하여 접근 불가 확인
- 관리자 권한으로 접근 가능 확인

3. **RPC 함수 테스트**

- Supabase 대시보드에서 직접 호출
- Flutter 앱에서 호출하여 동작 확인

---

## 6. 참고 사항

### 6.1 SECURITY DEFINER 주의사항

- `SECURITY DEFINER` 함수는 함수 소유자의 권한으로 실행됨
- 반드시 권한 체크 로직 포함 필요
- 민감한 작업은 `SECURITY INVOKER` 고려

### 6.2 성능 고려사항

- RPC 함수 내에서 인덱스 활용
- 불필요한 JOIN 최소화
- 페이지네이션 적용

### 6.3 에러 처리

- RPC 함수에서 명확한 에러 메시지 반환
- Flutter에서 에러 타입별 처리

---

## 7. 체크리스트

### 7.1 RLS 정책

- [ ] `wallets` 테이블
- [ ] `point_transactions` 테이블
- [ ] `campaigns` 테이블
- [ ] `campaign_action_logs` 테이블
- [ ] `users` 테이블
- [ ] `company_users` 테이블
- [ ] `sns_connections` 테이블
- [ ] `notifications` 테이블
- [ ] `companies` 테이블

### 7.2 RPC 함수

- [ ] `admin_get_users`
- [ ] `admin_update_user_status`
- [ ] `get_user_campaign_logs_safe`
- [ ] `get_campaign_logs_safe`
- [ ] `get_user_stats`
- [ ] `get_user_monthly_stats`
- [ ] `get_company_user_stats`
- [ ] `get_campaign_status_stats`
- [ ] `check_deletion_eligibility`
- [ ] `backup_user_data`
- [ ] `get_company_by_user_id`
- [ ] `get_pending_manager_request`
- [ ] `cancel_manager_request`
- [ ] `create_notification`
- [ ] `cancel_application`

### 7.3 Flutter 서비스 수정

- [ ] `AdminService.getUsers()`
- [ ] `AdminService.updateUserStatus()`
- [ ] `CampaignLogService.getUserCampaignLogs()`
- [ ] `CampaignLogService.getCampaignLogs()`
- [ ] `CampaignLogService.getStatusStats()`
- [ ] `UserService.getUserStats()`
- [ ] `WalletService.getUserMonthlyStats()`
- [ ] `WalletService.getCompanyUserStats()`
- [ ] `WalletService.updateUserWalletAccount()` (fallback 제거)
- [ ] `WalletService.updateCompanyWalletAccount()` (fallback 제거)
- [ ] `AccountDeletionService.checkDeletionEligibility()`
- [ ] `AccountDeletionService.backupUserData()`
- [ ] `CompanyService.getCompanyByUserId()`
- [ ] `CompanyService.getPendingManagerRequest()`
- [ ] `CompanyService.cancelManagerRequest()`
- [ ] `NotificationService.createNotification()`
- [ ] `CampaignApplicationService.cancelApplication()` (버그 수정)
- [ ] `AuthService._ensureUserProfile()` (display_name 업데이트)

---

## 8. 마이그레이션 순서 권장사항

1. **RLS 정책 먼저 추가** (보안 강화)
2. **기존 기능 테스트** (RLS로 인한 접근 제한 확인)
3. **RPC 함수 생성** (기능별로 단계적)
4. **Flutter 서비스 수정** (RPC 함수 사용)
5. **통합 테스트** (전체 플로우 확인)
6. **Fallback 제거** (안정화 후)

---

**작성 완료일**: 2025-01-15  
**다음 검토일**: 마이그레이션 완료 후

