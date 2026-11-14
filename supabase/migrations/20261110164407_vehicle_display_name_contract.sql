-- Some deployed databases have a required ordinary display_name column; the base
-- schema has a generated one. Fill only the ordinary variant without changing data.
CREATE OR REPLACE FUNCTION public.fill_vehicle_display_name()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.display_name IS NULL OR trim(NEW.display_name) = '' THEN
    NEW.display_name := concat_ws(' ', NEW.make, NEW.model);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.fill_vehicle_display_name() FROM PUBLIC, anon, authenticated;
DO $$
BEGIN
 IF EXISTS (SELECT 1 FROM information_schema.columns
   WHERE table_schema='public' AND table_name='vehicles'
     AND column_name='display_name' AND is_generated='NEVER') THEN
   DROP TRIGGER IF EXISTS fill_vehicle_display_name ON public.vehicles;
   CREATE TRIGGER fill_vehicle_display_name BEFORE INSERT OR UPDATE ON public.vehicles
     FOR EACH ROW EXECUTE FUNCTION public.fill_vehicle_display_name();
 END IF;
END;
$$;
NOTIFY pgrst, 'reload schema';
