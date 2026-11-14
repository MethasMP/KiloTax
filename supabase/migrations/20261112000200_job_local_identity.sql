-- Match the trip/expense transport contract for pre-existing local text job IDs.
ALTER TABLE public.job_sites ADD COLUMN IF NOT EXISTS local_id text;
CREATE INDEX IF NOT EXISTS idx_job_sites_local_identity ON public.job_sites(user_id, local_id);
NOTIFY pgrst, 'reload schema';
