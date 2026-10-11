-- Ritual One: run once in this project's Supabase SQL Editor.
-- Additive migration; it only manages tables prefixed ritual_.
begin;
create schema if not exists ritual_private;
revoke all on schema ritual_private from public;
grant usage on schema ritual_private to anon,authenticated;
create table if not exists public.ritual_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 60),
 timezone text not null default 'Asia/Kolkata',
 leaderboard_opt_in boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.ritual_habits (
 user_id uuid not null references public.ritual_profiles(id) on delete cascade,
 category text not null check(category in ('reading','meditation','exercise')),
 created_at timestamptz not null default now(),
 primary key(user_id,category)
);
create table if not exists public.ritual_entries (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.ritual_profiles(id) on delete cascade,
 category text not null check(category in ('reading','meditation','exercise')),
 completed_on date not null,
 minutes integer check(minutes between 1 and 1440),
 pages integer check(pages between 1 and 10000),
 reflection text not null default '' check(char_length(reflection)<=2000),
 created_at timestamptz not null default now(),
 unique(user_id,category,completed_on),
 check((category='reading' and ((minutes is not null and pages is null) or (pages is not null and minutes is null))) or (category='meditation' and minutes is not null and minutes=10 and pages is null) or (category='exercise' and minutes is null and pages is null))
);
create index if not exists ritual_entries_streak_idx on public.ritual_entries(user_id,category,completed_on);

-- Create a private profile when a user signs up.
create or replace function ritual_private.ritual_handle_signup() returns trigger language plpgsql security definer set search_path='' as $$
declare zone text;
begin
 zone:=coalesce(new.raw_user_meta_data->>'timezone','Asia/Kolkata');
 if not exists(select 1 from pg_timezone_names where name=zone) then zone:='Asia/Kolkata'; end if;
 insert into public.ritual_profiles(id,display_name,timezone)
 values(new.id,left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Ritual member'),60),zone)
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists ritual_on_auth_signup on auth.users;
create trigger ritual_on_auth_signup after insert on auth.users for each row execute function ritual_private.ritual_handle_signup();
revoke execute on function ritual_private.ritual_handle_signup() from public,anon,authenticated;

-- All completions are dated by the database in the member's time zone.
create or replace function ritual_private.ritual_validate_entry() returns trigger language plpgsql set search_path='' as $$
declare zone text;
begin
 if TG_OP='UPDATE' then
  if new.user_id<>old.user_id or new.category<>old.category or new.completed_on<>old.completed_on or new.created_at<>old.created_at then
   raise exception 'Completion identity and date cannot be changed';
  end if;
 else
  select timezone into zone from public.ritual_profiles where id=new.user_id;
  new.completed_on:=(now() at time zone coalesce(zone,'Asia/Kolkata'))::date;
  new.created_at:=now();
 end if;
 return new;
end; $$;
drop trigger if exists ritual_entry_date on public.ritual_entries;
create trigger ritual_entry_date before insert or update on public.ritual_entries for each row execute function ritual_private.ritual_validate_entry();
revoke execute on function ritual_private.ritual_validate_entry() from public,anon,authenticated;

alter table public.ritual_profiles enable row level security;
alter table public.ritual_habits enable row level security;
alter table public.ritual_entries enable row level security;
drop policy if exists ritual_profile_own on public.ritual_profiles;
create policy ritual_profile_own on public.ritual_profiles for all to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()) and exists(select 1 from pg_timezone_names where name=timezone));
drop policy if exists ritual_habits_own on public.ritual_habits;
create policy ritual_habits_own on public.ritual_habits for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists ritual_entries_own on public.ritual_entries;
create policy ritual_entries_own on public.ritual_entries for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
grant select,insert,update,delete on public.ritual_profiles,public.ritual_habits,public.ritual_entries to authenticated;
revoke all on public.ritual_profiles,public.ritual_habits,public.ritual_entries from anon;

-- Only public display names and aggregate streaks leave the private tables.
-- Emails, page counts and reflections never appear in the leaderboard.
create or replace function ritual_private.ritual_leaderboard(p_category text)
returns table(user_id uuid,display_name text,longest_streak bigint,current_streak bigint,total_days bigint)
language sql stable security definer set search_path='' as $$
 with numbered as (
  select e.user_id,e.completed_on,
   e.completed_on-(row_number() over(partition by e.user_id order by e.completed_on))::integer as island
  from public.ritual_entries e
  where e.category=p_category and p_category in ('reading','meditation','exercise')
 ), runs as (
  select n.user_id,count(*) as days,max(n.completed_on) as last_day from numbered n group by n.user_id,n.island
 ), stats as (
  select r.user_id,max(r.days) as best,sum(r.days) as total,
   coalesce(max(r.days) filter(where r.last_day>=(now() at time zone p.timezone)::date-1),0) as current
  from runs r join public.ritual_profiles p on p.id=r.user_id group by r.user_id
 )
 select p.id,p.display_name,coalesce(s.best,0),coalesce(s.current,0),coalesce(s.total,0)::bigint
 from public.ritual_profiles p
 join public.ritual_habits h on h.user_id=p.id and h.category=p_category
 left join stats s on s.user_id=p.id
 where p.leaderboard_opt_in and p_category in ('reading','meditation','exercise')
 order by coalesce(s.best,0) desc,coalesce(s.current,0) desc,coalesce(s.total,0) desc,p.created_at asc,p.id asc
 limit 100;
$$;
revoke all on function ritual_private.ritual_leaderboard(text) from public;
grant execute on function ritual_private.ritual_leaderboard(text) to anon,authenticated;
-- Public API wrapper is unprivileged; the private helper returns only opted-in aggregates.
create or replace function public.ritual_leaderboard(p_category text)
returns table(user_id uuid,display_name text,longest_streak bigint,current_streak bigint,total_days bigint)
language sql stable security invoker set search_path='' as $$
 select * from ritual_private.ritual_leaderboard(p_category);
$$;
revoke all on function public.ritual_leaderboard(text) from public;
grant execute on function public.ritual_leaderboard(text) to anon,authenticated;
notify pgrst,'reload schema';
commit;
