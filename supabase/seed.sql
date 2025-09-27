-- Seed data for development
-- This file will be executed after migrations during db reset

-- Insert sample campaigns
INSERT INTO public.campaigns (
    id, title, description, image_url, brand, category, type, 
    reward_points, reward_type, reward_description, deadline, 
    max_participants, status, requirements, tags
) VALUES 
(
    gen_random_uuid(),
    '새로운 스마트폰 리뷰 캠페인',
    '최신 스마트폰의 성능과 사용성을 솔직하게 리뷰해주세요.',
    'https://example.com/phone.jpg',
    'TechBrand',
    'product',
    'new_',
    1000,
    'points',
    '리뷰 작성 시 1000포인트 지급',
    NOW() + INTERVAL '30 days',
    50,
    'active',
    ARRAY['인스타그램 팔로워 1000명 이상', '리뷰 경험 3회 이상'],
    ARRAY['스마트폰', '테크', '리뷰']
),
(
    gen_random_uuid(),
    '맛집 카페 탐방 캠페인',
    '서울 강남구의 숨은 맛집 카페를 방문하고 후기를 작성해주세요.',
    'https://example.com/cafe.jpg',
    'CafeBrand',
    'place',
    'popular',
    500,
    'points',
    '리뷰 작성 시 500포인트 지급',
    NOW() + INTERVAL '14 days',
    30,
    'active',
    ARRAY['블로그 운영자', '음식 리뷰 경험'],
    ARRAY['카페', '맛집', '서울']
),
(
    gen_random_uuid(),
    '온라인 쇼핑몰 서비스 리뷰',
    '새로 오픈한 온라인 쇼핑몰의 서비스 품질을 평가해주세요.',
    'https://example.com/shopping.jpg',
    'ShopBrand',
    'service',
    'ongoing',
    800,
    'points',
    '리뷰 작성 시 800포인트 지급',
    NOW() + INTERVAL '60 days',
    100,
    'active',
    ARRAY['온라인 쇼핑 경험', '서비스 리뷰 경험'],
    ARRAY['쇼핑', '서비스', '온라인']
);

-- Note: User profiles will be automatically created when users sign up
-- through the auth system, so we don't need to insert sample users here.
