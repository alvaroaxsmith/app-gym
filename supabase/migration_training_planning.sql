-- Tabela de Mesociclos / Planos de Treino
create table if not exists training_plans (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  name text not null,
  description text,
  goal text check (goal in ('hypertrophy', 'strength', 'maintenance', 'other')),
  start_date date not null,
  duration_weeks int not null default 4,
  created_at timestamptz default now()
);

-- Tabela de Semanas do Plano
create table if not exists training_plan_weeks (
  id uuid default gen_random_uuid() primary key,
  plan_id uuid references training_plans(id) on delete cascade not null,
  week_number int not null,
  label text, -- Ex: "Semana 1 - MEV", "Semana 4 - Deload"
  target_rpe_min numeric,
  target_rpe_max numeric,
  is_deload boolean default false,
  notes text,
  created_at timestamptz default now()
);

-- Tabela de Treinos Planejados na Semana (Rotinas)
create table if not exists training_plan_workouts (
  id uuid default gen_random_uuid() primary key,
  week_id uuid references training_plan_weeks(id) on delete cascade not null,
  name text not null, -- Ex: "Treino A - Inferior"
  description text,
  day_index int, -- 0=Monday, ...
  created_at timestamptz default now()
);

-- Itens (Exercícios) dentro de um Treino Planejado
create table if not exists training_plan_workout_items (
  id uuid default gen_random_uuid() primary key,
  workout_id uuid references training_plan_workouts(id) on delete cascade not null,
  exercise_id uuid references exercise_library(id) not null,
  sets int default 3,
  reps text, -- "8-12", "AMRAP"
  rpe text, -- "8", "7-8"
  rest_seconds int,
  notes text,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- RLS policies
alter table training_plans enable row level security;
alter table training_plan_weeks enable row level security;
alter table training_plan_workouts enable row level security;
alter table training_plan_workout_items enable row level security;

-- Training Plans Policies
drop policy if exists "Users can view own plans" on training_plans;
create policy "Users can view own plans" on training_plans
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own plans" on training_plans;
create policy "Users can insert own plans" on training_plans
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own plans" on training_plans;
create policy "Users can update own plans" on training_plans
  for update using (auth.uid() = user_id);

drop policy if exists "Users can delete own plans" on training_plans;
create policy "Users can delete own plans" on training_plans
  for delete using (auth.uid() = user_id);

-- Training Plan Weeks Policies
drop policy if exists "Users can view own weeks" on training_plan_weeks;
create policy "Users can view own weeks" on training_plan_weeks
  for select using (
    exists (select 1 from training_plans p where p.id = training_plan_weeks.plan_id and p.user_id = auth.uid())
  );

drop policy if exists "Users can insert own weeks" on training_plan_weeks;
create policy "Users can insert own weeks" on training_plan_weeks
  for insert with check (
    exists (select 1 from training_plans p where p.id = training_plan_weeks.plan_id and p.user_id = auth.uid())
  );

drop policy if exists "Users can update own weeks" on training_plan_weeks;
create policy "Users can update own weeks" on training_plan_weeks
  for update using (
    exists (select 1 from training_plans p where p.id = training_plan_weeks.plan_id and p.user_id = auth.uid())
  );

drop policy if exists "Users can delete own weeks" on training_plan_weeks;
create policy "Users can delete own weeks" on training_plan_weeks
  for delete using (
    exists (select 1 from training_plans p where p.id = training_plan_weeks.plan_id and p.user_id = auth.uid())
  );

-- Training Plan Workouts Policies
drop policy if exists "Users can view own plan workouts" on training_plan_workouts;
create policy "Users can view own plan workouts" on training_plan_workouts
  for select using (
    exists (
       select 1 from training_plan_weeks w
       join training_plans p on p.id = w.plan_id
       where w.id = training_plan_workouts.week_id and p.user_id = auth.uid()
    )
  );

drop policy if exists "Users can modify own plan workouts" on training_plan_workouts;
create policy "Users can modify own plan workouts" on training_plan_workouts
  for all using (
    exists (
       select 1 from training_plan_weeks w
       join training_plans p on p.id = w.plan_id
       where w.id = training_plan_workouts.week_id and p.user_id = auth.uid()
    )
  );

-- Training Plan Workout Items Policies
drop policy if exists "Users can view own plan items" on training_plan_workout_items;
create policy "Users can view own plan items" on training_plan_workout_items
  for select using (
    exists (
       select 1 from training_plan_workouts w
       join training_plan_weeks k on k.id = w.week_id
       join training_plans p on p.id = k.plan_id
       where w.id = training_plan_workout_items.workout_id and p.user_id = auth.uid()
    )
  );

drop policy if exists "Users can modify own plan items" on training_plan_workout_items;
create policy "Users can modify own plan items" on training_plan_workout_items
  for all using (
    exists (
       select 1 from training_plan_workouts w
       join training_plan_weeks k on k.id = w.week_id
       join training_plans p on p.id = k.plan_id
       where w.id = training_plan_workout_items.workout_id and p.user_id = auth.uid()
    )
  );
