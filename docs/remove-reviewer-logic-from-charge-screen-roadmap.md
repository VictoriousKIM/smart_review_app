# PointChargeScreen에서 리뷰어 관련 로직 제거 로드맵

## 📋 개요

리뷰어는 포인트 충전이 불가능하므로, `PointChargeScreen`에서 리뷰어 관련 로직을 모두 제거합니다.

## 🔍 현재 문제점

1. **`_loadWalletInfo()` 메서드**
   - 리뷰어일 때 개인 지갑을 조회하는 로직이 있음
   - 하지만 `initState()`에서 이미 리뷰어 접근을 차단하므로 실행되지 않음
   - 불필요한 코드

2. **`_buildDepositAccountSection()` 메서드**
   - 리뷰어일 때 지갑에서 계좌 정보를 가져오는 로직이 있음
   - 하지만 리뷰어는 이 화면에 접근할 수 없으므로 불필요함

3. **코드 중복 및 혼란**
   - 리뷰어 관련 로직이 여러 곳에 산재되어 있음
   - 유지보수 시 혼란을 야기할 수 있음

## 🎯 제거 목표

1. `_loadWalletInfo()`에서 리뷰어 관련 로직 제거
2. `_buildDepositAccountSection()`에서 리뷰어 관련 로직 제거
3. 코드 단순화 및 명확화

## 📐 현재 코드 구조

### 1. `_loadWalletInfo()` 메서드 (67-117줄)

```dart
Future<void> _loadWalletInfo() async {
  // ...
  if (widget.userType == 'reviewer') {
    // 리뷰어: 무조건 개인 지갑 조회
    final wallet = await WalletService.getUserWallet();
    _currentPoints = wallet?.currentPoints ?? 0;
    _walletId = wallet?.id ?? '';
    _userWallet = wallet;
  } else if (widget.userType == 'advertiser') {
    // 광고주: owner 여부 확인
    // ...
  }
}
```

**문제**: `initState()`에서 이미 리뷰어 접근을 차단하므로 이 코드는 실행되지 않음

### 2. `_buildDepositAccountSection()` 메서드 (316-429줄)

```dart
Widget _buildDepositAccountSection() {
  // 광고주일 때는 고정된 계좌 정보 표시
  if (widget.userType == 'advertiser') {
    // ...
  }

  // 리뷰어일 때는 지갑에서 계좌 정보 가져오기
  String? bankName, accountNumber, accountHolder;
  // ...
}
```

**문제**: 리뷰어는 이 화면에 접근할 수 없으므로 이 로직은 불필요함

## 🔧 해결 방안

### Step 1: `_loadWalletInfo()` 메서드 수정

**변경 사항**:
- 리뷰어 관련 조건문 제거
- 광고주 로직만 유지

**수정 후**:
```dart
Future<void> _loadWalletInfo() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final user = await _authService.currentUser;
    if (user == null) return;

    // 광고주만 처리 (리뷰어는 initState에서 차단됨)
    if (widget.userType == 'advertiser') {
      final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);
      if (isOwner) {
        // owner: 회사 지갑 조회
        final companyId = await CompanyUserService.getUserCompanyId(user.uid);
        if (companyId != null) {
          final companyWallet =
              await WalletService.getCompanyWalletByCompanyId(companyId);
          _currentPoints = companyWallet?.currentPoints ?? 0;
          _walletId = companyWallet?.id ?? '';
          _companyWallet = companyWallet;
        }
      } else {
        // manager: 개인 지갑 조회
        final wallet = await WalletService.getUserWallet();
        _currentPoints = wallet?.currentPoints ?? 0;
        _walletId = wallet?.id ?? '';
        _userWallet = wallet;
      }
    }

    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    // ...
  }
}
```

### Step 2: `_buildDepositAccountSection()` 메서드 수정

**변경 사항**:
- 리뷰어 관련 로직 제거
- 광고주일 때만 고정된 계좌 정보 표시
- 리뷰어일 때 지갑에서 계좌 정보를 가져오는 부분 완전 제거

**수정 후**:
```dart
Widget _buildDepositAccountSection() {
  // 광고주일 때만 고정된 계좌 정보 표시
  // (리뷰어는 이 화면에 접근할 수 없음)
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '입금계좌정보',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '은행명: 농협',
              style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            SizedBox(height: 8),
            Text(
              '계좌번호: 312-0172-8650-01',
              style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            SizedBox(height: 8),
            Text(
              '예금주: 김동익',
              style: TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
          ],
        ),
      ),
    ],
  );
}
```

### Step 3: 불필요한 변수 및 메서드 확인

**확인 사항**:
- `_userWallet` 변수: 리뷰어 로직 제거 후 사용되지 않을 수 있음
- `_copyAccountNumber()` 메서드: 리뷰어 로직 제거 후 사용되지 않을 수 있음
- `_buildAccountInfoRow()` 메서드: 리뷰어 로직 제거 후 사용되지 않을 수 있음

**결과**:
- 광고주는 고정된 계좌 정보만 표시하므로 복사 기능 불필요
- `_userWallet`는 manager일 때 사용되므로 유지 필요
- `_buildAccountInfoRow()`는 사용되지 않으므로 제거 가능
- `_copyAccountNumber()`는 사용되지 않으므로 제거 가능

## 📝 구현 단계

### Step 1: `_loadWalletInfo()` 메서드 수정
- [ ] 리뷰어 관련 조건문 제거
- [ ] 광고주 로직만 유지
- [ ] 주석 추가: "리뷰어는 initState에서 차단됨"

### Step 2: `_buildDepositAccountSection()` 메서드 수정
- [ ] 리뷰어 관련 로직 완전 제거
- [ ] 광고주 고정 계좌 정보만 표시
- [ ] 불필요한 변수 선언 제거

### Step 3: 불필요한 메서드 제거
- [ ] `_buildAccountInfoRow()` 메서드 제거 (사용되지 않음)
- [ ] `_copyAccountNumber()` 메서드 제거 (사용되지 않음)

### Step 4: 변수 정리
- [ ] `_userWallet` 변수 확인: manager일 때 사용되므로 유지
- [ ] `_companyWallet` 변수 확인: owner일 때 사용되므로 유지

## ⚠️ 주의사항

1. **`initState()`의 리뷰어 체크는 유지**
   - 리뷰어 접근 차단을 위해 필수
   - 이 로직은 제거하지 않음

2. **광고주 manager 처리**
   - 광고주 manager는 개인 지갑을 사용하지만 충전은 가능
   - `_userWallet` 변수는 manager를 위해 유지 필요

3. **코드 단순화**
   - 리뷰어 관련 로직 제거로 코드가 더 명확해짐
   - 광고주만 처리하므로 조건문 단순화

## 🔍 검증 항목

- [ ] 리뷰어 관련 로직이 모두 제거되었는지
- [ ] 광고주 owner가 충전 화면에서 고정 계좌 정보를 볼 수 있는지
- [ ] 광고주 manager가 충전 화면에서 고정 계좌 정보를 볼 수 있는지
- [ ] 불필요한 메서드가 제거되었는지
- [ ] 코드가 더 명확하고 단순해졌는지

## 📅 예상 소요 시간

- Step 1: 10분
- Step 2: 15분
- Step 3: 10분
- Step 4: 5분

**총 예상 시간**: 약 40분

