# 마이페이지 새로고침 시 리다이렉트 문제 상세 분석 및 해결 방안

## 📋 문제 개요

마이페이지에서 새로고침(페이지 리로드)을 하면:
- ✅ **어드민**: 새로고침해도 `/mypage/admin` 경로가 유지됨
- ❌ **리뷰어**: 새로고침 시 `/mypage/reviewer`에서 `/home`으로 리다이렉트됨
- ❌ **광고주**: 새로고침 시 `/mypage/advertiser`에서 `/home`으로 리다이렉트됨

## 🔍 마이페이지로 연결되는 모든 로직 분석

### 1. 네비게이션 진입점

#### 1.1 하단 네비게이션 바 (`main_shell.dart`)

```106:125:lib/widgets/main_shell.dart
      case 3:
        // 마이페이지: 마지막 방문한 경로가 있으면 그 경로로, 없으면 사용자 타입에 따라 이동
        if (_lastMyPagePath != null) {
          // 마지막 방문한 경로로 이동
          context.go(_lastMyPagePath!);
        } else {
          // 마지막 경로가 없으면 사용자 타입에 따라 적절한 경로로 이동
          final user = ref.read(currentUserProvider).value;
          if (user != null) {
            if (user.userType == app_user.UserType.admin) {
              context.go('/mypage/admin');
            } else if (user.companyId != null) {
              context.go('/mypage/advertiser');
            } else {
              context.go('/mypage/reviewer');
            }
          } else {
            context.go('/mypage');
          }
        }
        break;
```

**특징:**
- `_lastMyPagePath`를 추적하여 마지막 방문 경로로 이동
- 사용자 타입에 따라 적절한 마이페이지로 분기
- `ref.read()`를 사용하여 동기적으로 사용자 정보 읽기

#### 1.2 직접 경로 접근 (`/mypage`)

```174:196:lib/config/app_router.dart
          // [2] 마이페이지 분기
          GoRoute(
            path: '/mypage',
            name: 'mypage',
            redirect: (context, state) {
              if (state.matchedLocation != '/mypage') return null;

              // 동기적 상태 읽기
              final userAsync = ref.read(currentUserProvider);

              return userAsync.when(
                data: (user) {
                  if (user == null) return '/login';
                  if (user.userType == app_user.UserType.admin)
                    return '/mypage/admin';
                  if (user.isAdvertiser) return '/mypage/advertiser';
                  return '/mypage/reviewer';
                },
                // 🔥 [핵심] 로딩이나 에러 시 절대 리다이렉트 하지 않음 (현재 경로 유지)
                loading: () => null,
                error: (_, __) => null,
              );
            },
          ),
```

**특징:**
- `/mypage` 접근 시 사용자 타입에 따라 적절한 마이페이지로 리다이렉트
- 로딩/에러 시 `null` 반환하여 현재 경로 유지

#### 1.3 화면 내 네비게이션

**리뷰어 마이페이지:**
- 사업자 전환: `context.pushReplacement('/mypage/advertiser')`
- 관리자 대시보드: `context.pushReplacement('/mypage/admin')`
- 프로필: `context.go('/mypage/profile')`
- 포인트: `context.go('/mypage/reviewer/points')`

**광고주 마이페이지:**
- 리뷰어 전환: `context.pushReplacement('/mypage/reviewer')`
- 관리자 대시보드: `context.pushReplacement('/mypage/admin')`
- 프로필: `context.go('/mypage/profile?tab=business')`
- 포인트: `context.go('/mypage/advertiser/points')`

**관리자 대시보드:**
- 리뷰어 전환: `context.go('/mypage/reviewer')`
- 사업자 전환: `context.go('/mypage/advertiser')`

### 2. 라우팅 구조 분석

#### 2.1 전역 Redirect (`app_router.dart`)

