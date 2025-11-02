# SNS 연결 기능 이그레스(Egress) 처리 분석

## 📊 현재 구조 분석

### 현재 아키텍처

#### 1. 데이터 저장 (Ingress)
```
┌─────────────┐
│ Flutter 앱  │
└──────┬──────┘
       │ Supabase RPC 호출 (요청 데이터 전송)
       ▼
┌─────────────────────┐
│ PostgreSQL Function  │
│ (create_sns_connection)│
└──────┬──────────────┘
       │ 내부 처리
       ▼
┌─────────────────────┐
│ PostgreSQL Database │
│ (sns_connections)   │
└─────────────────────┘
```

#### 2. 데이터 조회 (Egress) ⚠️
```
┌─────────────┐
│ Flutter 앱  │
└──────┬──────┘
       │ SELECT 쿼리 요청
       ▼
┌─────────────────────┐
│ Supabase API        │
│ (PostgreSQL 쿼리)    │
└──────┬──────────────┘
       │ 데이터 조회 (이그레스 발생!)
       ▼
┌─────────────────────┐
│ PostgreSQL Database │
│ (sns_connections)   │
└──────┬──────────────┘
       │ 응답 데이터 전송 (이그레스)
       ▼
┌─────────────┐
│ Flutter 앱  │
│ (마이페이지 표시)   │
└─────────────┘
```

### 현재 이그레스 상태
- ⚠️ **이그레스 발생**: 마이페이지 조회 시 데이터 전송
- ✅ **Supabase Database 이그레스**: 무료 플랜 포함 (제한 있음)
- ✅ **외부 API 호출 없음**: 실제 SNS API 검증 없음
- ⚠️ **단점**: 실제 SNS 계정 검증 불가

---

## 🔍 이그레스 발생 시나리오 분석

### 시나리오 1: 현재 구조 유지 (권장 초기 단계)
**이그레스: 발생 (Database 이그레스) - 캐싱 적용 ✅**

#### 이그레스 발생 지점
1. **마이페이지 조회 시**
   ```dart
   // lib/services/sns_platform_connection_service.dart:147
   final connections = await SNSPlatformConnectionService.getConnections();
   // 캐시에서 먼저 확인, 없으면 서버에서 조회
   ```
   - **첫 조회**: Supabase → Flutter 앱으로 데이터 전송 (이그레스 발생)
   - **캐시 사용**: 이후 24시간 내에는 캐시에서 가져옴 (이그레스 0)
   - 예상 데이터 크기: 연결당 약 200-500 bytes
   - 사용자당 평균 5개 연결: 약 1-2.5KB

2. **이그레스 비용 계산 (캐싱 적용 후)**
   - 일일 사용자 1,000명 × 첫 조회 1회 = 1,000회
   - 1,000회 × 2KB 평균 = 약 2MB/일
   - 월간 약 60MB (캐싱 전 180MB 대비 **67% 감소**)
   - **Supabase 무료 플랜**: 5GB/월 (충분히 여유있음)

**장점:**
- ✅ Supabase 무료 플랜으로 충분
- ✅ 로컬 캐싱으로 이그레스 67% 감소
- ✅ 빠른 응답 속도 (캐시 사용 시)
- ✅ 오프라인에서도 캐시 데이터 사용 가능
- ✅ 자동 캐시 무효화 (생성/수정/삭제 시)
- ✅ 빠른 구현
- ✅ 단순한 구조
- ✅ 기존 Supabase 사용 패턴

**단점:**
- ⚠️ 데이터 조회 시 이그레스 발생 (하지만 무료 범위 내, 캐싱으로 최소화)
- ⚠️ 잘못된 계정 정보 저장 가능
- ⚠️ 실제 연동 불가

---

### 시나리오 2: Edge Functions로 API 검증 추가 (향후 확장)
**이그레스: 추가 발생 (Edge Functions 이그레스)**

#### 추가 이그레스 발생
1. **Database 이그레스** (캐싱 적용)
   - 마이페이지 조회 시: 약 60MB/월 (캐싱으로 최소화)

2. **Edge Functions 이그레스** (새로 추가)
   ```
   ┌─────────────┐
   │ Flutter 앱  │
   └──────┬──────┘
          │ Edge Function 호출
          ▼
   ┌─────────────────────┐
   │ Supabase Edge        │
   │ Function             │
   │ (verify-sns-account)  │
   └──────┬───────────────┘
          │ 외부 API 호출 (이그레스 발생)
          ▼
   ┌─────────────────────┐
   │ Instagram API        │
   │ YouTube API          │
   │ TikTok API           │
   │ 기타 SNS API         │
   └─────────────────────┘
   ```
   - 각 검증 API 호출당 약 1-5KB
   - 월 10,000명 × 5개 연결 검증 = 약 150MB
   - **Supabase Edge Functions 무료 플랜**: 50GB/월 (충분히 여유있음)

**총 이그레스:**
- Database: 약 60MB/월 (캐싱 적용)
- Edge Functions: 약 150MB/월
- **합계: 약 210MB/월**
- **무료 플랜 내에서 충분히 처리 가능**

---

## 💡 권장 사항

### 단계별 접근

#### 1단계: 현재 구조 유지 (즉시 사용 가능)
- ✅ 이그레스 없음 (비용 절감)
- ✅ 빠른 배포 가능
- ✅ 사용자가 직접 입력한 정보 저장

```dart
// 현재 구조 그대로 사용
await SNSPlatformConnectionService.createConnection(
  platform: 'instagram',
  platformAccountId: userInput,
  platformAccountName: userInput,
  phone: phone,
);
```

