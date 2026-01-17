# Melhorias no Sistema de Ranking

## 1. Análise do Sistema Atual (AS-IS)

O sistema de ranking atual, embora funcional, apresenta limitações que podem desmotivar usuários a longo prazo e não refletem o esforço real de forma justa.

### Problemas Identificados:

1.  **Efeito "Bola de Neve" (Viés de Antiguidade):**
    *   **Causa:** A pontuação é baseada no volume total acumulado desde a criação da conta.
    *   **Impacto:** Usuários antigos dominam o topo permanentemente. Novos usuários não têm chance matemática de competir, independentemente de quão intenso seja o treino atual deles.

2.  **Viés de Modalidade (Força vs. Técnica):**
    *   **Causa:** Métrica única de `Volume Total (Sets * Reps * Carga)`.
    *   **Impacto:** Exercícios como Leg Press (altas cargas) geram pontuações desproporcionalmente maiores que exercícios de isolamento (Elevação Lateral), mesmo com esforço relativo (RPE) similar. Isso favorece treinos de força em detrimento de técnica/hipertrofia.

3.  **Falta de Privacidade e Escopo:**
    *   **Causa:** Ranking global único.
    *   **Impacto:** Exposição de dados para todos os usuários e intimidação de iniciantes.

4.  **Performance (Escalabilidade):**
    *   **Causa:** Cálculo em tempo real somando todo o histórico (`SUM` completo).
    *   **Impacto:** Degradação de performance conforme a base de dados cresce.

---

## 2. Proposta de Solução (TO-BE)

Transformar o ranking estático em um sistema **Sazonal e Multidimensional**.

### Pilares da Mudança:

1.  **Ciclos Temporais (Sazonalidade):**
    *   Os rankings devem "reiniciar" ou filtrar por períodos: **Semanal**, **Mensal** e **Geral**.
    *   Isso permite que um novato tenha chance de ser o "Campeão da Semana".

2.  **Múltiplas Métricas de Vitória:**
    *   **Volume Load (Monstro da Carga):** Para quem move mais peso.
    *   **Consistência (O Disciplinado):** Ranking ordenado por número de treinos concluídos (frequência) na semana.

---

## 3. História de Usuário (User Story)

**Título:**
Ranking Dinâmico com Filtros Semanais e Categorias de Consistência

**Como:**
Um "Atleta Competitivo" (usuário ativo do app).

**Eu quero:**
Visualizar o ranking filtrado por "Semana Atual" e "Mês Atual", além de poder alternar a classificação entre "Volume de Carga" e "Dias de Treino".

**Para que:**
Eu possa competir de igual para igual com outros usuários em ciclos curtos, tendo chances de alcançar o "TOP 3" baseando-me na minha disciplina desta semana, mesmo que eu seja um usuário novo ou levante menos carga bruta que os veteranos.

### Critérios de Aceite (Acceptance Criteria):

1.  **Seletor de Período:**
    *   A tela deve possuir filtros: "Semanal" (Default), "Mensal", "Geral".
    *   O filtro semanal compreende de Segunda-feira (00:00) a Domingo (23:59) da semana atual.

2.  **Seletor de Métrica:**
    *   Alternância entre: "Volume Total (kg)" e "Frequência (Nº Treinos)".

3.  **Feedback Visual:**
    *   O usuário deve ver claramente sua posição e a distância para o próximo colocado.
    *   As medalhas (Ouro/Prata/Bronze) devem ser atribuídas dinamicamente ao contexto selecionado (ex: "Ouro da Semana").

---

## 4. Requisitos Técnicos

### Backend (Supabase/SQL):
*   Atualizar a função `get_user_ranking` para aceitar parâmetros de data (`start_date`, `end_date`).
*   Adicionar retorno da coluna `total_workouts` (count distinct de dias/sessões) para permitir ordenação por consistência.

```sql
-- Exemplo conceitual da nova assinatura
function get_user_ranking(start_date date, end_date date, order_by text)
```

### Frontend (Flutter):
*   Adicionar `SegmentedButton` ou `Dropdown` no topo da `RankingPage`.
*   Gerenciar estado para recarregar a lista ao trocar os filtros.
