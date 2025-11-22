# Juso API 설정 가이드

## API 키 발급 방법

### 1. 회원가입 및 로그인

1. **행정안전부 도로명주소 안내 시스템** 접속
   - URL: https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do

2. **회원가입**
   - 우측 상단 "회원가입" 클릭
   - 필수 정보 입력 후 가입 완료

3. **로그인**
   - 발급받은 아이디/비밀번호로 로그인

### 2. API 키 신청

1. **API 신청 페이지 접속**
   - URL: https://business.juso.go.kr/addrlink/openApi/apiReqst.do
   - 또는 홈페이지에서 "API신청 > API 신청하기" 메뉴 클릭

2. **신청서 작성**
   - **API 종류**: 공개 도로명주소 API (기본 선택)
   - **API 유형**: **검색 API** 선택 ⚠️ (중요: 우리 프로젝트는 검색 API 사용)
   - **신청기관 유형**: 민간기관
   - **업체(기관)명**: 스마트 리뷰 (또는 실제 회사명)
   - **시스템명**: Smart Review App
   - **URL(IP)**: 
     - 개발 단계: `localhost` 또는 `127.0.0.1`
     - 운영 단계: 실제 도메인 (예: `yourdomain.com`)
   - **시스템 개요**: 리뷰 캠페인 플랫폼으로, 사용자가 주소를 입력할 때 우편번호 찾기 기능을 제공합니다.
   - **서비스망**: 인터넷 망 (기본 선택)
   - **서비스 용도**: 
     - 개발 단계: 개발(본인인증없이 발급) - 30일 선택
     - 운영 단계: 운영 (본인인증 필요)

3. **신청 제출**
   - "신청하기" 버튼 클릭
   - 신청 완료 확인

4. **승인 대기**
   - 개발용: 즉시 또는 몇 시간 내 발급
   - 운영용: 보통 1-2일 내 승인 완료
   - 승인 완료 시 이메일로 알림

**📋 상세한 신청서 작성 가이드는 `docs/juso-api-application-form-guide.md` 참고**

### 3. API 키 확인

1. **개발자 센터 > API 관리**
2. **승인된 API 목록**에서 확인
3. **API 키(confmKey)** 복사

### 4. 프로젝트에 적용

1. **`lib/services/juso_api_service.dart` 파일 열기**

2. **API 키 교체**
   ```dart
   static const String _apiKey = 'YOUR_JUSO_API_KEY';
   ```
   위 부분을 실제 발급받은 API 키로 교체:
   ```dart
   static const String _apiKey = '발급받은_API_키_입력';
   ```

3. **저장 후 테스트**
   - 앱 실행
   - 우편번호 찾기 버튼 클릭
   - 주소 검색 테스트

## API 사용 제한

- **일일 호출 제한**: 신청 시 설정한 제한에 따라 다름 (기본 10,000건/일)
- **무료 사용**: 개인/기업 모두 무료 사용 가능
- **사용 목적**: 주소 검색 및 우편번호 조회만 가능 (상업적 이용 가능)

## 문제 해결

### API 키가 작동하지 않는 경우

1. **API 키 확인**
   - 개발자 센터에서 API 키가 정확한지 확인
   - 복사 시 공백이나 특수문자 포함 여부 확인

2. **승인 상태 확인**
   - API 신청이 승인되었는지 확인
   - 승인 대기 중이면 승인 완료까지 대기

3. **에러 메시지 확인**
   - 앱 실행 시 콘솔에 표시되는 에러 메시지 확인
   - API 응답 코드 확인

### 자주 발생하는 에러

- **"인증키가 유효하지 않습니다"**: API 키가 잘못되었거나 승인되지 않음
- **"일일 호출 제한 초과"**: 일일 사용량 초과
- **"네트워크 오류"**: 인터넷 연결 확인

## 참고 자료

- [Juso API 개발 가이드](https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do)
- [API 사용 예제](https://www.juso.go.kr/addrlink/devAddrLinkRequestExample.do)
- [FAQ](https://www.juso.go.kr/addrlink/devAddrLinkRequestFaq.do)