```97:121:lib/config/app_router.dart
    // [1] 전역 Redirect
    redirect: (context, state) async {
      final matchedLocation = state.matchedLocation;

      final isLoggingIn = matchedLocation == '/login';
      final isRoot = matchedLocation == '/';

      // 1. 세션 확인 (비동기)
      final user = await authService.currentUser;
      final isLoggedIn = user != null;

      // 2. 비로그인 상태
      if (!isLoggedIn) {
        if (isLoggingIn) return null;
        // 마이페이지도 로컬 redirect에서 처리하므로 전역에서는 로그인 체크만
        return '/login';
      }

      // 3. 로그인 상태
      if (isLoggedIn) {
        // 로그인 페이지나 루트 접근 시 홈으로
        if (isLoggingIn || isRoot) return '/home';
      }

      return null;
    },
```

**특징:**
- 모든 경로에 대해 로그인 상태 확인
- 비로그인 시 `/login`으로 리다이렉트
- 로그인 상태에서 `/login` 또는 `/` 접근 시 `/home`으로 리다이렉트
- 마이페이지에 대한 특별 처리 없음 (일반 경로처럼 처리)

#### 2.2 리뷰어 마이페이지 Redirect

```199:227:lib/config/app_router.dart
          // [3] 리뷰어 마이페이지
          GoRoute(
            path: '/mypage/reviewer',
            name: 'mypage-reviewer',
            redirect: (context, state) {
              final userAsync = ref.read(currentUserProvider);
              return userAsync.when(
                data: (user) {
                  if (user == null) return '/login';
                  return null; // 통과
                },
                // 🔥 [핵심] 로딩/에러 시 현재 URL 유지 -> Builder에서 UI 처리
                loading: () => null,
                error: (_, __) => null,
              );
            },
            builder: (context, state) {
              // Builder 내에서 상태에 따라 UI 분기
              final userAsync = ref.watch(currentUserProvider);
              return userAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return ReviewerMyPageScreen(user: user);
                },
                // 로딩 중일 때 보여줄 UI
                loading: () => const LoadingScreen(),
                // 에러 났을 때 보여줄 UI (로그인으로 튕기지 않음)
                error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
              );
            },
```

**특징:**
- 로그인 체크만 수행
- 로딩/에러 시 `null` 반환하여 현재 경로 유지
- Builder에서 로딩 화면 표시

#### 2.3 광고주 마이페이지 Redirect

```278:305:lib/config/app_router.dart
          // [4] 광고주 마이페이지
          GoRoute(
            path: '/mypage/advertiser',
            name: 'mypage-advertiser',
            redirect: (context, state) {
              final userAsync = ref.read(currentUserProvider);
              return userAsync.when(
                data: (user) {
                  if (user == null) return '/login';
                  if (user.userType == app_user.UserType.admin) return null;
                  if (user.isAdvertiser) return null;
                  return '/mypage/reviewer';
                },
                // 🔥 [핵심] 로딩/에러 시 현재 URL 유지
                loading: () => null,
                error: (_, __) => null,
              );
            },
            builder: (context, state) {
              final userAsync = ref.watch(currentUserProvider);
              return userAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return AdvertiserMyPageScreen(user: user);
                },
                loading: () => const LoadingScreen(),
                error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
              );
            },
```

**특징:**
- 로그인 체크 및 사용자 타입 확인
- 어드민은 통과, 광고주는 통과, 그 외는 리뷰어로 리다이렉트
- 로딩/에러 시 `null` 반환하여 현재 경로 유지

#### 2.4 관리자 대시보드

```390:394:lib/config/app_router.dart
          // Admin 및 공통 라우트들 (기존과 동일)
          GoRoute(
            path: '/mypage/admin',
            name: 'admin-dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
```

**특징:**
- **redirect가 없음** - 이것이 핵심 차이점!
- Builder만 있어서 경로가 그대로 유지됨
- 화면 내에서 권한 체크 수행

### 3. 인증 상태 관리

#### 3.1 GoRouter Refresh Stream

```64:85:lib/config/app_router.dart
/// GoRouter Refresh Notifier
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        notifyListeners();
      });
    });
  }

  late final StreamSubscription<dynamic> _subscription;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
```

```94:94:lib/config/app_router.dart
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
```

**특징:**
- `authStateChanges` 스트림을 감지하여 GoRouter 재평가 트리거
- 200ms 디바운스 적용
- 새로고침 시 Supabase의 `onAuthStateChange`가 트리거됨

#### 3.2 CurrentUser Provider

