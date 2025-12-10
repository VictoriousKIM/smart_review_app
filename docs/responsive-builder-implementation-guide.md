# ResponsiveBuilder 패키지 전체 스크린 적용 가이드

**작성일**: 2025년 12월 10일  
**대상**: Smart Review App 전체 프로젝트  
**목표**: 모든 스크린에 ResponsiveBuilder 패키지를 적용하여 일관된 반응형 디자인 구현

## 📋 목차

1. [ResponsiveBuilder 패키지 소개](#responsivebuilder-패키지-소개)
2. [설치 및 설정](#설치-및-설정)
3. [기본 사용법](#기본-사용법)
4. [프로젝트 전체 적용 전략](#프로젝트-전체-적용-전략)
5. [단계별 마이그레이션 계획](#단계별-마이그레이션-계획)
6. [공통 위젯 및 헬퍼 생성](#공통-위젯-및-헬퍼-생성)
7. [스크린 타입별 적용 예시](#스크린-타입별-적용-예시)
8. [베스트 프랙티스](#베스트-프랙티스)
9. [주의사항 및 트러블슈팅](#주의사항-및-트러블슈팅)

---

## ResponsiveBuilder 패키지 소개

### 패키지 정보

- **패키지명**: `responsive_builder`
- **pub.dev**: https://pub.dev/packages/responsive_builder
- **버전**: ^0.7.0 (최신 안정 버전)
- **라이선스**: MIT

### 주요 기능

1. **자동 화면 크기 감지**: Mobile, Tablet, Desktop 자동 구분
2. **표준화된 브레이크포인트**: 일관된 반응형 디자인 시스템
3. **간편한 API**: `SizingInformation` 객체로 화면 정보 제공
4. **Orientation 지원**: 세로/가로 모드 감지
5. **Device Type 감지**: Phone, Tablet, Desktop 구분

### 기본 브레이크포인트

```dart
// 기본값 (커스터마이징 가능)
mobile: < 600px
tablet: 600px ~ 1200px
desktop: >= 1200px
```

---

## 설치 및 설정

### 1. 패키지 설치

```bash
flutter pub add responsive_builder
```

또는 `pubspec.yaml`에 직접 추가:

```yaml
dependencies:
  responsive_builder: ^0.7.0
```

### 2. 패키지 가져오기

```dart
import 'package:responsive_builder/responsive_builder.dart';
```

---

## 기본 사용법

### 기본 구조

```dart
ResponsiveBuilder(
  builder: (context, sizingInformation) {
    // sizingInformation을 사용하여 반응형 로직 구현
    if (sizingInformation.isMobile) {
      return MobileLayout();
    } else if (sizingInformation.isTablet) {
      return TabletLayout();
    } else {
      return DesktopLayout();
    }
  },
)
```

### SizingInformation 속성

```dart
sizingInformation.deviceScreenType  // DeviceScreenType.mobile/tablet/desktop
sizingInformation.screenSize        // Size(width, height)
sizingInformation.localWidgetSize   // Size (위젯의 실제 크기)
sizingInformation.orientation       // Orientation.portrait/landscape
sizingInformation.isMobile          // bool
sizingInformation.isTablet          // bool
sizingInformation.isDesktop         // bool
```

---

## 프로젝트 전체 적용 전략

### 적용 범위

프로젝트의 모든 스크린에 ResponsiveBuilder를 적용:

1. **인증 화면** (auth/)
   - login_screen.dart
   - signup_screen.dart
   - reviewer_signup_screen.dart
   - advertiser_signup_screen.dart

2. **홈 화면** (home/)
   - home_screen.dart

3. **캠페인 화면** (campaign/)
   - campaigns_screen.dart
   - campaign_detail_screen.dart
   - campaign_creation_screen.dart
   - campaign_edit_screen.dart

4. **마이페이지 화면** (mypage/)
   - reviewer_mypage_screen.dart
   - advertiser_mypage_screen.dart
   - profile_screen.dart
   - points_screen.dart
   - 기타 모든 마이페이지 하위 화면

5. **관리자 화면** (mypage/admin/)
   - admin_dashboard_screen.dart
   - admin_users_screen.dart
   - 기타 모든 관리자 화면

6. **기타 화면**
   - guide_screen.dart
   - account_deletion_screen.dart

### 적용 우선순위

1. **Phase 1 (우선순위 높음)**: 사용자 경험에 직접적인 영향
   - 캠페인 생성/편집 화면
   - 프로필 화면
   - 포인트 관련 화면

2. **Phase 2 (우선순위 중간)**: 자주 사용되는 화면
   - 홈 화면
   - 캠페인 목록/상세 화면
   - 마이페이지 메인 화면

3. **Phase 3 (우선순위 낮음)**: 덜 자주 사용되는 화면
   - 관리자 화면
   - 가이드 화면
   - 계정 삭제 화면

---

## 단계별 마이그레이션 계획

### Phase 0: 준비 단계 (1일)

#### 1. 패키지 설치

```bash
flutter pub add responsive_builder
flutter pub get
```

#### 2. 공통 유틸리티 생성

`lib/utils/responsive_helper.dart` 파일 생성 (다음 섹션 참조)

#### 3. 브레이크포인트 커스터마이징 (선택사항)

```dart
// lib/config/responsive_config.dart
import 'package:responsive_builder/responsive_builder.dart';

class ResponsiveConfig {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;
  
  static DeviceScreenType getDeviceType(double width) {
    if (width < mobileBreakpoint) {
      return DeviceScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }
}
```

### Phase 1: 핵심 화면 마이그레이션 (3-5일)

1. 캠페인 생성 화면 (`campaign_creation_screen.dart`)
2. 캠페인 편집 화면 (`campaign_edit_screen.dart`)
3. 프로필 화면 (`profile_screen.dart`)
4. 포인트 화면 (`points_screen.dart`)

### Phase 2: 주요 화면 마이그레이션 (5-7일)

1. 홈 화면 (`home_screen.dart`)
2. 캠페인 목록 화면 (`campaigns_screen.dart`)
3. 캠페인 상세 화면 (`campaign_detail_screen.dart`)
4. 마이페이지 메인 화면들

### Phase 3: 나머지 화면 마이그레이션 (3-5일)

1. 인증 화면들
2. 관리자 화면들
3. 기타 화면들

---

## 공통 위젯 및 헬퍼 생성

### 1. ResponsiveHelper 유틸리티

```dart
// lib/utils/responsive_helper.dart
import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

class ResponsiveHelper {
  /// 반응형 값 반환 (Mobile, Tablet, Desktop)
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return getValueForScreenType<T>(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile,
      desktop: desktop ?? tablet ?? mobile,
    );
  }
  
  /// 반응형 패딩 반환
  static EdgeInsets responsivePadding({
    required BuildContext context,
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    return responsiveValue<EdgeInsets>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 폰트 크기 반환
  static double responsiveFontSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 아이콘 크기 반환
  static double responsiveIconSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// 반응형 최대 너비 반환
  static double responsiveMaxWidth({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}
```

### 2. ResponsiveScreen 위젯 (공통 래퍼)

```dart
// lib/widgets/responsive_screen.dart
import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 모든 스크린의 body를 감싸는 공통 위젯
class ResponsiveScreen extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool centerContent;
  
  const ResponsiveScreen({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.padding,
    this.maxWidth,
    this.centerContent = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // 레이아웃 선택
        Widget layout = mobile;
        if (sizingInformation.isTablet && tablet != null) {
          layout = tablet!;
        } else if (sizingInformation.isDesktop && desktop != null) {
          layout = desktop!;
        }
        
        // 패딩 적용
        if (padding != null) {
          layout = Padding(
            padding: padding!,
            child: layout,
          );
        }
        
        // 최대 너비 제한
        if (maxWidth != null) {
          layout = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: layout,
            ),
          );
        } else if (centerContent) {
          layout = Center(child: layout);
        }
        
        return layout;
      },
    );
  }
}
```

### 3. ResponsiveContainer 위젯

```dart
// lib/widgets/responsive_container.dart
import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// 반응형 Container 위젯
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? maxWidth;
  final Color? color;
  final BoxDecoration? decoration;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.maxWidth,
    this.color,
    this.decoration,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // 반응형 패딩
        final responsivePadding = padding != null
            ? getValueForScreenType<EdgeInsets>(
                context: context,
                mobile: padding!,
                tablet: EdgeInsets.all(padding!.horizontal * 1.5),
                desktop: EdgeInsets.all(padding!.horizontal * 2),
              )
            : null;
        
        // 반응형 최대 너비
        final responsiveMaxWidth = maxWidth != null
            ? getValueForScreenType<double>(
                context: context,
                mobile: double.infinity,
                tablet: maxWidth! * 0.9,
                desktop: maxWidth!,
              )
            : null;
        
        return Container(
          padding: responsivePadding,
          margin: margin,
          width: width,
          constraints: responsiveMaxWidth != null
              ? BoxConstraints(maxWidth: responsiveMaxWidth)
              : null,
          color: color,
          decoration: decoration,
          child: child,
        );
      },
    );
  }
}
```

---

## 스크린 타입별 적용 예시

### 예시 1: 간단한 스크린 (로그인 화면)

#### Before

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 로그인 폼
        ],
      ),
    ),
  );
}
```

#### After

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ResponsiveBuilder(
      builder: (context, sizingInformation) {
        return SingleChildScrollView(
          padding: getValueForScreenType<EdgeInsets>(
            context: context,
            mobile: const EdgeInsets.all(24),
            tablet: const EdgeInsets.symmetric(horizontal: 100, vertical: 40),
            desktop: const EdgeInsets.symmetric(horizontal: 200, vertical: 60),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: getValueForScreenType<double>(
                  context: context,
                  mobile: double.infinity,
                  tablet: 500,
                  desktop: 400,
                ),
              ),
              child: Column(
                children: [
                  // 로그인 폼
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
```

### 예시 2: 복잡한 스크린 (캠페인 생성 화면)

#### Before

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProductSection(),
            _buildScheduleSection(),
            _buildRewardSection(),
          ],
        ),
      ),
    ),
  );
}
```

#### After

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ResponsiveBuilder(
      builder: (context, sizingInformation) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: getValueForScreenType<EdgeInsets>(
              context: context,
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              desktop: const EdgeInsets.symmetric(horizontal: 100, vertical: 30),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: getValueForScreenType<double>(
                    context: context,
                    mobile: double.infinity,
                    tablet: 700,
                    desktop: 900,
                  ),
                ),
                child: Column(
                  children: [
                    _buildProductSection(),
                    _buildScheduleSection(),
                    _buildRewardSection(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
```

