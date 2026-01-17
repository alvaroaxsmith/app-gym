# Documentação Funcional - App Gym

## 1. Visão Geral
O App Gym é uma aplicação focada em praticantes de musculação que desejam registrar seus treinos com precisão científica, acompanhar progressão de carga e planejar periodizações (mesociclos) de forma inteligente. O diferencial do aplicativo é o foco em métricas avançadas como RPE (Rate of Perceived Exertion), Volume de Treino e controle de fadiga.

---

## 2. Módulos Principais

### 2.1. Dashboard (Cockpit)
O Dashboard é a tela inicial onde o usuário tem uma visão macro do seu desempenho.
*   **Frequência Semanal**: Gráfico de barras mostrando os dias treinados na semana atual e anterior.
*   **Volume de Treino**: Gráfico de linha exibindo o volume total (Séries x Repetições x Carga) ao longo do tempo.
*   **Fadiga e RPE Médio**: Indicadores de intensidade média dos treinos recentes.
*   **Melhores Marcas (PRs)**: Exibição rápida dos recordes pessoais em exercícios chave.

### 2.2. Biblioteca de Exercícios
Um repositório central de exercícios que alimenta tanto os registros de treino quanto o planejamento.
*   **Exercícios Padronizados**: Lista pré-carregada de exercícios comuns (Supino, Agachamento, etc.) com grupo muscular e instruções.
*   **Exercícios Personalizados**: O usuário pode criar seus próprios exercícios se não encontrar na lista oficial.
*   **Filtros**: Busca por nome ou grupo muscular (Peito, Costas, Perna, etc.).

### 2.3. Registro de Treinos (Workout Logger)
Funcionalidade core para execução do treino no dia a dia.
*   **Criação de Treino**: Iniciar um treino vazio ou baseado em um plano existente.
*   **Registro de Séries**:
    *   **Carga (kg)**: Peso utilizado.
    *   **Repetições**: Quantidade de movimentos.
    *   **RPE (6-10)**: Nota de esforço percebido. 10 = Falha total, 8 = Sobraram 2 repetições.
    *   **Aquecimento**: Checkbox ou campo específico para marcar séries de aquecimento (não contam para o volume total de trabalho).
*   **Cronômetro de Descanso**: Timer automático ao finalizar uma série.
*   **Histórico**: Visualização do que foi feito no treino anterior daquele exercício para facilitar a progressão de carga.

### 2.4. Planejamento de Treinos (Ciclos e Periodização)
Módulo avançado para estruturar treinamentos de médio/longo prazo (Mesociclos).
*   **Criação de Plano**: O usuário define um objetivo (Hipertrofia, Força) e duração (ex: 4 a 8 semanas).
*   **Estrutura Semanal Auto-Gerada**: O app sugere uma estrutura baseada em princípios científicos:
    *   **Semana 1 (MEV/Adaptação)**: Volume recuperável mínimo.
    *   **Semanas Intermediárias (MAV)**: Progressão de carga/volume.
    *   **Última Semana (Deload)**: Semana regenerativa com volume/intensidade reduzidos automaticamente.
*   **Editor de Rotinas**: Dentro de cada semana, o usuário define as rotinas (ex: Treino A, Treino B) e adiciona os exercícios da biblioteca com metas de séries e repetições pré-definidas.

### 2.5. Autenticação e Perfil
*   Login e Registro via E-mail/Senha (Supabase Auth).
*   Recuperação de senha.
*   Gerenciamento de dados do perfil.

---

## 3. Conceitos Técnicos e Glossário

### 3.1. RPE (Rate of Perceived Exertion)
Escala de 1 a 10 usada para medir a intensidade de uma série.
*   **RPE 10**: Falha concêntrica (não faria mais nenhuma repetição).
*   **RPE 9**: Sobraria 1 repetição.
*   **RPE 8**: Sobrariam 2 repetições (Zona ideal de hipertrofia sustentável).
*   **RPE < 6**: Aquecimento ou carga muito leve.

### 3.2. Volume de Treino
Calculado como: `Carga × Repetições × Número de Séries`.
*   *Nota*: Séries marcadas como "Aquecimento" são excluídas do cálculo de volume total para não distorcer as métricas de progresso.

### 3.3. Deload
Uma semana planejada propositalmente com cargas ou volumes menores para permitir que o sistema nervoso central e articulações se recuperem, prevenindo lesões e estagnação (Overtraining).

---

## 4. Fluxos de Uso Comuns

### Cenário A: O treino do dia-a-dia
1.  Usuário abre o app no **Dashboard**.
2.  Clica em **"Novo Treino"** (Botão +).
3.  Adiciona exercícios conforme executa na academia.
4.  Preenche carga e reps. Marca "Aquecimento" nas primeiras séries.
5.  Finaliza o treino.
6.  Dashboard atualiza com o novo volume.

### Cenário B: Criando uma Periodização
1.  Usuário vai na aba **"Planejamento"**.
2.  Clica em **"Novo Plano"**.
3.  Escolhe "Hipertrofia", duração de 6 semanas, data de início "Segunda-feira".
4.  O App gera as 6 semanas.
5.  Usuário entra na "Semana 1", cria o "Treino A (Peito/Tríceps)".
6.  Adiciona "Supino Reto" (3 séries de 8-12 reps).
7.  Repete para os outros dias.
8.  Nos dias de treino, o usuário consulta esse plano para saber o que fazer.
