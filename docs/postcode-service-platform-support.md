# 우편번호 찾기 서비스 플랫폼 지원 가이드

## 현재 구현 상태

### 웹에서만 작동하는 이유

현재 구현된 우편번호 찾기 기능은 **웹 플랫폼에서만 작동**합니다. 그 이유는 다음과 같습니다:

#### 1. **JavaScript API 의존성**
- 다음(Daum) 우편번호 API는 **웹 브라우저용 JavaScript 라이브러리**입니다
- `dart:html`과 `dart:js` 패키지는 **웹 전용**이며, 모바일 앱에서는 사용할 수 없습니다
- `HtmlElementView`는 Flutter 웹에서만 지원되는 위젯입니다

#### 2. **플랫폼별 제약사항**

| 플랫폼 | 현재 구현 | 제약사항 |
|--------|----------|---------|
| **웹** | ✅ 작동 | JavaScript API 사용 가능 |
| **Android** | ❌ 작동 안 함 | `dart:html`, `dart:js` 사용 불가 |
| **iOS** | ❌ 작동 안 함 | `dart:html`, `dart:js` 사용 불가 |

#### 3. **코드 구조**

```dart
// 현재 구현 (웹 전용)
import 'dart:html' as html;  // 웹 전용
import 'dart:js' as js;      // 웹 전용

if (!kIsWeb) {
  return; // 웹이 아니면 동작하지 않음
}
```

---

## 앱에서도 작동하는 솔루션

### 솔루션 1: 다음 우편번호 API 모바일 SDK (권장)

다음(Daum)은 Android와 iOS용 네이티브 SDK를 제공합니다.

#### 장점
- 웹과 동일한 UI/UX 제공
- 공식 지원으로 안정성 높음
- 무료 사용 가능

#### 단점
- 플랫폼별 네이티브 코드 작성 필요
- Flutter 플러그인으로 래핑 필요

#### 구현 방법

**1. Android SDK 연동**

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import net.daum.mf.map.api.MapView
import com.example.postcode.PostcodePlugin

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 다음 우편번호 SDK 초기화
    }
}
```

**2. iOS SDK 연동**

```swift
// ios/Runner/AppDelegate.swift
import DaumMap
import PostcodePlugin

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 다음 우편번호 SDK 초기화
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

**3. Flutter 플러그인 생성**

```dart
// lib/postcode_plugin.dart
import 'package:flutter/services.dart';

class PostcodePlugin {
  static const MethodChannel _channel = MethodChannel('postcode_plugin');

  static Future<Map<String, String>> searchPostcode() async {
    final result = await _channel.invokeMethod('searchPostcode');
    return Map<String, String>.from(result);
  }
}
```

---

### 솔루션 2: 우체국 공공 API 사용 (추천)

우체국에서 제공하는 공공 API를 사용하면 모든 플랫폼에서 작동합니다.

#### 장점
- ✅ **모든 플랫폼 지원** (웹, Android, iOS)
- ✅ **무료 사용 가능**
- ✅ **공식 API로 안정성 높음**
- ✅ **Flutter에서 직접 HTTP 호출 가능**

#### 단점
- UI를 직접 구현해야 함
- API 키 발급 필요 (일부 API)

#### API 정보

**1. 우체국 우편번호 API**
- **URL**: `https://www.epost.go.kr/search/zipcode/cmzcd001k01.jsp`
- **방식**: 웹 스크래핑 또는 공식 API
- **제한**: 공식 API는 사업자 등록 필요

**2. 행정안전부 도로명주소 API (Juso.go.kr)**
- **URL**: `https://www.juso.go.kr/addrlink/addrLinkApi.do`
- **방식**: REST API
- **제한**: API 키 발급 필요 (무료)
- **문서**: https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do

#### 구현 예시

```dart
// lib/services/juso_api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class JusoApiService {
  static const String _apiKey = 'YOUR_API_KEY';
  static const String _baseUrl = 'https://www.juso.go.kr/addrlink/addrLinkApi.do';

  /// 주소 검색
  static Future<List<Map<String, String>>> searchAddress(String keyword) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      body: {
        'confmKey': _apiKey,
        'keyword': keyword,
        'resultType': 'json',
        'countPerPage': '20',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results']['juso'] as List;
      return results.map((juso) => {
        'postalCode': juso['zipNo'],
        'roadAddress': juso['roadAddr'],
        'jibunAddress': juso['jibunAddr'],
        'sido': juso['siNm'],
        'sigungu': juso['sggNm'],
        'dong': juso['emdNm'],
      }).toList();
    }
    return [];
  }
}
```

---

### 솔루션 3: 통합 플랫폼별 구현 (최종 권장)

웹과 앱 모두에서 작동하는 통합 솔루션입니다.

#### 구조

```
lib/
  services/
    postcode_service.dart          # 통합 인터페이스
    postcode_service_web.dart      # 웹 구현
    postcode_service_mobile.dart   # 모바일 구현 (Juso API 사용)
  widgets/
    postcode_search_dialog.dart    # 플랫폼 독립적 UI
```

#### 구현 코드

**1. 통합 서비스 인터페이스**

```dart
// lib/services/postcode_service.dart
abstract class PostcodeService {
  Future<PostcodeResult?> searchPostcode(BuildContext context);
  
  factory PostcodeService() {
    if (kIsWeb) {
      return PostcodeServiceWeb();
    } else {
      return PostcodeServiceMobile();
    }
  }
}

class PostcodeResult {
  final String postalCode;
  final String address;
  final String? extraAddress;
  
  PostcodeResult({
    required this.postalCode,
    required this.address,
    this.extraAddress,
  });
}
```

