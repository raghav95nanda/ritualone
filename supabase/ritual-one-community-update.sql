-- Ritual One community upgrade. Run AFTER ritual-one-setup.sql.
-- Additive and safe to rerun; existing check-ins and reflections are preserved.
begin;
create table if not exists public.ritual_posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.ritual_profiles(id) on delete cascade,
 category text not null check(category in ('reading','meditation','exercise')),
 subject text not null check(char_length(trim(subject)) between 1 and 160),
 book_author text not null default '' check(char_length(book_author)<=120),
 achievement text not null default '' check(char_length(achievement)<=120),
 body text not null default '' check(char_length(body)<=2000),
 author_name text not null check(char_length(author_name) between 1 and 60),
 created_at timestamptz not null default now()
);
create index if not exists ritual_posts_feed_idx on public.ritual_posts(created_at desc,id desc);
create index if not exists ritual_posts_category_feed_idx on public.ritual_posts(category,created_at desc,id desc);
create index if not exists ritual_posts_user_idx on public.ritual_posts(user_id);
create table if not exists public.ritual_post_cheers (
 post_id uuid not null references public.ritual_posts(id) on delete cascade,
 user_id uuid not null references public.ritual_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create index if not exists ritual_cheers_user_idx on public.ritual_post_cheers(user_id);
-- Feed stores only deliberately published content. It never reads ritual_entries.
-- Author and timestamp are assigned by the database; clients cannot impersonate another member.
create or replace function ritual_private.ritual_prepare_post() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.user_id is distinct from (select auth.uid()) then raise exception 'You can only publish your own updates'; end if;
 select p.display_name into new.author_name from public.ritual_profiles p where p.id=new.user_id;
 if new.author_name is null then raise exception 'A member profile is required'; end if;
 new.created_at:=now();
 new.subject:=trim(new.subject);
 if new.category<>'reading' then new.book_author:=''; end if;
 return new;
end; $$;
revoke all on function ritual_private.ritual_prepare_post() from public,anon,authenticated;
drop trigger if exists ritual_post_prepare on public.ritual_posts;
create trigger ritual_post_prepare before insert on public.ritual_posts for each row execute function ritual_private.ritual_prepare_post();
alter table public.ritual_posts enable row level security;
alter table public.ritual_post_cheers enable row level security;
drop policy if exists ritual_posts_public_read on public.ritual_posts;
create policy ritual_posts_public_read on public.ritual_posts for select to anon,authenticated using(true);
drop policy if exists ritual_posts_own_insert on public.ritual_posts;
create policy ritual_posts_own_insert on public.ritual_posts for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists ritual_posts_own_delete on public.ritual_posts;
create policy ritual_posts_own_delete on public.ritual_posts for delete to authenticated using(user_id=(select auth.uid()));
drop policy if exists ritual_cheers_public_read on public.ritual_post_cheers;
create policy ritual_cheers_public_read on public.ritual_post_cheers for select to anon,authenticated using(true);
drop policy if exists ritual_cheers_own_insert on public.ritual_post_cheers;
create policy ritual_cheers_own_insert on public.ritual_post_cheers for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists ritual_cheers_own_delete on public.ritual_post_cheers;
create policy ritual_cheers_own_delete on public.ritual_post_cheers for delete to authenticated using(user_id=(select auth.uid()));
revoke all on public.ritual_posts,public.ritual_post_cheers from public,anon,authenticated;
grant select on public.ritual_posts to anon,authenticated;
grant insert(user_id,category,subject,book_author,achievement,body),delete on public.ritual_posts to authenticated;
grant select(post_id,user_id) on public.ritual_post_cheers to anon,authenticated;
grant insert(post_id,user_id),delete on public.ritual_post_cheers to authenticated;
create or replace function public.ritual_community_feed(p_category text default null,p_limit integer default 20,p_before timestamptz default null,p_before_id uuid default null)
returns table(id uuid,user_id uuid,category text,subject text,book_author text,achievement text,body text,author_name text,created_at timestamptz,cheers bigint,cheered boolean)
language sql stable security invoker set search_path='' as $$
 with page as (
  select p.* from public.ritual_posts p
  where (p_category is null or p.category=p_category)
   and (p_category is null or p_category in ('reading','meditation','exercise'))
   and (p_before is null or (p.created_at,p.id)<(p_before,p_before_id))
  order by p.created_at desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),50)
 )
 select p.id,p.user_id,p.category,p.subject,p.book_author,p.achievement,p.body,p.author_name,p.created_at,
  (select count(*) from public.ritual_post_cheers c where c.post_id=p.id),
  exists(select 1 from public.ritual_post_cheers c where c.post_id=p.id and c.user_id=(select auth.uid()))
 from page p order by p.created_at desc,p.id desc;