### 예시 3: 그리드 레이아웃 (캠페인 목록 화면)

#### Before

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) => _buildCampaignCard(),
    ),
  );
}
```

#### After

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ResponsiveBuilder(
      builder: (context, sizingInformation) {
        return GridView.builder(
          padding: getValueForScreenType<EdgeInsets>(
            context: context,
            mobile: const EdgeInsets.all(16),
            tablet: const EdgeInsets.all(24),
            desktop: const EdgeInsets.all(32),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: getValueForScreenType<int>(
              context: context,
              mobile: 1,
              tablet: 2,
              desktop: 3,
            ),
            crossAxisSpacing: getValueForScreenType<double>(
              context: context,
              mobile: 12,
              tablet: 16,
              desktop: 24,
            ),
            mainAxisSpacing: getValueForScreenType<double>(
              context: context,
              mobile: 12,
              tablet: 16,
              desktop: 24,
            ),
            childAspectRatio: getValueForScreenType<double>(
              context: context,
              mobile: 1.2,
              tablet: 1.1,
              desktop: 1.0,
            ),
          ),
          itemBuilder: (context, index) => _buildCampaignCard(),
        );
      },
    ),
  );
}
```

### 예시 4: 탭 레이아웃 (프로필 화면)

#### Before

```dart
Widget _buildTabbedContent() {
  return Column(
    children: [
      TabBar(...),
      Expanded(
        child: TabBarView(
          children: [
            _buildProfileContent(),
            _buildBusinessTab(),
          ],
        ),
      ),
    ],
  );
}
```

