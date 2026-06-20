create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.learning_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('question','bite','session')),
  item_id text not null,
  system text,
  yield_level text check (yield_level is null or yield_level in ('HIGH','MEDIUM')),
  correct boolean,
  confidence text,
  points integer not null default 0,
  response_ms integer,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists learning_events_user_created_idx on public.learning_events(user_id,created_at desc);
alter table public.profiles enable row level security;
alter table public.learning_events enable row level security;
create policy "profiles_select_own" on public.profiles for select using (auth.uid()=id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid()=id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid()=id) with check (auth.uid()=id);
create policy "events_select_own" on public.learning_events for select using (auth.uid()=user_id);
create policy "events_insert_own" on public.learning_events for insert with check (auth.uid()=user_id);
create policy "events_update_own" on public.learning_events for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "events_delete_own" on public.learning_events for delete using (auth.uid()=user_id);
