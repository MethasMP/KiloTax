-- Additive repair of the deployed receipt/client contract. No historic rows are rewritten.
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS local_id text,
  ADD COLUMN IF NOT EXISTS start_odometer_photo_path text,
  ADD COLUMN IF NOT EXISTS start_odometer_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS start_odometer_image_hash text,
  ADD COLUMN IF NOT EXISTS end_odometer_photo_path text,
  ADD COLUMN IF NOT EXISTS end_odometer_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS end_odometer_image_hash text;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS local_id text;
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS local_id text,
  ADD COLUMN IF NOT EXISTS gst_amount numeric(10,2),
  ADD COLUMN IF NOT EXISTS sha256_hash text,
  ADD COLUMN IF NOT EXISTS receipt_audit jsonb,
  ADD COLUMN IF NOT EXISTS is_vault_only boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS vault_reason text,
  ADD COLUMN IF NOT EXISTS allocations jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.expenses.amount IS 'Full original receipt gross total; allocations reconcile to this amount.';
COMMENT ON COLUMN public.expenses.allocations IS 'Atomic receipt lines: description, amount, gst_amount (nullable), category (nullable), purpose: work/private/unresolved. Purpose is user classification, not tax eligibility.';

CREATE OR REPLACE FUNCTION public.validate_receipt_allocations()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  item jsonb;
  item_amount numeric;
  item_gst numeric;
  allocated numeric := 0;
  known_gst numeric := 0;
BEGIN
  IF NEW.linked_trip_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.trips t WHERE t.id = NEW.linked_trip_id AND t.vehicle_id = NEW.vehicle_id
  ) THEN
    RAISE EXCEPTION 'Linked trip must belong to the receipt vehicle' USING ERRCODE = '23514';
  END IF;
  IF NEW.amount IS NULL OR NEW.amount::text IN ('NaN','Infinity','-Infinity') OR NEW.amount < 0
     OR NEW.amount <> round(NEW.amount, 2) THEN
    RAISE EXCEPTION 'Invalid receipt total' USING ERRCODE = '23514';
  END IF;
  IF NEW.gst_amount IS NOT NULL AND (NEW.gst_amount < 0 OR NEW.gst_amount > NEW.amount / 11 + 0.01) THEN
    RAISE EXCEPTION 'Invalid receipt GST' USING ERRCODE = '23514';
  END IF;
  IF NEW.business_percentage IS NOT NULL AND
    (NEW.business_percentage::text IN ('NaN','Infinity','-Infinity') OR NEW.business_percentage < 0 OR NEW.business_percentage > 100) THEN
    RAISE EXCEPTION 'Invalid business percentage' USING ERRCODE = '23514';
  END IF;
  IF jsonb_typeof(NEW.allocations) IS DISTINCT FROM 'array' OR jsonb_array_length(NEW.allocations) > 200 THEN
    RAISE EXCEPTION 'Receipt allocations must be an array of at most 200 items' USING ERRCODE = '23514';
  END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(NEW.allocations) LOOP
    IF jsonb_typeof(item) IS DISTINCT FROM 'object'
       OR jsonb_typeof(item->'description') IS DISTINCT FROM 'string'
       OR length(trim(item->>'description')) = 0
       OR jsonb_typeof(item->'amount') IS DISTINCT FROM 'number'
       OR (item->>'purpose') IS NULL OR (item->>'purpose') NOT IN ('work','private','unresolved') THEN
      RAISE EXCEPTION 'Invalid receipt item' USING ERRCODE = '23514';
    END IF;
    IF item->>'category' IS NOT NULL AND item->>'category' NOT IN
      ('fuel','rego','insurance','maintenanceTyres','interest','tollsParking','toolsMaterials','otherBusiness') THEN
      RAISE EXCEPTION 'Invalid receipt item category' USING ERRCODE = '23514';
    END IF;
    item_amount := (item->>'amount')::numeric;
    IF item_amount <= 0 OR item_amount <> round(item_amount, 2) THEN
      RAISE EXCEPTION 'Item amount must be positive cents' USING ERRCODE = '23514';
    END IF;
    item_gst := NULL;
    IF item->>'gst_amount' IS NOT NULL THEN
      IF jsonb_typeof(item->'gst_amount') IS DISTINCT FROM 'number' THEN
        RAISE EXCEPTION 'Invalid item GST type' USING ERRCODE = '23514';
      END IF;
      item_gst := (item->>'gst_amount')::numeric;
      IF item_gst < 0 OR item_gst <> round(item_gst, 2) OR item_gst > item_amount / 11 + 0.01 THEN
        RAISE EXCEPTION 'Invalid item GST' USING ERRCODE = '23514';
      END IF;
    END IF;
    allocated := allocated + item_amount;
    known_gst := known_gst + coalesce(item_gst, 0);
  END LOOP;
  IF jsonb_array_length(NEW.allocations) > 0 AND allocated <> NEW.amount THEN
    RAISE EXCEPTION 'Receipt items must reconcile to the full receipt total' USING ERRCODE = '23514';
  END IF;
  IF NEW.gst_amount IS NOT NULL AND known_gst > NEW.gst_amount + 0.01 THEN
    RAISE EXCEPTION 'Item GST exceeds receipt GST' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.validate_receipt_allocations() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS validate_receipt_allocations ON public.expenses;
