# 캠페인 상태 분류 문제 분석 보고서

**작성일**: 2025년 11월 29일  
**문제**: 전체 3개 캠페인 중 모집중 1개만 분류됨  
**목적**: 상태 분류 로직의 문제점 파악 및 해결 방안 제시

---

## 📋 문제 상황

### 제공된 데이터

**전체 캠페인**: 3개

1. **브림유 BRIMU 무타공 흡착식 욕실선반**
   - `status=active`
   - `applyStartDate=2025-11-29 10:32:00.000Z`
   - `applyEndDate=2025-11-30 10:31:00.000Z`

2. **충전식 LED 투광기 무선 작업등**
   - `status=active`
   - `applyStartDate=2025-11-28 16:35:00.000Z`
   - `applyEndDate=2025-11-28 17:35:00.000Z`

3. **디프 초강력 무선 BLDC 터보팬**
   - `status=active`
   - `applyStartDate=2025-11-28 15:50:00.000Z`
   - `applyEndDate=2025-11-28 16:30:00.000Z`

### 분류 결과

- **전체**: 3개
- **대기중**: 0개
- **모집중**: 1개
- **선정완료**: 0개
- **등록기간**: 0개
- **종료**: 0개

**문제**: 전체 3개인데 모집중 1개만 분류되고, 나머지 2개가 어디에도 분류되지 않음

---

## 🔍 코드 분석

### 현재 분류 로직 (`_updateFilteredCampaigns()`)

```dart
void _updateFilteredCampaigns() {
  final now = DateTimeUtils.nowKST(); // 한국 시간 사용

  // 1. 대기중: 신청 시작일시보다 이전 (active 상태만)
  _pendingCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    return campaign.applyStartDate.isAfter(now);
  }).toList();

  // 2. 모집중: 신청 시작일 ~ 신청 종료일 사이
  _recruitingCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    // 신청 시작일이 지났고, 신청 종료일이 아직 안 지났어야 함
    if (campaign.applyStartDate.isAfter(now)) return false;
    if (campaign.applyEndDate.isBefore(now)) return false;
    // 참여자가 다 차지 않은 경우만
    if (campaign.maxParticipants != null &&
        campaign.currentParticipants >= campaign.maxParticipants!)
      return false;
    return true;
  }).toList();

  // 3. 선정완료: 신청 시작일 ~ 리뷰 시작일 사이 OR (신청 종료일 지남 + 참여자 다 참)
  _selectedCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    if (campaign.maxParticipants == null) return false;
    // 참여자가 다 찬 경우만
    if (campaign.currentParticipants < campaign.maxParticipants!)
      return false;

    // 조건 1: 신청 시작일 ~ 리뷰 시작일 사이
    final isBetweenApplyAndReview =
        !campaign.applyStartDate.isAfter(now) &&
        campaign.reviewStartDate.isAfter(now);

    // 조건 2: 신청 종료일이 지났고 참여자 다 참
    final isAfterApplyEndAndFull = campaign.applyEndDate.isBefore(now);

    return isBetweenApplyAndReview || isAfterApplyEndAndFull;
  }).toList();

  // 4. 등록기간: 리뷰 시작일 ~ 리뷰 종료일 사이
  _registeredCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status != CampaignStatus.active) return false;
    // 리뷰 시작일이 지났고, 리뷰 종료일이 아직 안 지났어야 함
    if (campaign.reviewStartDate.isAfter(now)) return false;
    if (campaign.reviewEndDate.isBefore(now)) return false;
    return true;
  }).toList();

  // 5. 종료: 리뷰 종료일 이후 또는 inactive 상태
  _completedCampaigns = _allCampaigns.where((campaign) {
    if (campaign.status == CampaignStatus.inactive) return true;
    // 리뷰 종료일이 지난 경우
    return campaign.reviewEndDate.isBefore(now);
  }).toList();
}
```

---

## 🐛 문제점 분석

### 문제 1: 시간대 불일치 (UTC vs KST)

**원인**:
- DB에서 가져온 날짜는 UTC 형식 (`2025-11-29 10:32:00.000Z`)
- `Campaign.fromJson()`에서 `DateTimeUtils.parseKST()`로 파싱하지만, 실제로는 UTC 문자열을 파싱
- `now = DateTimeUtils.nowKST()`는 한국 시간
- 비교 시 시간대 불일치로 잘못된 분류 발생

