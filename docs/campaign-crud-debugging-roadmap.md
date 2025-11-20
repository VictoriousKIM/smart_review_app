# 캠페인 생성/조회/삭제 문제 해결 로드맵

## 📋 개요

**문제 상황:**
- 캠페인 삭제 버튼을 눌렀을 때 "삭제됐다"는 메시지만 뜨고 실제로 삭제가 안 되는 문제
- 비활성화 상태이고 신청 인원이 0인 조건을 만족하는데도 삭제가 안 됨

**요구사항:**
- **하드 삭제**: 소프트 삭제가 아닌 실제 DELETE 수행
- **조건**: inactive 상태이고 참여자 수가 0일 때만 삭제 가능
- **권한**: 캠페인 소유 회사의 **owner** 또는 **캠페인을 생성한 매니저만** 삭제 가능
- **포인트 환불**: 삭제 시 캠페인 생성에 소요된 포인트를 환불
- **트랜잭션 기록**: 포인트 트랜잭션에 refund 타입으로 기록
- **로그 기록**: 삭제 로그 추가

**작업 목적:**
- 캠페인 생성, 조회, 삭제의 전체 흐름을 분석
- 하드 삭제 및 포인트 환불 로직 구현
- 문제점을 파악하고 해결 방안 제시

---

## 🔍 현재 상태 분석

### 1. 삭제 기능 흐름

#### 1.1 UI 레벨 (AdvertiserCampaignDetailScreen)
```dart
// 삭제 버튼 조건
onPressed: campaign.status != CampaignStatus.inactive
    ? null
    : () => _handleDelete(context, campaign),

// 삭제 처리
Future<void> _handleDelete(BuildContext context, Campaign campaign) async {
  // 1. 확인 다이얼로그
  final confirmed = await showDialog<bool>(...);
  
  // 2. 삭제 API 호출
  final result = await _campaignService.deleteCampaign(campaign.id);
  
  // 3. 성공 시 목록 화면으로 이동
  if (result.success) {
    context.go('/mypage/advertiser/my-campaigns');
  }
}
```

**문제점:**
- ✅ 삭제 성공 메시지는 표시됨
- ❌ 목록 화면으로 이동하지만 목록이 새로고침되지 않음
- ❌ Provider가 무효화되지 않음

#### 1.2 서비스 레벨 (CampaignService)
```dart
Future<ApiResponse<void>> deleteCampaign(String campaignId) async {
  try {
    final response = await _supabase.rpc(
      'delete_campaign',
      params: {'p_campaign_id': campaignId},
    );
    
    if (response['success'] == true) {
      return ApiResponse<void>(
        success: true,
        message: response['message'] ?? '캠페인이 삭제되었습니다',
      );
    }
    
    return ApiResponse<void>(
      success: false,
      error: response['error'] ?? '캠페인 삭제에 실패했습니다',
    );
  } catch (e) {
    return ApiResponse<void>(
      success: false,
      error: '캠페인 삭제 중 오류가 발생했습니다: ${e.toString()}',
    );
  }
}
```

**문제점:**
- ✅ RPC 함수 호출은 정상
- ❌ 에러 처리 로직 확인 필요
- ❌ 실제 삭제 여부 확인 로직 없음

#### 1.3 데이터베이스 레벨 (RPC Function)
```sql
CREATE OR REPLACE FUNCTION delete_campaign(
  p_campaign_id UUID
)
RETURNS JSONB
AS $$
DECLARE
  v_current_participants INTEGER;
BEGIN
  -- 1. 권한 확인
  -- 2. 캠페인 소유권 확인
  -- 3. 참여자 수 확인
  IF v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 캠페인은 삭제할 수 없습니다';
  END IF;
  
  -- 4. 소프트 삭제 (status를 inactive로 변경)
  UPDATE public.campaigns
  SET status = 'inactive',
      updated_at = NOW()
  WHERE id = p_campaign_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'message', '캠페인이 삭제되었습니다'
  );
END;
$$;
```

