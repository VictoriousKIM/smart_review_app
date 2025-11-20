# 광고주 캠페인 디테일 페이지 구현 로드맵

## 📋 목표

`/mypage/advertiser/my-campaigns` 화면의 캠페인 카드를 클릭하면 광고주 전용 캠페인 디테일 페이지로 이동하여 다음 기능을 제공:

1. 캠페인 상세 정보 표시
2. 활성화/비활성화 토글 기능
3. 캠페인 삭제 기능 (비활성화 + 참여자가 없는 경우)

---

## 🎯 작업 항목

### Phase 1: 데이터베이스 및 백엔드 준비

#### 1.1 캠페인 상태 업데이트 RPC 함수 생성
- **파일:** `supabase/migrations/YYYYMMDDHHMMSS_update_campaign_status.sql`
- **작업 내용:**
  - 캠페인 상태 업데이트 함수 생성
  - 권한 확인 (소유자/매니저만 가능)
  - 참여자 수 확인 로직 포함

```sql
-- 캠페인 상태 업데이트 함수
CREATE OR REPLACE FUNCTION update_campaign_status(
  p_campaign_id UUID,
  p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_campaign_company_id UUID;
  v_current_participants INTEGER;
BEGIN
  -- 1. 현재 사용자 확인
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 2. 사용자의 회사 ID 조회
  SELECT cu.company_id INTO v_company_id
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았거나 권한이 없습니다';
  END IF;

  -- 3. 캠페인 소유권 확인
  SELECT company_id, current_participants
  INTO v_campaign_company_id, v_current_participants
  FROM public.campaigns
  WHERE id = p_campaign_id;

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 수정할 권한이 없습니다';
  END IF;

  -- 4. 상태 유효성 검증
  IF p_status NOT IN ('active', 'inactive') THEN
    RAISE EXCEPTION '유효하지 않은 상태입니다';
  END IF;

  -- 5. 상태 업데이트
  UPDATE public.campaigns
  SET status = p_status,
      updated_at = NOW()
  WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'status', p_status
  );
END;
$$;
```

#### 1.2 캠페인 삭제 RPC 함수 생성
- **파일:** 동일 마이그레이션 파일
- **작업 내용:**
  - 캠페인 삭제 함수 생성
  - 참여자 수 확인 (0명일 때만 삭제 가능)
  - 실제 삭제 대신 `status = 'inactive'`로 변경 (소프트 삭제)

