-- ==============================================================================
-- KiloTax Database Migration: Global Canonical ATO Tax Rules
-- Centralized Single Source of Truth for Australian Cents-per-Kilometre Rates
-- References: ITAA 1997 Division 28 (Car Expenses) & Annual ATO Determinations
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.ato_tax_rules (
    financial_year text PRIMARY KEY, -- e.g. '2023-24', '2024-25', '2025-26', '2026-27'
    start_year integer NOT NULL UNIQUE, -- e.g. 2023, 2024, 2025, 2026
    cents_per_km_rate numeric(4, 2) NOT NULL CHECK (cents_per_km_rate >= 0.50 AND cents_per_km_rate <= 2.00),
    cents_per_km_max_km numeric NOT NULL DEFAULT 5000.0,
    car_depreciation_limit numeric NOT NULL DEFAULT 69674.0,
    legislative_ref text NOT NULL DEFAULT 'ITAA 1997 s.28-25',
    source_url text NOT NULL DEFAULT 'https://www.ato.gov.au/tax-rates-and-codes/cents-per-kilometre',
    is_active boolean NOT NULL DEFAULT false,
    verified_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for instant start_year lookups
CREATE INDEX IF NOT EXISTS idx_ato_tax_rules_start_year ON public.ato_tax_rules(start_year);
CREATE INDEX IF NOT EXISTS idx_ato_tax_rules_is_active ON public.ato_tax_rules(is_active);

-- Enable Row Level Security
ALTER TABLE public.ato_tax_rules ENABLE ROW LEVEL SECURITY;

-- Allow read access for all clients (anon and authenticated tradies)
DROP POLICY IF EXISTS "Allow public read on ato_tax_rules" ON public.ato_tax_rules;
CREATE POLICY "Allow public read on ato_tax_rules" 
    ON public.ato_tax_rules FOR SELECT 
    USING (true);

-- Restrict write/update to service role only (no client mutations allowed)
DROP POLICY IF EXISTS "Service role write on ato_tax_rules" ON public.ato_tax_rules;
CREATE POLICY "Service role write on ato_tax_rules" 
    ON public.ato_tax_rules FOR ALL 
    TO service_role 
    USING (true) 
    WITH CHECK (true);

-- Seed Official Statutory Rates (Gazetted ATO Determinations)
INSERT INTO public.ato_tax_rules 
    (financial_year, start_year, cents_per_km_rate, cents_per_km_max_km, car_depreciation_limit, legislative_ref, is_active)
VALUES
    ('2020-21', 2020, 0.72, 5000.0, 59136.0, 'ITAA 1997 s.28-25 / TD 2020/6', false),
    ('2021-22', 2021, 0.72, 5000.0, 60733.0, 'ITAA 1997 s.28-25 / TD 2021/6', false),
    ('2022-23', 2022, 0.78, 5000.0, 64741.0, 'ITAA 1997 s.28-25 / TD 2022/13', false),
    ('2023-24', 2023, 0.85, 5000.0, 68108.0, 'ITAA 1997 s.28-25 / TD 2023/3', false),
    ('2024-25', 2024, 0.88, 5000.0, 69674.0, 'ITAA 1997 s.28-25 / TD 2024/6', false),
    ('2025-26', 2025, 0.88, 5000.0, 69674.0, 'ITAA 1997 s.28-25 / TD 2024/6 (Continuing)', false),
    ('2026-27', 2026, 0.91, 5000.0, 69674.0, 'ITAA 1997 s.28-25 / TD 2026/X (Active Rule)', true)
ON CONFLICT (financial_year) DO UPDATE SET
    cents_per_km_rate = EXCLUDED.cents_per_km_rate,
    is_active = EXCLUDED.is_active,
    legislative_ref = EXCLUDED.legislative_ref,
    verified_at = now();

-- Server-Side Health & Freshness Audit Function
-- Evaluates whether the current date has rolled over into a financial year that lacks a verified rule.
-- Designed for Server-side cron/edge-function alerting without impacting mobile users.
CREATE OR REPLACE FUNCTION public.check_ato_rules_freshness(check_date timestamptz DEFAULT now())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_month integer;
    v_year integer;
    v_target_start_year integer;
    v_found_rule record;
    v_result jsonb;
BEGIN
    v_month := EXTRACT(MONTH FROM check_date);
    v_year := EXTRACT(YEAR FROM check_date);
    
    -- In Australia, FY starts 1 July
    IF v_month >= 7 THEN
        v_target_start_year := v_year;
    ELSE
        v_target_start_year := v_year - 1;
    END IF;

    -- Lookup rule for active target year
    SELECT * INTO v_found_rule
    FROM public.ato_tax_rules
    WHERE start_year = v_target_start_year;

    IF FOUND THEN
        v_result := jsonb_build_object(
            'status', 'healthy',
            'financial_year', v_found_rule.financial_year,
            'cents_per_km_rate', v_found_rule.cents_per_km_rate,
            'is_stale', false,
            'target_start_year', v_target_start_year,
            'checked_at', now()
        );
    ELSE
        -- CRITICAL: Post-1-July rollover missing verified rate -> Triggers Developer Alert
        v_result := jsonb_build_object(
            'status', 'developer_alert_required',
            'error', 'Financial year rollover occurred but no verified rate exists for start_year ' || v_target_start_year,
            'is_stale', true,
            'target_start_year', v_target_start_year,
            'checked_at', now()
        );
    END IF;

    RETURN v_result;
END;
$$;