**예시**:
- `applyStartDate=2025-11-29 10:32:00.000Z` (UTC)
- 한국 시간으로 변환하면: `2025-11-29 19:32:00` (KST, UTC+9)
- 현재 시간이 `2025-11-29 15:00:00` (KST)라면:
  - UTC 기준: `2025-11-29 06:00:00` (UTC)
  - `applyStartDate.isAfter(now)` 비교 시 UTC와 KST를 혼용하여 잘못된 결과

### 문제 2: 분류 조건의 겹침 및 누락

**현재 로직의 문제**:

1. **대기중**: `applyStartDate.isAfter(now)` ✅
2. **모집중**: `applyStartDate <= now && applyEndDate >= now && 참여자 미만` ✅
3. **선정완료**: `참여자 다 참 && (신청~리뷰 사이 OR 신청 종료일 지남)` ⚠️
4. **등록기간**: `reviewStartDate <= now && reviewEndDate >= now` ⚠️
5. **종료**: `inactive OR reviewEndDate < now` ⚠️

**문제 시나리오**:

**시나리오 A: 신청 종료일이 지났지만 리뷰 시작일이 아직 안 지난 경우**
- `applyEndDate < now` (신청 종료일 지남)
- `reviewStartDate > now` (리뷰 시작일 아직 안 지남)
- 참여자 미만인 경우:
  - ❌ 대기중: `applyStartDate.isAfter(now)` = false
  - ❌ 모집중: `applyEndDate.isBefore(now)` = true → 제외
  - ❌ 선정완료: 참여자 미만 → 제외
  - ❌ 등록기간: `reviewStartDate.isAfter(now)` = true → 제외
  - ❌ 종료: `reviewEndDate.isBefore(now)` = false (리뷰 종료일 아직 안 지남)
  - **결과: 어디에도 분류되지 않음!**

**시나리오 B: 신청 종료일이 지났고 참여자 미만인 경우**
- `applyEndDate < now` (신청 종료일 지남)
- `currentParticipants < maxParticipants` (참여자 미만)
- `reviewStartDate > now` (리뷰 시작일 아직 안 지남)
- **결과: 어디에도 분류되지 않음!**

### 문제 3: 선정완료 조건의 모호함

**현재 조건**:
```dart
final isAfterApplyEndAndFull = campaign.applyEndDate.isBefore(now);
```

**문제**:
- "신청 종료일이 지났고 참여자 다 참"이라는 조건이지만
- `isAfterApplyEndAndFull`만으로는 "참여자 다 참" 조건이 이미 위에서 체크되었으므로
- 실제로는 "신청 종료일이 지났으면" 선정완료로 분류됨
- 하지만 참여자 미만인 경우는 어디에도 분류되지 않음

### 문제 4: 등록기간 조건의 누락

**현재 조건**:
```dart
_registeredCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  if (campaign.reviewStartDate.isAfter(now)) return false;
  if (campaign.reviewEndDate.isBefore(now)) return false;
  return true;
}).toList();
```

**문제**:
- `status != CampaignStatus.active` 체크가 있지만
- 신청 종료일이 지났지만 리뷰 시작일이 아직 안 지난 경우도 등록기간으로 분류될 수 있음
- 하지만 실제로는 `reviewStartDate.isAfter(now)`로 제외됨

---

## 📊 실제 데이터 분석

### 캠페인별 분류 예상

**현재 시간 가정**: 2025년 11월 29일 15:00:00 (KST)

#### 1. 브림유 BRIMU
- `applyStartDate=2025-11-29 10:32:00.000Z` (UTC) = `2025-11-29 19:32:00` (KST)
- `applyEndDate=2025-11-30 10:31:00.000Z` (UTC) = `2025-11-30 19:31:00` (KST)
- 현재 시간: `2025-11-29 15:00:00` (KST)
- **분류**: 대기중 (applyStartDate가 미래)

#### 2. 충전식 LED 투광기
- `applyStartDate=2025-11-28 16:35:00.000Z` (UTC) = `2025-11-29 01:35:00` (KST)
- `applyEndDate=2025-11-28 17:35:00.000Z` (UTC) = `2025-11-29 02:35:00` (KST)
- 현재 시간: `2025-11-29 15:00:00` (KST)
- **분류**: 
  - 모집중: ❌ (applyEndDate가 이미 지남)
  - 선정완료: ❌ (참여자 정보 없음, 조건 불만족)
  - 등록기간: ❌ (reviewStartDate 정보 없음)
  - 종료: ❌ (reviewEndDate 정보 없음)
  - **결과: 어디에도 분류되지 않음!**

