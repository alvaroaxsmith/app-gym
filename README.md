# Construindo Fibra

App mobile-first para registrar e analisar treinos de musculação usando Flutter Web e Supabase.

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

3. Habilite a verificação de e-mail (opcional) e configure o template de recuperação de senha para apontar para a URL do seu app.

> Dúvidas sobre Supabase e deploy? Veja:
>
> - [`docs/supabase_deploy.md`](docs/supabase_deploy.md) para configurar o backend.
> - [`docs/vercel_deploy.md`](docs/vercel_deploy.md) para publicar na Vercel.

## ▶️ Executando localmente

```bash
flutter run -d web-server
```

## 🧪 Testes rápidos

```bash
flutter test
```


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

## 📄 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` (adicionar conforme necessário).