**문제점:**
- ✅ 소프트 삭제 로직은 정상
- ❌ 실제로 UPDATE가 실행되었는지 확인 필요
- ❌ 참여자 수 체크 로직 확인 필요

### 2. 조회 기능 흐름

#### 2.1 광고주 캠페인 목록 조회
```dart
// AdvertiserMyCampaignsScreen
Future<void> _loadCampaigns() async {
  final response = await _campaignService.getCampaignsByCompanyId();
  // ...
  _allCampaigns = response.data ?? [];
  _updateFilteredCampaigns();
}
```

**문제점:**
- ❌ 삭제 후 목록이 자동으로 새로고침되지 않음
- ❌ Provider 무효화가 없음

#### 2.2 캠페인 상세 조회
```dart
// CampaignDetailProvider
final campaignDetailProvider = FutureProvider.family<...>((ref, campaignId) async {
  return await campaignService.getCampaignById(campaignId);
});
```

**문제점:**
- ❌ 삭제 후 Provider가 무효화되지 않음

### 3. 생성 기능 흐름

#### 3.1 캠페인 생성
```dart
// CampaignCreationScreen
final response = await _campaignService.createCampaignV2(...);
if (response.success) {
  context.go('/mypage/advertiser/my-campaigns');
}
```

**문제점:**
- ❌ 생성 후 목록이 자동으로 새로고침되지 않음

---

## 🎯 문제점 요약

### 문제 1: 삭제 후 UI 업데이트 안 됨
- **원인:** 삭제 성공 후 목록 화면으로 이동하지만 목록이 새로고침되지 않음
- **영향:** 사용자가 삭제가 안 된 것으로 인식

### 문제 2: Provider 무효화 없음
- **원인:** 삭제 후 관련 Provider가 무효화되지 않음
- **영향:** 캐시된 데이터가 계속 표시됨

### 문제 3: 실제 삭제 여부 확인 없음
- **원인:** RPC 함수 호출 후 실제로 삭제되었는지 확인하지 않음
- **영향:** 에러가 발생해도 성공으로 처리될 수 있음

### 문제 4: 소프트 삭제 vs 하드 삭제
- **원인:** 현재 소프트 삭제(status를 inactive로 변경)를 사용하지만, 요구사항은 하드 삭제
- **영향:** 삭제된 캠페인이 데이터베이스에 남아있음

### 문제 5: 포인트 환불 없음
- **원인:** 삭제 시 캠페인 생성에 소요된 포인트를 환불하지 않음
- **영향:** 사용자가 포인트 손실을 경험할 수 있음

---

## 📝 해결 방안

### Phase 1: 삭제 기능 개선

#### 1.1 삭제 후 목록 새로고침
- **파일:** `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`
- **작업 내용:**
  - 삭제 성공 시 목록 화면으로 이동하면서 새로고침 트리거
  - `context.go()` 대신 `context.pop(true)` 사용하여 결과 전달
  - 목록 화면에서 결과를 받아 새로고침

#### 1.2 Provider 무효화
- **파일:** `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`
- **작업 내용:**
  - 삭제 성공 시 관련 Provider 무효화
  - `ref.invalidate(campaignDetailProvider(widget.campaignId))`
  - 목록 Provider도 무효화

#### 1.3 실제 삭제 여부 확인
- **파일:** `lib/services/campaign_service.dart`
- **작업 내용:**
  - RPC 함수 호출 후 실제로 삭제되었는지 확인
  - `getCampaignById`로 재조회하여 status 확인
  - 삭제 실패 시 에러 메시지 개선

### Phase 2: 조회 기능 개선

#### 2.1 목록 새로고침 로직 개선
- **파일:** `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- **작업 내용:**
  - 상세 화면에서 돌아올 때 결과를 받아 새로고침
  - `context.pushNamed().then((result) => ...)` 패턴 사용

#### 2.2 필터링 로직 확인
- **파일:** `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- **작업 내용:**
  - inactive 상태 캠페인이 목록에서 제외되는지 확인
  - "종료" 탭에만 표시되는지 확인

### Phase 3: 생성 기능 개선