```sql
-- 캠페인 삭제 함수 (소프트 삭제)
CREATE OR REPLACE FUNCTION delete_campaign(
  p_campaign_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_campaign_company_id UUID;
  v_current_participants INTEGER;
BEGIN
  -- 1. 현재 사용자 확인
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 2. 사용자의 회사 ID 조회
  SELECT cu.company_id INTO v_company_id
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았거나 권한이 없습니다';
  END IF;

  -- 3. 캠페인 소유권 및 참여자 수 확인
  SELECT company_id, current_participants
  INTO v_campaign_company_id, v_current_participants
  FROM public.campaigns
  WHERE id = p_campaign_id;

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 삭제할 권한이 없습니다';
  END IF;

  -- 4. 참여자 수 확인
  IF v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 캠페인은 삭제할 수 없습니다';
  END IF;

  -- 5. 소프트 삭제 (status를 inactive로 변경)
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

---

### Phase 2: Flutter 서비스 함수 추가

#### 2.1 CampaignService에 상태 업데이트 함수 추가
- **파일:** `lib/services/campaign_service.dart`
- **작업 내용:**
  - `updateCampaignStatus` 함수 추가
  - RPC 함수 호출

```dart
/// 캠페인 상태 업데이트
Future<ApiResponse<Campaign>> updateCampaignStatus({
  required String campaignId,
  required CampaignStatus status,
}) async {
  try {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      return ApiResponse<Campaign>(
        success: false,
        error: '로그인이 필요합니다.',
      );
    }

    final response = await _supabase.rpc(
      'update_campaign_status',
      params: {
        'p_campaign_id': campaignId,
        'p_status': status.name,
      },
    );

    if (response['success'] == true) {
      // 업데이트된 캠페인 조회
      final updatedCampaign = await getCampaignById(campaignId);
      return updatedCampaign;
    } else {
      return ApiResponse<Campaign>(
        success: false,
        error: response['error'] ?? '상태 업데이트에 실패했습니다',
      );
    }
  } catch (e) {
    return ApiResponse<Campaign>(
      success: false,
      error: '상태 업데이트 중 오류가 발생했습니다: ${e.toString()}',
    );
  }
}
```

#### 2.2 CampaignService에 삭제 함수 추가
- **파일:** `lib/services/campaign_service.dart`
- **작업 내용:**
  - `deleteCampaign` 함수 추가
  - RPC 함수 호출

```dart
/// 캠페인 삭제 (소프트 삭제)
Future<ApiResponse<void>> deleteCampaign(String campaignId) async {
  try {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      return ApiResponse<void>(
        success: false,
        error: '로그인이 필요합니다.',
      );
    }

    final response = await _supabase.rpc(
      'delete_campaign',
      params: {
        'p_campaign_id': campaignId,
      },
    );

    if (response['success'] == true) {
      return ApiResponse<void>(
        success: true,
        message: response['message'] ?? '캠페인이 삭제되었습니다',
      );
    } else {
      return ApiResponse<void>(
        success: false,
        error: response['error'] ?? '캠페인 삭제에 실패했습니다',
      );
    }
  } catch (e) {
    return ApiResponse<void>(
      success: false,
      error: '캠페인 삭제 중 오류가 발생했습니다: ${e.toString()}',
    );
  }
}
```

---

### Phase 3: 광고주 전용 캠페인 디테일 페이지 생성

#### 3.1 새로운 화면 파일 생성
- **파일:** `lib/screens/mypage/advertiser/advertiser_campaign_detail_screen.dart`
- **작업 내용:**
  - 광고주 전용 캠페인 디테일 화면 구현
  - 캠페인 정보 표시
  - 활성화/비활성화 토글
  - 삭제 버튼

**주요 구성 요소:**
1. **캠페인 정보 섹션**
   - 제목, 설명
   - 제품 이미지
   - 플랫폼, 캠페인 타입
   - 시작일, 종료일, 만료일
   - 참여자 수 (현재/최대)
   - 리워드 정보
   - 상태 표시

2. **액션 섹션**
   - 활성화/비활성화 토글 스위치
   - 삭제 버튼 (참여자가 0명일 때만 활성화)

3. **UI 구성**
   - AppBar (뒤로가기, 제목)
   - SingleChildScrollView
   - 정보 카드들
   - 액션 버튼들

#### 3.2 Provider 추가 (선택사항)
- **파일:** `lib/providers/campaign_provider.dart`
- **작업 내용:**
  - 광고주 캠페인 디테일 Provider 추가 (기존 Provider 재사용 가능)

---

### Phase 4: 라우터 설정

#### 4.1 라우터에 경로 추가
- **파일:** `lib/config/app_router.dart`
- **작업 내용:**
  - `/mypage/advertiser/my-campaigns/:id` 경로 추가

```dart
GoRoute(
  path: '/mypage/advertiser/my-campaigns',
  name: 'advertiser-my-campaigns',
  builder: (context, state) {
    final initialTab = state.uri.queryParameters['tab'];
    return AdvertiserMyCampaignsScreen(initialTab: initialTab);
  },
  routes: [
    GoRoute(
      path: 'create',
      name: 'advertiser-my-campaigns-create',
      builder: (context, state) => const CampaignCreationScreen(),
    ),
    GoRoute(
      path: ':id',
      name: 'advertiser-campaign-detail',
      builder: (context, state) {
        final campaignId = state.pathParameters['id']!;
        return AdvertiserCampaignDetailScreen(campaignId: campaignId);
      },
    ),
  ],
),
```

---

### Phase 5: 캠페인 목록 화면 수정

#### 5.1 캠페인 카드 클릭 이벤트 수정
- **파일:** `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- **작업 내용:**
  - 카드 클릭 시 광고주 디테일 페이지로 이동하도록 변경

```dart
// 변경 전
onTap: () => context.go('/campaigns/${campaign.id}'),

// 변경 후
onTap: () => context.go('/mypage/advertiser/my-campaigns/${campaign.id}'),
```

---

### Phase 6: UI/UX 개선

#### 6.1 토글 스위치 디자인
- **위치:** `advertiser_campaign_detail_screen.dart`
- **작업 내용:**
  - 활성화/비활성화 상태에 따른 색상 변경
  - 로딩 상태 표시
  - 확인 다이얼로그 (상태 변경 시)

#### 6.2 삭제 버튼 디자인
- **위치:** `advertiser_campaign_detail_screen.dart`
- **작업 내용:**
  - 참여자가 있을 때 비활성화
  - 삭제 확인 다이얼로그
  - 삭제 후 목록 화면으로 이동

#### 6.3 에러 처리
- **작업 내용:**
  - 상태 업데이트 실패 시 에러 메시지 표시
  - 삭제 실패 시 에러 메시지 표시
  - 권한 없음 에러 처리