```12:16:lib/providers/auth_provider.dart
// 현재 사용자 Provider
@riverpod
Future<app_user.User?> currentUser(Ref ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.currentUser;
}
```

**특징:**
- `Future`를 반환하는 비동기 Provider
- 새로고침 시 초기 로딩 상태가 발생할 수 있음

## 🔴 문제 원인 분석

### 핵심 원인: 새로고침 시 Redirect 체인에서의 타이밍 이슈

#### 시나리오 1: 리뷰어/광고주 마이페이지 새로고침

1. **새로고침 발생**
   - 브라우저가 페이지를 리로드
   - URL은 `/mypage/reviewer` 또는 `/mypage/advertiser` 유지

2. **GoRouter 초기화**
   - `GoRouterRefreshStream`이 `authStateChanges`를 감지
   - GoRouter가 전체 라우팅 로직 재평가 시작

3. **전역 Redirect 실행**
   ```dart
   redirect: (context, state) async {
     final user = await authService.currentUser;  // 비동기 호출
     // ... 로그인 체크 후 null 반환 (통과)
   }
   ```
   - 비동기로 사용자 정보 조회
   - 로그인 상태 확인 후 `null` 반환 (통과)

4. **로컬 Redirect 실행 (문제 발생 지점)**
   ```dart
   redirect: (context, state) {
     final userAsync = ref.read(currentUserProvider);  // 동기 호출
     return userAsync.when(
       loading: () => null,  // 로딩 시 null 반환
       // ...
     );
   }
   ```
   - **문제**: 새로고침 직후 `currentUserProvider`가 아직 로딩 중일 수 있음
   - `ref.read()`는 현재 상태를 즉시 반환 (Future가 완료되지 않았을 수 있음)
   - 로딩 상태에서 `null`을 반환하여 통과

5. **Builder 실행**
   ```dart
   builder: (context, state) {
     final userAsync = ref.watch(currentUserProvider);
     return userAsync.when(
       loading: () => const LoadingScreen(),
       // ...
     );
   }
   ```
   - `ref.watch()`로 상태 감시
   - 로딩 화면 표시

6. **인증 상태 변경 감지 (추가 재평가)**
   - `authStateChanges`가 다시 트리거될 수 있음
   - GoRouter가 다시 재평가
   - 이 과정에서 경로가 변경될 수 있음

#### 시나리오 2: 어드민 마이페이지 새로고침 (정상 작동)

1. **새로고침 발생**
   - URL은 `/mypage/admin` 유지

2. **전역 Redirect 실행**
   - 로그인 체크 후 `null` 반환 (통과)

3. **로컬 Redirect 실행**
   - **어드민은 redirect가 없음!**
   - 바로 Builder로 이동

4. **Builder 실행**
   ```dart
   builder: (context, state) => const AdminDashboardScreen(),
   ```
   - 화면 내에서 권한 체크
   - 경로가 유지됨

### 왜 어드민은 작동하고 리뷰어/광고주는 작동하지 않는가?

**핵심 차이점:**

| 구분 | 어드민 | 리뷰어/광고주 |
|------|--------|--------------|
| Redirect 존재 | ❌ 없음 | ✅ 있음 |
| 새로고침 시 재평가 | 전역 redirect만 실행 | 전역 + 로컬 redirect 실행 |
| 로딩 상태 처리 | 불필요 | 필요 (문제 발생 지점) |
| 경로 유지 | 항상 유지 | 로딩 상태에서 불안정 |

### 추가 원인: `ref.read()` vs `ref.watch()` 불일치

**로컬 Redirect에서:**
```dart
final userAsync = ref.read(currentUserProvider);  // 동기적 읽기
```

**Builder에서:**
```dart
final userAsync = ref.watch(currentUserProvider);  // 반응형 감시
```

**문제:**
- `ref.read()`는 현재 캐시된 값을 즉시 반환
- 새로고침 직후 캐시가 비어있거나 로딩 상태일 수 있음
- `ref.watch()`는 상태 변경을 감지하지만, redirect는 한 번만 실행됨

### 가능한 추가 원인: 전역 Redirect의 비동기 처리

