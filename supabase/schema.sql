-- Supabase schema for Workout Logger MVP
create extension if not exists "uuid-ossp";

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

create table if not exists workouts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  date date not null,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

create index if not exists workouts_user_date_idx on workouts(user_id, date);

create table if not exists exercises (
  id uuid primary key default uuid_generate_v4(),
  workout_id uuid references workouts(id) on delete cascade,
  name text not null,
  muscle_group text not null,
  sets integer not null,
  reps text not null,
  weight_kg numeric(10,2) not null,
  rest_seconds integer not null,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

alter table workouts enable row level security;
alter table exercises enable row level security;

create policy "Users can manage own workouts" on workouts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage exercises of own workouts" on exercises
  for all
  using (
    exists (
      select 1 from workouts w
      where w.id = exercises.workout_id
        and w.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from workouts w
      where w.id = exercises.workout_id
        and w.user_id = auth.uid()
    )
  );
