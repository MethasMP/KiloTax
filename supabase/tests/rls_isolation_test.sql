BEGIN;
SELECT plan(5);

-- 1. Create two test users in auth.users
INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'user_a_rls@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'user_b_rls@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Create vehicle and trip for user A
INSERT INTO public.vehicles (id, user_id, make, model, rego_plate, initial_odometer, tax_method)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Toyota', 'Hilux', 'TRADIE1', 10000, 'logbook')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.trips (id, user_id, vehicle_id, date, distance_km, purpose, classification, tax_method, evidence_source)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now(), 25.5, 'Site inspection', 'business', 'logbook', 'auto_telemetry')
ON CONFLICT (id) DO NOTHING;

-- 3. User A creates a trip_evidence_link
INSERT INTO public.trip_evidence_links (id, user_id, trip_id, confidence_score, association_method)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 0.95, 'manual_user')
ON CONFLICT (id) DO NOTHING;

-- Test 1: User A can see their own trip_evidence_link
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" TO '11111111-1111-1111-1111-111111111111';
SET LOCAL "request.jwt.claims" TO '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
    (SELECT count(*)::integer FROM public.trip_evidence_links WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    1,
    'User A can read their own trip_evidence_link'
);

-- Test 2: User B cannot see User A's trip_evidence_link by specific id
SET LOCAL "request.jwt.claim.sub" TO '22222222-2222-2222-2222-222222222222';
SET LOCAL "request.jwt.claims" TO '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT is(
    (SELECT count(*)::integer FROM public.trip_evidence_links WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    0,
    'User B cannot read User A trip_evidence_link (RLS isolation)'
);

-- Test 3: User B querying full trip_evidence_links table returns 0 rows
SELECT is(
    (SELECT count(*)::integer FROM public.trip_evidence_links),
    0,
    'User B querying full trip_evidence_links table returns 0 rows'
);

-- Test 4: User B cannot delete User A's trip_evidence_link
DELETE FROM public.trip_evidence_links WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer FROM public.trip_evidence_links WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    1,
    'User A link still exists after User B attempt to delete it'
);

-- Test 5: Anonymous user cannot read trip_evidence_links
SET LOCAL ROLE anon;
RESET "request.jwt.claim.sub";
RESET "request.jwt.claims";

SELECT is(
    (SELECT count(*)::integer FROM public.trip_evidence_links),
    0,
    'Anonymous user cannot read any trip_evidence_links'
);

RESET ROLE;

SELECT finish();
ROLLBACK;
