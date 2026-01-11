-- Script para padronizar grupos musculares no banco de dados
-- Corrige "Perna" para "Pernas" e "Ombro" para "Ombros" (plural)

-- Atualizar exercise_library
UPDATE exercise_library 
SET muscle_group = 'Pernas' 
WHERE muscle_group = 'Perna';

UPDATE exercise_library 
SET muscle_group = 'Ombros' 
WHERE muscle_group = 'Ombro';

-- Atualizar exercises (treinos dos usuários)
UPDATE exercises 
SET muscle_group = 'Pernas' 
WHERE muscle_group = 'Perna';

UPDATE exercises 
SET muscle_group = 'Ombros' 
WHERE muscle_group = 'Ombro';

-- Atualizar user_custom_exercises (exercícios personalizados)
UPDATE user_custom_exercises 
SET muscle_group = 'Pernas' 
WHERE muscle_group = 'Perna';

UPDATE user_custom_exercises 
SET muscle_group = 'Ombros' 
WHERE muscle_group = 'Ombro';

-- Verificar os resultados
SELECT DISTINCT muscle_group FROM exercise_library ORDER BY muscle_group;
SELECT DISTINCT muscle_group FROM exercises ORDER BY muscle_group;
SELECT DISTINCT muscle_group FROM user_custom_exercises ORDER BY muscle_group;
