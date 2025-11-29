# 캠페인 Realtime 동기화 로드맵 - 리뷰 피드백 반영 요약

## 📋 개요
재미나이님의 리뷰 피드백을 반영하여 로드맵과 설계 근거 문서를 보강했습니다.

---

## ✅ 반영된 주요 제안사항

### 1. 🔴 동시성 문제 및 DB 레벨 방어 (매우 중요)

**제안 내용**:
- Realtime은 미세한 지연이 있으므로, UI에서 버튼을 막는 것만으로는 부족
- DB 레벨이나 Edge Function에서 트랜잭션으로 막는 로직이 반드시 필요
- Realtime만 믿으면 안 됨

**반영 내용**:
- ✅ 로드맵에 "동시성 문제 및 DB 레벨 방어" 섹션 추가
- ✅ `join_campaign_safe` RPC 함수에서 이미 체크하고 있음을 확인
- ✅ UI에서 버튼을 막는 것은 사용자 편의용이며, 실제 보호는 DB 레벨에서 수행됨을 명시
- ✅ 트랜잭션 레벨에서 행 잠금(`FOR UPDATE`) 사용 여부 확인 권장
- ✅ 동시 신청 시나리오 테스트 필수 항목 추가

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - 섹션 0

---

### 2. 🔴 데이터 충돌 및 깜빡임 (State Management)

**제안 내용**:
- Pull-to-Refresh 중 Realtime 이벤트가 들어오면 충돌 가능
- `isLoading = true`일 때는 Realtime 이벤트를 무시하거나 큐에 쌓았다가 로딩이 끝나면 반영

**반영 내용**:
- ✅ 로드맵에 "데이터 충돌 및 깜빡임" 섹션 추가
- ✅ 이벤트 큐에 저장하는 방법과 무시하는 방법 모두 코드 예시 포함
- ✅ Step 2, Step 4에 Pull-to-Refresh 충돌 방지 항목 추가
- ✅ 체크리스트에 항목 추가

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - 섹션 6

---

### 3. 🔴 플랫폼별 임포트 처리 (웹/앱 호환성)

**제안 내용**:
- `dart:html`은 웹에서만 작동, 앱 빌드 시 컴파일 에러
- `kIsWeb` 체크만으로는 부족
- Conditional Import 또는 `universal_html` 패키지 사용 필요

**반영 내용**:
- ✅ 로드맵에 "플랫폼별 임포트 처리" 섹션 추가
- ✅ `universal_html` 패키지 사용 방법 코드 예시 포함
- ✅ Step 1에 `universal_html` 패키지 추가 항목 추가
- ✅ 체크리스트에 항목 추가

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - 섹션 7

---

### 4. 🟡 Supabase Replica Identity 확인

**제안 내용**:
- Supabase Realtime은 기본적으로 변경된 row의 전체 데이터를 보낼 수도 있음
- Replica Identity 설정 확인 필요 (Full vs Default)
- 클라이언트 코드에서 filter를 걸더라도 서버에서 클라이언트로 데이터를 쏠 때 페이로드가 크면 이그레스 비용 발생

**반영 내용**:
- ✅ 로드맵에 Replica Identity 확인 내용 추가
- ✅ Full vs Default 설명 추가
- ✅ Step 5에 Supabase Replica Identity 확인 항목 추가
- ✅ 체크리스트에 항목 추가

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - 섹션 1.2 (방안 4), Step 5

---

### 5. 🟡 StreamBuilder 활용 고려

**제안 내용**:
- `setState`를 직접 호출하여 리스트를 갱신하는 것도 좋지만, 화면의 일부분만 StreamBuilder로 감싸서 처리하면 전체 화면 리빌드를 막아 성능을 더 최적화할 수 있음

**반영 내용**:
- ✅ Step 2, Step 4에 StreamBuilder 활용 고려 항목 추가
- ✅ Step 5에 StreamBuilder 활용 항목 추가
- ✅ 성능 최적화 팁에 StreamBuilder 활용 내용 추가

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - Step 2, Step 4, Step 5, 참고사항 10

---

### 6. 🟡 Debounce 시간 설정 조정

