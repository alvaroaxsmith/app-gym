-- Atualiza a função get_user_ranking para suportar filtros de data e ordenação
-- Drop da versão antiga (sem parâmetros ou com parâmetros diferentes, o replace resolverá se a assinatura for a mesma, mas como mudamos assinatura, melhor dropar explicitamente se necessário, mas em PL/pgSQL overload é permitido. Aqui vou fazer create or replace, mas cuidado com chamadas antigas se não atualizar o client)

-- Como o Dart chamará com parametros nomeados ou posicionais, a assinatura precisa bater.
-- Vou criar uma nova versão. A antiga sem parametros continuará existindo se eu não dropar, mas o 'create or replace' com assinatura diferente cria uma sobrecarga (overload). 
-- Para limpar, vou dropar a função sem parametros.

DROP FUNCTION IF EXISTS get_user_ranking();

CREATE OR REPLACE FUNCTION get_user_ranking(
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_order_by text DEFAULT 'volume'
)
RETURNS TABLE (
  user_id uuid,
  email text,
  display_name text,
  total_volume numeric,
  total_workouts bigint
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  WITH user_stats AS (
    SELECT
      w.user_id,
      SUM(e.sets * 
          CASE 
            WHEN e.reps ~ '^[0-9]+(\.[0-9]+)?$' THEN e.reps::numeric
            WHEN e.reps ~ '^[0-9]+' THEN substring(e.reps FROM '^[0-9]+')::numeric
            ELSE 1
          END * e.weight_kg) AS total_volume,
      COUNT(DISTINCT w.id) AS total_workouts
    FROM workouts w
    JOIN exercises e ON e.workout_id = w.id
    WHERE (p_start_date IS NULL OR w.date >= p_start_date)
      AND (p_end_date IS NULL OR w.date <= p_end_date)
    GROUP BY w.user_id
  )
  SELECT
    us.user_id,
    -- PROTEÇÃO DE PRIVACIDADE: Extrai apenas a parte antes do @
    -- Se tiver display_name, usa ele. Se não, usa o prefixo do email.
    -- Nunca retorna o email completo.
    COALESCE(p.full_name, split_part(u.email, '@', 1)) AS display_name,
    NULL as email, -- Campo mantido para compatibilidade, mas enviando nulo (Dart deve tratar)
    COALESCE(us.total_volume, 0) AS total_volume,
    COALESCE(us.total_workouts, 0) AS total_workouts
  FROM user_stats us
  JOIN auth.users u ON u.id = us.user_id
  LEFT JOIN profiles p ON p.id = us.user_id
  ORDER BY 
    CASE WHEN p_order_by = 'workouts' THEN us.total_workouts END DESC,
    CASE WHEN p_order_by = 'volume' THEN us.total_volume END DESC,
    us.total_volume DESC; -- Desempate padrão
$$;
