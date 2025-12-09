# 남아있는 린터 경고 요약

**작성일**: 2025년 12월 09일  
**총 경고 개수**: 약 100개 이상

---

## 📊 경고 유형별 현황

### 1. unused_element (2개) ⚠️
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:756` - `_addCampaignById`
- `lib/services/campaign_log_service.dart:196` - `_handleStatusSpecificLogic` (이미 ignore 주석 있음)

### 2. unnecessary_import (약 20개) ⚠️
**문제**: `package:flutter/foundation.dart`가 `package:flutter/material.dart`에 포함되어 불필요
- `advertiser_my_campaigns_screen.dart:2`
- `campaign_detail_screen.dart:3`
- `home_screen.dart:2`
- `campaigns_screen.dart:2`
- `admin_dashboard_screen.dart:1`
- `advertiser_manager_screen.dart:1`
- `advertiser_mypage_screen.dart:1`
- `advertiser_reviewer_screen.dart:1`
- `account_registration_form.dart:1`
- `point_charge_screen.dart:1`
- `points_screen.dart:1`
- `profile_screen.dart:2`
- `my_campaigns_screen.dart:1`
- `reviewer_company_request_screen.dart:3`
- `reviewer_mypage_screen.dart:1`
- `sns_platform_connection_service.dart:2`
- 기타 `dart:typed_data` 불필요한 import들

### 3. prefer_final_fields (약 8개) ⚠️
- `advertiser_my_campaigns_screen.dart:56` - `_pendingRealtimeEvents`
- `signup_screen.dart:21` - `_isLoading`
- `campaign_creation_screen.dart:109` - `_campaignType`
- `campaign_creation_screen.dart:114` - `_onlyAllowedReviewers`
- `campaign_edit_screen.dart:88` - `_paymentType`
- `campaign_edit_screen.dart:91` - `_onlyAllowedReviewers`
- `campaign_edit_screen.dart:104` - `_totalCost`
- `campaigns_screen.dart:36` - `_pendingRealtimeEvents`
- `home_screen.dart:33` - `_pendingRealtimeEvents`

### 4. deprecated_member_use_from_same_package (약 8개) ⚠️
**문제**: `_loadCampaigns` 메서드가 deprecated인데 사용 중
- `advertiser_my_campaigns_screen.dart` - 여러 곳에서 사용

### 5. deprecated_member_use (약 20개) ⚠️
**5-1. `value` → `initialValue` (TextFormField)**
- `campaign_creation_screen.dart:2019, 2031, 2167, 2209, 2271, 2895`
- `campaign_edit_screen.dart:819, 831, 968, 1010, 1072`
- `admin_campaigns_screen.dart:142`
- `admin_users_screen.dart:257, 275`
- `point_charge_screen.dart:597`

**5-2. `groupValue` / `onChanged` → `RadioGroup` (Radio)**
- `point_charge_screen.dart:493, 494, 645, 646, 665, 666`

### 6. use_build_context_synchronously (약 30개) ⚠️
**문제**: BuildContext를 async gap에서 사용
- `reviewer_signup_screen.dart:414`
- `signup_screen.dart:70`
- `campaign_creation_screen.dart` - 여러 곳
- `campaign_edit_screen.dart` - 여러 곳
- `campaign_detail_screen.dart` - 여러 곳
- `advertiser_campaign_detail_screen.dart` - 여러 곳
- `profile_screen.dart` - 여러 곳

### 7. sort_child_properties_last (약 8개) ⚠️
- `campaign_creation_screen.dart:2039, 2044, 2930, 2948`
- `campaign_edit_screen.dart:839, 844`
- `account_registration_form.dart:322`
- `profile_screen.dart:333`

### 8. unnecessary_brace_in_string_interps (약 3개) ⚠️
- `home_screen.dart:81`
- `campaign_card.dart:391, 392`

### 9. curly_braces_in_flow_control_structures (1개) ⚠️
- `advertiser_mypage_screen.dart:197`

### 10. depend_on_referenced_packages (2개) ⚠️
- `auth_service.dart:6` - `postgrest` 패키지
- `campaign_image_service.dart:5` - `http_parser` 패키지

### 11. unnecessary_to_list_in_spreads (1개) ⚠️
- `mypage_common_widgets.dart:901`

### 12. TODO 주석 (약 20개) ℹ️
- 정보성 주석이므로 경고가 아닌 참고용

---

## 🎯 우선순위별 수정 권장사항

### 높은 우선순위 (즉시 수정 권장)
1. **unused_element** (2개) - 간단히 수정 가능
2. **unnecessary_import** (약 20개) - 간단히 제거 가능
3. **deprecated_member_use** (약 20개) - 향후 Flutter 버전 호환성

### 중간 우선순위 (점진적 수정)
4. **use_build_context_synchronously** (약 30개) - 버그 가능성 있음
5. **prefer_final_fields** (약 8개) - 코드 품질 향상
6. **deprecated_member_use_from_same_package** (약 8개) - 내부 deprecated 사용

### 낮은 우선순위 (선택적 수정)
7. **sort_child_properties_last** (약 8개) - 스타일 가이드
8. **unnecessary_brace_in_string_interps** (약 3개) - 스타일 가이드
9. **curly_braces_in_flow_control_structures** (1개) - 스타일 가이드
10. **depend_on_referenced_packages** (2개) - 패키지 의존성 확인 필요
11. **unnecessary_to_list_in_spreads** (1개) - 스타일 가이드

---

## 📝 수정 가이드

### 1. unused_element 수정
```dart
// ignore: unused_element
@Deprecated('...')
Future<bool> _addCampaignById(String campaignId) async {
  // ...
}
```

### 2. unnecessary_import 제거
```dart
// ❌ 제거
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ✅ 유지
import 'package:flutter/material.dart'; // foundation 포함됨
```

### 3. deprecated_member_use 수정
```dart
// ❌
TextFormField(value: initialValue)

// ✅
TextFormField(initialValue: initialValue)
```

### 4. use_build_context_synchronously 수정
```dart
// ❌
await someAsyncFunction();
context.go('/path');

// ✅
await someAsyncFunction();
if (!mounted) return;
context.go('/path');
```

### 5. prefer_final_fields 수정
```dart
// ❌
String _campaignType = 'normal';

// ✅
final String _campaignType = 'normal';
```

---

## ✅ 체크리스트

- [ ] unused_element (2개)
- [ ] unnecessary_import (약 20개)
- [ ] deprecated_member_use (약 20개)
- [ ] use_build_context_synchronously (약 30개)
- [ ] prefer_final_fields (약 8개)
- [ ] deprecated_member_use_from_same_package (약 8개)
- [ ] sort_child_properties_last (약 8개)
- [ ] unnecessary_brace_in_string_interps (약 3개)
- [ ] curly_braces_in_flow_control_structures (1개)
- [ ] depend_on_referenced_packages (2개)
- [ ] unnecessary_to_list_in_spreads (1개)