#### 3. 디프 초강력 무선
- `applyStartDate=2025-11-28 15:50:00.000Z` (UTC) = `2025-11-29 00:50:00` (KST)
- `applyEndDate=2025-11-28 16:30:00.000Z` (UTC) = `2025-11-29 01:30:00` (KST)
- 현재 시간: `2025-11-29 15:00:00` (KST)
- **분류**: 
  - 모집중: ❌ (applyEndDate가 이미 지남)
  - 선정완료: ❌ (참여자 정보 없음, 조건 불만족)
  - 등록기간: ❌ (reviewStartDate 정보 없음)
  - 종료: ❌ (reviewEndDate 정보 없음)
  - **결과: 어디에도 분류되지 않음!**

---

## 🎯 근본 원인

### 1. 시간대 불일치
- UTC와 KST 혼용으로 인한 잘못된 시간 비교

### 2. 분류 로직의 불완전성
- **신청 종료일이 지났지만 리뷰 시작일이 아직 안 지난 경우**에 대한 분류 누락
- **참여자 미만인 경우**의 후속 상태 분류 누락

### 3. 상태 전환 로직의 모호함
- 캠페인의 생명주기가 명확하지 않음
- 각 상태 간 전환 조건이 불명확

---

## 💡 해결 방안

### 방안 1: 시간대 통일

**문제**: UTC와 KST 혼용

**해결**:
1. 모든 날짜를 KST로 통일
2. `Campaign.fromJson()`에서 `DateTimeUtils.parseKST()` 사용 확인
3. 비교 시 모든 날짜가 동일한 시간대인지 확인

### 방안 2: 분류 로직 개선

**문제**: 신청 종료일이 지났지만 리뷰 시작일이 아직 안 지난 경우 누락

**해결**:
```dart
// 개선된 분류 로직
void _updateFilteredCampaigns() {
  final now = DateTimeUtils.nowKST();

  // 모든 리스트 초기화
  _pendingCampaigns = [];
  _recruitingCampaigns = [];
  _selectedCampaigns = [];
  _registeredCampaigns = [];
  _completedCampaigns = [];

  for (final campaign in _allCampaigns) {
    // 1. 종료: inactive 상태 또는 리뷰 종료일 지남
    if (campaign.status == CampaignStatus.inactive ||
        campaign.reviewEndDate.isBefore(now)) {
      _completedCampaigns.add(campaign);
      continue;
    }

    // 2. 등록기간: 리뷰 시작일 ~ 리뷰 종료일 사이
    if (!campaign.reviewStartDate.isAfter(now) &&
        !campaign.reviewEndDate.isBefore(now)) {
      _registeredCampaigns.add(campaign);
      continue;
    }

    // 3. 선정완료: 
    //    - 신청기간 ~ 종료기간 사이 AND 신청자 다 참
    //    - OR 종료기간 ~ 리뷰시작기간 사이
    final isInApplyPeriod = !campaign.applyStartDate.isAfter(now) &&
                            !campaign.applyEndDate.isBefore(now);
    final isBetweenApplyEndAndReviewStart = campaign.applyEndDate.isBefore(now) &&
                                            campaign.reviewStartDate.isAfter(now);
    final isFull = campaign.currentParticipants == campaign.maxParticipants!;

    if ((isInApplyPeriod && isFull) || isBetweenApplyEndAndReviewStart) {
      _selectedCampaigns.add(campaign);
      continue;
    }

    // 4. 모집중: 신청기간 ~ 종료기간 사이 AND 신청자 다 안참
    if (isInApplyPeriod &&
        campaign.currentParticipants < campaign.maxParticipants!) {
      _recruitingCampaigns.add(campaign);
      continue;
    }

    // 5. 대기중: 신청기간 이전
    if (campaign.applyStartDate.isAfter(now)) {
      _pendingCampaigns.add(campaign);
      continue;
    }
  }
}
```

### 방안 3: 상태 추가

**문제**: 신청 종료일이 지났지만 리뷰 시작일이 아직 안 지난 경우

