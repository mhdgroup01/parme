-- Paruay Web Push — subscription store (run once in Supabase SQL editor)
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  shop_id text not null default '',
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz default now()
);

create index if not exists push_subscriptions_shop_idx on public.push_subscriptions (shop_id);

alter table public.push_subscriptions enable row level security;

-- Each user manages only their own device subscriptions.
-- (The Edge Function reads rows with the service-role key, bypassing RLS.)
drop policy if exists "ps own select" on public.push_subscriptions;
drop policy if exists "ps own insert" on public.push_subscriptions;
drop policy if exists "ps own update" on public.push_subscriptions;
drop policy if exists "ps own delete" on public.push_subscriptions;

create policy "ps own select" on public.push_subscriptions
  for select using (auth.uid() = user_id);
create policy "ps own insert" on public.push_subscriptions
  for insert with check (auth.uid() = user_id);
create policy "ps own update" on public.push_subscriptions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "ps own delete" on public.push_subscriptions
  for delete using (auth.uid() = user_id);
