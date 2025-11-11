# 어드민 기능 구현 로드맵

## 📋 개요
사용자 타입이 `admin`인 경우 접근 가능한 관리자 대시보드 및 관리 기능을 구현합니다.

## 🎯 목표
- Drawer에 어드민 전용 메뉴 추가
- 어드민 대시보드 구현
- 사용자 관리, 캠페인 관리, 통계 등 관리 기능 제공

---

## 📁 파일 구조

### 새로 생성할 파일들

```
lib/
├── widgets/
│   └── drawer/
│       └── admin_drawer.dart          # 어드민 전용 Drawer
│
├── screens/
│   └── mypage/
│       └── admin/                     # 어드민 전용 스크린 폴더
│           ├── admin_dashboard_screen.dart      # 대시보드 (메인)
│           ├── admin_users_screen.dart           # 사용자 관리
│           ├── admin_companies_screen.dart       # 회사 관리
│           ├── admin_campaigns_screen.dart       # 캠페인 관리
│           ├── admin_reviews_screen.dart         # 리뷰 관리
│           ├── admin_points_screen.dart          # 포인트 관리
│           ├── admin_statistics_screen.dart      # 통계
│           ├── admin_settings_screen.dart        # 시스템 설정
│           └── widgets/                          # 어드민 전용 위젯
│               ├── user_management_card.dart
│               ├── campaign_management_card.dart
│               ├── statistics_chart.dart
│               └── admin_action_dialog.dart
│
└── services/
    └── admin_service.dart             # 어드민 전용 서비스
```

---

## 🔧 수정할 파일들

### 1. `lib/widgets/main_shell.dart`
- Drawer 선택 로직 추가
- `user.userType == UserType.admin`인 경우 `AdminDrawer` 표시

### 2. `lib/screens/mypage/mypage_screen.dart`
- 어드민인 경우 `AdminDashboardScreen` 표시

### 3. `lib/config/app_router.dart`
- 어드민 라우트 추가:
  - `/mypage/admin` - 대시보드
  - `/mypage/admin/users` - 사용자 관리
  - `/mypage/admin/companies` - 회사 관리
  - `/mypage/admin/campaigns` - 캠페인 관리
  - `/mypage/admin/reviews` - 리뷰 관리
  - `/mypage/admin/points` - 포인트 관리
  - `/mypage/admin/statistics` - 통계
  - `/mypage/admin/settings` - 시스템 설정

### 4. `lib/providers/auth_provider.dart`
- 어드민 권한 체크 헬퍼 함수 추가 (선택사항)

---

## 🚀 구현 단계

### Phase 1: 기본 구조 설정 (우선순위: 높음)

#### 1.1 Drawer 구현
- [ ] `lib/widgets/drawer/admin_drawer.dart` 생성
  - 어드민 전용 메뉴 아이템들
  - 대시보드, 사용자 관리, 회사 관리, 캠페인 관리, 리뷰 관리, 포인트 관리, 통계, 설정
  - 로그아웃 버튼

#### 1.2 라우팅 설정
- [ ] `app_router.dart`에 어드민 라우트 추가
- [ ] 각 라우트에 권한 체크 미들웨어 추가 (userType == admin)

#### 1.3 메인 스크린 수정
- [ ] `main_shell.dart`에서 Drawer 선택 로직 추가
- [ ] `mypage_screen.dart`에서 어드민 분기 추가

#### 1.4 기본 대시보드
- [ ] `admin_dashboard_screen.dart` 생성
  - 간단한 통계 카드들 (사용자 수, 회사 수, 캠페인 수 등)
  - 최근 활동 목록
  - 빠른 액션 버튼들

---

### Phase 2: 사용자 관리 (우선순위: 높음)

#### 2.1 사용자 목록 화면
- [ ] `admin_users_screen.dart` 생성
  - 사용자 목록 테이블/리스트
  - 검색 기능 (이메일, 이름)
  - 필터링 (user_type, status)
  - 페이지네이션

#### 2.2 사용자 상세/편집
- [ ] 사용자 상세 정보 표시
- [ ] 사용자 타입 변경 (RPC: `admin_change_user_role` 사용)
- [ ] 사용자 상태 변경 (active/inactive)
- [ ] 사용자 삭제/비활성화

#### 2.3 사용자 통계
- [ ] 사용자 가입 추이 (차트)
- [ ] 사용자 타입별 분포
- [ ] 활성 사용자 수

---

### Phase 3: 회사 관리 (우선순위: 중간)

#### 3.1 회사 목록 화면
- [ ] `admin_companies_screen.dart` 생성
  - 회사 목록 (사업자명, 사업자번호, 대표자명)
  - 검색 기능
  - 승인 상태 필터링

#### 3.2 회사 승인/거부
- [ ] 회사 등록 승인 기능
- [ ] 회사 정보 수정
- [ ] 회사 삭제/비활성화

#### 3.3 회사 통계
- [ ] 회사 등록 추이
- [ ] 승인 대기 중인 회사 수

---

### Phase 4: 캠페인 관리 (우선순위: 중간)

#### 4.1 캠페인 목록 화면
- [ ] `admin_campaigns_screen.dart` 생성
  - 모든 캠페인 목록
  - 상태별 필터링 (진행중, 종료, 대기중)
  - 검색 기능

#### 4.2 캠페인 승인/거부
- [ ] 캠페인 승인 기능
- [ ] 캠페인 거부 (사유 입력)
- [ ] 캠페인 수정/삭제

