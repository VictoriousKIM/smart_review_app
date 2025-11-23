-- 영수증 발행 정보 필드 추가
-- cash_transactions 테이블에 영수증 발행 관련 필드 추가

ALTER TABLE "public"."cash_transactions"
    ADD COLUMN IF NOT EXISTS "receipt_type" text,
    -- 현금영수증 관련 필드
    ADD COLUMN IF NOT EXISTS "cash_receipt_recipient_type" text,
    ADD COLUMN IF NOT EXISTS "cash_receipt_name" text,
    ADD COLUMN IF NOT EXISTS "cash_receipt_phone" text,
    ADD COLUMN IF NOT EXISTS "cash_receipt_business_name" text,
    ADD COLUMN IF NOT EXISTS "cash_receipt_business_number" text,
    -- 세금계산서 관련 필드
    ADD COLUMN IF NOT EXISTS "tax_invoice_representative" text,
    ADD COLUMN IF NOT EXISTS "tax_invoice_company_name" text,
    ADD COLUMN IF NOT EXISTS "tax_invoice_business_number" text,
    ADD COLUMN IF NOT EXISTS "tax_invoice_email" text,
    ADD COLUMN IF NOT EXISTS "tax_invoice_postal_code" text,
    ADD COLUMN IF NOT EXISTS "tax_invoice_address" text,
    ADD COLUMN IF NOT EXISTS "tax_invoice_detail_address" text;

-- 제약조건 추가
ALTER TABLE "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_receipt_type_check" 
    CHECK (("receipt_type" IS NULL) OR ("receipt_type" = ANY (ARRAY['cash_receipt'::"text", 'tax_invoice'::"text", 'none'::"text"])));

ALTER TABLE "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_cash_receipt_recipient_type_check" 
    CHECK (("cash_receipt_recipient_type" IS NULL) OR ("cash_receipt_recipient_type" = ANY (ARRAY['individual'::"text", 'business'::"text"])));

-- 코멘트 추가
COMMENT ON COLUMN "public"."cash_transactions"."receipt_type" IS '영수증 발행 방법: cash_receipt(현금영수증), tax_invoice(세금계산서), none(발행안함)';
COMMENT ON COLUMN "public"."cash_transactions"."cash_receipt_recipient_type" IS '현금영수증 수령자 유형: individual(개인), business(사업자)';
COMMENT ON COLUMN "public"."cash_transactions"."cash_receipt_name" IS '현금영수증 수령자 이름 (개인)';
COMMENT ON COLUMN "public"."cash_transactions"."cash_receipt_phone" IS '현금영수증 수령자 휴대폰 번호 (개인)';
COMMENT ON COLUMN "public"."cash_transactions"."cash_receipt_business_name" IS '현금영수증 사업자명 (사업자)';
COMMENT ON COLUMN "public"."cash_transactions"."cash_receipt_business_number" IS '현금영수증 사업자번호 (사업자)';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_representative" IS '세금계산서 대표자명';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_company_name" IS '세금계산서 회사명';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_business_number" IS '세금계산서 사업자번호';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_email" IS '세금계산서 이메일';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_postal_code" IS '세금계산서 우편번호';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_address" IS '세금계산서 주소';
COMMENT ON COLUMN "public"."cash_transactions"."tax_invoice_detail_address" IS '세금계산서 상세주소';

