#!/usr/bin/env bash
# Distribui o app pelo Firebase App Distribution.
#
#   ./scripts/distribute.sh android            # release APK
#   ./scripts/distribute.sh android --debug     # build de debug (mais rápido)
#   ./scripts/distribute.sh ios                 # IPA (exige perfil ad-hoc)
#
# Autenticação: usa a sessão do `firebase login`. Para CI, exporte
# GOOGLE_APPLICATION_CREDENTIALS apontando para uma service account com o papel
# "Firebase App Distribution Admin" e rode com nenhum usuário logado.
set -euo pipefail

PROJECT="multiplicado-a36cf"
ANDROID_APP="1:390130821317:android:afdf37f8376e854a3968ac"
IOS_APP="1:390130821317:ios:d763bda4e732035a3968ac"

# Grupo de testadores criado no console (Firebase → App Distribution → Testadores).
GROUPS="${DISTRIBUTE_GROUPS:-testadores}"

# A API de dev roda na LAN; um build distribuído precisa de uma URL que os
# testadores alcancem. Ajuste antes de distribuir para fora da sua rede.
API_BASE_URL="${API_BASE_URL:-http://192.168.3.4:3999/v1}"

# UDIDs exportados do Firebase (App Distribution → Testadores → Exportar UDIDs).
# Quando presente, os aparelhos são cadastrados na Apple antes do build iOS.
UDIDS_FILE="${UDIDS_FILE:-udids.txt}"

PLATFORM="${1:-}"
MODE="${2:---release}"

if [[ -z "$PLATFORM" ]]; then
  echo "uso: $0 <android|ios> [--release|--debug]" >&2
  exit 1
fi

notes_file="$(mktemp)"
trap 'rm -f "$notes_file"' EXIT
{
  echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'sem git')"
  echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
  echo "Data: $(date '+%d/%m/%Y %H:%M')"
  echo "API: $API_BASE_URL"
} > "$notes_file"

case "$PLATFORM" in
  android)
    echo "▸ build Android ($MODE)"
    flutter build apk "$MODE" --dart-define=API_BASE_URL="$API_BASE_URL"
    artifact="build/app/outputs/flutter-apk/app-${MODE#--}.apk"
    app_id="$ANDROID_APP"
    ;;
  ios)
    # Aparelho novo só instala se o UDID estiver no perfil no momento da
    # assinatura — por isso o cadastro vem antes do build, não depois.
    if [[ -f "$UDIDS_FILE" ]]; then
      echo "▸ registrando UDIDs na Apple ($UDIDS_FILE)"
      set +e
      node "$(dirname "$0")/apple-devices.mjs" "$UDIDS_FILE"
      rc=$?
      set -e
      case $rc in
        0)
          echo "▸ aparelho novo cadastrado — regenerando perfil"
          # O Xcode só rebaixa o perfil se o cache local sair da frente.
          rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null || true
          ;;
        3) echo "▸ nenhum aparelho novo; perfil atual serve" ;;
        2) echo "▸ credenciais da Apple ausentes — pulando cadastro de UDIDs" ;;
        *) echo "▸ cadastro de UDIDs falhou; seguindo com o perfil atual" ;;
      esac
    else
      echo "▸ $UDIDS_FILE não encontrado — pulando cadastro de UDIDs"
    fi

    echo "▸ build iOS ($MODE)"
    # `ad-hoc` é obrigatório aqui. O padrão do Flutter é `app-store`, que assina
    # com um perfil sem lista de aparelhos: serve para submeter à loja e não
    # instala em lugar nenhum. O testador recebe o convite, cadastra o UDID e
    # fica preso em "você receberá um email", porque não existe build que o
    # aparelho dele possa instalar. O perfil ad-hoc embute os UDIDs no momento
    # da assinatura — daí o cadastro na Apple ter que vir antes do build.
    flutter build ipa "$MODE" \
      --export-method ad-hoc \
      --dart-define=API_BASE_URL="$API_BASE_URL"
    artifact="$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1)"
    app_id="$IOS_APP"
    ;;
  *)
    echo "plataforma inválida: $PLATFORM" >&2
    exit 1
    ;;
esac

if [[ ! -f "$artifact" ]]; then
  echo "artefato não encontrado: $artifact" >&2
  exit 1
fi

echo "▸ enviando $artifact"

# O `:distribute` às vezes falha com 404 logo após a release ser criada — a
# release ainda não propagou quando o CLI tenta associar os testadores.
# Reexecutar é seguro: o upload detecta a release existente e só refaz a
# associação, em vez de criar outra.
tentativas=3
for n in $(seq 1 $tentativas); do
  if firebase appdistribution:distribute "$artifact" \
      --app "$app_id" \
      --project "$PROJECT" \
      --groups "$GROUPS" \
      --release-notes-file "$notes_file"; then
    echo "✓ distribuído para o grupo '$GROUPS'"
    exit 0
  fi
  if [[ $n -lt $tentativas ]]; then
    espera=$((n * 5))
    echo "▸ falhou (tentativa $n/$tentativas) — nova tentativa em ${espera}s"
    sleep "$espera"
  fi
done

echo "✗ distribuição falhou após $tentativas tentativas" >&2
exit 1