CREATE TRIGGER validate_receipt_allocations BEFORE INSERT OR UPDATE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.validate_receipt_allocations();

-- Replace calculation input with work-only lines. Original parent totals remain in expenses.
-- Keep the existing view columns and security-invoker semantics for current consumers.
CREATE OR REPLACE VIEW public.v_accountant_deductions WITH (security_invoker = true) AS
WITH effective_expenses AS (
 SELECT e.id, e.vehicle_id, e.date, e.supplier, e.business_percentage,
        e.receipt_storage_path, e.linked_trip_id, e.client_dedup_id, e.deleted_at,
        coalesce(line.value->>'category', e.category) AS category,
        (CASE WHEN line.value IS NULL THEN e.amount ELSE (line.value->>'amount')::numeric END)::numeric(10,2) AS amount
 FROM public.expenses e
 LEFT JOIN LATERAL jsonb_array_elements(e.allocations) line(value) ON true
 WHERE NOT e.is_vault_only AND e.deleted_at IS NULL
   AND (line.value IS NULL OR line.value->>'purpose' = 'work')
), vehicle_logbook_rates AS (
 SELECT v.id AS vehicle_id, public.get_financial_year(t.date) AS financial_year,
   CASE WHEN coalesce(sum(t.distance_km), 0) > 0
        THEN round(sum(CASE WHEN t.classification = 'business' THEN t.distance_km ELSE 0 END) / sum(t.distance_km) * 100, 2)
        ELSE 0::numeric END AS logbook_percentage
 FROM public.vehicles v LEFT JOIN public.trips t ON t.vehicle_id = v.id AND t.deleted_at IS NULL
 WHERE v.deleted_at IS NULL GROUP BY v.id, public.get_financial_year(t.date)
)
SELECT e.id AS expense_id, e.vehicle_id, v.user_id, v.rego_plate,
 v.display_name AS vehicle_name, v.tax_method, e.date,
 public.get_financial_year(e.date) AS financial_year, e.category, e.supplier, e.amount,
 coalesce(e.business_percentage, 100.0) AS business_percentage,
 e.receipt_storage_path, e.linked_trip_id, e.client_dedup_id, e.deleted_at,
 CASE WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_work_deduction' ELSE 'car_running_cost' END AS claim_type,
 CASE WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_100_percent' ELSE 'logbook_apportioned' END AS deduction_method,
 e.category IN ('toolsMaterials','tollsParking','otherBusiness') AS is_direct_claim,
 CASE WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN round(e.amount * coalesce(e.business_percentage, 100.0) / 100, 2)
      WHEN v.tax_method = 'centsPerKm' THEN 0.00
      ELSE round(e.amount * coalesce(vlr.logbook_percentage, 0) / 100, 2) END AS safe_deductible_amount,
 CASE WHEN v.tax_method = 'centsPerKm' AND e.category NOT IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'substantiation_only'
      WHEN e.category IN ('toolsMaterials','tollsParking','otherBusiness') THEN 'direct_100_claim'
      ELSE 'logbook_claimable' END AS ato_status
FROM effective_expenses e JOIN public.vehicles v ON v.id = e.vehicle_id
LEFT JOIN vehicle_logbook_rates vlr ON vlr.vehicle_id = v.id AND vlr.financial_year = public.get_financial_year(e.date)
WHERE v.deleted_at IS NULL;
NOTIFY pgrst, 'reload schema';
