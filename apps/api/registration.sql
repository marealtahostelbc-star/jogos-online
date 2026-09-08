create table lions_private.registration_limits(bucket text primary key,window_at timestamptz not null,count integer not null);
alter table lions_private.registration_limits enable row level security;
create function public.lions_registration_gate(p_bucket text) returns boolean language plpgsql security definer set search_path='' as $$declare n int;begin
if auth.role()<>'service_role' then raise exception 'SERVICE_ONLY';end if;
if length(p_bucket)<>64 then raise exception 'INVALID_BUCKET';end if;
perform pg_advisory_xact_lock(991001);
if (select count(*) from auth.users)>1000 then return false;end if;
insert into lions_private.registration_limits values(p_bucket,now(),1) on conflict(bucket) do update set count=case when lions_private.registration_limits.window_at<now()-interval '1 hour' then 1 else lions_private.registration_limits.count+1 end,window_at=case when lions_private.registration_limits.window_at<now()-interval '1 hour' then now() else lions_private.registration_limits.window_at end returning count into n;
return n<=5;end$$;
revoke all on function public.lions_registration_gate(text) from public,anon,authenticated;
grant execute on function public.lions_registration_gate(text) to service_role;
-- Explicit default-deny policies document intentional RPC-only access.
do $$declare r record;begin for r in select tablename from pg_tables where schemaname='lions_private' loop execute format('create policy deny_direct_access on lions_private.%I for all to anon,authenticated using(false) with check(false)',r.tablename);end loop;end$$;