$$;
revoke all on function public.ritual_community_feed(text,integer,timestamptz,uuid) from public;
grant execute on function public.ritual_community_feed(text,integer,timestamptz,uuid) to anon,authenticated;
-- All members share Monday 00:00 IST boundaries. No scheduled job is required.
-- Only this week (0) and last week (-1) may be queried. Ranking resets automatically.
create index if not exists ritual_entries_week_idx on public.ritual_entries(category,completed_on,user_id);
create or replace function ritual_private.ritual_weekly_leaderboard(p_category text,p_week_offset integer default 0)
returns table(user_id uuid,display_name text,longest_streak bigint,current_streak bigint,total_days bigint,week_start date)
language sql stable security definer set search_path='' as $$
 with bounds as (
  select (date_trunc('week',now() at time zone 'Asia/Kolkata')::date + coalesce(p_week_offset,0)*7) as start_day,
   (now() at time zone 'Asia/Kolkata')::date as today
  where p_week_offset in (0,-1) and p_category in ('reading','meditation','exercise')
 ), numbered as (
  select e.user_id,e.completed_on,e.created_at,
   e.completed_on-(row_number() over(partition by e.user_id order by e.completed_on))::integer as island
  from public.ritual_entries e cross join bounds b
  where e.category=p_category and e.completed_on>=b.start_day and e.completed_on<b.start_day+7 and e.completed_on<=b.today
 ), runs as (
  select n.user_id,count(*) as days,max(n.completed_on) as last_day,min(n.created_at) as first_checkin from numbered n group by n.user_id,n.island
 ), stats as (
  select r.user_id,max(r.days) as best,sum(r.days)::bigint as total,min(r.first_checkin) as first_checkin,
   coalesce(max(r.days) filter(where r.last_day>=least(b.today,b.start_day+6)-1),0) as current
  from runs r cross join bounds b group by r.user_id
 )
 select p.id,p.display_name,s.best,s.current,s.total,b.start_day
 from stats s join public.ritual_profiles p on p.id=s.user_id
 join public.ritual_habits h on h.user_id=p.id and h.category=p_category cross join bounds b
 where p.leaderboard_opt_in
 order by s.best desc,s.total desc,s.first_checkin asc,p.id asc limit 100;
$$;
revoke all on function ritual_private.ritual_weekly_leaderboard(text,integer) from public;
grant execute on function ritual_private.ritual_weekly_leaderboard(text,integer) to anon,authenticated;
create or replace function public.ritual_weekly_leaderboard(p_category text,p_week_offset integer default 0)
returns table(user_id uuid,display_name text,longest_streak bigint,current_streak bigint,total_days bigint,week_start date)
language sql stable security invoker set search_path='' as $$
 select * from ritual_private.ritual_weekly_leaderboard(p_category,p_week_offset);
$$;
revoke all on function public.ritual_weekly_leaderboard(text,integer) from public;
grant execute on function public.ritual_weekly_leaderboard(text,integer) to anon,authenticated;
notify pgrst,'reload schema';
commit;