#### After

```dart
Widget _buildTabbedContent() {
  return ResponsiveBuilder(
    builder: (context, sizingInformation) {
      // 데스크톱에서는 가로 레이아웃
      if (sizingInformation.isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사이드바 형태의 탭
            Container(
              width: 200,
              child: Column(
                children: [
                  _buildTabButton('리뷰어', 0),
                  _buildTabButton('광고주', 1),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildProfileContent(),
                  _buildBusinessTab(),
                ],
              ),
            ),
          ],
        );
      }
      
      // 모바일/태블릿에서는 기본 탭 레이아웃
      return Column(
        children: [
          TabBar(...),
          Expanded(
            child: TabBarView(
              children: [
                _buildProfileContent(),
                _buildBusinessTab(),
              ],
            ),
          ),
        ],
      );
    },
  );
}
```

---

## 베스트 프랙티스

### 1. 브레이크포인트 일관성 유지

프로젝트 전체에서 동일한 브레이크포인트 사용:

```dart
// lib/config/responsive_breakpoints.dart
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1200;
  
  // 커스텀 브레이크포인트가 필요한 경우
  static const double smallMobile = 400;
  static const double largeTablet = 900;
}
```

### 2. 공통 패턴 추출

반복되는 패턴은 공통 위젯으로 추출:

```dart
// lib/widgets/responsive_card.dart
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: getValueForScreenType<EdgeInsets>(
        context: context,
        mobile: const EdgeInsets.all(8),
        tablet: const EdgeInsets.all(12),
        desktop: const EdgeInsets.all(16),
      ),
      child: Padding(
        padding: padding ?? getValueForScreenType<EdgeInsets>(
          context: context,
          mobile: const EdgeInsets.all(16),
          tablet: const EdgeInsets.all(20),
          desktop: const EdgeInsets.all(24),
        ),
        child: child,
      ),
    );
  }
}
```

### 3. 점진적 마이그레이션

한 번에 모든 화면을 변경하지 말고, 단계적으로 마이그레이션:

1. **새로운 화면**: 처음부터 ResponsiveBuilder 사용
2. **기존 화면**: 사용자가 자주 사용하는 화면부터 우선 적용
3. **레거시 화면**: 나중에 시간이 날 때 적용

### 4. 테스트 전략

각 화면 크기별로 테스트:

```dart
// 테스트 예시
testWidgets('캠페인 생성 화면 - 모바일 레이아웃', (tester) async {
  tester.view.physicalSize = const Size(390, 844); // iPhone 12
  tester.view.devicePixelRatio = 2.0;
  
  await tester.pumpWidget(MyApp());
  // 모바일 레이아웃 테스트
});

testWidgets('캠페인 생성 화면 - 태블릿 레이아웃', (tester) async {
  tester.view.physicalSize = const Size(768, 1024); // iPad
  tester.view.devicePixelRatio = 2.0;
  
  await tester.pumpWidget(MyApp());
  // 태블릿 레이아웃 테스트
});
```

### 5. 성능 최적화

불필요한 rebuild 방지:

```dart
// ❌ 나쁜 예: 매번 ResponsiveBuilder 생성
Widget build(BuildContext context) {
  return ResponsiveBuilder(
    builder: (context, sizingInformation) {
      return ResponsiveBuilder(  // 중첩된 ResponsiveBuilder
        builder: (context, sizingInformation) {
          // ...
        },
      );
    },
  );
}

// ✅ 좋은 예: 한 번만 사용
Widget build(BuildContext context) {
  return ResponsiveBuilder(
    builder: (context, sizingInformation) {
      return Column(
        children: [
          _buildHeader(sizingInformation),
          _buildContent(sizingInformation),
        ],
      );
    },
  );
}
```

---

## 주의사항 및 트러블슈팅

### 주의사항

1. **Context 사용**: ResponsiveBuilder 내부에서 `context`를 사용할 때 주의
   ```dart
   // ❌ 나쁜 예
   ResponsiveBuilder(
     builder: (context, sizingInformation) {
       return Text(MediaQuery.of(context).size.width.toString());
     },
   );
   
   // ✅ 좋은 예
   ResponsiveBuilder(
     builder: (context, sizingInformation) {
       return Text(sizingInformation.screenSize.width.toString());
     },
   );
   ```

2. **Orientation 변경**: 화면 회전 시 자동으로 rebuild되지만, 상태 관리 주의
   ```dart
   // Orientation 변경 감지
   ResponsiveBuilder(
     builder: (context, sizingInformation) {
       final isPortrait = sizingInformation.orientation == Orientation.portrait;
       // ...
     },
   );
   ```

