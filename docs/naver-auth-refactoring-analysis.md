# naver-auth.ts 리팩토링 분석

## 📊 현재 상태

- **파일 크기**: 419줄
- **복잡도**: 중간 (하나의 파일로 관리)
- **유지보수성**: 양호 (단일 파일로 모든 로직 포함)

**원칙**: 네이버 인증은 하나의 스크립트로 완결되므로 과도한 분리 불필요

---

## 🔴 필수 수정 사항

### 1. 중복 코드: `removeBOM` 함수

**문제**: `removeBOM` 함수가 두 번 정의됨 (192-196줄, 237-240줄)

```typescript
// 첫 번째 정의 (192-196줄)
const removeBOM = (str: string | undefined): string => {
  if (!str) return '';
  return str.replace(/^\uFEFF/, '').trim();
};

// 두 번째 정의 (237-240줄) - 동일한 코드
const removeBOM = (str: string | undefined): string => {
  if (!str) return '';
  return str.replace(/^\uFEFF/, '').trim();
};
```

**해결 방법**: 파일 상단에 한 번만 정의

```typescript
// 파일 상단에 한 번만 정의
function removeBOM(str: string | undefined): string {
  if (!str) return '';
  return str.replace(/^\uFEFF/, '').trim();
}

// 이후 두 곳에서 재사용
const clientId = removeBOM(env.NAVER_CLIENT_ID);
// ...
const supabaseUrl = removeBOM(env.SUPABASE_URL);
```

**우선순위**: 🔴 필수 (즉시 수정)

---

## 🟡 선택적 개선 사항

### 2. 디버깅 로그 정리 (선택사항)

**현재**: 디버깅용 로그가 많음 (154-270줄)

**개선 방법**: 환경 변수 기반 조건부 로깅

```typescript
const DEBUG = env.ENVIRONMENT === 'development';

if (DEBUG) {
  console.log('=== Workers API 요청 수신 ===');
  // 디버그 로그들...
}
```

**우선순위**: 🟡 선택 (필요시만)

**참고**: 디버깅 중이라면 그대로 유지해도 됨

---

## 📋 리팩토링 요약

| 우선순위 | 항목 | 작업량 | 비고 |
|---------|------|--------|------|
| 🔴 필수 | 1. removeBOM 중복 제거 | 5분 | 파일 상단에 한 번만 정의 |
| 🟡 선택 | 2. 디버깅 로그 정리 | 30분 | 필요시만 |

---

## 🎯 권장 리팩토링 계획

### 필수 수정 (5분)
1. ✅ `removeBOM` 함수를 파일 상단에 한 번만 정의하고 재사용

### 선택적 개선 (필요시)
2. ✅ 디버깅 로그를 조건부로 실행 (개발 중이라면 유지해도 됨)

---

## 📁 파일 구조 (변경 없음)

```
workers/
└── functions/
    └── naver-auth.ts (단일 파일로 유지)
```

**원칙**: 네이버 인증은 하나의 파일로 완결되므로 분리 불필요

---

## ✅ 리팩토링 후 예상 효과

1. **코드 중복 제거**: `removeBOM` 함수 중복 제거로 일관성 향상
2. **가독성**: 약간 향상 (중복 코드 제거)
3. **유지보수성**: 단일 파일 유지로 관리 용이

---

## ⚠️ 주의사항

1. **기존 동작 보장**: `removeBOM` 함수 중복 제거 시 동일한 동작 보장
2. **테스트**: 수정 후 네이버 로그인 동작 확인
3. **단일 파일 유지**: 네이버 인증 로직은 하나의 파일로 유지

---

**작성일**: 2025-01-XX
**분석 대상**: `workers/functions/naver-auth.ts` (419줄)

