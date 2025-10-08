-- Update exercise library with image URLs
-- Using placeholder images from UI Avatars (can be replaced with actual exercise images later)

-- Peito
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Supino+Reto&background=4CAF50&color=fff&size=200&bold=true' where name = 'Supino Reto';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Supino+Inclinado&background=4CAF50&color=fff&size=200&bold=true' where name = 'Supino Inclinado';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Crucifixo&background=4CAF50&color=fff&size=200&bold=true' where name = 'Crucifixo';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Flexao&background=4CAF50&color=fff&size=200&bold=true' where name = 'Flexão';

-- Costas
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Barra+Fixa&background=2196F3&color=fff&size=200&bold=true' where name = 'Barra Fixa';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Remada+Curvada&background=2196F3&color=fff&size=200&bold=true' where name = 'Remada Curvada';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Pulldown&background=2196F3&color=fff&size=200&bold=true' where name = 'Pulldown';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Remada+Unilateral&background=2196F3&color=fff&size=200&bold=true' where name = 'Remada Unilateral';

-- Pernas
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Agachamento&background=FF9800&color=fff&size=200&bold=true' where name = 'Agachamento';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Leg+Press&background=FF9800&color=fff&size=200&bold=true' where name = 'Leg Press';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Extensao&background=FF9800&color=fff&size=200&bold=true' where name = 'Extensão de Pernas';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Flexao+Pernas&background=FF9800&color=fff&size=200&bold=true' where name = 'Flexão de Pernas';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Stiff&background=FF9800&color=fff&size=200&bold=true' where name = 'Stiff';

-- Ombros
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Desenvolvimento&background=9C27B0&color=fff&size=200&bold=true' where name = 'Desenvolvimento';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Elevacao+Lateral&background=9C27B0&color=fff&size=200&bold=true' where name = 'Elevação Lateral';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Elevacao+Frontal&background=9C27B0&color=fff&size=200&bold=true' where name = 'Elevação Frontal';

-- Bíceps
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Rosca+Direta&background=F44336&color=fff&size=200&bold=true' where name = 'Rosca Direta';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Rosca+Alternada&background=F44336&color=fff&size=200&bold=true' where name = 'Rosca Alternada';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Rosca+Martelo&background=F44336&color=fff&size=200&bold=true' where name = 'Rosca Martelo';

-- Tríceps
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Triceps+Testa&background=00BCD4&color=fff&size=200&bold=true' where name = 'Tríceps Testa';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Triceps+Pulley&background=00BCD4&color=fff&size=200&bold=true' where name = 'Tríceps Pulley';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Mergulho&background=00BCD4&color=fff&size=200&bold=true' where name = 'Mergulho';

-- Abdômen
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Abdominal&background=FFC107&color=000&size=200&bold=true' where name = 'Abdominal';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Prancha&background=FFC107&color=000&size=200&bold=true' where name = 'Prancha';
update exercise_library set image_url = 'https://ui-avatars.com/api/?name=Elevacao+Pernas&background=FFC107&color=000&size=200&bold=true' where name = 'Elevação de Pernas';

-- Nota: Estas são imagens placeholder com iniciais coloridas
-- Para produção, substitua por URLs de imagens reais de exercícios
-- Opções: 
-- 1. Upload para Supabase Storage
-- 2. Usar API como ExerciseDB (https://exercisedb.p.rapidapi.com/)
-- 3. Assets locais no app
