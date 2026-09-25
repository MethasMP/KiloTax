-- ==============================================================================
-- KiloTax Database Migration: Direct Work Deductions vs Car Running Costs
-- Conforms to Clean Code N1 (Intention-revealing names) & PostgreSQL snake_case conventions
-- References: ITAA 1997 Division 28 & Division 8-1
-- ==============================================================================

-- 1. Add generated column is_direct_claim to expenses (PostgreSQL auto-computes direct deductions)
ALTER TABLE expenses 
ADD COLUMN IF NOT EXISTS is_direct_claim boolean GENERATED ALWAYS AS (
  category IN ('toolsMaterials', 'tollsParking', 'otherBusiness')
) STORED;

-- 2. Drop and Recreate v_accountant_deductions with self-documenting column names
DROP VIEW IF EXISTS v_accountant_deductions CASCADE;

CREATE VIEW v_accountant_deductions AS
SELECT 
  e.id AS expense_id,
  e.vehicle_id,
  v.user_id,
  v.rego_plate,
  v.display_name AS vehicle_name,
  v.tax_method,
  e.date,
  get_financial_year(e.date) AS financial_year,
  e.category,
  e.supplier,
  e.amount,
  COALESCE(e.business_percentage, 100.0) AS business_percentage,
  e.receipt_storage_path,
  e.linked_trip_id,
  e.client_dedup_id,
  e.deleted_at,
  -- Intention-revealing claim classification (Clean Code N1, snake_case)
  CASE 
    WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text]) 
      THEN 'direct_work_deduction'::text
    ELSE 'car_running_cost'::text
  END AS claim_type,
  CASE 
    WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text]) 
      THEN 'direct_100_percent'::text
    ELSE 'logbook_apportioned'::text
  END AS deduction_method,
  (e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text])) AS is_direct_claim,
  CASE 
    WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text]) 
      THEN round(e.amount * (COALESCE(e.business_percentage, 100.0) / 100.0), 2)
    WHEN v.tax_method = 'centsPerKm'::text AND (e.category = ANY (ARRAY['fuel'::text, 'maintenanceTyres'::text, 'rego'::text, 'insurance'::text, 'interest'::text])) 
      THEN 0.00 
    ELSE round(e.amount * (COALESCE(e.business_percentage, 100.0) / 100.0), 2) 
  END AS safe_deductible_amount,
  CASE 
    WHEN v.tax_method = 'centsPerKm'::text AND (e.category = ANY (ARRAY['fuel'::text, 'maintenanceTyres'::text, 'rego'::text, 'insurance'::text, 'interest'::text])) 
      THEN 'substantiation_only'::text 
    WHEN e.category = ANY (ARRAY['toolsMaterials'::text, 'tollsParking'::text, 'otherBusiness'::text])
      THEN 'direct_100_claim'::text
    ELSE 'logbook_claimable'::text 
  END AS ato_status 
FROM expenses e 
JOIN vehicles v ON e.vehicle_id = v.id 
WHERE e.deleted_at IS NULL AND v.deleted_at IS NULL;
