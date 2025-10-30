-- Fix RLS policy bug for companies table update
-- The original policy had a bug: company_users.company_id = company_users.id (wrong)
-- Should be: company_users.company_id = companies.id (correct)

DROP POLICY IF EXISTS "Companies are updatable by owners" ON public.companies;

CREATE POLICY "Companies are updatable by owners" ON public.companies 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1
    FROM public.company_users
    WHERE (
      company_users.company_id = companies.id 
      AND company_users.user_id = auth.uid()
      AND company_users.company_role = 'owner'::text
    )
  )
);

