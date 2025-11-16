# 포인트 중복 차감 및 이미지 로딩 문제 해결 요약

## ✅ 해결된 문제

### 1. 포인트 중복 차감 문제

**원인**:
- RPC 함수 `create_campaign_with_points_v2`에서 `UPDATE wallets SET current_points = ...`로 직접 차감
- `point_transactions_wallet_balance_trigger` 트리거가 `point_transactions` INSERT 시 자동으로 차감
- 결과: 2번 차감됨

**해결**:
- RPC 함수에서 `wallets` 직접 업데이트 제거
- 트리거만 사용하여 포인트 차감 (한 번만 실행)
- 마이그레이션: `20251116130000_fix_duplicate_point_deduction_trigger.sql`

**변경 사항**:
```sql
-- 이전: RPC 함수에서 직접 차감
UPDATE public.wallets
SET current_points = current_points - v_total_cost
WHERE id = v_wallet_id;

-- 이후: 트리거만 사용 (RPC 함수에서 UPDATE 제거)
-- point_transactions INSERT 시 트리거가 자동으로 차감
INSERT INTO public.point_transactions (
  wallet_id, transaction_type, amount, ...
) VALUES (
  v_wallet_id, 'spend', -v_total_cost, ...
);
```

---

### 2. 이미지 로딩 실패 문제

**원인**:
- R2 Public URL (`https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/...`)은 직접 접근이 안 될 수 있음
- CORS 설정 문제 또는 Private Bucket 설정

**해결**:
- Cloudflare Workers를 통해 이미지 제공
- URL 형식 변경: `https://smart-review-api.nightkille.workers.dev/api/files/{filePath}`

**변경 사항**:
```dart
// 이전: R2 Public URL 직접 사용
final publicUrl = '${SupabaseConfig.r2PublicUrl}/${presignedUrlResponse.filePath}';

// 이후: Cloudflare Workers를 통해 제공
final publicUrl = '${SupabaseConfig.workersApiUrl}/api/files/${presignedUrlResponse.filePath}';
```

---

## 📝 적용된 변경사항

### 1. 데이터베이스 마이그레이션
- `supabase/migrations/20251116130000_fix_duplicate_point_deduction_trigger.sql`
  - RPC 함수에서 `wallets` 직접 업데이트 제거
  - 트리거만 사용하여 포인트 차감

### 2. Flutter 코드
- `lib/screens/campaign/campaign_creation_screen.dart`
  - 이미지 URL 생성 시 Cloudflare Workers URL 사용

---

## 🧪 테스트 방법

### 포인트 중복 차감 테스트
1. 캠페인 생성 전 포인트 잔액 확인
2. 캠페인 생성
3. 생성 후 포인트 잔액 확인
4. `total_cost`와 차감된 포인트가 일치하는지 확인
5. `point_transactions` 테이블에서 중복 레코드 확인

```sql
-- 포인트 거래 내역 확인
SELECT 
  pt.id,
  pt.transaction_type,
  pt.amount,
  pt.campaign_id,
  c.title as campaign_title,
  pt.created_at
FROM point_transactions pt
LEFT JOIN campaigns c ON c.id = pt.campaign_id
WHERE pt.wallet_id = '지갑ID'
  AND pt.created_at > NOW() - INTERVAL '1 hour'
ORDER BY pt.created_at DESC;

-- 중복 차감 확인
SELECT 
  campaign_id,
  COUNT(*) as deduction_count,
  SUM(ABS(amount)) as total_deduced
FROM point_transactions
WHERE wallet_id = '지갑ID'
  AND transaction_type = 'spend'
  AND campaign_id IS NOT NULL
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY campaign_id
HAVING COUNT(*) > 1;
```

### 이미지 로딩 테스트
1. 캠페인 생성 시 이미지 업로드
2. 생성된 캠페인 목록에서 이미지 표시 확인
3. 캠페인 상세 페이지에서 이미지 표시 확인
4. 브라우저 개발자 도구에서 네트워크 탭 확인 (CORS 에러 없음)

---

## 📅 작성일

2025-11-16

