-- Supabase schema for Construindo Fibra
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

-- Function para calcular ranking de usuários por volume total
create or replace function get_user_ranking()
returns table (
  user_id uuid,
  email text,
  display_name text,
  total_volume numeric,
  total_workouts bigint
)
language sql
security definer
as $$
  with user_stats as (
    select
      w.user_id,
      sum(e.sets * 
          case 
            when e.reps ~ '^[0-9]+(\.[0-9]+)?$' then e.reps::numeric
            when e.reps ~ '^[0-9]+' then substring(e.reps from '^[0-9]+')::numeric
            else 1
          end * e.weight_kg) as total_volume,
      count(distinct w.id) as total_workouts
    from workouts w
    join exercises e on e.workout_id = w.id
    group by w.user_id
  )
  select
    us.user_id,
    coalesce(au.email, '') as email,
    p.full_name as display_name,
    coalesce(us.total_volume, 0) as total_volume,
    coalesce(us.total_workouts, 0) as total_workouts
  from user_stats us
  join auth.users au on au.id = us.user_id
  left join profiles p on p.id = us.user_id
  where us.total_volume > 0
  order by us.total_volume desc;
$$;

-- Permitir que usuários autenticados vejam o ranking
create policy "Anyone can view user ranking" on profiles
  for select
  using (true);
