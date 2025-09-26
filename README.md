# Workout Logger MVP

MVP mobile-first para registrar e analisar treinos de musculação usando Flutter Web e Supabase.

## ✨ Funcionalidades

- Autenticação com Supabase (login, cadastro e recuperação de senha)
- Calendário mensal com indicadores de treinos
- CRUD completo de treinos diários e exercícios
- Importação em massa via arquivos CSV ou JSON
- Dashboard com gráficos de volume de treino e distribuição por grupo muscular
- Exemplo de esquema de banco de dados Supabase e assets de exemplo

## 🚀 Pré-requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) 3.22+ com suporte Web habilitado
- Conta no [Supabase](https://supabase.com/)

## 🔧 Configuração

1. Clone o repositório e instale as dependências:

```bash
flutter pub get
```

2. Crie o arquivo `.env` na raiz com as chaves do Supabase (veja `.env.example`):

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

3. Configure o banco no Supabase:

```sql
-- Copie o conteúdo de supabase/schema.sql e execute no SQL Editor do Supabase
```

4. Habilite a verificação de e-mail (opcional) e configure o template de recuperação de senha para apontar para a URL do seu app.

## ▶️ Executando localmente

```bash
flutter run -d chrome
```

## 🧪 Testes rápidos

```bash
flutter test
```

## 📦 Build para deploy

```bash
flutter build web
```

O diretório `build/web` pode ser publicado em serviços como Netlify, Vercel (usando adaptador), Firebase Hosting ou GitHub Pages.

## 🔁 Fluxo de Deploy sugerido

- Fork/branch principal com revisão via pull request
- GitHub Actions (`.github/workflows/ci.yml`) executa testes e build Web
- Deploy automatizado para serviço de hospedagem estática usando token/secrets (configure conforme seu provedor)

## 📂 Estrutura principal

```
lib/
 ├─ core/              # configuração global (tema, utilitários)
 ├─ features/
 │   ├─ auth/          # telas e provider de autenticação
 │   ├─ home/          # navegação principal
 │   ├─ workouts/      # calendário e CRUD de treinos
 │   ├─ imports/       # upload e processamento de arquivos
 │   └─ dashboard/     # gráficos e análises
 ├─ models/            # modelos de domínio (Workout, Exercise, etc.)
assets/samples/        # arquivos de importação de exemplo
supabase/              # schema SQL
```

## 🗺️ Roadmap sugerido

1. Ajustar UI e validar fluxo com usuários
2. Integrar analytics/breadcrumbs
3. Adicionar notificações ou lembretes de treino
4. Melhorar experiência offline com caching local

## 📄 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` (adicionar conforme necessário).