---

## 📝 구현 세부사항

### 캠페인 정보 표시 항목

1. **기본 정보**
   - 제목
   - 설명
   - 제품 이미지
   - 플랫폼
   - 캠페인 타입

2. **일정 정보**
   - 시작일
   - 종료일
   - 만료일

3. **참여 정보**
   - 현재 참여자 수
   - 최대 참여자 수
   - 참여율 (진행률 바)

4. **리워드 정보**
   - 리뷰 리워드 (OP)
   - 제품 가격

5. **상태 정보**
   - 현재 상태 (활성화/비활성화)
   - 상태 배지

### 활성화/비활성화 토글

- **위치:** 화면 하단 고정 영역
- **동작:**
  1. 현재 상태 표시
  2. 토글 스위치로 상태 변경
  3. 확인 다이얼로그 표시
  4. 상태 업데이트 API 호출
  5. 성공 시 화면 새로고침

### 삭제 버튼

- **위치:** 화면 하단 (토글 아래)
- **조건:**
  - `current_participants == 0`일 때만 활성화
  - 참여자가 있으면 비활성화 + 툴팁 표시
- **동작:**
  1. 삭제 확인 다이얼로그 표시
  2. 확인 시 삭제 API 호출
  3. 성공 시 목록 화면으로 이동
  4. 목록 화면 새로고침

---

## 🔄 상태 흐름

### 상태 업데이트 흐름
```
사용자 토글 클릭
  ↓
확인 다이얼로그 표시
  ↓
사용자 확인
  ↓
로딩 표시
  ↓
updateCampaignStatus API 호출
  ↓
성공 → 화면 새로고침
실패 → 에러 메시지 표시
```

### 삭제 흐름
```
사용자 삭제 버튼 클릭
  ↓
참여자 수 확인 (0명인지)
  ↓
삭제 확인 다이얼로그 표시
  ↓
사용자 확인
  ↓
로딩 표시
  ↓
deleteCampaign API 호출
  ↓
성공 → 목록 화면으로 이동 + 새로고침
실패 → 에러 메시지 표시
```

---

## ✅ 검증 항목

### 기능 검증
- [ ] 캠페인 정보가 정확히 표시되는가?
- [ ] 활성화/비활성화 토글이 정상 작동하는가?
- [ ] 상태 변경 시 확인 다이얼로그가 표시되는가?
- [ ] 삭제 버튼이 참여자 수에 따라 활성화/비활성화되는가?
- [ ] 삭제 시 확인 다이얼로그가 표시되는가?
- [ ] 권한이 없는 사용자는 접근할 수 없는가?

### 에러 처리 검증
- [ ] 네트워크 오류 시 적절한 메시지가 표시되는가?
- [ ] 권한 오류 시 적절한 메시지가 표시되는가?
- [ ] 참여자가 있는 캠페인 삭제 시도 시 에러가 표시되는가?

### UI/UX 검증
- [ ] 로딩 상태가 적절히 표시되는가?
- [ ] 상태 변경 후 화면이 새로고침되는가?
- [ ] 삭제 후 목록 화면으로 올바르게 이동하는가?

---

## 📅 구현 순서

1. **Phase 1: 데이터베이스 및 백엔드 준비** (1-2일)
   - RPC 함수 생성 및 테스트

2. **Phase 2: Flutter 서비스 함수 추가** (0.5일)
   - CampaignService 함수 추가

3. **Phase 3: 광고주 전용 캠페인 디테일 페이지 생성** (2-3일)
   - 화면 구현
   - UI 구성

4. **Phase 4: 라우터 설정** (0.5일)
   - 라우터 경로 추가

5. **Phase 5: 캠페인 목록 화면 수정** (0.5일)
   - 카드 클릭 이벤트 수정

6. **Phase 6: UI/UX 개선** (1일)
   - 다이얼로그 추가
   - 에러 처리
   - 로딩 상태

**총 예상 기간:** 5-7일

---

## 📌 참고사항

### 보안 고려사항
- RPC 함수에서 반드시 권한 확인
- 회사 소유권 확인
- 역할 확인 (owner, manager만 가능)

### 데이터 무결성
- 삭제는 소프트 삭제로 구현 (실제 삭제 대신 status 변경)
- 참여자가 있는 캠페인은 삭제 불가

### 사용자 경험
- 상태 변경 시 확인 다이얼로그로 실수 방지
- 삭제 시 확인 다이얼로그로 실수 방지
- 로딩 상태 표시로 사용자 피드백 제공

---

**작성일:** 2025-01-16  
**작성자:** AI Assistant

