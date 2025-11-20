# 광고주 캠페인 목록 필터링 문제 해결 로드맵

## 📋 개요

광고주 캠페인 목록에서 시작 날짜가 지나지 않았는데도 캠페인이 보이거나, 종료 날짜가 지나도 보이는 문제를 조사하고 해결하는 로드맵입니다.

---

## 🔍 문제 분석

### 현재 필터링 로직 분석

#### 1. 모집 (대기중) 탭
```dart
_pendingCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  return campaign.startDate != null &&
      campaign.startDate!.isAfter(now);
}).toList();
```
**문제점:** ✅ 정상 (startDate가 null이면 포함되지 않음)

#### 2. 모집중 탭
```dart
_recruitingCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  if (campaign.startDate != null && campaign.startDate!.isAfter(now)) return false;
  if (campaign.endDate != null && campaign.endDate!.isBefore(now)) return false;
  if (campaign.maxParticipants != null &&
      campaign.currentParticipants >= campaign.maxParticipants!) return false;
  return true;
}).toList();
```
**문제점:**
- ❌ `startDate`가 null이면 시작일 체크를 건너뛰므로, 시작일이 지나지 않은 캠페인도 포함될 수 있음
- ❌ `endDate`가 null이면 종료일 체크를 건너뛰므로, 종료일이 지난 캠페인도 포함될 수 있음
- ❌ `startDate`와 `endDate`가 모두 null이면 모든 active 캠페인이 포함됨

#### 3. 선정완료 탭
```dart
_selectedCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  if (campaign.startDate != null && campaign.startDate!.isAfter(now)) return false;
  if (campaign.endDate != null && campaign.endDate!.isBefore(now)) return false;
  if (campaign.maxParticipants == null) return false;
  return campaign.currentParticipants >= campaign.maxParticipants!;
}).toList();
```
**문제점:**
- ❌ `startDate`가 null이면 시작일 체크를 건너뛰므로, 시작일이 지나지 않은 캠페인도 포함될 수 있음
- ❌ `endDate`가 null이면 종료일 체크를 건너뛰므로, 종료일이 지난 캠페인도 포함될 수 있음

#### 4. 등록기간 탭
```dart
_registeredCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  if (campaign.endDate == null || campaign.endDate!.isAfter(now)) return false;
  if (campaign.expirationDate == null || campaign.expirationDate!.isBefore(now)) return false;
  return true;
}).toList();
```
**문제점:** ✅ 정상 (endDate와 expirationDate가 null이면 포함되지 않음)

#### 5. 종료 탭
```dart
_completedCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status == CampaignStatus.inactive) return true;
  if (campaign.expirationDate != null && campaign.expirationDate!.isBefore(now)) return true;
  return false;
}).toList();
```
**문제점:**
- ❌ `expirationDate`가 null이고 `status`가 `active`인 캠페인은 종료 탭에 포함되지 않음
- ❌ `endDate`가 지났지만 `expirationDate`가 null인 캠페인은 종료 탭에 포함되지 않음

---

## 🎯 해결 방안

### 원칙
1. **필수 필드 검증:** `startDate`와 `endDate`는 필수로 간주하고, null인 경우 적절히 처리
2. **명확한 조건:** 각 탭의 조건을 명확하게 정의
3. **중복 제거:** 한 캠페인이 여러 탭에 동시에 나타나지 않도록 보장

### 수정된 필터링 로직

#### 1. 모집 (대기중) 탭
```dart
_pendingCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  // startDate가 필수이므로 null 체크
  if (campaign.startDate == null) return false;
  // 시작일이 아직 지나지 않았을 때
  return campaign.startDate!.isAfter(now);
}).toList();
```

#### 2. 모집중 탭
```dart
_recruitingCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  
  // startDate와 endDate가 필수이므로 null 체크
  if (campaign.startDate == null || campaign.endDate == null) return false;
  
  // 시작일이 지났는지 확인
  if (campaign.startDate!.isAfter(now)) return false;
  
  // 종료일이 지나지 않았는지 확인
  if (campaign.endDate!.isBefore(now)) return false;
  
  // 참여자가 다 차지 않았는지 확인
  if (campaign.maxParticipants != null &&
      campaign.currentParticipants >= campaign.maxParticipants!) return false;
  
  return true;
}).toList();
```

#### 3. 선정완료 탭
```dart
_selectedCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  
  // startDate와 endDate가 필수이므로 null 체크
  if (campaign.startDate == null || campaign.endDate == null) return false;
  
  // 시작일이 지났는지 확인
  if (campaign.startDate!.isAfter(now)) return false;
  
  // 종료일이 지나지 않았는지 확인
  if (campaign.endDate!.isBefore(now)) return false;
  
  // maxParticipants가 필수
  if (campaign.maxParticipants == null) return false;
  
  // 참여자가 다 찼는지 확인
  return campaign.currentParticipants >= campaign.maxParticipants!;
}).toList();
```

#### 4. 등록기간 탭
```dart
_registeredCampaigns = _allCampaigns.where((campaign) {
  if (campaign.status != CampaignStatus.active) return false;
  
  // endDate와 expirationDate가 필수이므로 null 체크
  if (campaign.endDate == null || campaign.expirationDate == null) return false;
  
  // 종료일이 지났는지 확인
  if (campaign.endDate!.isAfter(now)) return false;
  
  // 만료일이 지나지 않았는지 확인
  if (campirationDate!.isBefore(now)) return false;
  
  return true;
}).toList();
```

