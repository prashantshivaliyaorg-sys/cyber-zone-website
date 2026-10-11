-- Cyber Zone public overview only: returns aggregate totals for this Cyber Zone owner.
-- Does not expose individual customer/work/expense rows.
CREATE OR REPLACE FUNCTION public.cz_public_overview()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH state AS (
  SELECT
    COALESCE((SELECT state_json FROM public.cz_app_state WHERE owner_id = 'b47958d7-7615-4962-acbd-f3ae26b64acf' AND state_key = 'works' LIMIT 1), '[]'::jsonb) AS works,
    COALESCE((SELECT state_json FROM public.cz_app_state WHERE owner_id = 'b47958d7-7615-4962-acbd-f3ae26b64acf' AND state_key = 'money' LIMIT 1), '[]'::jsonb) AS money
), work_rows AS (
  SELECT value AS w FROM state, jsonb_array_elements(CASE WHEN jsonb_typeof(state.works)='array' THEN state.works ELSE '[]'::jsonb END)
), money_rows AS (
  SELECT value AS m FROM state, jsonb_array_elements(CASE WHEN jsonb_typeof(state.money)='array' THEN state.money ELSE '[]'::jsonb END)
), totals AS (
  SELECT
    (SELECT COUNT(DISTINCT lower(trim(COALESCE(w->>'name',''))) || '|' || regexp_replace(COALESCE(w->>'phone',''), '\D', '', 'g')) FROM work_rows WHERE COALESCE(trim(w->>'name'),'') <> '' OR COALESCE(trim(w->>'phone'),'') <> '') AS total_customers,
    COALESCE((SELECT SUM(COALESCE(NULLIF(w->>'paid','')::numeric,0)-COALESCE(NULLIF(w->>'cost','')::numeric,0)-COALESCE(NULLIF(w->>'commission','')::numeric,0)) FROM work_rows),0) AS total_profit,
    COALESCE((SELECT SUM(COALESCE(NULLIF(w->>'cost','')::numeric,0)) FROM work_rows),0) + COALESCE((SELECT SUM(COALESCE(NULLIF(m->>'amount','')::numeric,0)) FROM money_rows WHERE m->>'type'='expense'),0) AS total_expenses,
    COALESCE((SELECT SUM(CASE WHEN w->>'udhaarDone'='Yes' THEN 0 ELSE GREATEST(0,COALESCE(NULLIF(w->>'charge','')::numeric,0)-COALESCE(NULLIF(w->>'paid','')::numeric,0)) END) FROM work_rows),0) AS total_udhaar
)
SELECT jsonb_build_object('total_customers',total_customers,'total_profit',total_profit,'total_expenses',total_expenses,'total_udhaar',total_udhaar) FROM totals;
$$;
REVOKE ALL ON FUNCTION public.cz_public_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cz_public_overview() TO anon, authenticated;
