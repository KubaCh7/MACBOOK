-- macbook progress — schemat początkowy
-- Tabele: profiles, goals, deposits, macbook_catalog, app_config
-- RLS na wszystkim, miękkie usuwanie (deleted_at), trigger updated_at,
-- Storage na zdjęcia (<user_id>/<goal_id>.jpg), Realtime, RPC.

-- ───────────────────────── pomocnicze ─────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ───────────────────────── katalog modeli ─────────────────────────
create table public.macbook_catalog (
  id            text primary key,                 -- np. 'air13-m5-16-512'
  family        text not null check (family in ('neo', 'air', 'pro')),
  name          text not null,                    -- 'MacBook Air 13" M5'
  chip          text not null,
  screen_inches numeric(3,1) not null,
  cpu_cores     int,
  gpu_cores     int,
  memory_gb     int not null,
  storage_gb    int not null,
  price_pln     numeric(10,2) not null check (price_pln > 0),
  popularity    int not null default 0,           -- im wyżej, tym wyżej na liście
  is_active     boolean not null default true,
  updated_at    timestamptz not null default now()
);
create trigger macbook_catalog_updated_at before update on public.macbook_catalog
  for each row execute function public.set_updated_at();

alter table public.macbook_catalog enable row level security;
create policy "catalog readable by everyone" on public.macbook_catalog
  for select to anon, authenticated using (true);

-- ───────────────────────── konfiguracja aplikacji ─────────────────────────
create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
create trigger app_config_updated_at before update on public.app_config
  for each row execute function public.set_updated_at();

alter table public.app_config enable row level security;
create policy "config readable by everyone" on public.app_config
  for select to anon, authenticated using (true);

-- ───────────────────────── profile ─────────────────────────
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 60),
  onboarded    boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
create policy "own profile select" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "own profile insert" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "own profile update" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- profil zakładany automatycznie przy rejestracji (imię z metadanych)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 60))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ───────────────────────── cele ─────────────────────────
create table public.goals (
  id             uuid primary key default gen_random_uuid(),   -- klient może podać własne (offline)
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name           text not null check (char_length(name) between 1 and 120),
  target_amount  numeric(12,2) not null check (target_amount > 0),
  photo_url      text,             -- ścieżka w Storage (<user_id>/<goal_id>.jpg) albo pełny link https://
  photo_position text not null default '50% 50%'
                 check (photo_position ~ '^(100|[0-9]{1,2})(\.[0-9]+)?% (100|[0-9]{1,2})(\.[0-9]+)?%$'),
  catalog_id     text references public.macbook_catalog (id) on delete set null,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);
create index goals_user_idx on public.goals (user_id) where deleted_at is null;
create unique index goals_one_default_per_user on public.goals (user_id)
  where is_default and deleted_at is null;
create index goals_catalog_idx on public.goals (catalog_id);
create trigger goals_updated_at before update on public.goals
  for each row execute function public.set_updated_at();

alter table public.goals enable row level security;
create policy "own goals select" on public.goals
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "own goals insert" on public.goals
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own goals update" on public.goals
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- brak DELETE: usuwanie jest miękkie (deleted_at); twarde tylko przez delete_account()

-- ───────────────────────── wpłaty / wypłaty ─────────────────────────
create table public.deposits (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  goal_id      uuid not null references public.goals (id) on delete cascade,
  amount       numeric(12,2) not null check (amount <> 0),   -- ujemna = wypłata
  deposit_date date not null default current_date,
  note         text check (char_length(note) <= 200),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index deposits_goal_idx on public.deposits (goal_id, deposit_date) where deleted_at is null;
create index deposits_user_idx on public.deposits (user_id);
create trigger deposits_updated_at before update on public.deposits
  for each row execute function public.set_updated_at();

alter table public.deposits enable row level security;
create policy "own deposits select" on public.deposits
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "own deposits insert" on public.deposits
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.goals g where g.id = goal_id and g.user_id = (select auth.uid()))
  );
create policy "own deposits update" on public.deposits
  for update to authenticated using ((select auth.uid()) = user_id) with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.goals g where g.id = goal_id and g.user_id = (select auth.uid()))
  );

-- wypłata nie może przekroczyć uzbieranej kwoty (sprawdzane na koniec transakcji)
create or replace function public.check_goal_balance()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  bal numeric;
begin
  select coalesce(sum(amount), 0) into bal
  from public.deposits
  where goal_id = new.goal_id and deleted_at is null;
  if bal < 0 then
    raise exception 'withdrawal_exceeds_balance' using errcode = '23514';
  end if;
  return null;
end;
$$;
create constraint trigger deposits_balance_check
  after insert or update on public.deposits
  deferrable initially deferred
  for each row execute function public.check_goal_balance();

-- ───────────────────────── RPC ─────────────────────────
create or replace function public.set_default_goal(p_goal_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.goals
    where id = p_goal_id and user_id = (select auth.uid()) and deleted_at is null
  ) then
    raise exception 'goal_not_found';
  end if;
  update public.goals set is_default = false
    where user_id = (select auth.uid()) and is_default and id <> p_goal_id;
  update public.goals set is_default = true
    where id = p_goal_id and user_id = (select auth.uid());
end;
$$;
revoke execute on function public.set_default_goal(uuid) from public, anon;
grant execute on function public.set_default_goal(uuid) to authenticated;

-- usuwa konto i wszystkie dane (kaskada); zdjęcia klient usuwa wcześniej przez Storage API
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;
  delete from public.deposits where user_id = uid;
  delete from public.goals where user_id = uid;
  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;
revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

-- ───────────────────────── Storage ─────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('goal-photos', 'goal-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

create policy "own photos select" on storage.objects
  for select to authenticated
  using (bucket_id = 'goal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own photos insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'goal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own photos update" on storage.objects
  for update to authenticated
  using (bucket_id = 'goal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own photos delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'goal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ───────────────────────── Realtime ─────────────────────────
alter publication supabase_realtime add table public.goals, public.deposits, public.profiles,
  public.macbook_catalog, public.app_config;