#### 4.3 캠페인 통계
- [ ] 캠페인 상태별 분포
- [ ] 캠페인별 참여자 수
- [ ] 캠페인별 예산/지출

---

### Phase 5: 리뷰 관리 (우선순위: 낮음)

#### 5.1 리뷰 목록 화면
- [ ] `admin_reviews_screen.dart` 생성
  - 모든 리뷰 목록
  - 신고된 리뷰 필터링
  - 검색 기능

#### 5.2 리뷰 관리
- [ ] 리뷰 삭제
- [ ] 리뷰 숨김 처리
- [ ] 신고 처리

---

### Phase 6: 포인트 관리 (우선순위: 중간)

#### 6.1 포인트 관리 화면
- [ ] `admin_points_screen.dart` 생성
  - 사용자별 포인트 현황
  - 포인트 지급/차감 기능
  - 포인트 이력 조회

#### 6.2 포인트 통계
- [ ] 총 포인트 발행량
- [ ] 포인트 사용량
- [ ] 포인트 지급 추이

---

### Phase 7: 통계 대시보드 (우선순위: 중간)

#### 7.1 통계 화면
- [ ] `admin_statistics_screen.dart` 생성
  - 사용자 통계 (가입 추이, 활성 사용자)
  - 캠페인 통계 (생성 추이, 참여율)
  - 포인트 통계 (발행량, 사용량)
  - 리뷰 통계 (작성 추이, 평균 평점)
  - 차트 라이브러리 사용 (fl_chart 또는 charts_flutter)

#### 7.2 데이터 내보내기
- [ ] 통계 데이터 CSV/Excel 내보내기 (선택사항)

---

### Phase 8: 시스템 설정 (우선순위: 낮음)

#### 8.1 시스템 설정 화면
- [ ] `admin_settings_screen.dart` 생성
  - 시스템 점검 모드 설정
  - 공지사항 관리
  - 이벤트 관리
  - 알림 설정

---

## 🔐 보안 및 권한 체크

### RPC 함수 활용
- 기존 RPC 함수 사용:
  - `admin_change_user_role`: 사용자 권한 변경

### 추가 필요한 RPC 함수 (백엔드에서 구현 필요)
1. `admin_get_users` - 사용자 목록 조회 (필터링, 페이지네이션)
2. `admin_get_companies` - 회사 목록 조회
3. `admin_approve_company` - 회사 승인
4. `admin_reject_company` - 회사 거부
5. `admin_get_campaigns` - 캠페인 목록 조회
6. `admin_approve_campaign` - 캠페인 승인
7. `admin_reject_campaign` - 캠페인 거부
8. `admin_get_statistics` - 통계 데이터 조회
9. `admin_manage_points` - 포인트 지급/차감

### 권한 체크 로직
- 모든 어드민 화면 진입 시 `user.userType == UserType.admin` 체크
- 라우트 가드 추가 (app_router.dart)
- RPC 함수 호출 전 권한 체크 (서버 측에서도 체크)

---

## 📊 데이터 모델

### 필요한 데이터 구조
- 사용자 정보: `users` 테이블
- 회사 정보: `companies` 테이블
- 캠페인 정보: `campaigns` 테이블
- 리뷰 정보: `reviews` 테이블
- 포인트 정보: `wallets`, `wallet_histories` 테이블

---

## 🎨 UI/UX 가이드라인

### 디자인 원칙
- 깔끔하고 전문적인 관리자 인터페이스
- 중요한 정보는 카드 형태로 표시
- 데이터 테이블은 정렬, 필터링, 검색 기능 제공
- 액션 버튼은 명확한 색상으로 구분 (승인: 초록, 거부: 빨강)

### 색상 팔레트
- 어드민 전용 색상: 보라색 계열 또는 회색 계열
- 위험 액션: 빨강
- 성공 액션: 초록
- 정보: 파랑

---

## 📝 구현 시 주의사항

### 1. 성능 최적화
- 대량 데이터 조회 시 페이지네이션 필수
- 무한 스크롤 또는 페이지 번호 방식 선택
- 검색/필터링 시 디바운싱 적용

### 2. 에러 처리
- 권한 없는 접근 시 명확한 에러 메시지
- 네트워크 에러 처리
- 데이터 로딩 실패 시 재시도 옵션

### 3. 사용자 경험
- 로딩 상태 표시
- 작업 완료 시 성공 메시지 (SnackBar)
- 확인 다이얼로그 (삭제, 거부 등 중요 액션)

### 4. 테스트
- 어드민 권한이 아닌 사용자의 접근 차단 테스트
- 각 관리 기능의 정상 동작 테스트
- 대량 데이터 처리 테스트

---

## 🔄 구현 순서 요약

1. **Phase 1**: 기본 구조 (Drawer, 라우팅, 대시보드)
2. **Phase 2**: 사용자 관리 (가장 중요)
3. **Phase 3**: 회사 관리
4. **Phase 4**: 캠페인 관리
5. **Phase 6**: 포인트 관리
6. **Phase 7**: 통계 대시보드
7. **Phase 5**: 리뷰 관리
8. **Phase 8**: 시스템 설정

---

## 📌 다음 단계

로드맵 검토 후, Phase 1부터 순차적으로 구현을 시작합니다.
각 Phase 완료 후 테스트 및 검토를 진행합니다.

