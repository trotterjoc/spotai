-- ════════════════════════════════════════════════════════════
-- SPOT — Supabase schema for user profiles
-- Run this in the Supabase SQL Editor (Project → SQL Editor → New query)
-- ════════════════════════════════════════════════════════════

-- 1. PROFILES TABLE
-- Extends Supabase's built-in auth.users with public profile data.
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  display_name text not null,
  bio text,
  avatar_emoji text default '🙂',
  created_at timestamp with time zone default now()
);

-- 2. FRIENDS TABLE
-- Simple bidirectional friendship. We store one row per accepted friendship
-- with the lower user id first, to avoid duplicate reversed rows.
create table public.friends (
  id uuid default gen_random_uuid() primary key,
  user_id_1 uuid references public.profiles(id) on delete cascade not null,
  user_id_2 uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamp with time zone default now(),
  unique(user_id_1, user_id_2)
);

-- 3. FAVORITE SPOTS TABLE
-- Links a user to spots they've favorited. Spot data itself (name, coords, etc)
-- lives in your frontend SPOTS array for now — this just stores the relationship.
create table public.favorite_spots (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  spot_id integer not null,
  spot_name text not null,
  created_at timestamp with time zone default now(),
  unique(user_id, spot_id)
);

-- 4. POSTS TABLE ("I'll be here" posts)
-- Already designed for this from the original plan — included here so
-- profiles can show "post history."
create table public.posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  spot_id integer not null,
  spot_name text not null,
  note text,
  time_window text not null,
  visibility text default 'friends' check (visibility in ('friends', 'close_friends')),
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone default now()
);

-- ════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS) — users only see/edit what they should
-- ════════════════════════════════════════════════════════════

alter table public.profiles enable row level security;
alter table public.friends enable row level security;
alter table public.favorite_spots enable row level security;
alter table public.posts enable row level security;

-- PROFILES: anyone logged in can view any profile (needed to see friends'
-- profiles), but you can only edit your own.
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- FRIENDS: you can see friendships you're part of, and create friend requests
-- where you're one of the two people.
create policy "Users can view their own friendships"
  on public.friends for select
  using (auth.uid() = user_id_1 or auth.uid() = user_id_2);

create policy "Users can create friend requests"
  on public.friends for insert
  with check (auth.uid() = user_id_1 or auth.uid() = user_id_2);

create policy "Users can update friendships they're part of"
  on public.friends for update
  using (auth.uid() = user_id_1 or auth.uid() = user_id_2);

-- FAVORITE SPOTS: you manage your own favorites, but friends can view them
-- (this policy is permissive for simplicity in v1 — tighten later if needed)
create policy "Favorites are viewable by authenticated users"
  on public.favorite_spots for select
  using (auth.role() = 'authenticated');

create policy "Users can manage their own favorites"
  on public.favorite_spots for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own favorites"
  on public.favorite_spots for delete
  using (auth.uid() = user_id);

-- POSTS: visible to authenticated users (frontend filters by friends list
-- and visibility setting); only the author can create/delete their post.
create policy "Posts are viewable by authenticated users"
  on public.posts for select
  using (auth.role() = 'authenticated');

create policy "Users can create their own posts"
  on public.posts for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own posts"
  on public.posts for delete
  using (auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════
-- AUTO-CREATE PROFILE ON SIGNUP
-- When someone signs up via Supabase Auth, automatically create a
-- matching row in public.profiles with a default username/display name.
-- ════════════════════════════════════════════════════════════

create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'display_name', 'New User')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
