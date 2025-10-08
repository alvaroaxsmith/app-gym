# Atualização de Imagens dos Exercícios

## 📝 Descrição

Este script atualiza as URLs das imagens dos exercícios na biblioteca. As imagens atuais são **placeholders** gerados dinamicamente com as iniciais dos exercícios, cada grupo muscular com uma cor específica.

## 🎨 Cores por Grupo Muscular

- **Peito** 🟢 - Verde (#4CAF50)
- **Costas** 🔵 - Azul (#2196F3)
- **Pernas** 🟠 - Laranja (#FF9800)
- **Ombros** 🟣 - Roxo (#9C27B0)
- **Bíceps** 🔴 - Vermelho (#F44336)
- **Tríceps** 🔷 - Ciano (#00BCD4)
- **Abdômen** 🟡 - Amarelo (#FFC107)

## ⚙️ Como Aplicar

### Opção 1: Via Supabase Dashboard (Recomendado)

1. Acesse o [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecione seu projeto
3. Vá em **SQL Editor** (na barra lateral)
4. Clique em **New query**
5. Copie e cole o conteúdo de `update_exercise_images.sql`
6. Clique em **Run** (ou pressione Ctrl/Cmd + Enter)
7. Verifique se apareceu a mensagem de sucesso

### Opção 2: Via CLI do Supabase

```bash
# Se tiver o Supabase CLI instalado
supabase db push --file supabase/update_exercise_images.sql
```

### Opção 3: Via psql (PostgreSQL Client)

```bash
psql -h db.your-project.supabase.co -U postgres -d postgres -f supabase/update_exercise_images.sql
```

## ✅ Verificação

Após executar o script, você pode verificar se as URLs foram atualizadas:

```sql
-- Ver todas as imagens
SELECT name, image_url, muscle_group 
FROM exercise_library 
ORDER BY muscle_group, name;

-- Contar exercícios com imagens
SELECT COUNT(*) as total_com_imagens
FROM exercise_library 
WHERE image_url IS NOT NULL;
```

## 🔄 Substituir por Imagens Reais

As URLs atuais são **temporárias**. Para substituir por imagens reais de exercícios:

### Opção 1: API ExerciseDB (Recomendado)

1. Cadastre-se em [RapidAPI](https://rapidapi.com/)
2. Inscreva-se na [ExerciseDB API](https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb)
3. Use o seguinte formato de URL:
   ```
   https://exercisedb.p.rapidapi.com/image/exercise_id.jpg
   ```

### Opção 2: Upload Manual para Supabase Storage

1. Crie um bucket `exercise-images` no Supabase Storage
2. Configure políticas de acesso público para leitura
3. Faça upload das imagens
4. Atualize as URLs:

```sql
UPDATE exercise_library 
SET image_url = 'https://your-project.supabase.co/storage/v1/object/public/exercise-images/supino-reto.jpg'
WHERE name = 'Supino Reto';
```

### Opção 3: Assets Locais no App

1. Adicione imagens em `assets/exercises/`
2. Atualize `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/exercises/
   ```
3. Use `AssetImage` no código:
   ```dart
   Image.asset('assets/exercises/supino-reto.jpg')
   ```

## 📦 APIs de Imagens de Exercícios

### ExerciseDB (RapidAPI)
- **URL:** https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb
- **Recursos:** 1300+ exercícios com GIFs animados
- **Plano Free:** 100 requisições/dia
- **Formato:** GIF, JPG

### WGER Workout Manager
- **URL:** https://wger.de/en/software/api
- **Recursos:** API gratuita e open-source
- **Licença:** AGPL
- **Formato:** JPG, PNG

### FitnessAI
- **URL:** https://www.fitnessai.com/api
- **Recursos:** Imagens e vídeos de exercícios
- **Status:** Beta/Limitada

## 🐛 Troubleshooting

### Erro: "permission denied"
- Verifique se você está autenticado como superuser
- Use a role `postgres` ou com privilégios de UPDATE

### Erro: "relation exercise_library does not exist"
- Execute primeiro o `schema.sql` principal
- Verifique se está no banco de dados correto

### URLs não carregam no app
- Verifique conexão com internet
- Teste a URL diretamente no navegador
- Confira CORS se usando API externa

## 📝 Notas

- As URLs dos placeholders são geradas pelo serviço [UI Avatars](https://ui-avatars.com/)
- O serviço é gratuito e não requer autenticação
- Imagens são geradas em tempo real (200x200px)
- Para produção, recomenda-se fazer cache ou usar imagens próprias

## 🚀 Próximos Passos

Veja a [Issue #24](https://github.com/alvaroaxsmith/app-gym/issues/24) para implementação de:
- Upload de imagens personalizadas
- Integração com Supabase Storage
- Compressão e otimização de imagens
- Cache local de imagens

---

**Criado em:** 2025-10-08  
**Relacionado:** Issue #11, Issue #24
