#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "[vercel_build] Defina SUPABASE_URL e SUPABASE_ANON_KEY nas variáveis de ambiente do projeto." >&2
  exit 1
fi

FLUTTER_CHANNEL=${FLUTTER_CHANNEL:-stable}
FLUTTER_REPO=${FLUTTER_REPO:-https://github.com/flutter/flutter.git}
FLUTTER_PATH="$PWD/.vercel/flutter"

if [[ ! -d "$FLUTTER_PATH" ]]; then
  echo "[vercel_build] Instalando Flutter ($FLUTTER_CHANNEL) em $FLUTTER_PATH"
  git clone --depth 1 -b "$FLUTTER_CHANNEL" "$FLUTTER_REPO" "$FLUTTER_PATH"
fi

export PATH="$FLUTTER_PATH/bin:$PATH"

flutter config --enable-web
flutter --version
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "[vercel_build] Build finalizado. Artefatos em build/web"
