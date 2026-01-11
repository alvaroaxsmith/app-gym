-- Migration: Add Custom Exercises Feature
-- Date: 2026-01-11
-- Description: Permite usuários criarem exercícios personalizados

-- Tabela para exercícios customizados do usuário
create table if not exists user_custom_exercises (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  muscle_group text not null,
  description text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now()),
  
  -- Constraint para evitar nomes duplicados por usuário
  unique(user_id, name)
);

-- Índices para melhor performance
create index if not exists user_custom_exercises_user_id_idx on user_custom_exercises(user_id);
create index if not exists user_custom_exercises_muscle_group_idx on user_custom_exercises(muscle_group);
create index if not exists user_custom_exercises_name_idx on user_custom_exercises(name);

-- Row Level Security (RLS)
alter table user_custom_exercises enable row level security;

-- Policy: Usuários só podem ver seus próprios exercícios
create policy "Users can view own custom exercises" on user_custom_exercises
  for select
  using (auth.uid() = user_id);

-- Policy: Usuários podem inserir seus próprios exercícios
create policy "Users can insert own custom exercises" on user_custom_exercises
  for insert
  with check (auth.uid() = user_id);

-- Policy: Usuários podem atualizar seus próprios exercícios
create policy "Users can update own custom exercises" on user_custom_exercises
  for update
  using (auth.uid() = user_id);

-- Policy: Usuários podem deletar seus próprios exercícios
create policy "Users can delete own custom exercises" on user_custom_exercises
  for delete
  using (auth.uid() = user_id);

-- Trigger para atualizar updated_at automaticamente
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

create trigger update_user_custom_exercises_updated_at
  before update on user_custom_exercises
  for each row
  execute function update_updated_at_column();

-- Comentários para documentação
comment on table user_custom_exercises is 'Exercícios personalizados criados pelos usuários';
comment on column user_custom_exercises.user_id is 'ID do usuário que criou o exercício';
comment on column user_custom_exercises.name is 'Nome do exercício personalizado';
comment on column user_custom_exercises.muscle_group is 'Grupo muscular trabalhado';
comment on column user_custom_exercises.description is 'Descrição opcional do exercício';
comment on column user_custom_exercises.image_url is 'URL da imagem do exercício (opcional)';
