-- Nullable additions preserve historical records without assuming their currency.
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS currency text;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS supplier_abn text;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS invoice_number text;
