# 앱 라우터 구조 문서

**작성일**: 2025년 11월 24일  
**파일 위치**: `lib/config/app_router.dart`

## 📋 목차

1. [라우터 개요](#라우터-개요)
2. [전역 리다이렉트 로직](#전역-리다이렉트-로직)
3. [라우트 구조](#라우트-구조)
4. [접근 권한](#접근-권한)
5. [제거된 경로](#제거된-경로)

---

## 라우터 개요

이 앱은 **GoRouter**를 사용하여 라우팅을 관리합니다. 주요 특징:

- **인증 기반 리다이렉트**: 로그인 상태에 따라 자동 리다이렉트
- **사용자 타입별 분기**: 리뷰어, 광고주, 관리자에 따라 다른 화면 표시
- **ShellRoute**: 메인 쉘(하단 네비게이션 바)을 포함한 공통 레이아웃

---

## 전역 리다이렉트 로직

### 리다이렉트 규칙

```dart
redirect: (context, state) async {
  // 1. 마이페이지 경로: 로그인 체크만 수행
  if (isMyPage) {
    if (user == null) return '/login';
    return null; // 경로 유지
  }
  
  // 2. 비로그인 상태
  if (!isLoggedIn) {
    if (isLoggingIn) return null;
    return '/login';
  }
  
  // 3. 로그인 상태
  if (isLoggedIn) {
    if (isLoggingIn || isRoot) return '/home';
  }
  
  return null;
}
```

### 리다이렉트 동작

| 상황 | 접근 경로 | 리다이렉트 결과 |
|------|----------|----------------|
| 비로그인 | `/` | `/login` |
| 비로그인 | `/home` | `/login` |
| 비로그인 | `/campaigns` | `/login` |
| 비로그인 | `/mypage/*` | `/login` |
| 로그인 | `/` | `/home` |
| 로그인 | `/login` | `/home` |
| 로그인 | `/mypage` | 사용자 타입에 따라 분기 |

---

## 라우트 구조

### 1. 루트 경로

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/` | `root` | `SizedBox.shrink()` | 모든 사용자 (리다이렉트됨) |
| `/login` | `login` | `LoginScreen` | 비로그인 사용자만 |

### 2. 메인 쉘 (ShellRoute)

**하단 네비게이션 바가 포함된 공통 레이아웃**

#### 2.1 홈 & 캠페인

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/home` | `home` | `HomeScreen` | 로그인 필요 |
| `/campaigns` | `campaigns` | `CampaignsScreen` | 로그인 필요 |
| `/campaigns/:id` | `campaign-detail` | `CampaignDetailScreen` | 로그인 필요 |
| `/guide` | `guide` | `GuideScreen` | 로그인 필요 |

#### 2.2 마이페이지 분기

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/mypage` | `mypage` | 사용자 타입에 따라 자동 분기 | 로그인 필요 |

**분기 로직:**
- `admin` → `/mypage/admin`
- `advertiser` → `/mypage/advertiser`
- 기타 (리뷰어) → `/mypage/reviewer`

#### 2.3 리뷰어 마이페이지 (`/mypage/reviewer`)

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/mypage/reviewer` | `mypage-reviewer` | `MyPageRouteWrapper` (리뷰어) | 리뷰어 |
| `/mypage/reviewer/my-campaigns` | `reviewer-my-campaigns` | `MyCampaignsScreen` | 리뷰어 |
| `/mypage/reviewer/reviews` | `reviewer-reviews` | `ReviewerReviewsScreen` | 리뷰어 |
| `/mypage/reviewer/points` | `reviewer-points` | `PointsScreen` (userType: 'reviewer') | 리뷰어 |
| `/mypage/reviewer/points/withdraw` | `reviewer-points-withdraw` | `PointRefundScreen` (userType: 'reviewer') | 리뷰어 |
| `/mypage/reviewer/points/refund` | `reviewer-points-refund` | `PointRefundScreen` (userType: 'reviewer') | 리뷰어 |
| `/mypage/reviewer/points/:id` | `reviewer-points-detail` | `PointTransactionDetailScreen` | 리뷰어 |
| `/mypage/reviewer/sns` | `reviewer-sns` | `SNSConnectionScreen` | 리뷰어 |

#### 2.4 광고주 마이페이지 (`/mypage/advertiser`)

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/mypage/advertiser` | `mypage-advertiser` | `MyPageRouteWrapper` (광고주) | 광고주 |
| `/mypage/advertiser/my-campaigns` | `advertiser-my-campaigns` | `AdvertiserMyCampaignsScreen` | 광고주 |
| `/mypage/advertiser/my-campaigns/create` | `advertiser-my-campaigns-create` | `CampaignCreationScreen` | 광고주 |
| `/mypage/advertiser/my-campaigns/:id` | `advertiser-campaign-detail` | `AdvertiserCampaignDetailScreen` | 광고주 |
| `/mypage/advertiser/analytics` | `advertiser-analytics` | `AdvertiserAnalyticsScreen` | 광고주 |
| `/mypage/advertiser/participants` | `advertiser-participants` | `AdvertiserParticipantsScreen` | 광고주 |
| `/mypage/advertiser/managers` | `advertiser-managers` | `AdvertiserManagerScreen` | 광고주 |
| `/mypage/advertiser/penalties` | `advertiser-penalties` | `AdvertiserPenaltiesScreen` | 광고주 |
| `/mypage/advertiser/points` | `advertiser-points` | `PointsScreen` (userType: 'advertiser') | 광고주 |
| `/mypage/advertiser/points/deposit` | `advertiser-points-deposit` | `PointChargeScreen` (userType: 'advertiser') | 광고주 |
| `/mypage/advertiser/points/withdraw` | `advertiser-points-withdraw` | `PointRefundScreen` (userType: 'advertiser') | 광고주 |
| `/mypage/advertiser/points/charge` | `advertiser-points-charge` | `PointChargeScreen` (userType: 'advertiser') | 광고주 |
| `/mypage/advertiser/points/refund` | `advertiser-points-refund` | `PointRefundScreen` (userType: 'advertiser') | 광고주 |
| `/mypage/advertiser/points/:id` | `advertiser-points-detail` | `PointTransactionDetailScreen` | 광고주 |

#### 2.5 관리자 마이페이지 (`/mypage/admin`)

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/mypage/admin` | `admin-dashboard` | `AdminDashboardScreen` | 관리자 |
| `/mypage/admin/users` | `admin-users` | `AdminUsersScreen` | 관리자 |
| `/mypage/admin/companies` | `admin-companies` | `AdminCompaniesScreen` | 관리자 |
| `/mypage/admin/campaigns` | `admin-campaigns` | `AdminCampaignsScreen` | 관리자 |
| `/mypage/admin/reviews` | `admin-reviews` | `AdminReviewsScreen` | 관리자 |
| `/mypage/admin/points` | `admin-points` | `AdminPointsScreen` | 관리자 |
| `/mypage/admin/statistics` | `admin-statistics` | `AdminStatisticsScreen` | 관리자 |
| `/mypage/admin/settings` | `admin-settings` | `AdminSettingsScreen` | 관리자 |

#### 2.6 공통 마이페이지

| 경로 | 이름 | 화면 | 접근 권한 |
|------|------|------|----------|
| `/mypage/profile` | `profile` | `ProfileScreen` | 로그인 필요 |
| `/account-deletion` | `account-deletion` | `AccountDeletionScreen` | 로그인 필요 |

---

## 접근 권한

### 권한 체크 방식

1. **전역 리다이렉트**: 로그인 여부만 체크
2. **화면 레벨**: 각 화면에서 사용자 타입 체크
3. **MyPageRouteWrapper**: 리뷰어/광고주 화면에서 권한 체크 수행

### 사용자 타입별 접근 가능 경로

| 사용자 타입 | 접근 가능 경로 |
|------------|---------------|
| **비로그인** | `/login` |
| **리뷰어** | `/home`, `/campaigns`, `/campaigns/:id`, `/guide`, `/mypage/reviewer/*`, `/mypage/profile`, `/account-deletion` |
| **광고주** | `/home`, `/campaigns`, `/campaigns/:id`, `/guide`, `/mypage/advertiser/*`, `/mypage/profile`, `/account-deletion` |
| **관리자** | 모든 경로 (`/mypage/admin/*` 포함) |

---

## 제거된 경로

### ❌ `/campaigns/create` (제거됨)

**상태**: **제거 완료** ✅

**제거 이유**: 
- 캠페인 생성은 광고주 전용 기능입니다
- 광고주는 `/mypage/advertiser/my-campaigns/create` 경로를 사용해야 합니다

**올바른 경로**:
- ✅ `/mypage/advertiser/my-campaigns/create` (광고주 전용)

**제거 일자**: 2025년 11월 24일

**참고**: 해당 경로로 접근 시 404 에러 페이지가 표시됩니다.

---

## 라우트 트리 구조

```
/
├── /login (비로그인 전용)
└── ShellRoute (MainShell)
    ├── /home
    ├── /campaigns
    ├── /campaigns/:id
    ├── /guide
    ├── /mypage (자동 분기)
    │   ├── /mypage/reviewer
    │   │   ├── /mypage/reviewer/my-campaigns
    │   │   ├── /mypage/reviewer/reviews
    │   │   ├── /mypage/reviewer/points
    │   │   │   ├── /mypage/reviewer/points/withdraw
    │   │   │   ├── /mypage/reviewer/points/refund
    │   │   │   └── /mypage/reviewer/points/:id
    │   │   └── /mypage/reviewer/sns
    │   ├── /mypage/advertiser
    │   │   ├── /mypage/advertiser/my-campaigns
    │   │   │   ├── /mypage/advertiser/my-campaigns/create ✅
    │   │   │   └── /mypage/advertiser/my-campaigns/:id
    │   │   ├── /mypage/advertiser/analytics
    │   │   ├── /mypage/advertiser/participants
    │   │   ├── /mypage/advertiser/managers
    │   │   ├── /mypage/advertiser/penalties
    │   │   └── /mypage/advertiser/points
    │   │       ├── /mypage/advertiser/points/deposit
    │   │       ├── /mypage/advertiser/points/withdraw
    │   │       ├── /mypage/advertiser/points/charge
    │   │       ├── /mypage/advertiser/points/refund
    │   │       └── /mypage/advertiser/points/:id
    │   ├── /mypage/admin
    │   │   ├── /mypage/admin/users
    │   │   ├── /mypage/admin/companies
    │   │   ├── /mypage/admin/campaigns
    │   │   ├── /mypage/admin/reviews
    │   │   ├── /mypage/admin/points
    │   │   ├── /mypage/admin/statistics
    │   │   └── /mypage/admin/settings
    │   └── /mypage/profile
    └── /account-deletion
```

---

## 쿼리 파라미터

### 지원하는 쿼리 파라미터

| 경로 | 파라미터 | 설명 |
|------|----------|------|
| `/mypage/reviewer/my-campaigns` | `tab` | 초기 탭 선택 |
| `/mypage/advertiser/my-campaigns` | `tab` | 초기 탭 선택 |
| `/mypage/admin/points` | `tab` | 초기 탭 선택 |

**사용 예시**:
```
/mypage/reviewer/my-campaigns?tab=active
/mypage/advertiser/my-campaigns?tab=pending
/mypage/admin/points?tab=transactions
```

---

## 에러 처리

### 404 에러

존재하지 않는 경로 접근 시:

```dart
errorBuilder: (context, state) => Scaffold(
  body: Center(
    child: Column(
      children: [
        Icon(Icons.error, size: 64, color: Colors.red),
        Text('페이지를 찾을 수 없습니다: ${state.matchedLocation}'),
        ElevatedButton(
          onPressed: () => context.go('/'),
          child: Text('홈으로 이동'),
        ),
      ],
    ),
  ),
)
```

---

## 참고사항

1. **라우트 이름 사용**: `context.goNamed('route-name')` 방식 권장
2. **경로 파라미터**: `:id` 형식으로 동적 경로 지원
3. **리다이렉트**: 전역 리다이렉트와 화면 레벨 리다이렉트 모두 지원
4. **새로고침 대응**: 마이페이지 경로는 새로고침 시 경로 유지

---

## 변경 이력

- **2025년 11월 24일**: 
  - 초기 문서 작성
    - 전체 라우터 구조 정리
    - `/campaigns/create` 경로 제거 필요 사항 명시
  - `/campaigns/create` 경로 제거 완료
    - `lib/config/app_router.dart`에서 해당 라우트 제거
    - 문서에 제거 완료 상태 반영

