-- BURHAN DeAI backend test bootstrap — PART 2 (after schema.sql)
-- Mimics the Supabase default/documented grants that the RLS policies rely on.
-- The client may only READ own rows (server-only lifecycle is schema-enforced).

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT SELECT ON public.organizations              TO anon, authenticated;
GRANT SELECT ON public.branches                   TO anon, authenticated;
GRANT SELECT ON public.profiles                   TO authenticated;
GRANT SELECT ON public.entities                   TO anon, authenticated;
GRANT SELECT ON public.observatory_threats        TO anon, authenticated;
GRANT SELECT ON public.observatory_analysts       TO anon, authenticated;
GRANT SELECT ON public.ai_jobs                    TO authenticated;
GRANT SELECT ON public.ai_usage                   TO authenticated;
GRANT SELECT ON public.plans                      TO anon, authenticated;
GRANT SELECT ON public.subscriptions              TO authenticated;

-- Mimic Supabase client privileges for authenticated role on domain tables
GRANT ALL PRIVILEGES ON public.entities           TO authenticated;
GRANT ALL PRIVILEGES ON public.branches           TO authenticated;
GRANT ALL PRIVILEGES ON public.series             TO authenticated;
GRANT ALL PRIVILEGES ON public.profiles           TO authenticated;

-- Supabase default privileges grant ALL to client roles on public tables; RLS
-- is what gates rows. The observatory reporters path needs the INSERT grant
-- (its WITH CHECK policy `threats_insert_public` is what allows anonymous
-- reports). Scoped to this table so it cannot override the server-only
-- REVOKEs that 00010 applies to ai_jobs / ai_usage.
GRANT INSERT ON public.observatory_threats        TO anon, authenticated;

-- The service-role path needs full access (bypasses RLS in real Supabase).
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO service_role;