3. **Dialog/Modal**: Dialog 내부에서도 ResponsiveBuilder 사용 가능
   ```dart
   showDialog(
     context: context,
     builder: (context) => ResponsiveBuilder(
       builder: (context, sizingInformation) {
         return AlertDialog(
           contentPadding: getValueForScreenType<EdgeInsets>(
             context: context,
             mobile: const EdgeInsets.all(16),
             tablet: const EdgeInsets.all(24),
             desktop: const EdgeInsets.all(32),
           ),
           // ...
         );
       },
     ),
   );
   ```

### 트러블슈팅

#### 문제 1: ResponsiveBuilder가 작동하지 않음

**원인**: Context가 올바르지 않거나, 위젯 트리 구조 문제

**해결**:
```dart
// ✅ 올바른 사용
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ResponsiveBuilder(  // Scaffold의 child로 직접 사용
      builder: (context, sizingInformation) {
        // ...
      },
    ),
  );
}
```

#### 문제 2: 화면 회전 시 레이아웃이 업데이트되지 않음

**원인**: StatefulWidget의 setState가 호출되지 않음

**해결**: ResponsiveBuilder는 자동으로 rebuild되므로 추가 작업 불필요

#### 문제 3: 성능 이슈

**원인**: 너무 많은 ResponsiveBuilder 중첩

**해결**: 
- 최상위 레벨에서 한 번만 사용
- 필요한 경우에만 사용

---

## 마이그레이션 체크리스트

각 스크린을 마이그레이션할 때 다음 체크리스트를 사용하세요:

### ✅ 준비 단계

- [ ] `responsive_builder` 패키지 설치 확인
- [ ] `lib/utils/responsive_helper.dart` 생성 확인
- [ ] `lib/widgets/responsive_screen.dart` 생성 확인 (선택사항)

### ✅ 마이그레이션 단계

- [ ] 스크린의 `build` 메서드에 `ResponsiveBuilder` 적용
- [ ] 패딩/마진을 반응형으로 변경
- [ ] 폰트 크기를 반응형으로 변경 (필요한 경우)
- [ ] 그리드/리스트의 열 개수를 반응형으로 변경 (필요한 경우)
- [ ] 최대 너비 제한 추가 (데스크톱용)

### ✅ 테스트 단계

- [ ] 모바일 크기 (390x844 - iPhone 12)에서 테스트
- [ ] 태블릿 크기 (768x1024 - iPad)에서 테스트
- [ ] 데스크톱 크기 (1920x1080)에서 테스트
- [ ] 화면 회전 테스트 (세로/가로)
- [ ] 오버플로우 에러 확인

### ✅ 코드 리뷰

- [ ] 하드코딩된 크기 값 제거 확인
- [ ] 공통 패턴이 공통 위젯으로 추출되었는지 확인
- [ ] 불필요한 ResponsiveBuilder 중첩 제거 확인

---

## 예상 소요 시간

### 전체 프로젝트 마이그레이션

- **Phase 0 (준비)**: 1일
- **Phase 1 (핵심 화면)**: 3-5일
- **Phase 2 (주요 화면)**: 5-7일
- **Phase 3 (나머지 화면)**: 3-5일

**총 예상 시간**: 12-18일 (약 2-3주)

### 화면당 예상 시간

- **간단한 화면** (로그인, 가이드 등): 30분 - 1시간
- **일반 화면** (목록, 상세 등): 1-2시간
- **복잡한 화면** (캠페인 생성, 프로필 등): 2-4시간

---

## 결론

ResponsiveBuilder 패키지를 모든 스크린에 적용하면:

1. **일관된 반응형 디자인**: 프로젝트 전체에서 표준화된 반응형 로직
2. **유지보수 용이성**: 브레이크포인트 중앙 관리
3. **확장성**: 새로운 화면 크기 추가 시 쉽게 대응
4. **개발 생산성**: 반복적인 반응형 로직을 패키지가 처리

**권장 사항**: 단계적으로 마이그레이션하여 리스크를 최소화하고, 각 단계마다 충분한 테스트를 수행하세요.

---

## 참고 자료

- [responsive_builder 패키지 문서](https://pub.dev/packages/responsive_builder)
- [Flutter 반응형 디자인 가이드](https://docs.flutter.dev/development/ui/layout/responsive)
- [Material Design 반응형 레이아웃](https://material.io/design/layout/responsive-layout-grid.html)

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025년 12월 10일

