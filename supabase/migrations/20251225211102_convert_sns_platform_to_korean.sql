-- SNS 플랫폼 연결의 platform 필드를 영어에서 한글로 변환

-- 1. 스토어 플랫폼 변환
UPDATE "public"."sns_connections"
SET "platform" = '쿠팡'
WHERE "platform" = 'coupang';

UPDATE "public"."sns_connections"
SET "platform" = 'N스토어'
WHERE "platform" = 'smartstore';

-- 기존에 '스마트스토어'로 저장된 데이터를 'N스토어'로 변환
UPDATE "public"."sns_connections"
SET "platform" = 'N스토어'
WHERE "platform" = '스마트스토어';

UPDATE "public"."sns_connections"
SET "platform" = '카카오'
WHERE "platform" = 'kakao';

UPDATE "public"."sns_connections"
SET "platform" = '11번가'
WHERE "platform" = '11st';

UPDATE "public"."sns_connections"
SET "platform" = '지마켓'
WHERE "platform" = 'gmarket';

UPDATE "public"."sns_connections"
SET "platform" = '옥션'
WHERE "platform" = 'auction';

UPDATE "public"."sns_connections"
SET "platform" = '위메프'
WHERE "platform" = 'wemakeprice';

-- 2. SNS 플랫폼 변환
UPDATE "public"."sns_connections"
SET "platform" = '네이버 블로그'
WHERE "platform" = 'blog';

UPDATE "public"."sns_connections"
SET "platform" = '인스타그램'
WHERE "platform" = 'instagram';

UPDATE "public"."sns_connections"
SET "platform" = '유튜브'
WHERE "platform" = 'youtube';

UPDATE "public"."sns_connections"
SET "platform" = '틱톡'
WHERE "platform" = 'tiktok';

UPDATE "public"."sns_connections"
SET "platform" = '네이버'
WHERE "platform" = 'naver';

-- 3. RPC 함수 수정: create_sns_connection의 v_store_platforms 배열을 한글로 변경
CREATE OR REPLACE FUNCTION "public"."create_sns_connection"(
    "p_user_id" "uuid",
    "p_platform" "text",
    "p_platform_account_id" "text",
    "p_platform_account_name" "text",
    "p_phone" "text",
    "p_address" "text" DEFAULT NULL::"text",
    "p_return_address" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_store_platforms text[] := ARRAY['쿠팡', 'N스토어', '11번가', '지마켓', '옥션', '위메프', '카카오'];
    v_result jsonb;
BEGIN
    -- 1. 사용자 존재 확인
    IF NOT EXISTS (SELECT 1 FROM "public"."users" WHERE "id" = "p_user_id") THEN
        RAISE EXCEPTION '사용자를 찾을 수 없습니다';
    END IF;
    
    -- 2. 스토어 플랫폼 주소 필수 검증
    IF "p_platform" = ANY(v_store_platforms) AND ("p_address" IS NULL OR "p_address" = '') THEN
        RAISE EXCEPTION '스토어 플랫폼(%)은 주소 입력이 필수입니다', "p_platform";
    END IF;
    
    -- 3. 중복 확인 (같은 계정 ID 중복 방지)
    IF EXISTS (
        SELECT 1 FROM "public"."sns_connections"
        WHERE "user_id" = "p_user_id"
          AND "platform" = "p_platform"
          AND "platform_account_id" = "p_platform_account_id"
    ) THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    END IF;
    
    -- 4. SNS 연결 생성
    INSERT INTO "public"."sns_connections" (
        "user_id",
        "platform",
        "platform_account_id",
        "platform_account_name",
        "phone",
        "address",
        "return_address"
    ) VALUES (
        "p_user_id",
        "p_platform",
        "p_platform_account_id",
        "p_platform_account_name",
        "p_phone",
        CASE 
            WHEN "p_platform" = ANY(v_store_platforms) THEN "p_address"
            ELSE NULL
        END,
        "p_return_address"
    )
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'return_address', "return_address",
        'created_at', "created_at"
    ) INTO v_result;
    
    RETURN jsonb_build_object(
        'success', true,
        'data', v_result
    );
    
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    WHEN OTHERS THEN
        RAISE;
END;
$$;

