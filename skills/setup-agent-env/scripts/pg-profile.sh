#!/bin/bash
# Создаёт (или пересоздаёт) профиль подключения @microsoft/postgres-mcp для одной БД:
# режим только чтения (ro), пароль — в Связку ключей macOS, ни в файлы, ни в вывод он не попадает.
#
#   pg-profile.sh <имя-профиля> <env-файл> [префикс]
#
# env-файл должен задавать <префикс>HOST, PORT, NAME, USERNAME, PASSWORD (префикс по умолчанию DB_),
# например ~/.config/trading_bot/trading_bot.env. Повторный запуск обновляет профиль и пароль —
# так же действуй после смены пароля БД.
set -euo pipefail

NAME="${1:?имя профиля}"
ENV_FILE="${2:?путь к env-файлу}"
PREFIX="${3:-DB_}"
PKG="@microsoft/postgres-mcp@${POSTGRES_MCP_VERSION:-0.3.0}"
NPX="$(npm prefix -g)/bin/npx"

[[ "$NAME" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Имя профиля: только a-z A-Z 0-9 _ -" >&2; exit 2; }
[ -f "$ENV_FILE" ] || { echo "Нет файла $ENV_FILE" >&2; exit 2; }

# Переменные читаются в подоболочке, чтобы не утекали в окружение вызывающего.
(
  set -a; . "$ENV_FILE"; set +a
  var() { local v="${PREFIX}$1"; printf '%s' "${!v:-}"; }
  HOST="$(var HOST)"; PORT="$(var PORT)"; DB="$(var NAME)"; USER_="$(var USERNAME)"; PASS="$(var PASSWORD)"
  for k in HOST PORT DB USER_ PASS; do
    [ -n "${!k}" ] || { echo "В $ENV_FILE не задана переменная для $k (префикс $PREFIX)" >&2; exit 2; }
  done
  # Локальная БД (docker на 127.0.0.1) — без TLS; удалённая — с проверкой сертификата.
  case "$HOST" in localhost|127.0.0.1|::1) SSL=disable ;; *) SSL=verify-full ;; esac

  pgm() { "$NPX" -y "$PKG" "$@"; }
  hide() { sed "s/$(printf '%s' "$PASS" | sed 's/[][\\/.*^$]/\\&/g')/<скрыто>/g"; }

  if pgm connection list 2>/dev/null | grep -qE "^  $NAME\$"; then
    pgm connection remove "$NAME" -f 2>&1 | hide
  fi
  pgm connection add "$NAME" "host=$HOST port=$PORT dbname=$DB user=$USER_ sslmode=$SSL" --access-mode ro 2>&1 | hide | grep -v 'No password set\|set one with\|trust or peer' || true
  POSTGRES_MCP_PASSWORD="$PASS" pgm connection set-password "$NAME" 2>&1 | hide
)
grep -A8 -E "name: $NAME\$" "$HOME/.postgres-mcp/connections.yaml" | grep -E 'name|host|port|database|user|ssl_mode|access_mode'
