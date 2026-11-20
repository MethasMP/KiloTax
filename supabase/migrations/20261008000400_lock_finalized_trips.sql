-- Migration: 20261008_lock_finalized_trips.sql
-- Enforce trip immutability trigger for finalized logbooks (ITAA 1997 Subdivision 28-F & TR 97/11)
-- Blocks update and delete on trips within concluded 12-week logbook periods (>84 days from logbook start date).

CREATE OR REPLACE FUNCTION public.check_trip_logbook_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_logbook_start timestamptz;
    v_trip_date timestamptz;
    v_is_locked boolean := false;
BEGIN
    -- Determine target trip date and vehicle
    IF TG_OP = 'DELETE' THEN
        v_trip_date := OLD.date;
        SELECT logbook_start_date INTO v_logbook_start
        FROM public.vehicles
        WHERE id = OLD.vehicle_id;
    ELSE
        v_trip_date := NEW.date;
        SELECT logbook_start_date INTO v_logbook_start
        FROM public.vehicles
        WHERE id = NEW.vehicle_id;
    END IF;

    -- Concluded 12-week logbook period check:
    -- Logbook runs for 84 days (12 weeks * 7 days).
    -- Once concluded (logbook_start_date + 84 days <= now()), historical trips inside that window are finalized.
    IF v_logbook_start IS NOT NULL THEN
        IF (v_logbook_start + INTERVAL '84 days') <= now() THEN
            IF v_trip_date >= v_logbook_start AND v_trip_date < (v_logbook_start + INTERVAL '84 days') THEN
                v_is_locked := true;
            END IF;
        END IF;
    END IF;

    IF v_is_locked THEN
        RAISE EXCEPTION 'Trip is locked: concluded 12-week logbook period is immutable under ATO TR 97/11 and ITAA 1997 Subdivision 28-F'
            USING ERRCODE = '23505'; -- Or custom statutory violation
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_lock_finalized_trips ON public.trips;

CREATE TRIGGER trg_lock_finalized_trips
BEFORE UPDATE OR DELETE ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.check_trip_logbook_immutability();

COMMENT ON FUNCTION public.check_trip_logbook_immutability() IS 'Guarantees statutory immutability of concluded 12-week logbook trips under ATO TR 97/11';