#### 5. 종료 탭
```dart
_completedCampaigns = _allCampaigns.where((campaign) {
  // status가 inactive인 경우
  if (campaign.status == CampaignStatus.inactive) return true;
  
  // expirationDate가 있고 만료일이 지난 경우
  if (campaign.expirationDate != null && campaign.expirationDate!.isBefore(now)) return true;
  
  // endDate가 있고 종료일이 지났는데 expirationDate가 없는 경우
  // (expirationDate가 null이면 endDate 기준으로 종료 처리)
  if (campaign.endDate != null && 
      campaign.endDate!.isBefore(now) && 
      campaign.expirationDate == null) return true;
  
  return false;
}).toList();
```

---

## 📝 구현 단계

### Phase 1: 필터링 로직 수정

#### 1.1 `_updateFilteredCampaigns` 메서드 수정
- **파일:** `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
- **작업 내용:**
  - 각 탭의 필터링 조건을 명확하게 수정
  - null 체크 추가
  - 날짜 비교 로직 개선

#### 1.2 `advertiser_mypage_screen.dart`의 통계 계산 로직 수정
- **파일:** `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`
- **작업 내용:**
  - 동일한 필터링 로직 적용
  - 통계 카운트 계산 로직 수정

### Phase 2: 데이터 검증

#### 2.1 캠페인 생성 시 필수 필드 검증
- **파일:** `lib/screens/campaign/campaign_creation_screen.dart`
- **작업 내용:**
  - `startDate`와 `endDate`가 필수인지 확인
  - null인 경우 에러 메시지 표시

#### 2.2 데이터베이스 제약 조건 확인
- **작업 내용:**
  - `campaigns` 테이블에서 `start_date`와 `end_date`가 NOT NULL인지 확인
  - 필요시 마이그레이션 추가

### Phase 3: 테스트 및 검증

#### 3.1 테스트 시나리오 작성
- **시나리오 1:** startDate가 null인 캠페인
- **시나리오 2:** endDate가 null인 캠페인
- **시나리오 3:** startDate와 endDate가 모두 null인 캠페인
- **시나리오 4:** startDate가 미래인 캠페인
- **시나리오 5:** endDate가 과거인 캠페인
- **시나리오 6:** expirationDate가 null이고 endDate가 지난 캠페인

#### 3.2 UI 테스트
- 각 탭에서 올바른 캠페인만 표시되는지 확인
- 한 캠페인이 여러 탭에 동시에 나타나지 않는지 확인

---

## 🔍 추가 조사 필요 사항

### 1. 데이터베이스 스키마 확인
- `start_date`와 `end_date`가 NULL을 허용하는지 확인
- NULL을 허용한다면, NULL인 경우의 비즈니스 로직 정의 필요

### 2. 기존 데이터 확인
- 현재 데이터베이스에 `start_date`나 `end_date`가 NULL인 캠페인이 있는지 확인
- 있다면 마이그레이션 계획 수립

### 3. 비즈니스 로직 확인
- `start_date`와 `end_date`가 필수인지 선택인지 확인
- 선택이라면, NULL인 경우의 처리 방법 정의

---

## ⚠️ 주의사항

### 1. 기존 데이터 호환성
- 기존에 `start_date`나 `end_date`가 NULL인 캠페인이 있을 수 있음
- 수정 시 기존 데이터 처리 방법 결정 필요

### 2. 날짜 비교 정확도
- `DateTime.now()`는 초 단위까지 비교하므로, 날짜만 비교하려면 시간 부분을 제거해야 할 수 있음
- 예: `DateTime(now.year, now.month, now.day)`

### 3. 타임존 처리
- 서버와 클라이언트의 타임존이 다를 수 있음
- UTC 기준으로 통일하거나, 클라이언트 타임존을 명시적으로 사용

---

## 📊 예상 결과

### 수정 전
- ❌ startDate가 null인 캠페인이 모집중 탭에 표시됨
- ❌ endDate가 null인 캠페인이 모집중/선정완료 탭에 표시됨
- ❌ endDate가 지났지만 expirationDate가 null인 캠페인이 종료 탭에 표시되지 않음

### 수정 후
- ✅ startDate가 null인 캠페인은 어떤 탭에도 표시되지 않음 (또는 종료 탭에만 표시)
- ✅ endDate가 null인 캠페인은 적절히 처리됨
- ✅ 각 탭에 올바른 캠페인만 표시됨
- ✅ 한 캠페인이 여러 탭에 동시에 나타나지 않음

---

## 📝 관련 파일

### 수정 필요 파일
1. `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
   - `_updateFilteredCampaigns` 메서드 수정

2. `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart`
   - 통계 계산 로직 수정

### 참고 파일
3. `lib/screens/campaign/campaign_creation_screen.dart`
   - 필수 필드 검증 확인

4. `supabase/migrations/` (필요시)
   - 데이터베이스 제약 조건 확인/추가

---

**작성 일자:** 2025-11-20  
**작성자:** AI Assistant  
**상태:** 로드맵 작성 완료, 구현 대기

