# 캠페인 생성 후 목록 표시 문제 및 Status 처리 분석

## 📋 목차
1. [문제 개요](#문제-개요)
2. [캠페인 생성 후 목록 표시 문제 분석](#캠페인-생성-후-목록-표시-문제-분석)
3. [캠페인 Status 처리 상세 분석](#캠페인-status-처리-상세-분석)
4. [문제점 및 개선 방안](#문제점-및-개선-방안)

---

## 문제 개요

### 발견된 문제
1. **캠페인 생성 후 목록에 바로 표시되지 않는 문제**
   - 캠페인 생성 버튼 클릭 후 `/mypage/advertiser/my-campaigns` 화면으로 돌아왔을 때 생성된 캠페인이 목록에 바로 나타나지 않음

2. **Status 처리의 불일치**
   - 데이터베이스와 Flutter 모델 간의 status 값 불일치
   - Status 필터링 로직의 복잡성

---

## 캠페인 생성 후 목록 표시 문제 분석

### 현재 구현 흐름

#### 1. 캠페인 생성 화면 (`campaign_creation_screen.dart`)

```1095:1110:lib/screens/campaign/campaign_creation_screen.dart
      if (response.success) {
        // ✅ 성공 시 즉시 플래그 해제
        _isCreatingCampaign = false;
        _lastCampaignCreationId = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? '캠페인이 생성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          // pushNamed().then() 패턴: 생성된 캠페인 ID를 전달하여 상위 화면에서 직접 조회
          final campaignId = response.data?.id;
          context.pop(campaignId); // 생성된 캠페인 ID를 반환
        }
      }
```

**특징:**
- 생성 성공 시 `campaignId`를 반환하여 상위 화면으로 전달
- `pushNamed().then()` 패턴 사용

#### 2. 캠페인 목록 화면 (`advertiser_my_campaigns_screen.dart`)

```91:106:lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart
  /// 캠페인 생성 화면으로 이동 (pushNamed().then() 패턴)
  void _navigateToCreateCampaign() {
    context.pushNamed('advertiser-my-campaigns-create').then((result) {
      // result는 생성된 캠페인 ID (String) 또는 null
      if (result != null && result is String) {
        final campaignId = result;
        debugPrint('✅ 캠페인 생성 완료 - campaignId: $campaignId');
        // 생성된 캠페인을 직접 조회하여 목록에 추가 (Eventual Consistency 문제 해결)
        _addCampaignByIdDirectly(campaignId);
      } else if (result == true) {
        // fallback: true가 반환된 경우 일반 새로고침
        debugPrint('🔄 일반 새로고침 실행');
        _loadCampaigns();
      }
    });
  }
```

**특징:**
- 생성된 `campaignId`를 받아서 `_addCampaignByIdDirectly()` 호출
- Eventual Consistency 문제 해결을 위한 직접 조회 방식

#### 3. 생성된 캠페인 직접 조회 (`_addCampaignByIdDirectly`)

```108:154:lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart
  /// 생성된 캠페인을 직접 조회하여 목록에 추가 (Eventual Consistency 문제 해결)
  Future<void> _addCampaignByIdDirectly(String campaignId) async {
    if (!mounted) return;

    debugPrint('🔍 생성된 캠페인 직접 조회 시작 - campaignId: $campaignId');

    try {
      // 짧은 지연 후 조회 (트랜잭션 커밋 대기)
      await Future.delayed(const Duration(milliseconds: 300));

      final result = await _campaignService.getCampaignById(campaignId);
      debugPrint(
        '📥 캠페인 조회 결과 - success: ${result.success}, data: ${result.data != null}',
      );

      if (result.success && result.data != null && mounted) {
        final campaign = result.data!;

        // 중복 체크
        if (!_allCampaigns.any((c) => c.id == campaignId)) {
          debugPrint('➕ 캠페인을 목록에 추가 - ${campaign.title}');
          _allCampaigns.insert(0, campaign);
          _updateFilteredCampaigns();

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('✅ UI 업데이트 완료 - 총 캠페인 수: ${_allCampaigns.length}');
          }
        } else {
          debugPrint('ℹ️ 캠페인이 이미 목록에 있습니다: $campaignId');
        }
      } else {
        debugPrint('⚠️ 캠페인을 찾을 수 없습니다. 일반 새로고침 실행...');
        // 직접 조회 실패 시 일반 새로고침
        _loadCampaigns();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 캠페인 직접 조회 실패: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // 에러 발생 시 일반 새로고침
      if (mounted) {
        _loadCampaigns();
      }
    }
  }
```

**문제점:**
1. **300ms 지연**: 트랜잭션 커밋 대기를 위한 지연이 있지만, 실제로는 불필요할 수 있음
2. **Status 필터링 누락**: `_updateFilteredCampaigns()`에서 status에 따라 탭별로 분류하지만, 생성 직후의 캠페인이 올바른 탭에 표시되지 않을 수 있음

#### 4. Status 기반 필터링 (`_updateFilteredCampaigns`)

```490:529:lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart
  /// 상태별 필터링 업데이트
  void _updateFilteredCampaigns() {
    final now = DateTime.now();

    // 대기중: upcoming 상태 또는 시작일이 아직 지나지 않음
    _pendingCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'upcoming' ||
          (campaign.startDate != null && campaign.startDate!.isAfter(now));
    }).toList();

    // 모집중: active 상태이고 현재 기간 내
    _recruitingCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'active' &&
          (campaign.startDate == null || campaign.startDate!.isBefore(now)) &&
          (campaign.endDate == null || campaign.endDate!.isAfter(now));
    }).toList();

    // 선정완료: active 상태이지만 참여자 선정이 완료된 경우
    _selectedCampaigns = _recruitingCampaigns.where((campaign) {
      return campaign.currentParticipants >= (campaign.maxParticipants ?? 0);
    }).toList();

    // 등록기간: active 상태이지만 모집이 완료되고 진행 중인 상태
    _registeredCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'active' &&
          campaign.currentParticipants > 0 &&
          (campaign.maxParticipants == null ||
              campaign.currentParticipants < campaign.maxParticipants!);
    }).toList();

    // 종료: completed 상태 또는 종료일이 지남
    _completedCampaigns = _allCampaigns.where((campaign) {
      final status = campaign.status.toString().split('.').last;
      return status == 'completed' ||
          (campaign.endDate != null && campaign.endDate!.isBefore(now));
    }).toList();
  }
```

**문제점:**
1. **Status 불일치**: DB에는 'upcoming' 상태가 없지만, 필터링 로직에서 'upcoming'을 체크함
2. **복잡한 필터링 로직**: Status와 날짜를 함께 고려하여 복잡함
3. **탭 전환 필요**: 생성된 캠페인이 올바른 탭에 표시되려면 사용자가 해당 탭으로 이동해야 함

---

## 캠페인 Status 처리 상세 분석

### 1. 데이터베이스 스키마

#### Status 가능 값 (DB)

```3595:3595:supabase/migrations/20251116140000_remove_unused_campaign_columns.sql
    CONSTRAINT "campaigns_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'completed'::"text", 'cancelled'::"text"])))
```

**DB Status 값:**
- `'active'`: 활성 상태 (기본값)
- `'inactive'`: 비활성 상태
- `'completed'`: 완료 상태
- `'cancelled'`: 취소 상태

#### Status 기본값

```3567:3567:supabase/migrations/20251116140000_remove_unused_campaign_columns.sql
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
```

**기본값:** `'active'`

### 2. Flutter 모델

#### CampaignStatus Enum

```292:292:lib/models/campaign.dart
enum CampaignStatus { active, completed, upcoming }
```

**Flutter Status 값:**
- `active`: 활성 상태
- `completed`: 완료 상태
- `upcoming`: 예정 상태 (⚠️ **DB에는 없음**)

#### Status 매핑 (fromJson)

```118:121:lib/models/campaign.dart
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'active'),
        orElse: () => CampaignStatus.active,
      ),
```

**문제점:**
- DB의 `'inactive'`, `'cancelled'`는 Flutter enum에 없음
- DB의 `'upcoming'`도 없지만, Flutter enum에는 `upcoming`이 있음
- 매핑 실패 시 기본값으로 `active` 사용

### 3. 캠페인 생성 시 Status 설정

#### RPC 함수 (`create_campaign_with_points_v2`)

```434:459:supabase/migrations/20251116140000_remove_unused_campaign_columns.sql
    -- 6. 캠페인 생성
    INSERT INTO public.campaigns (
      title, description, company_id, user_id,
      campaign_type, platform,
      keyword, option, quantity, seller, product_number,
      product_image_url, product_name, product_price,
      purchase_method,
      review_type, review_text_length, review_image_count,
      review_reward, review_cost, max_participants, current_participants,
      start_date, end_date,
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
      p_review_reward, p_review_reward, p_max_participants, 0,
      p_start_date, p_end_date,
      p_prevent_product_duplicate, p_prevent_store_duplicate, p_duplicate_prevent_days,
      p_payment_method, v_total_cost,
      'active', NOW(), NOW()
    ) RETURNING id INTO v_campaign_id;
```

**특징:**
- 캠페인 생성 시 **항상 `'active'`로 설정**
- `start_date`가 미래여도 status는 `'active'`로 설정됨

### 4. Status 필터링 로직

#### 사용자 캠페인 조회 RPC (`get_user_campaigns_safe`)

```1358:1441:supabase/migrations/20251116140000_remove_unused_campaign_columns.sql
CREATE OR REPLACE FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text" DEFAULT 'all'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
```

**특징:**
- `p_status` 파라미터로 필터링 가능
- 기본값은 `'all'` (모든 status 조회)
- `'all'`이 아닌 경우 해당 status만 조회

#### Flutter에서의 Status 필터링

```315:350:lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart
      // 상태별 필터링
      final now = DateTime.now();

      // 대기중: upcoming 상태 또는 시작일이 아직 지나지 않음
      _pendingCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'upcoming' ||
            (campaign.startDate != null && campaign.startDate!.isAfter(now));
      }).toList();

      // 모집중: active 상태이고 현재 기간 내
      _recruitingCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'active' &&
            (campaign.startDate == null || campaign.startDate!.isBefore(now)) &&
            (campaign.endDate == null || campaign.endDate!.isAfter(now));
      }).toList();

      // 선정완료: active 상태이지만 참여자 선정이 완료된 경우
      // (실제로는 campaign_events의 approved 상태를 확인해야 하지만, 여기서는 간단히 처리)
      _selectedCampaigns = _recruitingCampaigns.where((campaign) {
        return campaign.currentParticipants >= (campaign.maxParticipants ?? 0);
      }).toList();

      // 등록기간: active 상태이지만 모집이 완료되고 진행 중인 상태
      _registeredCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'active' &&
            campaign.currentParticipants > 0 &&
            (campaign.maxParticipants == null ||
                campaign.currentParticipants < campaign.maxParticipants!);
      }).toList();

      // 종료: completed 상태 또는 종료일이 지남
      _completedCampaigns = _allCampaigns.where((campaign) {
        final status = campaign.status.toString().split('.').last;
        return status == 'completed' ||
            (campaign.endDate != null && campaign.endDate!.isBefore(now));
      }).toList();
```

**문제점:**
1. **Status와 날짜 혼용**: Status만으로는 부족하여 날짜를 함께 고려
2. **'upcoming' 상태 체크**: DB에는 없지만 코드에서 체크함
3. **복잡한 분류 로직**: 여러 조건을 조합하여 탭별로 분류

### 5. Status 업데이트 로직

현재 코드베이스에서 캠페인 status를 업데이트하는 로직은 발견되지 않았습니다. 

**추정:**
- Status 업데이트는 주로 데이터베이스 트리거나 별도의 관리자 기능에서 처리될 것으로 추정
- 또는 `end_date`가 지나면 자동으로 `'completed'`로 변경되는 트리거가 있을 수 있음

---

## 문제점 및 개선 방안

### 문제점 요약

#### 1. 캠페인 생성 후 목록 표시 문제

**원인:**
1. **300ms 지연**: 트랜잭션 커밋 대기를 위한 지연이 있지만, 실제로는 불필요할 수 있음
2. **Status 필터링**: 생성된 캠페인이 올바른 탭에 표시되지 않을 수 있음
3. **탭 전환 필요**: 사용자가 해당 탭으로 이동해야 생성된 캠페인을 볼 수 있음

**증상:**
- 캠페인 생성 후 목록 화면으로 돌아왔을 때 생성된 캠페인이 보이지 않음
- 올바른 탭으로 이동해야만 표시됨

#### 2. Status 처리 불일치

**원인:**
1. **DB와 Flutter Enum 불일치**
   - DB: `'active'`, `'inactive'`, `'completed'`, `'cancelled'`
   - Flutter: `active`, `completed`, `upcoming`
   - `'inactive'`, `'cancelled'`는 Flutter에서 처리되지 않음
   - `upcoming`은 DB에 없지만 Flutter에서 사용

2. **Status와 날짜 혼용**
   - Status만으로는 부족하여 날짜를 함께 고려
   - 복잡한 필터링 로직

3. **Status 업데이트 로직 부재**
   - `start_date`가 미래인 경우에도 status는 `'active'`로 설정
   - `end_date`가 지나도 자동으로 `'completed'`로 변경되지 않을 수 있음

### 개선 방안

#### 1. 캠페인 생성 후 목록 표시 개선

**방안 A: 지연 제거 및 즉시 조회**
```dart
Future<void> _addCampaignByIdDirectly(String campaignId) async {
  if (!mounted) return;

  try {
    // 지연 제거 - 트랜잭션이 이미 커밋되었을 것으로 가정
    final result = await _campaignService.getCampaignById(campaignId);
    
    if (result.success && result.data != null && mounted) {
      final campaign = result.data!;
      
      if (!_allCampaigns.any((c) => c.id == campaignId)) {
        _allCampaigns.insert(0, campaign);
        _updateFilteredCampaigns();
        
        // 생성된 캠페인이 속한 탭으로 자동 이동
        _navigateToCampaignTab(campaign);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // 재시도 로직 (최대 3회, 지수 백오프)
      await _retryAddCampaign(campaignId, maxRetries: 3);
    }
  } catch (e) {
    // 에러 처리
    _loadCampaigns();
  }
}
```

**방안 B: 생성된 캠페인 탭으로 자동 이동**
```dart
void _navigateToCampaignTab(Campaign campaign) {
  final now = DateTime.now();
  final status = campaign.status.toString().split('.').last;
  
  int targetTabIndex = 1; // 기본값: 모집중
  
  if (status == 'upcoming' || 
      (campaign.startDate != null && campaign.startDate!.isAfter(now))) {
    targetTabIndex = 0; // 대기중
  } else if (status == 'active' &&
      (campaign.startDate == null || campaign.startDate!.isBefore(now)) &&
      (campaign.endDate == null || campaign.endDate!.isAfter(now))) {
    targetTabIndex = 1; // 모집중
  } else if (status == 'completed' ||
      (campaign.endDate != null && campaign.endDate!.isBefore(now))) {
    targetTabIndex = 4; // 종료
  }
  
  _tabController.animateTo(targetTabIndex);
}
```

#### 2. Status 처리 개선

**방안 A: Flutter Enum 확장**
```dart
enum CampaignStatus { 
  active, 
  inactive,  // 추가
  completed, 
  cancelled, // 추가
  upcoming   // 유지 (클라이언트 측 계산용)
}
```

**방안 B: Status 계산 로직 개선**
```dart
CampaignStatus calculateCampaignStatus(Campaign campaign) {
  final now = DateTime.now();
  final dbStatus = campaign.status; // DB에서 가져온 실제 status
  
  // DB status가 우선
  if (dbStatus == CampaignStatus.completed || 
      dbStatus == CampaignStatus.cancelled ||
      dbStatus == CampaignStatus.inactive) {
    return dbStatus;
  }
  
  // active인 경우 날짜로 계산
  if (campaign.startDate != null && campaign.startDate!.isAfter(now)) {
    return CampaignStatus.upcoming; // 클라이언트 측 계산
  }
  
  if (campaign.endDate != null && campaign.endDate!.isBefore(now)) {
    return CampaignStatus.completed; // 종료일 지남
  }
  
  return CampaignStatus.active;
}
```

**방안 C: DB 트리거 추가 (Status 자동 업데이트)**
```sql
-- 캠페인 status 자동 업데이트 트리거
CREATE OR REPLACE FUNCTION update_campaign_status_by_date()
RETURNS TRIGGER AS $$
BEGIN
  -- end_date가 지났으면 completed로 변경
  IF NEW.end_date IS NOT NULL AND NEW.end_date < NOW() THEN
    NEW.status = 'completed';
  END IF;
  
  -- start_date가 미래면 upcoming으로 변경 (DB에 upcoming 추가 시)
  -- 또는 별도 필드로 관리
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER campaign_status_update_trigger
BEFORE INSERT OR UPDATE ON campaigns
FOR EACH ROW
EXECUTE FUNCTION update_campaign_status_by_date();
```

#### 3. Status 필터링 로직 단순화

**방안: Status 기반 필터링 우선, 날짜는 보조**
```dart
void _updateFilteredCampaigns() {
  final now = DateTime.now();
  
  _pendingCampaigns = _allCampaigns.where((campaign) {
    final calculatedStatus = calculateCampaignStatus(campaign);
    return calculatedStatus == CampaignStatus.upcoming;
  }).toList();
  
  _recruitingCampaigns = _allCampaigns.where((campaign) {
    final calculatedStatus = calculateCampaignStatus(campaign);
    return calculatedStatus == CampaignStatus.active &&
        campaign.currentParticipants < (campaign.maxParticipants ?? 0);
  }).toList();
  
  // ... 나머지 필터링
}
```

### 권장 사항

1. **즉시 개선 (High Priority)**
   - 생성된 캠페인 탭으로 자동 이동 기능 추가
   - Status 필터링 로직 단순화

2. **중기 개선 (Medium Priority)**
   - Flutter Enum 확장 (`inactive`, `cancelled` 추가)
   - Status 계산 로직 개선

3. **장기 개선 (Low Priority)**
   - DB 트리거 추가 (Status 자동 업데이트)
   - DB에 `upcoming` status 추가 검토

---

## 로드맵: Status 및 탭 분류 로직 개선

### 목표
- Status를 `active`와 `inactive`만 사용하도록 단순화
- 만료기간 필드 추가
- 탭 분류 로직을 명확하고 일관성 있게 개선

### 작업 항목

#### 1. 데이터베이스 스키마 변경

**1.1 Status 제약 조건 변경**
- 현재: `'active'`, `'inactive'`, `'completed'`, `'cancelled'` 허용
- 변경: `'active'`, `'inactive'`만 허용
- 작업:
  ```sql
  -- campaigns_status_check 제약 조건 수정
  ALTER TABLE campaigns 
  DROP CONSTRAINT IF EXISTS campaigns_status_check;
  
  ALTER TABLE campaigns 
  ADD CONSTRAINT campaigns_status_check 
  CHECK (status = ANY (ARRAY['active'::text, 'inactive'::text]));
  ```

**1.2 만료기간 필드 추가**
- 필드명: `expiration_date` (timestamp with time zone)
- 설명: 캠페인의 최종 만료일 (종료일 이후 리뷰 등록 기간)
- 작업:
  ```sql
  ALTER TABLE campaigns 
  ADD COLUMN expiration_date timestamp with time zone;
  
  COMMENT ON COLUMN campaigns.expiration_date IS '캠페인 만료일 (종료일 이후 리뷰 등록 기간)';
  ```

**1.3 기존 데이터 마이그레이션**
- `status = 'completed'` 또는 `status = 'cancelled'`인 경우:
  - `status = 'inactive'`로 변경
- `expiration_date`가 NULL인 경우:
  - `end_date` 기준으로 기본값 설정 (예: `end_date + 30일`)

#### 2. Flutter 모델 변경

**2.1 CampaignStatus Enum 수정**
- 현재: `enum CampaignStatus { active, completed, upcoming }`
- 변경: `enum CampaignStatus { active, inactive }`
- 파일: `lib/models/campaign.dart`

**2.2 Campaign 모델에 expirationDate 필드 추가**
- 필드 추가:
  ```dart
  final DateTime? expirationDate;
  ```
- `fromJson` 및 `toJson` 메서드 업데이트
- `copyWith` 메서드 업데이트

#### 3. 탭 분류 로직 개선

**3.1 새로운 탭 분류 규칙**

`/mypage/advertiser/my-campaigns` 화면의 탭 분류:

1. **모집** (대기중)
   - 조건: `start_date`가 현재 시간보다 미래인 경우
   - 설명: 시작기간이 되지 않았을 때

2. **모집중**
   - 조건:
     - `status = 'active'`
     - `start_date <= 현재 시간 < end_date`
     - `current_participants < max_participants`
   - 설명: 시작기간과 종료기간 사이면서 참여자가 다 차지 않은 경우

3. **선정완료**
   - 조건:
     - `status = 'active'`
     - `start_date <= 현재 시간 < end_date`
     - `current_participants >= max_participants`
   - 설명: 시작기간과 종료기간 사이면서 참여자가 다 찬 경우

4. **등록기간**
   - 조건:
     - `status = 'active'`
     - `end_date <= 현재 시간 < expiration_date`
   - 설명: 종료기간과 만료기간 사이에 있는 경우

5. **종료**
   - 조건:
     - `status = 'inactive'` 또는
     - `expiration_date`가 현재 시간보다 과거인 경우
   - 설명: 만료기간이 지나거나 status가 inactive

**3.2 필터링 로직 구현**

파일: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`

```dart
void _updateFilteredCampaigns() {
  final now = DateTime.now();
  
  // 모집 (대기중): 시작기간이 되지 않았을 때
  _pendingCampaigns = _allCampaigns.where((campaign) {
    return campaign.startDate != null && 
           campaign.startDate!.isAfter(now);
  }).toList();
  
  // 모집중: 시작기간과 종료기간 사이면서 참여자가 다 차지 않은 경우
  _recruitingCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    if (campaign.startDate != null && campaign.startDate!.isAfter(now)) return false;
    if (campaign.endDate != null && campaign.endDate!.isBefore(now)) return false;
    if (campaign.maxParticipants != null && 
        campaign.currentParticipants >= campaign.maxParticipants!) return false;
    return true;
  }).toList();
  
  // 선정완료: 시작기간과 종료기간 사이면서 참여자가 다 찬 경우
  _selectedCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    if (campaign.startDate != null && campaign.startDate!.isAfter(now)) return false;
    if (campaign.endDate != null && campaign.endDate!.isBefore(now)) return false;
    if (campaign.maxParticipants == null) return false;
    return campaign.currentParticipants >= campaign.maxParticipants!;
  }).toList();
  
  // 등록기간: 종료기간과 만료기간 사이에 있는 경우
  _registeredCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    if (campaign.endDate == null || campaign.endDate!.isAfter(now)) return false;
    if (campaign.expirationDate == null || campaign.expirationDate!.isBefore(now)) return false;
    return true;
  }).toList();
  
  // 종료: 만료기간이 지나거나 status가 inactive
  _completedCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status == CampaignStatus.inactive) return true;
    if (campaign.expirationDate != null && campaign.expirationDate!.isBefore(now)) return true;
    return false;
  }).toList();
}
```

#### 4. 캠페인 생성/수정 화면 업데이트

**4.1 만료기간 입력 필드 추가**
- 파일: `lib/screens/campaign/campaign_creation_screen.dart`
- `expiration_date` 입력 필드 추가
- 기본값: `end_date + 30일` (선택 가능)

**4.2 RPC 함수 업데이트**
- `create_campaign_with_points_v2` 함수에 `expiration_date` 파라미터 추가
- 파일: `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql`

#### 5. 기타 업데이트

**5.1 Status 관련 코드 정리**
- `completed`, `cancelled`, `upcoming` 관련 코드 제거
- Status 매핑 로직 단순화

**5.2 UI 텍스트 업데이트**
- 탭 이름: "대기중" → "모집" (선택사항)
- Status 표시 텍스트 업데이트

### 구현 순서

1. **Phase 1: 데이터베이스 변경**
   - Status 제약 조건 변경
   - `expiration_date` 필드 추가
   - 기존 데이터 마이그레이션

2. **Phase 2: Flutter 모델 업데이트**
   - CampaignStatus Enum 수정
   - Campaign 모델에 `expirationDate` 추가

3. **Phase 3: 탭 분류 로직 개선**
   - `_updateFilteredCampaigns()` 메서드 재작성
   - 테스트 및 검증

4. **Phase 4: UI 업데이트**
   - 캠페인 생성/수정 화면에 만료기간 필드 추가
   - RPC 함수 업데이트

5. **Phase 5: 코드 정리**
   - 불필요한 Status 관련 코드 제거
   - 문서 업데이트

### 참고사항

- 만료기간은 종료일 이후의 기간을 의미합니다
- Status는 `active`와 `inactive`만 사용하며, 탭 분류는 주로 날짜 기반으로 처리됩니다
- 기존 `completed`, `cancelled` 상태의 캠페인은 `inactive`로 마이그레이션됩니다

---

## 참고 자료

- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`: 캠페인 목록 화면
- `lib/screens/campaign/campaign_creation_screen.dart`: 캠페인 생성 화면
- `lib/models/campaign.dart`: Campaign 모델 및 Status Enum
- `lib/services/campaign_service.dart`: Campaign 서비스
- `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql`: DB 스키마 및 RPC 함수