**해결**:
- ✅ **제안된 필터 기준에 따라 선정완료로 분류됨**
- 제안된 로직: "캠페인 종료기간 - 리뷰신청기간 → 선정완료"
- 따라서 별도의 상태 추가 불필요

### 방안 4: 우선순위 기반 분류

**문제**: 여러 조건에 동시에 해당하는 경우

**해결**:
- 우선순위 기반 분류 (종료 > 등록기간 > 선정완료 > 모집중 > 대기중)
- `if-else if` 구조로 중복 방지

---

## 🔧 권장 수정사항

### 1. 즉시 수정 (High Priority)

1. **시간대 통일 확인**
   - `Campaign.fromJson()`에서 `DateTimeUtils.parseKST()` 사용 확인
   - 모든 날짜 비교 시 동일한 시간대 사용 확인

2. **분류 로직 개선**
   - 우선순위 기반 분류로 변경
   - 모든 케이스 커버하도록 수정

### 2. 중기 개선 (Medium Priority)

1. **로깅 강화**
   - 분류되지 않은 캠페인 로깅
   - 각 캠페인의 분류 과정 로깅

### 3. 장기 개선 (Low Priority)

1. **상태 머신 도입**
   - 명확한 상태 전환 로직
   - 상태별 검증 로직

2. **단위 테스트 추가**
   - 각 상태 분류 로직 테스트
   - 엣지 케이스 테스트

---

## 📝 결론

### 문제 요약

1. **시간대 불일치**: UTC와 KST 혼용
2. **분류 로직 불완전**: 신청 종료일이 지났지만 리뷰 시작일이 아직 안 지난 경우 누락
3. **상태 전환 모호**: 참여자 미만인 경우의 후속 상태 불명확

### 해결 방향

1. **즉시**: 시간대 통일 및 분류 로직 개선
2. **중기**: 상태 추가 및 로깅 강화
3. **장기**: 상태 머신 도입 및 테스트 추가

---

**작성자**: AI Assistant  
**검토 상태**: 완료  
**다음 작업**: 분류 로직 개선 및 시간대 통일 확인

---

## ✅ 제안된 로직 검증

### 제안된 분류 로직

1. **대기중**: 캠페인 신청기간 이전
2. **모집중**: 캠페인 신청기간 - 캠페인 종료기간 (and 신청자 다 안참)
3. **선정완료**: 
   - 캠페인 신청기간 - 캠페인 종료기간 (and 신청자 다 참) 
   - OR 캠페인 종료기간 - 리뷰신청기간
4. **등록기간**: 리뷰신청기간 - 리뷰종료기간
5. **종료**: 리뷰종료기간 이후 또는 status가 inactive

### 시간축 분석

```
[applyStartDate] --- [applyEndDate] --- [reviewStartDate] --- [reviewEndDate] ---
```

### 케이스별 검증

#### ✅ 케이스 1: applyStartDate 이전
- **조건**: `now < applyStartDate`
- **분류**: 대기중 ✅
- **결과**: 커버됨

#### ✅ 케이스 2: applyStartDate ~ applyEndDate 사이 (신청자 미만)
- **조건**: `applyStartDate <= now <= applyEndDate` AND `currentParticipants < maxParticipants`
- **분류**: 모집중 ✅
- **결과**: 커버됨

#### ✅ 케이스 3: applyStartDate ~ applyEndDate 사이 (신청자 다 참)
- **조건**: `applyStartDate <= now <= applyEndDate` AND `currentParticipants == maxParticipants`
- **분류**: 선정완료 ✅
- **결과**: 커버됨
- **참고**: `currentParticipants`는 `maxParticipants`보다 클 수 없으므로 `>=` 대신 `==` 사용

#### ✅ 케이스 4: applyEndDate ~ reviewStartDate 사이
- **조건**: `applyEndDate < now < reviewStartDate`
- **분류**: 선정완료 ✅
- **결과**: 커버됨 (이전 로직에서 누락되었던 케이스 해결!)

#### ✅ 케이스 5: reviewStartDate ~ reviewEndDate 사이
- **조건**: `reviewStartDate <= now <= reviewEndDate`
- **분류**: 등록기간 ✅
- **결과**: 커버됨

#### ✅ 케이스 6: reviewEndDate 이후
- **조건**: `now > reviewEndDate`
- **분류**: 종료 ✅
- **결과**: 커버됨