#### 3.1 생성 후 목록 새로고침
- **파일:** `lib/screens/campaign/campaign_creation_screen.dart`
- **작업 내용:**
  - 생성 성공 시 목록 화면으로 이동하면서 새로고침 트리거
  - `context.go()` 대신 결과 전달 패턴 사용

### Phase 4: 데이터베이스 함수 개선 (하드 삭제 + 포인트 환불)

#### 4.1 포인트 트랜잭션 타입 확장
- **파일:** `supabase/migrations/YYYYMMDDHHMMSS_add_refund_transaction_type.sql`
- **작업 내용:**
  - `point_transactions.transaction_type`에 'refund' 추가
  - CHECK 제약 조건 수정: `('earn', 'spend', 'refund')`

#### 4.2 삭제 함수 재작성 (하드 삭제 + 포인트 환불)
- **파일:** `supabase/migrations/YYYYMMDDHHMMSS_improve_delete_campaign_function.sql`
- **작업 내용:**
  - 소프트 삭제 → 하드 삭제 (DELETE)로 변경
  - inactive 상태 확인 추가
  - 참여자 수 0 확인
  - 캠페인 생성 시 사용된 포인트 조회 (`total_cost`)
  - 회사 지갑에 포인트 환불 (current_points 증가)
  - 포인트 트랜잭션에 refund 타입으로 기록
  - 삭제 로그 추가
  - 트랜잭션 처리 (원자성 보장)

---

## 🔧 구현 세부사항

### 1. 삭제 후 목록 새로고침 구현

#### 1.1 AdvertiserCampaignDetailScreen 수정
```dart
Future<void> _handleDelete(BuildContext context, Campaign campaign) async {
  // ... 확인 다이얼로그 ...
  
  final result = await _campaignService.deleteCampaign(campaign.id);
  
  if (!mounted) return;
  
  if (result.success) {
    // Provider 무효화
    ref.invalidate(campaignDetailProvider(widget.campaignId));
    
    // 실제 삭제 여부 확인
    final verifyResult = await _campaignService.getCampaignById(campaign.id);
    if (verifyResult.success && verifyResult.data != null) {
      final updatedCampaign = verifyResult.data!;
      if (updatedCampaign.status == CampaignStatus.inactive) {
        // 삭제 성공 - 목록 화면으로 이동하면서 새로고침 트리거
        setState(() {
          _hasChanges = true; // 변경사항 있음 표시
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '캠페인이 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 목록 화면으로 이동하면서 새로고침 트리거
        context.pop(true); // true를 반환하여 새로고침 필요함을 알림
      } else {
        // 삭제 실패
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캠페인 삭제에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // 캠페인을 찾을 수 없음 = 삭제 성공
      setState(() {
        _hasChanges = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '캠페인이 삭제되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
      
      context.pop(true);
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.error ?? '캠페인 삭제에 실패했습니다'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

#### 1.2 AdvertiserMyCampaignsScreen 수정
```dart
// 상세 화면으로 이동
onTap: () async {
  final result = await context.pushNamed(
    'advertiser-campaign-detail',
    pathParameters: {'id': campaign.id},
  );
  
  // 삭제 또는 수정이 있었으면 목록 새로고침
  if (result == true) {
    _loadCampaigns();
  }
},
```

### 2. 삭제 함수 재작성 (하드 삭제 + 포인트 환불)

#### 2.1 포인트 트랜잭션 타입 확장
```sql
-- point_transactions 테이블의 transaction_type에 'refund' 추가
ALTER TABLE public.point_transactions
  DROP CONSTRAINT IF EXISTS point_transactions_transaction_type_check;

ALTER TABLE public.point_transactions
  ADD CONSTRAINT point_transactions_transaction_type_check 
  CHECK (transaction_type = ANY (ARRAY['earn'::text, 'spend'::text, 'refund'::text]));