**제안 내용**:
- 참여자 수 카운트는 Throttle이 낫고, 리스트 목록 갱신은 Debounce가 낫다
- 참여자 수는 1초보다 조금 더 짧아도(예: 500ms) 괜찮을 것 같다 (UI 반응성을 위해서)

**반영 내용**:
- ✅ 디바운싱/스로틀링 구현 섹션에 Throttle과 Debounce 구분하여 설명
- ✅ 참여자 수: Throttle (500ms) 적용
- ✅ 리스트 갱신: Debounce (1초) 적용
- ✅ 코드 예시에 두 가지 방법 모두 포함

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - 섹션 3.1

---

### 7. 🟡 연결 해제 안전장치 (Timer)

**제안 내용**:
- `dispose`에서 `unsubscribe`를 호출하더라도, 가끔 예기치 않은 에러로 dispose가 끝까지 실행되지 않을 수 있음
- `CampaignRealtimeService` 내부에 `Set<String> _activeSubscriptions`를 두고, 앱이 완전히 종료되거나 로그아웃할 때 한 번 더 전체적으로 `unsubscribeAll()`을 호출하는 안전장치를 두면 좋음

**반영 내용**:
- ✅ 로드맵에 "연결 해제 안전장치 (Global Cleanup)" 섹션 추가
- ✅ `unsubscribeAll()` 메서드 구현 코드 예시 포함
- ✅ 앱 종료/로그아웃 시 호출 방법 설명
- ✅ Step 1, Step 6에 Global Cleanup 항목 추가
- ✅ 체크리스트에 항목 추가

**위치**: `docs/campaign-realtime-sync-optimization-roadmap.md` - 섹션 1.2, Step 1, Step 6

---

## 📊 변경 사항 요약

### 추가된 섹션
1. **섹션 0**: 동시성 문제 및 DB 레벨 방어 (매우 중요)
2. **섹션 6**: 데이터 충돌 및 깜빡임 (State Management)
3. **섹션 7**: 플랫폼별 임포트 처리 (웹/앱 호환성)
4. **섹션 1.2**: 연결 해제 안전장치 (Global Cleanup)

### 수정된 섹션
1. **섹션 1.2 (방안 4)**: Supabase Replica Identity 확인 내용 추가
2. **섹션 3.1**: 디바운싱/스로틀링 구현 - Throttle과 Debounce 구분
3. **Step 1**: 플랫폼별 임포트 처리, Global Cleanup 추가
4. **Step 2**: Pull-to-Refresh 충돌 방지, StreamBuilder 활용 추가
5. **Step 4**: Pull-to-Refresh 충돌 방지, StreamBuilder 활용, DB 레벨 방어 확인 추가
6. **Step 5**: Supabase Replica Identity 확인, StreamBuilder 활용 추가
7. **Step 6**: Global Cleanup, 동시성 테스트 추가
8. **체크리스트**: 모든 새로운 항목 추가
9. **참고사항**: 동시성 문제, 데이터 충돌, 플랫폼별 임포트, 성능 최적화 팁 추가

### 설계 근거 문서 업데이트
- `docs/campaign-realtime-service-design-rationale.md`에 추가 검토 사항 섹션 추가

---

## 🎯 다음 단계

1. ✅ **로드맵 검토 완료**: 모든 제안사항 반영
2. ⏳ **구현 시작**: Step 1부터 순차적으로 진행
3. ⏳ **패키지 추가**: `universal_html` 패키지 추가 필요
4. ⏳ **DB 확인**: Supabase Replica Identity 설정 확인
5. ⏳ **테스트**: 동시성 테스트 시나리오 작성

---

## 📝 참고 문서

- **로드맵**: `docs/campaign-realtime-sync-optimization-roadmap.md`
- **설계 근거**: `docs/campaign-realtime-service-design-rationale.md`
- **리뷰 피드백 반영 요약**: `docs/campaign-realtime-review-feedback-summary.md` (본 문서)

---

**작성일**: 2025년 1월 24일  
**검토자**: 재미나이님  
**반영 완료**: ✅ 모든 제안사항 반영 완료

