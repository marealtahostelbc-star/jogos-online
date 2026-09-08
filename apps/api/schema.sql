-- Lions Games sandbox only. Never used for real money. PostgreSQL 17.
create schema if not exists lions_private;
revoke all on schema lions_private from public,anon,authenticated;
create table lions_private.settings(id boolean primary key default true check(id), real_money_mode boolean not null default false check(real_money_mode=false));
insert into lions_private.settings values(true,false);
create table lions_private.profiles(user_id uuid primary key references auth.users(id),paused boolean not null default false,blocked boolean not null default false,rate_at timestamptz not null default now(),rate_count integer not null default 0,created_at timestamptz not null default now());
create table lions_private.roles(user_id uuid primary key references auth.users(id),role text not null check(role in('admin','auditor')),created_at timestamptz not null default now());
create table lions_private.accounts(id uuid primary key default gen_random_uuid(),user_id uuid not null references lions_private.profiles(user_id),code text not null check(code in('available','reserved','clearing','gaming')),currency text not null default 'DEMO' check(currency='DEMO'),unique(user_id,code));
create table lions_private.journals(id uuid primary key default gen_random_uuid(),user_id uuid not null references lions_private.profiles(user_id),type text not null,text text not null,created_at timestamptz not null default now());
create index journals_user_time on lions_private.journals(user_id,created_at desc);
create table lions_private.lines(id bigint generated always as identity primary key,journal_id uuid not null references lions_private.journals(id),account_id uuid not null references lions_private.accounts(id),signed_amount bigint not null check(signed_amount<>0 and abs(signed_amount)<=1000000));
create index lines_journal on lions_private.lines(journal_id);
create index lines_account on lions_private.lines(account_id);
create table lions_private.audit(id bigint generated always as identity primary key,actor_id uuid references auth.users(id),action text not null,resource_id uuid,details jsonb not null default '{}',created_at timestamptz not null default now());
create index audit_actor_time on lions_private.audit(actor_id,created_at desc);
create table lions_private.requests(user_id uuid not null references lions_private.profiles(user_id),key uuid not null,payload jsonb not null,response jsonb not null,created_at timestamptz not null default now(),primary key(user_id,key));
create table lions_private.withdrawals(id uuid primary key default gen_random_uuid(),user_id uuid not null references lions_private.profiles(user_id),amount bigint not null check(amount between 1 and 10000),status text not null default 'PENDING' check(status in('PENDING','COMPLETED','REJECTED')),created_at timestamptz not null default now());
create index withdrawals_user on lions_private.withdrawals(user_id,created_at desc);
create table lions_private.bets(id uuid primary key default gen_random_uuid(),user_id uuid not null references lions_private.profiles(user_id),kind text not null check(kind in('arena','sports')),amount bigint not null check(amount between 1 and 10000),choice text not null,result text,payout bigint not null default 0,status text not null check(status in('PENDING','SETTLED','CANCELLED')),engine_version text not null default 'arena-sandbox-1',created_at timestamptz not null default now());
create index bets_user on lions_private.bets(user_id,created_at desc);
create function lions_private.immutable() returns trigger language plpgsql set search_path='' as $$begin raise exception 'IMMUTABLE_RECORD';end$$;
create trigger immutable_journals before update or delete on lions_private.journals for each row execute function lions_private.immutable();
create trigger immutable_lines before update or delete on lions_private.lines for each row execute function lions_private.immutable();
create trigger immutable_audit before update or delete on lions_private.audit for each row execute function lions_private.immutable();
create trigger immutable_requests before update or delete on lions_private.requests for each row execute function lions_private.immutable();
create trigger immutable_accounts before update or delete on lions_private.accounts for each row execute function lions_private.immutable();
create function lions_private.balanced() returns trigger language plpgsql security definer set search_path='' as $$declare jid uuid; total bigint; n int; bad int; begin if tg_table_name='journals' then jid:=new.id;else jid:=new.journal_id;end if;select coalesce(sum(signed_amount),0),count(*) into total,n from lions_private.lines where journal_id=jid; select count(*) into bad from lions_private.lines l join lions_private.accounts a on a.id=l.account_id join lions_private.journals j on j.id=l.journal_id where j.id=jid and a.user_id<>j.user_id;if total<>0 or n<2 or bad>0 then raise exception 'UNBALANCED_JOURNAL';end if;return null;end$$;
create constraint trigger balanced_journal after insert on lions_private.journals deferrable initially deferred for each row execute function lions_private.balanced();
create constraint trigger balanced_lines after insert on lions_private.lines deferrable initially deferred for each row execute function lions_private.balanced();
-- No direct table grants: all access through the two authenticated RPC wrappers.
do $$declare t text;begin foreach t in array array['settings','profiles','roles','accounts','journals','lines','audit','requests','withdrawals','bets'] loop execute format('alter table lions_private.%I enable row level security',t);end loop;end$$;
create function lions_private.require_user() returns uuid language plpgsql security definer set search_path='' as $$declare u uuid:=auth.uid(); sid uuid;begin
if u is null then raise exception 'LOGIN_REQUIRED';end if;
if not exists(select 1 from auth.users where id=u and email_confirmed_at is not null and deleted_at is null and (banned_until is null or banned_until<now())) then raise exception 'VERIFIED_USER_REQUIRED';end if;
sid:=(auth.jwt()->>'session_id')::uuid;
if sid is null or not exists(select 1 from auth.sessions where id=sid and user_id=u and (not_after is null or not_after>now())) then raise exception 'SESSION_EXPIRED';end if;
if not exists(select 1 from lions_private.settings where id and real_money_mode=false) then raise exception 'SANDBOX_DISABLED';end if;return u;end$$;
create function lions_private.post(p_user uuid,p_type text,p_text text,p_debit text,p_credit text,p_amount bigint) returns uuid language plpgsql set search_path='' as $$declare j uuid;begin if p_amount<=0 then raise exception 'INVALID_AMOUNT';end if;insert into lions_private.journals(user_id,type,text) values(p_user,p_type,p_text) returning id into j;insert into lions_private.lines(journal_id,account_id,signed_amount) select j,id,case when code=p_debit then p_amount else -p_amount end from lions_private.accounts where user_id=p_user and code in(p_debit,p_credit);return j;end$$;
create function lions_private.funds(p_user uuid,p_code text) returns bigint language sql stable set search_path='' as $$select coalesce(-sum(l.signed_amount),0)::bigint from lions_private.accounts a left join lions_private.lines l on l.account_id=a.id where a.user_id=p_user and a.code=p_code$$;
create function lions_private.ensure_profile(p_user uuid) returns void language plpgsql set search_path='' as $$declare inserted int;begin
insert into lions_private.profiles(user_id) values(p_user) on conflict do nothing;get diagnostics inserted=row_count;
perform 1 from lions_private.profiles where user_id=p_user for update;
if inserted=1 then insert into lions_private.accounts(user_id,code) select p_user,unnest(array['available','reserved','clearing','gaming']);perform lions_private.post(p_user,'OPENING','Créditos iniciais sandbox','clearing','available',1000);insert into lions_private.audit(actor_id,action,resource_id) values(p_user,'WALLET_CREATED',p_user);end if;
if exists(select 1 from lions_private.profiles where user_id=p_user and blocked) then raise exception 'ACCOUNT_BLOCKED';end if;end$$;
create function lions_private.state() returns jsonb language plpgsql security definer set search_path='' as $$declare u uuid:=lions_private.require_user(); r text; state_output jsonb;begin perform lions_private.ensure_profile(u);select role into r from lions_private.roles where user_id=u;
select jsonb_build_object('version',4,'mode','sandbox','realMoney',false,'userId',u,'role',coalesce(r,'player'),'paused',p.paused,'available',lions_private.funds(u,'available'),'reserved',lions_private.funds(u,'reserved'),'entries',coalesce((select jsonb_agg(x order by x.at desc) from (select j.id,j.type,j.text,j.created_at as at,coalesce(-sum(l.signed_amount) filter(where a.code in('available','reserved')),0) as amount from lions_private.journals j join lions_private.lines l on l.journal_id=j.id join lions_private.accounts a on a.id=l.account_id where j.user_id=u group by j.id order by j.created_at desc limit 200)x),'[]'::jsonb),'withdrawals',coalesce((select jsonb_agg(x) from (select id,amount,status,user_id,created_at from lions_private.withdrawals where user_id=u order by created_at desc limit 100)x),'[]'::jsonb),'tickets',coalesce((select jsonb_agg(x) from (select id,amount,status,choice as text from lions_private.bets where user_id=u and kind='sports' order by created_at desc limit 100)x),'[]'::jsonb),'bets',coalesce((select jsonb_agg(x) from (select id,amount,choice,result,payout,status from lions_private.bets where user_id=u and kind='arena' order by created_at desc limit 30)x),'[]'::jsonb)) into state_output from lions_private.profiles p where p.user_id=u;
if r in('admin','auditor') then state_output:=state_output||jsonb_build_object('admin',jsonb_build_object('users',(select count(*) from lions_private.profiles),'journalCount',(select count(*) from lions_private.journals),'pendingCount',(select count(*) from lions_private.withdrawals where status='PENDING'),'withdrawals',coalesce((select jsonb_agg(x) from (select * from lions_private.withdrawals order by created_at desc limit 100)x),'[]'::jsonb),'audit',coalesce((select jsonb_agg(x) from (select * from lions_private.audit order by created_at desc limit 100)x),'[]'::jsonb)));end if;return state_output;end$$;
create function lions_private.action(p_key uuid,p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$declare u uuid:=lions_private.require_user(); payload jsonb:=jsonb_build_object('action',p_action,'data',p_data); old lions_private.requests%rowtype; amt bigint; ref uuid; w lions_private.withdrawals%rowtype; b lions_private.bets%rowtype; response jsonb; result_symbol text; n int; v_choice text; r text; j uuid;begin
if p_key is null or p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>2048 then raise exception 'INVALID_REQUEST';end if;
perform lions_private.ensure_profile(u);
select * into old from lions_private.requests where user_id=u and key=p_key;if found then if old.payload<>payload then raise exception 'IDEMPOTENCY_CONFLICT';end if;return old.response;end if;
update lions_private.profiles set rate_count=case when rate_at<now()-interval '1 minute' then 1 else rate_count+1 end,rate_at=case when rate_at<now()-interval '1 minute' then now() else rate_at end where user_id=u returning rate_count into n;if n>60 then raise exception 'RATE_LIMIT';end if;
if p_action in('DEPOSIT','WITHDRAW','PLAY','TICKET') then if (p_data->>'amount') is null or (p_data->>'amount') !~ '^[0-9]{1,5}$' then raise exception 'INVALID_AMOUNT';end if;amt:=(p_data->>'amount')::bigint;if amt<1 or amt>10000 then raise exception 'INVALID_AMOUNT';end if;end if;
if p_action in('PLAY','TICKET') and exists(select 1 from lions_private.profiles where user_id=u and paused) then raise exception 'PLAY_PAUSED';end if;
if p_action in('WITHDRAW','PLAY','TICKET') and lions_private.funds(u,'available')<amt then raise exception 'INSUFFICIENT_FUNDS';end if;
case p_action
when 'DEPOSIT' then
if coalesce((select sum(l.signed_amount) from lions_private.journals j join lions_private.lines l on l.journal_id=j.id where j.user_id=u and j.type='DEPOSIT' and j.created_at>=date_trunc('day',now()) and l.signed_amount>0),0)+amt>50000 then raise exception 'DAILY_DEMO_LIMIT';end if;
j:=lions_private.post(u,'DEPOSIT','Depósito sandbox','clearing','available',amt);response:=jsonb_build_object('id',j,'type','DEPOSIT');
when 'WITHDRAW' then insert into lions_private.withdrawals(user_id,amount) values(u,amt) returning id into ref;perform lions_private.post(u,'RESERVE','Reserva de saque sandbox','available','reserved',amt);response:=jsonb_build_object('id',ref,'type','WITHDRAW','status','PENDING');
when 'APPROVE','REJECT' then
select role into r from lions_private.roles where user_id=u;if r is distinct from 'admin' then raise exception 'ADMIN_REQUIRED';end if;
ref:=(p_data->>'ref')::uuid;select * into w from lions_private.withdrawals where id=ref for update;if not found or w.status<>'PENDING' then raise exception 'ALREADY_PROCESSED';end if;
perform 1 from lions_private.profiles where user_id=w.user_id for update;
if p_action='APPROVE' then perform lions_private.post(w.user_id,'WITHDRAWAL','Saque sandbox concluído','reserved','clearing',w.amount);update lions_private.withdrawals set status='COMPLETED' where id=ref;else perform lions_private.post(w.user_id,'RELEASE','Reserva de saque liberada','reserved','available',w.amount);update lions_private.withdrawals set status='REJECTED' where id=ref;end if;response:=jsonb_build_object('id',ref,'type',p_action);
when 'PLAY' then
v_choice:=p_data->>'choice';if v_choice is null or v_choice not in('Coroa','Escudo','Estrela') then raise exception 'INVALID_CHOICE';end if;
-- Rejection sampling: 0..254, equal probabilities, result only on server.
loop n:=get_byte(extensions.gen_random_bytes(1),0);exit when n<255;end loop;result_symbol:=(array['Coroa','Escudo','Estrela'])[1+n%3];
insert into lions_private.bets(user_id,kind,amount,choice,result,payout,status) values(u,'arena',amt,v_choice,result_symbol,case when v_choice=result_symbol then amt*3 else 0 end,'SETTLED') returning id into ref;
perform lions_private.post(u,'BET','Arena · escolha '||v_choice||' · resultado '||result_symbol,'available','gaming',amt);if v_choice=result_symbol then perform lions_private.post(u,'PAYOUT','Prêmio sandbox da Arena','gaming','available',amt*3);end if;
response:=jsonb_build_object('id',ref,'type','PLAY','result',result_symbol,'payout',case when v_choice=result_symbol then amt*3 else 0 end,'engineVersion','arena-sandbox-1');
when 'TICKET' then
if coalesce(p_data->>'match','') not in('0','1','2') or coalesce(p_data->>'outcome','') not in('0','1','2') then raise exception 'INVALID_MATCH';end if;
v_choice:=(array['Aurora FC × Atlético do Vale','Estrela do Sul × União da Serra','Real Horizonte × Nacional da Costa'])[1+(p_data->>'match')::int]||' · '||(array['1','X','2'])[1+(p_data->>'outcome')::int];
insert into lions_private.bets(user_id,kind,amount,choice,status) values(u,'sports',amt,v_choice,'PENDING') returning id into ref;perform lions_private.post(u,'BET',v_choice,'available','gaming',amt);response:=jsonb_build_object('id',ref,'type','TICKET');
when 'CANCEL' then
ref:=(p_data->>'ref')::uuid;select * into b from lions_private.bets where id=ref and user_id=u and kind='sports' for update;if not found or b.status<>'PENDING' then raise exception 'ALREADY_PROCESSED';end if;perform lions_private.post(u,'REVERSAL','Bilhete sandbox cancelado','gaming','available',b.amount);update lions_private.bets set status='CANCELLED' where id=ref;response:=jsonb_build_object('id',ref,'type','CANCEL');
when 'PAUSE' then
if jsonb_typeof(p_data->'paused') is distinct from 'boolean' then raise exception 'INVALID_REQUEST';end if;update lions_private.profiles set paused=(p_data->>'paused')::boolean where user_id=u;response:=jsonb_build_object('id',u,'type','PAUSE','paused',(p_data->>'paused')::boolean);
else raise exception 'UNKNOWN_ACTION';end case;
insert into lions_private.audit(actor_id,action,resource_id,details) values(u,p_action,(response->>'id')::uuid,response||jsonb_build_object('requestKey',p_key));
insert into lions_private.requests(user_id,key,payload,response) values(u,p_key,payload,response);
return response;end$$;
create function public.lions_state() returns jsonb language sql security invoker set search_path='' as $$select lions_private.state()$$;
create function public.lions_action(p_key uuid,p_action text,p_data jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select lions_private.action(p_key,p_action,p_data)$$;
revoke all on all tables in schema lions_private from public,anon,authenticated;
revoke all on all sequences in schema lions_private from public,anon,authenticated;
revoke all on all functions in schema lions_private from public,anon,authenticated;
revoke all on function public.lions_state() from public,anon;
revoke all on function public.lions_action(uuid,text,jsonb) from public,anon;
grant usage on schema lions_private to authenticated;
grant execute on function lions_private.state(),lions_private.action(uuid,text,jsonb) to authenticated;
grant execute on function public.lions_state(),public.lions_action(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