```

#### 2.2 삭제 함수 재작성
```sql
CREATE OR REPLACE FUNCTION delete_campaign(
  p_campaign_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_user_role TEXT;
  v_campaign_company_id UUID;
  v_campaign_status TEXT;
  v_campaign_user_id UUID;
  v_current_participants INTEGER;
  v_total_cost INTEGER;
  v_wallet_id UUID;
  v_current_points INTEGER;
  v_refund_amount INTEGER;
  v_rows_affected INTEGER;
BEGIN
  -- 1. 현재 사용자 확인
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 2. 사용자의 회사 ID 및 역할 조회
  SELECT cu.company_id, cu.company_role INTO v_company_id, v_user_role
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았거나 권한이 없습니다';
  END IF;

  -- 3. 캠페인 정보 조회 (소유권, 상태, 참여자 수, 총 비용, 생성자, 제목)
  SELECT company_id, status, current_participants, total_cost, user_id, title
  INTO v_campaign_company_id, v_campaign_status, v_current_participants, v_total_cost, v_campaign_user_id, v_campaign_title
  FROM public.campaigns
  WHERE id = p_campaign_id
  FOR UPDATE; -- 행 잠금으로 동시성 제어

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 삭제할 권한이 없습니다';
  END IF;

  -- 4. 삭제 권한 확인: owner이거나, 캠페인을 생성한 매니저만 삭제 가능
  IF v_user_role = 'manager' AND v_campaign_user_id != v_user_id THEN
    RAISE EXCEPTION '캠페인을 생성한 매니저만 삭제할 수 있습니다';
  END IF;

  -- 5. 상태 확인 (inactive만 삭제 가능)
  IF v_campaign_status != 'inactive' THEN
    RAISE EXCEPTION '비활성화된 캠페인만 삭제할 수 있습니다 (현재 상태: %)', v_campaign_status;
  END IF;

  -- 6. 참여자 수 확인
  IF v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 캠페인은 삭제할 수 없습니다 (참여자 수: %)', v_current_participants;
  END IF;

  -- 7. 회사 지갑 조회
  SELECT id, current_points
  INTO v_wallet_id, v_current_points
  FROM public.wallets
  WHERE company_id = v_company_id
    AND user_id IS NULL
  FOR UPDATE; -- 행 잠금

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
  END IF;

  -- 8. 포인트 환불 (total_cost가 있는 경우만)
  v_refund_amount := COALESCE(v_total_cost, 0);
  
  IF v_refund_amount > 0 THEN
    -- 지갑 잔액 증가
    UPDATE public.wallets
    SET current_points = current_points + v_refund_amount,
        updated_at = NOW()
    WHERE id = v_wallet_id;

    -- 포인트 트랜잭션 기록 (refund 타입)
    -- 주의: campaign_id는 포함하지만, 캠페인 삭제 시 ON DELETE SET NULL로 인해 NULL로 변경됨
    -- 따라서 description에 캠페인 정보를 포함하여 추적 가능하도록 함
    INSERT INTO public.point_transactions (
      wallet_id,
      transaction_type,
      amount,
      campaign_id, -- 삭제 전이므로 참조 가능, 삭제 후 NULL로 변경됨
      description,
      created_by_user_id,
      created_at,
      completed_at
    ) VALUES (
      v_wallet_id,
      'refund',
      v_refund_amount, -- 양수로 기록 (환불)
      p_campaign_id, -- 삭제 전이므로 참조 가능
      '캠페인 삭제 환불: ' || v_campaign_title || ' (캠페인 ID: ' || p_campaign_id::text || ')',
      v_user_id,
      NOW(),
      NOW()
    );
  END IF;

  -- 9. 하드 삭제 (실제 DELETE)
  -- 주의: point_transactions.campaign_id는 ON DELETE SET NULL로 설정되어 있어
  -- 캠페인 삭제 시 자동으로 NULL로 변경됨
  -- 하지만 description에 캠페인 정보가 포함되어 있어 추적 가능
  DELETE FROM public.campaigns
  WHERE id = p_campaign_id;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION '캠페인 삭제에 실패했습니다';
  END IF;

  -- 10. 결과 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'message', '캠페인이 삭제되었습니다',
    'refund_amount', v_refund_amount,
    'rows_affected', v_rows_affected
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

COMMENT ON FUNCTION delete_campaign IS '캠페인 하드 삭제 (inactive 상태이고 참여자가 없을 때만 가능, 포인트 환불 포함)';
```

### 3. 트랜잭션 처리

#### 3.1 원자성 보장
- 함수 내부에서 모든 작업을 수행하여 원자성 보장
- 에러 발생 시 자동 롤백
- FOR UPDATE로 행 잠금하여 동시성 제어

#### 3.2 포인트 환불 로직
- `total_cost` 필드에서 환불 금액 조회
- 회사 지갑 잔액 증가
- 포인트 트랜잭션에 'refund' 타입으로 기록
- 트리거가 자동으로 지갑 잔액 업데이트하는 경우 주의 필요

---

## 📊 테스트 시나리오

### 시나리오 1: 정상 삭제 (포인트 환불 포함)
1. 비활성화 상태이고 참여자 수가 0인 캠페인 선택
2. 삭제 버튼 클릭
3. 확인 다이얼로그에서 "삭제" 선택
4. **예상 결과:**
   - 삭제 성공 메시지 표시
   - 포인트 환불 완료 (회사 지갑 잔액 증가)
   - 포인트 트랜잭션에 refund 기록
   - 목록 화면으로 이동
   - 목록에서 해당 캠페인이 완전히 제거됨 (하드 삭제)

### 시나리오 2: 참여자가 있는 캠페인 삭제 시도
1. 참여자 수가 1 이상인 캠페인 선택
2. 삭제 버튼 클릭 (비활성화 상태)
3. **예상 결과:**
   - 삭제 버튼이 비활성화되어 있음
   - 또는 삭제 시도 시 에러 메시지 표시

### 시나리오 3: 활성화 상태 캠페인 삭제 시도
1. 활성화 상태인 캠페인 선택
2. 삭제 버튼 클릭
3. **예상 결과:**
   - 삭제 버튼이 비활성화되어 있음
   - "비활성화된 캠페인만 삭제할 수 있습니다" 메시지 표시

### 시나리오 4: 삭제 후 목록 새로고침
1. 캠페인 삭제 성공
2. 목록 화면으로 이동
3. **예상 결과:**
   - 목록이 자동으로 새로고침됨
   - 삭제된 캠페인이 목록에서 제거됨

---

## ⚠️ 주의사항

### 1. 하드 삭제
- 실제 DELETE 수행으로 데이터베이스에서 완전히 제거
- CASCADE로 관련 데이터도 함께 삭제됨 (campaign_action_logs 등)
- 삭제 후 복구 불가능

### 2. 참여자 수 체크
- `current_participants`만 체크하는 것이 정확한지 확인
- `campaign_action_logs` 테이블에서 실제 참여자 수 확인 필요

### 3. 권한 체크
- 소유권 확인 로직이 정확한지 확인
- RLS 정책과 충돌하지 않는지 확인

### 4. 포인트 트랜잭션의 campaign_id 처리
- **현재 제약 조건:** `ON DELETE SET NULL`
- **동작:** 캠페인 삭제 시 `point_transactions.campaign_id`가 자동으로 NULL로 변경됨
- **해결 방안:**
  - 포인트 트랜잭션 INSERT 시 `campaign_id` 포함 (삭제 전이므로 참조 가능)
  - `description`에 캠페인 제목과 ID를 포함하여 추적 가능하도록 함
  - 삭제 후 `campaign_id`는 NULL이 되지만, `description`으로 어떤 캠페인에 대한 환불인지 확인 가능

---

## 📝 관련 파일

### Flutter 화면
1. `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart` (수정)
2. `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart` (수정)
3. `lib/screens/campaign/campaign_creation_screen.dart` (수정)

### Flutter 서비스
4. `lib/services/campaign_service.dart` (수정)

### 데이터베이스
5. `supabase/migrations/YYYYMMDDHHMMSS_add_refund_transaction_type.sql` (신규)
6. `supabase/migrations/YYYYMMDDHHMMSS_improve_delete_campaign_function.sql` (신규)

---

**작성 일자:** 2025-11-20  
**작성자:** AI Assistant  
**상태:** 로드맵 작성 완료, 구현 대기