전역 redirect가 `async`이고 `await authService.currentUser`를 호출하는데, 이 과정에서:
1. 네트워크 지연
2. 세션 갱신
3. 프로필 조회

등의 과정이 발생하면서 시간이 걸릴 수 있습니다. 이 동안 로컬 redirect가 실행되면 로딩 상태일 수 있습니다.

## 🛠️ 해결 방안

### 해결 방안 1: 어드민처럼 Redirect 제거 (권장)

리뷰어와 광고주 마이페이지에서도 redirect를 제거하고, Builder에서만 권한 체크를 수행합니다.

**장점:**
- 어드민과 동일한 패턴으로 일관성 유지
- 새로고침 시 경로가 항상 유지됨
- 로딩 상태 처리 불필요

**단점:**
- Builder에서 권한 체크 로직 추가 필요

**구현:**

```dart
// [3] 리뷰어 마이페이지
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  // redirect 제거
  builder: (context, state) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          // 비로그인 시 로그인으로 리다이렉트 (Builder 내에서 처리)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const LoadingScreen();
        }
        return ReviewerMyPageScreen(user: user);
      },
      loading: () => const LoadingScreen(),
      error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
    );
  },
  // ... routes
),

// [4] 광고주 마이페이지
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  // redirect 제거
  builder: (context, state) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const LoadingScreen();
        }
        // 권한 체크
        if (user.userType == app_user.UserType.admin) {
          // 어드민은 통과 (어드민도 광고주 마이페이지 접근 가능)
        } else if (!user.isAdvertiser) {
          // 광고주가 아니면 리뷰어로 리다이렉트
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/mypage/reviewer');
          });
          return const LoadingScreen();
        }
        return AdvertiserMyPageScreen(user: user);
      },
      loading: () => const LoadingScreen(),
      error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
    );
  },
  // ... routes
),
```

### 해결 방안 2: Redirect에서 비동기 처리

로컬 redirect를 `async`로 변경하고 `ref.read()` 대신 직접 `authService.currentUser`를 호출합니다.

**장점:**
- 현재 구조 유지
- 명시적인 비동기 처리

**단점:**
- redirect가 복잡해짐
- 타이밍 이슈가 완전히 해결되지 않을 수 있음

**구현:**

```dart
// [3] 리뷰어 마이페이지
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) async {
    // 비동기로 사용자 정보 조회
    final user = await ref.read(authServiceProvider).currentUser;
    if (user == null) return '/login';
    return null; // 통과
  },
  builder: (context, state) {
    // ... 기존과 동일
  },
),
```

**주의사항:**
- GoRouter의 redirect는 `async`를 지원하지만, 반복 호출을 방지해야 함
- 로딩 상태 처리가 어려움

### 해결 방안 3: 전역 Redirect에서 마이페이지 특별 처리

전역 redirect에서 마이페이지 경로를 감지하여 특별히 처리합니다.

**장점:**
- 로컬 redirect 로직 유지
- 전역에서 일관된 처리

**단점:**
- 전역 redirect가 복잡해짐
- 마이페이지 특별 처리로 인한 일관성 저하

**구현:**

```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  
  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';
  final isMyPage = matchedLocation.startsWith('/mypage');

  // 1. 세션 확인 (비동기)
  final user = await authService.currentUser;
  final isLoggedIn = user != null;

  // 2. 비로그인 상태
  if (!isLoggedIn) {
    if (isLoggingIn) return null;
    return '/login';
  }

  // 3. 로그인 상태
  if (isLoggedIn) {
    // 로그인 페이지나 루트 접근 시 홈으로
    if (isLoggingIn || isRoot) return '/home';
    
    // 마이페이지는 로컬 redirect에 위임 (특별 처리)
    if (isMyPage) return null;
  }

  return null;
},
```

### 해결 방안 4: `ref.read()` 대신 `ref.watch()` 사용 (비권장)

로컬 redirect에서 `ref.watch()`를 사용하지만, 이는 권장되지 않습니다.

**이유:**
- redirect는 한 번만 실행되어야 하는데, `ref.watch()`는 반응형
- 무한 루프 위험
- 성능 문제

## ✅ 권장 해결 방안: 해결 방안 1