#### 2단계: 선택적 검증 추가 (필요 시)
- 실제 SNS API 연동이 필요한 경우에만 Edge Function 추가
- 사용자가 "인증" 버튼을 클릭할 때만 검증 수행

```typescript
// supabase/functions/verify-sns-account/index.ts
Deno.serve(async (req) => {
  const { platform, accountId } = await req.json();
  
  // Instagram API 검증
  if (platform === 'instagram') {
    const response = await fetch(
      `https://graph.instagram.com/${accountId}?access_token=${ACCESS_TOKEN}`
    );
    // 검증 로직
  }
  
  return new Response(JSON.stringify({ verified: true }));
});
```

#### 3단계: 백그라운드 검증 (선택 사항)
- 저장 후 백그라운드에서 검증
- 검증 실패 시 알림만 표시

---

## 📈 비용 최적화 전략

### 1. 캐싱 활용
- 검증된 계정 정보는 캐시하여 재검증 방지
- Redis 또는 Supabase Realtime 사용

### 2. 배치 처리
- 여러 계정을 한 번에 검증
- 일일 배치로 검증 상태 업데이트

### 3. 사용자 액션 기반 검증
- 저장 시점에 검증하지 않고
- "인증하기" 버튼 클릭 시에만 검증
- 대부분의 사용자는 검증하지 않을 수 있음

---

## 🎯 결론 및 권장사항

### 현재 구조 평가: ✅ **괜찮음**

**이유:**
1. ✅ **Database 이그레스**: Supabase 무료 플랜(5GB/월)으로 충분
   - 예상 사용량: 약 60MB/월 (캐싱 적용)
   - 여유 공간: 약 4.94GB
2. ✅ **로컬 캐싱 적용**: 이그레스 약 67% 감소
   - 캐시 만료: 24시간
   - 자동 캐시 무효화: 생성/수정/삭제 시
3. ✅ **비용 효율적**: 무료 플랜 내에서 처리 가능
4. ✅ **확장 가능**: 필요 시 Edge Functions 추가 가능
5. ✅ **표준 패턴**: Supabase의 일반적인 사용 방식

### 이그레스 상세 분석

#### 현재 구조의 이그레스 (캐싱 적용 후)
```
마이페이지 조회 시:
- 첫 조회: 서버에서 가져옴 (2KB)
- 이후 24시간 내: 캐시에서 가져옴 (이그레스 0)
- 사용자당 평균: 2KB
- 일일 1,000명 × 1회 조회 = 2MB/일
- 월간: 약 60MB (캐싱 전 180MB 대비 67% 감소)

Supabase 무료 플랜:
- Database 이그레스: 5GB/월
- 사용률: 약 1.2% (충분히 여유있음)
```

#### 향후 확장 시
```
Database 이그레스: 60MB/월 (캐싱 적용)
Edge Functions 이그레스: 150MB/월 (검증 시)
총합: 210MB/월

Supabase 무료 플랜:
- Database: 5GB/월
- Edge Functions: 50GB/월
- 사용률: 매우 낮음 (충분히 여유있음)
```

### 향후 개선 사항
1. **선택적 검증**: 사용자가 원할 때만 검증
2. **Edge Function 활용**: 검증이 필요할 때만 호출
3. **비용 모니터링**: 이그레스 사용량 추적 (Supabase Dashboard에서 확인 가능)
4. **캐싱 전략**: 자주 조회되는 데이터는 로컬 캐싱

### 최종 권장사항
- **현재 구조 유지** ✅
  - Database 이그레스는 무료 플랜으로 충분
  - 추가 비용 없음
- 나중에 실제 API 연동이 필요할 때만 Edge Function 추가
- 검증은 선택적으로 제공 (사용자 액션 기반)

---

## 📝 참고사항

### Supabase 이그레스 제한

#### Database 이그레스 (PostgreSQL)
- **무료 플랜**: 5GB/월
- **Pro 플랜**: 100GB/월
- **현재 사용량**: 약 60MB/월 (캐싱 적용, 무료 플랜의 1.2%)
- **주의**: Database 이그레스는 모든 SELECT 쿼리에서 발생 (캐싱으로 최소화)

#### Edge Functions 이그레스
- **무료 플랜**: 50GB/월
- **Pro 플랜**: 200GB/월
- **현재 사용량**: 0 (검증 기능 없음)
- **향후 예상**: 약 150MB/월 (무료 플랜의 0.3%)

### 이그레스 최적화 팁

1. **✅ 로컬 캐싱 적용 (구현 완료)**
   ```dart
   // 자주 변경되지 않는 데이터는 로컬에 캐싱
   final connections = await SNSPlatformConnectionService.getConnections();
   // 캐시에서 먼저 확인, 없으면 서버에서 조회
   ```
   - **캐시 만료 시간**: 24시간
   - **캐시 무효화**: 생성/수정/삭제 시 자동
   - **예상 이그레스 감소**: 약 90% 감소 (하루 한 번만 조회)

2. **필요한 컬럼만 조회**
   ```dart
   // ❌ 나쁜 예: 모든 컬럼 조회
   .select()
   
   // ✅ 좋은 예: 필요한 컬럼만 조회
   .select('id, platform, platform_account_name')
   ```

3. **페이지네이션 활용**
   ```dart
   // 많은 데이터가 있을 경우
   .limit(20)
   .offset(page * 20)
   ```

### 실제 SNS API 연동 시 고려사항
1. **OAuth 인증 필요**: 각 플랫폼별 OAuth 설정
2. **API Rate Limit**: 플랫폼별 호출 제한 확인
3. **토큰 관리**: Refresh Token 관리 필요
4. **보안**: API 키는 환경 변수로 관리
5. **이그레스 비용**: Edge Functions 이그레스 추가 발생 가능

