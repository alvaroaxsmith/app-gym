-- Migration: Add Exercise Library Feature
-- Date: 2025-10-08
-- Description: Adds exercise library table and history function

-- Table for pre-defined exercise library
create table if not exists exercise_library (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  muscle_group text not null,
  difficulty_level text check (difficulty_level in ('beginner', 'intermediate', 'advanced')),
  equipment text,
  instructions text,
  image_url text,
  video_url text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

create index if not exists exercise_library_muscle_group_idx on exercise_library(muscle_group);
create index if not exists exercise_library_difficulty_idx on exercise_library(difficulty_level);

-- Make exercise library readable by all authenticated users
alter table exercise_library enable row level security;

create policy "Anyone can view exercise library" on exercise_library
  for select
  using (true);

-- Function para buscar histórico de exercícios do usuário
create or replace function get_user_exercise_history(user_id_param uuid)
returns table (
  name text,
  muscle_group text,
  last_sets integer,
  last_reps text,
  last_weight_kg numeric,
  last_rest_seconds integer,
  last_used_date date,
  usage_count bigint
)
language sql
security definer
as $$
  with exercise_stats as (
    select
      e.name,
      e.muscle_group,
      e.sets as last_sets,
      e.reps as last_reps,
      e.weight_kg as last_weight_kg,
      e.rest_seconds as last_rest_seconds,
      w.date as workout_date,
      row_number() over (partition by lower(trim(e.name)) order by w.date desc) as rn,
      count(*) over (partition by lower(trim(e.name))) as usage_count
    from exercises e
    join workouts w on w.id = e.workout_id
    where w.user_id = user_id_param
  )
  select
    name,
    muscle_group,
    last_sets,
    last_reps,
    last_weight_kg,
    last_rest_seconds,
    workout_date as last_used_date,
    usage_count
  from exercise_stats
  where rn = 1
  order by usage_count desc, workout_date desc;
$$;

-- Insert basic exercises into library
insert into exercise_library (name, description, muscle_group, difficulty_level, equipment, instructions) values
  -- Peito
  ('Supino Reto', 'Exercício fundamental para desenvolvimento do peitoral maior', 'Peito', 'intermediate', 'Barra e Banco', 'Deite no banco, pegue a barra com pegada média, desça até o peito e empurre para cima'),
  ('Supino Inclinado', 'Foca na parte superior do peitoral', 'Peito', 'intermediate', 'Barra e Banco Inclinado', 'Similar ao supino reto, mas com banco inclinado 30-45 graus'),
  ('Crucifixo', 'Isolamento do peitoral com amplitude máxima', 'Peito', 'beginner', 'Halteres', 'Abra os braços em cruz mantendo leve flexão nos cotovelos'),
  ('Flexão', 'Exercício de peso corporal clássico', 'Peito', 'beginner', 'Peso Corporal', 'Posição de prancha, desça o corpo até quase tocar o chão'),
  
  -- Costas
  ('Barra Fixa', 'Exercício composto para desenvolvimento das costas', 'Costas', 'intermediate', 'Barra Fixa', 'Pegue a barra e puxe seu corpo até o queixo passar a barra'),
  ('Remada Curvada', 'Trabalha toda a musculatura das costas', 'Costas', 'intermediate', 'Barra', 'Incline o tronco, puxe a barra até o abdômen'),
  ('Pulldown', 'Puxada alta para dorsais', 'Costas', 'beginner', 'Máquina', 'Puxe a barra até a altura do peito'),
  ('Remada Unilateral', 'Trabalha cada lado independentemente', 'Costas', 'beginner', 'Halter', 'Apoie um joelho no banco, puxe o halter até o quadril'),
  
  -- Pernas
  ('Agachamento', 'Rei dos exercícios para pernas', 'Pernas', 'intermediate', 'Barra', 'Desça mantendo o peso nos calcanhares até coxas paralelas'),
  ('Leg Press', 'Exercício seguro para desenvolvimento das pernas', 'Pernas', 'beginner', 'Máquina', 'Empurre a plataforma com os pés na largura dos ombros'),
  ('Extensão de Pernas', 'Isolamento do quadríceps', 'Pernas', 'beginner', 'Máquina', 'Estenda as pernas contra a resistência'),
  ('Flexão de Pernas', 'Isolamento dos posteriores de coxa', 'Pernas', 'beginner', 'Máquina', 'Flexione as pernas puxando o peso em direção aos glúteos'),
  ('Stiff', 'Trabalha posteriores e glúteos', 'Pernas', 'intermediate', 'Barra ou Halteres', 'Desça a barra mantendo pernas levemente flexionadas'),
  
  -- Ombros
  ('Desenvolvimento', 'Exercício base para ombros', 'Ombros', 'intermediate', 'Barra ou Halteres', 'Empurre o peso acima da cabeça'),
  ('Elevação Lateral', 'Isolamento do deltoide lateral', 'Ombros', 'beginner', 'Halteres', 'Eleve os braços lateralmente até a altura dos ombros'),
  ('Elevação Frontal', 'Foca no deltoide anterior', 'Ombros', 'beginner', 'Halter ou Barra', 'Eleve o peso à frente até a altura dos ombros'),
  
  -- Bíceps
  ('Rosca Direta', 'Exercício clássico para bíceps', 'Bíceps', 'beginner', 'Barra', 'Flexione os cotovelos mantendo costas retas'),
  ('Rosca Alternada', 'Trabalha cada braço independentemente', 'Bíceps', 'beginner', 'Halteres', 'Alterne a flexão dos cotovelos'),
  ('Rosca Martelo', 'Trabalha bíceps e antebraços', 'Bíceps', 'beginner', 'Halteres', 'Flexione mantendo pegada neutra (palmas face a face)'),
  
  -- Tríceps
  ('Tríceps Testa', 'Isolamento do tríceps', 'Tríceps', 'intermediate', 'Barra W', 'Deite no banco, baixe a barra até a testa'),
  ('Tríceps Pulley', 'Exercício de isolamento na polia', 'Tríceps', 'beginner', 'Polia', 'Empurre a barra/corda para baixo estendendo os cotovelos'),
  ('Mergulho', 'Exercício composto com peso corporal', 'Tríceps', 'intermediate', 'Barras Paralelas', 'Desça o corpo flexionando os cotovelos'),
  
  -- Abdômen
  ('Abdominal', 'Exercício básico para abdômen', 'Abdômen', 'beginner', 'Peso Corporal', 'Deite e flexione o tronco em direção aos joelhos'),
  ('Prancha', 'Isometria para core', 'Abdômen', 'beginner', 'Peso Corporal', 'Mantenha posição de flexão apoiado nos antebraços'),
  ('Elevação de Pernas', 'Trabalha abdômen inferior', 'Abdômen', 'intermediate', 'Peso Corporal ou Barra', 'Eleve as pernas mantendo costas apoiadas')
on conflict do nothing;