#### ✅ 케이스 7: inactive 상태
- **조건**: `status == inactive`
- **분류**: 종료 ✅
- **결과**: 커버됨

### 엣지 케이스 검증

#### ✅ 엣지 케이스 1: applyEndDate == now
- **분류**: 
  - 신청자 미만 → 모집중 (applyStartDate <= now <= applyEndDate)
  - 신청자 다 참 → 선정완료 (applyStartDate <= now <= applyEndDate AND 신청자 다 참)
- **결과**: 커버됨

#### ✅ 엣지 케이스 2: reviewStartDate == now
- **분류**: 등록기간 (reviewStartDate <= now <= reviewEndDate)
- **결과**: 커버됨

#### ✅ 엣지 케이스 3: reviewEndDate == now
- **분류**: 등록기간 (reviewStartDate <= now <= reviewEndDate)
- **결과**: 커버됨

### ⚠️ 주의사항

#### 1. 데이터 제약 조건
- **`currentParticipants <= maxParticipants`**: `currentParticipants`는 `maxParticipants`보다 클 수 없음
- 따라서 "신청자 다 참" 조건은 `currentParticipants == maxParticipants`로 체크
- "신청자 미만" 조건은 `currentParticipants < maxParticipants`로 체크

#### 2. 우선순위 기반 분류 필요
- 여러 조건에 동시에 해당할 수 있으므로 우선순위 기반 분류 필요
- 우선순위: 종료 > 등록기간 > 선정완료 > 모집중 > 대기중

### 📝 최종 검증 결과

**✅ 제안된 로직은 모든 케이스를 커버합니다!**

다만 다음 사항을 고려해야 합니다:

1. **데이터 제약 조건**: `currentParticipants <= maxParticipants` (항상 참)
2. **우선순위 기반 분류**: if-else 구조로 중복 방지
3. **시간대 통일**: 모든 날짜 비교 시 KST로 통일
4. **maxParticipants 필수**: `maxParticipants`는 필수 필드이므로 null 체크 불필요

### 💻 구현 예시

```dart
void _updateFilteredCampaigns() {
  final now = DateTimeUtils.nowKST();

  // 모든 리스트 초기화
  _pendingCampaigns = [];
  _recruitingCampaigns = [];
  _selectedCampaigns = [];
  _registeredCampaigns = [];
  _completedCampaigns = [];

  for (final campaign in _allCampaigns) {
    // 1. 종료: inactive 상태 또는 리뷰 종료일 이후
    if (campaign.status == CampaignStatus.inactive ||
        campaign.reviewEndDate.isBefore(now)) {
      _completedCampaigns.add(campaign);
      continue;
    }

    // 2. 등록기간: 리뷰 시작일 ~ 리뷰 종료일 사이
    if (!campaign.reviewStartDate.isAfter(now) &&
        !campaign.reviewEndDate.isBefore(now)) {
      _registeredCampaigns.add(campaign);
      continue;
    }

    // 3. 선정완료: 
    //    - 신청기간 ~ 종료기간 사이 AND 신청자 다 참
    //    - OR 종료기간 ~ 리뷰시작기간 사이
    final isInApplyPeriod = !campaign.applyStartDate.isAfter(now) &&
                            !campaign.applyEndDate.isBefore(now);
    final isBetweenApplyEndAndReviewStart = campaign.applyEndDate.isBefore(now) &&
                                            campaign.reviewStartDate.isAfter(now);
    final isFull = campaign.currentParticipants == campaign.maxParticipants!;

    if ((isInApplyPeriod && isFull) || isBetweenApplyEndAndReviewStart) {
      _selectedCampaigns.add(campaign);
      continue;
    }

    // 4. 모집중: 신청기간 ~ 종료기간 사이 AND 신청자 다 안참
    if (isInApplyPeriod &&
        campaign.currentParticipants < campaign.maxParticipants!) {
      _recruitingCampaigns.add(campaign);
      continue;
    }

    // 5. 대기중: 신청기간 이전
    if (campaign.applyStartDate.isAfter(now)) {
      _pendingCampaigns.add(campaign);
      continue;
    }
  }
}
```

---

**검증 완료일**: 2025년 11월 29일  
**검증 결과**: ✅ 모든 케이스 커버됨  
**제약 조건**: 
- `maxParticipants`는 필수 필드
- `currentParticipants <= maxParticipants` (항상 참)

