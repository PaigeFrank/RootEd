-- Run this in Supabase SQL Editor
-- Dashboard → SQL Editor → New query → paste → Run

-- TABLES
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  first_name text,
  last_name text,
  student_type text check (student_type in ('hs', 'college')),
  grade text,
  hs_school text,
  college text,
  major text,
  year text,
  interests text[] default '{}',
  seeking text[] default '{}',
  bio text,
  zip text,
  linkedin text,
  avatar_url text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create table if not exists public.saved_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  item_id integer not null,
  item_type text not null,
  title text,
  created_at timestamp with time zone default now(),
  unique(user_id, item_id)
);

create table if not exists public.connections (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  mentor_id integer not null,
  mentor_name text,
  connected_at timestamp with time zone default now(),
  unique(user_id, mentor_id)
);

create table if not exists public.resume_roasts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  file_name text,
  mentor_id integer,
  mentor_name text,
  status text default 'pending',
  submitted_at timestamp with time zone default now()
);

-- ENABLE RLS
alter table public.profiles enable row level security;
alter table public.saved_items enable row level security;
alter table public.connections enable row level security;
alter table public.resume_roasts enable row level security;

-- DROP OLD POLICIES FIRST (safe if they don't exist)
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can manage own saved items" on public.saved_items;
drop policy if exists "Users can manage own connections" on public.connections;
drop policy if exists "Users can manage own roasts" on public.resume_roasts;

-- CREATE POLICIES
create policy "Users can view own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can manage own saved items" on public.saved_items for all using (auth.uid() = user_id);
create policy "Users can manage own connections" on public.connections for all using (auth.uid() = user_id);
create policy "Users can manage own roasts" on public.resume_roasts for all using (auth.uid() = user_id);

-- AUTO CREATE PROFILE ON SIGNUP
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, first_name, last_name)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'first_name',
    new.raw_user_meta_data->>'last_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