-- create_cash_transaction 함수에 영수증 관련 파라미터 추가
CREATE OR REPLACE FUNCTION "public"."create_cash_transaction"(
    "p_wallet_id" "uuid",
    "p_transaction_type" "text",
    "p_point_amount" integer,
    "p_cash_amount" numeric DEFAULT NULL::numeric,
    "p_payment_method" "text" DEFAULT NULL::"text",
    "p_bank_name" "text" DEFAULT NULL::"text",
    "p_account_number" "text" DEFAULT NULL::"text",
    "p_account_holder" "text" DEFAULT NULL::"text",
    "p_description" "text" DEFAULT NULL::"text",
    "p_created_by_user_id" "uuid" DEFAULT NULL::"uuid",
    -- 영수증 관련 파라미터 추가
    "p_receipt_type" "text" DEFAULT NULL::"text",
    "p_cash_receipt_recipient_type" "text" DEFAULT NULL::"text",
    "p_cash_receipt_name" "text" DEFAULT NULL::"text",
    "p_cash_receipt_phone" "text" DEFAULT NULL::"text",
    "p_cash_receipt_business_name" "text" DEFAULT NULL::"text",
    "p_cash_receipt_business_number" "text" DEFAULT NULL::"text",
    "p_tax_invoice_representative" "text" DEFAULT NULL::"text",
    "p_tax_invoice_company_name" "text" DEFAULT NULL::"text",
    "p_tax_invoice_business_number" "text" DEFAULT NULL::"text",
    "p_tax_invoice_email" "text" DEFAULT NULL::"text",
    "p_tax_invoice_postal_code" "text" DEFAULT NULL::"text",
    "p_tax_invoice_address" "text" DEFAULT NULL::"text",
    "p_tax_invoice_detail_address" "text" DEFAULT NULL::"text"
) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- wallet 존재 확인
    IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE id = p_wallet_id) THEN
        RAISE EXCEPTION 'Wallet not found';
    END IF;
    
    IF p_transaction_type NOT IN ('deposit', 'withdraw') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be deposit or withdraw';
    END IF;
    
    -- 출금 시 계좌 정보 필수
    IF p_transaction_type = 'withdraw' AND (
        p_bank_name IS NULL OR 
        p_account_number IS NULL OR 
        p_account_holder IS NULL
    ) THEN
        RAISE EXCEPTION 'Bank account information is required for withdraw transactions';
    END IF;
    
    -- 영수증 타입 검증
    IF p_receipt_type IS NOT NULL AND p_receipt_type NOT IN ('cash_receipt', 'tax_invoice', 'none') THEN
        RAISE EXCEPTION 'Invalid receipt_type. Must be cash_receipt, tax_invoice, or none';
    END IF;
    
    -- 현금영수증 수령자 유형 검증
    IF p_cash_receipt_recipient_type IS NOT NULL AND p_cash_receipt_recipient_type NOT IN ('individual', 'business') THEN
        RAISE EXCEPTION 'Invalid cash_receipt_recipient_type. Must be individual or business';
    END IF;
    
    -- 거래 생성 (status는 기본값 'pending')
    INSERT INTO public.cash_transactions (
        wallet_id,
        transaction_type,
        point_amount,
        cash_amount,
        payment_method,
        bank_name,
        account_number,
        account_holder,
        description,
        created_by_user_id,
        -- 영수증 관련 필드
        receipt_type,
        cash_receipt_recipient_type,
        cash_receipt_name,
        cash_receipt_phone,
        cash_receipt_business_name,
        cash_receipt_business_number,
        tax_invoice_representative,
        tax_invoice_company_name,
        tax_invoice_business_number,
        tax_invoice_email,
        tax_invoice_postal_code,
        tax_invoice_address,
        tax_invoice_detail_address
    ) VALUES (
        p_wallet_id,
        p_transaction_type,
        p_point_amount,
        p_cash_amount,
        p_payment_method,
        p_bank_name,
        p_account_number,
        p_account_holder,
        p_description,
        COALESCE(p_created_by_user_id, auth.uid()),
        -- 영수증 관련 값
        p_receipt_type,
        p_cash_receipt_recipient_type,
        p_cash_receipt_name,
        p_cash_receipt_phone,
        p_cash_receipt_business_name,
        p_cash_receipt_business_number,
        p_tax_invoice_representative,
        p_tax_invoice_company_name,
        p_tax_invoice_business_number,
        p_tax_invoice_email,
        p_tax_invoice_postal_code,
        p_tax_invoice_address,
        p_tax_invoice_detail_address
    )
    RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$;

