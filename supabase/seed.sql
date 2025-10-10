-- 로컬 Docker DB의 실제 사용자 데이터 동기화

-- 1. auth.users 테이블에 실제 개발용 계정 삽입
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, 
  invited_at, confirmation_token, confirmation_sent_at, recovery_token, 
  recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, 
  last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, 
  created_at, updated_at, phone, phone_confirmed_at, phone_change, 
  phone_change_token, phone_change_sent_at, email_change_token_current, 
  email_change_confirm_status, banned_until, reauthentication_token, 
  reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous
) VALUES 
-- 개발용 이메일 계정: dev@example.com
(
  '00000000-0000-0000-0000-000000000000', 
  '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1', 
  'authenticated', 
  'authenticated', 
  'dev@example.com', 
  '$2a$10$gu.flQGU.//LMFDSE/J7yOMr96eOboIzL95hVeTY0eOyaFIXQUlNu', 
  '2025-09-29 05:29:27.513119+00', 
  NULL, 
  '', 
  NULL, 
  '', 
  NULL, 
  '', 
  '', 
  NULL, 
  '2025-09-30 06:04:43.466817+00', 
  '{"provider": "email", "providers": ["email"]}', 
  '{"sub": "5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1", "email": "dev@example.com", "display_name": "dev", "email_verified": true, "phone_verified": false}', 
  NULL, 
  '2025-09-29 05:29:27.503599+00', 
  '2025-10-01 05:06:21.208936+00', 
  NULL, 
  NULL, 
  '', 
  '', 
  NULL, 
  '', 
  0, 
  NULL, 
  '', 
  NULL, 
  false, 
  NULL, 
  false
),
-- 관리자 계정: admin@example.com
(
  '00000000-0000-0000-0000-000000000000', 
  '9cb57f0c-6ffe-4ad6-bc91-fd49aec221e3', 
  'authenticated', 
  'authenticated', 
  'admin@example.com', 
  '$2a$10$RgoPnggNqED2fjRmazkPreiok.MvZak09i565Dg2a9.8pIqzZR9oC', 
  '2025-10-01 05:06:44.148487+00', 
  NULL, 
  '', 
  NULL, 
  '', 
  NULL, 
  '', 
  '', 
  NULL, 
  '2025-10-01 05:06:44.148487+00', 
  '{"provider": "email", "providers": ["email"]}', 
  '{"sub": "9cb57f0c-6ffe-4ad6-bc91-fd49aec221e3", "email": "admin@example.com", "display_name": "admin", "email_verified": true, "phone_verified": false}', 
  NULL, 
  '2025-10-01 05:06:44.13555+00', 
  '2025-10-01 05:06:44.158958+00', 
  NULL, 
  NULL, 
  '', 
  '', 
  NULL, 
  '', 
  0, 
  NULL, 
  '', 
  NULL, 
  false, 
  NULL, 
  false
),
-- 리뷰어 계정: reviewer@example.com
(
  '00000000-0000-0000-0000-000000000000', 
  'a0f8827d-2cbe-4e8e-a7cb-003b32b1a1f7', 
  'authenticated', 
  'authenticated', 
  'reviewer@example.com', 
  '$2a$10$W38eQBPvbWvj0lKMsAAoFeUdSW6MmXBFrt0kZhawQ8daOxfiiLxM.', 
  '2025-10-01 05:07:06.399031+00', 
  NULL, 
  '', 
  NULL, 
  '', 
  NULL, 
  '', 
  '', 
  NULL, 
  '2025-10-01 05:07:06.399031+00', 
  '{"provider": "email", "providers": ["email"]}', 
  '{"sub": "a0f8827d-2cbe-4e8e-a7cb-003b32b1a1f7", "email": "reviewer@example.com", "display_name": "reviewer", "email_verified": true, "phone_verified": false}', 
  NULL, 
  '2025-10-01 05:07:06.394924+00', 
  '2025-10-01 05:07:06.40384+00', 
  NULL, 
  NULL, 
  '', 
  '', 
  NULL, 
  '', 
  0, 
  NULL, 
  '', 
  NULL, 
  false, 
  NULL, 
  false
);

-- 2. 회사 시드 데이터
INSERT INTO companies (id, name, business_number, contact_email, contact_phone, address, created_by)
VALUES 
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', '테스트 회사', '123-45-67890', 'company@test.com', '02-1234-5678', '서울시 강남구', '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1');

-- 3. public.users 테이블에 사용자 정보 동기화
INSERT INTO public.users (id, display_name, email, user_type, company_id)
VALUES 
  ('5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1', 'dev', 'dev@example.com', 'user', null),
  ('9cb57f0c-6ffe-4ad6-bc91-fd49aec221e3', 'admin', 'admin@example.com', 'user', null),
  ('a0f8827d-2cbe-4e8e-a7cb-003b32b1a1f7', 'reviewer', 'reviewer@example.com', 'user', null)
ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  email = EXCLUDED.email,
  user_type = EXCLUDED.user_type,
  company_id = EXCLUDED.company_id,
  updated_at = NOW();

-- 4. 회사-사용자 관계 설정
INSERT INTO company_users (company_id, user_id, company_role)
VALUES 
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1', 'owner');

-- 5. 캠페인 시드 데이터 삽입
INSERT INTO campaigns (
  title, 
  description, 
  product_image_url, 
  platform, 
  platform_logo_url, 
  campaign_type, 
  product_price, 
  review_reward, 
  start_date, 
  end_date, 
  max_participants, 
  current_participants, 
  status,
  created_by,
  company_id
) VALUES 
(
  '무선 이어폰 리뷰 캠페인',
  '최신 블루투스 무선 이어폰을 체험하고 솔직한 리뷰를 작성해주세요.',
  'https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?w=400',
  'coupang',
  'https://logo.clearbit.com/coupang.com',
  'reviewer',
  89000,
  15000,
  NOW(),
  NOW() + INTERVAL '30 days',
  50,
  12,
  'active',
  '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1',
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
),
(
  '스마트워치 체험단 모집',
  '건강 관리 기능이 뛰어난 스마트워치를 체험하고 리뷰를 작성해주세요.',
  'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400',
  'naver',
  'https://logo.clearbit.com/naver.com',
  'reviewer',
  250000,
  30000,
  NOW(),
  NOW() + INTERVAL '21 days',
  30,
  8,
  'active',
  '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1',
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
),
(
  '카페 체인 신메뉴 체험단',
  '새로 오픈한 카페에서 신메뉴를 체험하고 방문 후기를 작성해주세요.',
  'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400',
  'naver',
  'https://logo.clearbit.com/naver.com',
  'visit',
  15000,
  5000,
  NOW(),
  NOW() + INTERVAL '21 days',
  80,
  20,
  'active',
  '5d1e6c3b-7202-4dd8-9a67-d1ff0363f2f1',
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
);