**이유:**
1. **일관성**: 어드민과 동일한 패턴
2. **안정성**: 새로고침 시 경로가 항상 유지됨
3. **단순성**: redirect 로직 제거로 코드 단순화
4. **유지보수성**: Builder에서 모든 로직 처리로 이해하기 쉬움

## 🔧 구현 단계

### 1단계: 리뷰어 마이페이지 Redirect 제거

```dart
// lib/config/app_router.dart
// [3] 리뷰어 마이페이지
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  // redirect 제거
  builder: (context, state) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          // 비로그인 시 로그인으로 리다이렉트
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/login');
            }
          });
          return const LoadingScreen();
        }
        return ReviewerMyPageScreen(user: user);
      },
      loading: () => const LoadingScreen(),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('데이터 로드 실패: $err'),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('홈으로 이동'),
            ),
          ],
        ),
      ),
    );
  },
  routes: [
    // ... 기존 routes 유지
  ],
),
```

### 2단계: 광고주 마이페이지 Redirect 제거

```dart
// lib/config/app_router.dart
// [4] 광고주 마이페이지
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  // redirect 제거
  builder: (context, state) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          // 비로그인 시 로그인으로 리다이렉트
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/login');
            }
          });
          return const LoadingScreen();
        }
        
        // 권한 체크
        if (user.userType != app_user.UserType.admin && !user.isAdvertiser) {
          // 광고주가 아니면 리뷰어로 리다이렉트
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/mypage/reviewer');
            }
          });
          return const LoadingScreen();
        }
        
        return AdvertiserMyPageScreen(user: user);
      },
      loading: () => const LoadingScreen(),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('데이터 로드 실패: $err'),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('홈으로 이동'),
            ),
          ],
        ),
      ),
    );
  },
  routes: [
    // ... 기존 routes 유지
  ],
),
```

### 3단계: 테스트

1. **리뷰어 마이페이지**
   - `/mypage/reviewer` 접속
   - 새로고침 (F5 또는 Ctrl+R)
   - 경로가 유지되는지 확인

2. **광고주 마이페이지**
   - `/mypage/advertiser` 접속
   - 새로고침 (F5 또는 Ctrl+R)
   - 경로가 유지되는지 확인

3. **하위 경로**
   - `/mypage/reviewer/points` 접속 후 새로고침
   - `/mypage/advertiser/points` 접속 후 새로고침
   - 경로가 유지되는지 확인

4. **비로그인 상태**
   - 로그아웃 후 `/mypage/reviewer` 접속
   - 로그인 페이지로 리다이렉트되는지 확인

5. **권한 체크**
   - 리뷰어 계정으로 `/mypage/advertiser` 접속
   - 리뷰어 마이페이지로 리다이렉트되는지 확인

## 📝 추가 고려사항

### 1. `WidgetsBinding.instance.addPostFrameCallback` 사용 이유

Builder 내에서 직접 `context.go()`를 호출하면:
- Build 과정 중에 네비게이션이 발생하여 위젯 트리 오류 가능
- `addPostFrameCallback`을 사용하여 Build 완료 후 실행

### 2. `context.mounted` 체크

비동기 작업 후 `context.mounted`를 체크하여:
- 위젯이 여전히 마운트되어 있는지 확인
- 메모리 누수 방지

### 3. 에러 처리

에러 발생 시:
- 사용자에게 에러 메시지 표시
- 홈으로 이동할 수 있는 버튼 제공
- 로그인으로 강제 리다이렉트하지 않음 (사용자 경험 개선)

## 🎯 결론

**문제의 핵심:**
- 리뷰어/광고주 마이페이지에 redirect가 있어서 새로고침 시 재평가 과정에서 타이밍 이슈 발생
- 어드민은 redirect가 없어서 경로가 항상 유지됨

**해결 방법:**
- 리뷰어/광고주 마이페이지에서도 redirect를 제거하고 Builder에서만 권한 체크
- 어드민과 동일한 패턴으로 일관성 유지
- 새로고침 시 경로가 항상 유지되도록 보장

이 방법을 통해 새로고침 시에도 마이페이지 경로가 유지되도록 보장할 수 있습니다.