**2. 웹 구현 (기존 코드 활용)**

```dart
// lib/services/postcode_service_web.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/postcode_dialog.dart';

class PostcodeServiceWeb implements PostcodeService {
  @override
  Future<PostcodeResult?> searchPostcode(BuildContext context) async {
    PostcodeResult? result;
    await PostcodeDialog.show(
      context,
      onComplete: (postalCode, address, extraAddress) {
        result = PostcodeResult(
          postalCode: postalCode,
          address: address,
          extraAddress: extraAddress,
        );
      },
    );
    return result;
  }
}
```

**3. 모바일 구현 (Juso API 사용)**

```dart
// lib/services/postcode_service_mobile.dart
import 'package:flutter/material.dart';
import 'juso_api_service.dart';
import '../widgets/postcode_search_dialog.dart';

class PostcodeServiceMobile implements PostcodeService {
  @override
  Future<PostcodeResult?> searchPostcode(BuildContext context) async {
    return await showDialog<PostcodeResult>(
      context: context,
      builder: (context) => PostcodeSearchDialog(
        onSearch: (keyword) => JusoApiService.searchAddress(keyword),
        onSelect: (result) {
          return PostcodeResult(
            postalCode: result['postalCode']!,
            address: result['roadAddress']!,
            extraAddress: result['jibunAddress'],
          );
        },
      ),
    );
  }
}
```

**4. 플랫폼 독립적 UI**

```dart
// lib/widgets/postcode_search_dialog.dart
class PostcodeSearchDialog extends StatefulWidget {
  final Future<List<Map<String, String>>> Function(String) onSearch;
  final PostcodeResult Function(Map<String, String>) onSelect;

  const PostcodeSearchDialog({
    required this.onSearch,
    required this.onSelect,
  });

  @override
  State<PostcodeSearchDialog> createState() => _PostcodeSearchDialogState();
}

class _PostcodeSearchDialogState extends State<PostcodeSearchDialog> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    final results = await widget.onSearch(_searchController.text);
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 검색 입력
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '도로명 또는 지번 주소 검색',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _search,
                    child: const Text('검색'),
                  ),
                ],
              ),
            ),
            // 검색 결과
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return ListTile(
                              title: Text(result['roadAddress'] ?? ''),
                              subtitle: Text(
                                '${result['postalCode']} | ${result['jibunAddress']}',
                              ),
                              onTap: () {
                                Navigator.of(context).pop(
                                  widget.onSelect(result),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**5. 사용 예시**

```dart
// lib/screens/mypage/common/point_charge_screen.dart
ElevatedButton(
  onPressed: () async {
    final result = await PostcodeService().searchPostcode(context);
    if (result != null) {
      setState(() {
        _taxInvoicePostalCodeController.text = result.postalCode;
        _taxInvoiceAddressController.text = result.address + (result.extraAddress ?? '');
      });
    }
  },
  child: const Text('우편번호 찾기'),
),
```

---

## 솔루션 비교

| 솔루션 | 웹 | Android | iOS | 구현 난이도 | 비용 | 추천도 |
|--------|:---:|:-------:|:---:|:----------:|:----:|:------:|
| **현재 구현 (다음 API 웹)** | ✅ | ❌ | ❌ | 낮음 | 무료 | ⭐ |
| **다음 모바일 SDK** | ❌ | ✅ | ✅ | 높음 | 무료 | ⭐⭐ |
| **우체국/행정안전부 API** | ✅ | ✅ | ✅ | 중간 | 무료 | ⭐⭐⭐ |
| **통합 솔루션** | ✅ | ✅ | ✅ | 높음 | 무료 | ⭐⭐⭐⭐ |

---

## 권장 구현 방안

### 단계별 구현 계획

#### Phase 1: 모바일 API 연동 (즉시 구현 가능)
1. 행정안전부 Juso API 키 발급
2. `JusoApiService` 구현
3. `PostcodeSearchDialog` 위젯 구현
4. `PostcodeServiceMobile` 구현

#### Phase 2: 통합 서비스 (선택)
1. `PostcodeService` 추상 클래스 생성
2. 플랫폼별 구현 통합
3. 기존 코드 리팩토링

#### Phase 3: 다음 모바일 SDK (향후)
1. Android/iOS 네이티브 SDK 연동
2. Flutter 플러그인 개발
3. 웹과 동일한 UI 제공

---

## API 키 발급 방법

### 행정안전부 Juso API

1. **회원가입**: https://www.juso.go.kr/addrlink/addrLinkRequestWrite.do
2. **API 키 신청**: 개발자 센터에서 신청
3. **승인 대기**: 1-2일 소요
4. **사용 시작**: 승인 후 API 키로 호출

### 우체국 API

1. **사업자 등록**: 우체국 공공 API는 사업자 등록 필요
2. **신청**: 우체국 고객센터 문의
3. **승인**: 사업자 확인 후 승인

---

## 참고 자료

- [행정안전부 도로명주소 API 가이드](https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do)
- [다음 우편번호 API 문서](https://postcode.map.daum.net/guide)
- [Flutter 플랫폼 채널 가이드](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Flutter 웹 플랫폼 뷰](https://docs.flutter.dev/development/platform-integration/web/platform-views)

---

## 결론

현재 구현은 **웹 전용**이지만, **행정안전부 Juso API**를 사용하면 **모든 플랫폼에서 작동**하는 솔루션을 구현할 수 있습니다. 

**즉시 구현 가능한 방법**: Juso API를 사용한 모바일 구현 (Phase 1)
**장기적 솔루션**: 통합 서비스 패턴으로 웹과 모바일 모두 지원 (Phase 2)

