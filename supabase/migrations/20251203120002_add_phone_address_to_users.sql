-- users 테이블에 phone과 address 컬럼 추가
DO $$ 
BEGIN
  -- phone 컬럼 추가 (없는 경우에만)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'phone'
  ) THEN
    ALTER TABLE public.users ADD COLUMN phone TEXT;
    COMMENT ON COLUMN public.users.phone IS '사용자 전화번호';
  END IF;

  -- address 컬럼 추가 (없는 경우에만)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'address'
  ) THEN
    ALTER TABLE public.users ADD COLUMN address TEXT;
    COMMENT ON COLUMN public.users.address IS '사용자 주소';
  END IF;
END $$;

