#!/bin/bash
# Развёртывание окружения агента Claude Code на macOS: agent-lsp с языковыми серверами,
# хуки agent-lsp, jarpeek, PostgreSQL MCP, правила settings.json.
#
#   setup.sh            — то же, что check
#   setup.sh check      — только проверка, ничего не меняет
#   setup.sh apply      — устанавливает и настраивает недостающее (идемпотентно)
#
# Версии можно переопределить переменными окружения (см. блок «Версии»).
set -uo pipefail

MODE="${1:-check}"
case "$MODE" in check|apply) ;; *) echo "Использование: $0 [check|apply]" >&2; exit 2 ;; esac

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"

# ── Версии (проверены вместе 2026-11-12) ────────────────────────────────────
NPM_PACKAGES=(
  "@blackwell-systems/agent-lsp@${AGENT_LSP_VERSION:-0.24.2}"
  "yaml-language-server@${YAML_LS_VERSION:-2.0.0}"
  "vscode-langservers-extracted@${JSON_LS_VERSION:-4.10.0}"
  "dockerfile-language-server-nodejs@${DOCKER_LS_VERSION:-0.15.0}"
  "pyright@${PYRIGHT_VERSION:-1.1.414}"
  "jarpeek@${JARPEEK_VERSION:-0.4.8}"
)
BREW_FORMULAE=(jdtls postgres-language-server)
LEMMINX_VERSION="${LEMMINX_VERSION:-0.31.2}"
LOMBOK_VERSION="${LOMBOK_VERSION:-1.18.46}"
POSTGRES_MCP_PKG="@microsoft/postgres-mcp@${POSTGRES_MCP_VERSION:-0.3.0}"

# ── Вывод ───────────────────────────────────────────────────────────────────
PROBLEMS=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; PROBLEMS=$((PROBLEMS + 1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
doit() { [ "$MODE" = apply ]; }

# ── Предусловия ─────────────────────────────────────────────────────────────
step "1. Базовые инструменты"
[ "$(uname -s)" = Darwin ] || { echo "Скрипт рассчитан на macOS (Homebrew, Связка ключей)." >&2; exit 1; }

if command -v brew >/dev/null; then ok "Homebrew $(brew --version | head -1 | cut -d' ' -f2)"
else bad "нет Homebrew — установи вручную: https://brew.sh (скрипт его не ставит)"; exit 1; fi
BREW_PREFIX="$(brew --prefix)"

if command -v claude >/dev/null; then ok "Claude Code CLI"; else bad "нет CLI claude"; exit 1; fi

# jq нужен самому скрипту для проверок, поэтому ставится раньше остального.
if command -v jq >/dev/null; then ok "jq"
elif doit; then brew install jq && ok "установлен jq"
else bad "нет jq — без него проверка невозможна (brew install jq)"; exit 1; fi

node_major() { node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }
if [ "$(node_major || echo 0)" -ge 22 ] 2>/dev/null; then ok "Node.js $(node -v)"
else
  bad "нужен Node.js 22+ (сейчас: $(node -v 2>/dev/null || echo нет))"
  if doit; then brew install node && hash -r && ok "установлен Node.js $(node -v)"; fi
fi
NPM_BIN="$(npm prefix -g 2>/dev/null)/bin"
NPX="$NPM_BIN/npx"

# JDK 21+ для lemminx и jarpeek; jdtls из Homebrew тянет свой openjdk.
JAVA_HOME_DETECTED="$(/usr/libexec/java_home -v 21+ 2>/dev/null || true)"
if [ -z "$JAVA_HOME_DETECTED" ] && [ -d "$BREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]; then
  JAVA_HOME_DETECTED="$BREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi
if [ -n "$JAVA_HOME_DETECTED" ]; then ok "JDK: $JAVA_HOME_DETECTED"
else
  bad "нет JDK 21+"
  if doit; then brew install openjdk && JAVA_HOME_DETECTED="$BREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home" && ok "установлен openjdk"; fi
fi

command -v python3 >/dev/null && ok "python3 (для хука env-check)" || bad "нет python3 (xcode-select --install или brew install python)"
command -v docker >/dev/null && ok "docker CLI" || warn "нет Docker — нужен для локальных БД проектов, скрипт его не ставит"

# ── Homebrew-формулы ────────────────────────────────────────────────────────
step "2. Homebrew: jdtls, postgres-language-server"
for f in "${BREW_FORMULAE[@]}"; do
  if brew list --versions "$f" >/dev/null 2>&1; then ok "$(brew list --versions "$f")"
  else bad "$f не установлен"; doit && brew install "$f" && ok "установлен $f"; fi
done

# ── npm-пакеты ──────────────────────────────────────────────────────────────
step "3. npm (глобально): agent-lsp, языковые серверы, jarpeek"
NPM_LS="$(npm ls -g --depth=0 --json 2>/dev/null || echo '{}')"
for spec in "${NPM_PACKAGES[@]}"; do
  name="${spec%@*}"; want="${spec##*@}"
  have="$(jq -r --arg n "$name" '.dependencies[$n].version // empty' <<<"$NPM_LS")"
  if [ "$have" = "$want" ]; then ok "$name $have"
  else
    bad "$name: нужна $want, сейчас ${have:-нет}"
    doit && npm install -g "$spec" >/dev/null 2>&1 && ok "установлен $spec"
  fi
done

# ── Lombok для jdtls ────────────────────────────────────────────────────────
step "4. Lombok $LOMBOK_VERSION (агент для jdtls)"
LOMBOK_JAR="$HOME/.m2/repository/org/projectlombok/lombok/$LOMBOK_VERSION/lombok-$LOMBOK_VERSION.jar"
fetch_verified() { # url dest — скачивание со сверкой SHA-1 из того же репозитория
  local url=$1 dest=$2 tmp want got
  tmp="$(mktemp)"
  curl -fsSL -o "$tmp" "$url" || { rm -f "$tmp"; return 1; }
  want="$(curl -fsSL "$url.sha1" | cut -c1-40)"
  got="$(shasum -a 1 "$tmp" | cut -c1-40)"
  if [ -n "$want" ] && [ "$want" = "$got" ]; then mkdir -p "$(dirname "$dest")"; mv "$tmp" "$dest"
  else rm -f "$tmp"; echo "SHA-1 не совпал для $url" >&2; return 1; fi
}
if [ -f "$LOMBOK_JAR" ]; then ok "$LOMBOK_JAR"
else
  bad "нет $LOMBOK_JAR"
  doit && fetch_verified "https://repo.maven.apache.org/maven2/org/projectlombok/lombok/$LOMBOK_VERSION/lombok-$LOMBOK_VERSION.jar" "$LOMBOK_JAR" && ok "скачан Lombok $LOMBOK_VERSION"
fi

# ── LemMinX (XML) ───────────────────────────────────────────────────────────
step "5. LemMinX $LEMMINX_VERSION (XML)"
LEMMINX_JAR="$HOME/.local/share/lemminx/org.eclipse.lemminx-$LEMMINX_VERSION-uber.jar"
LEMMINX_BIN="$HOME/.local/bin/lemminx"
if [ -f "$LEMMINX_JAR" ]; then ok "$LEMMINX_JAR"
else
  bad "нет $LEMMINX_JAR"
  doit && fetch_verified "https://repo.eclipse.org/content/repositories/lemminx-releases/org/eclipse/lemminx/org.eclipse.lemminx/$LEMMINX_VERSION/org.eclipse.lemminx-$LEMMINX_VERSION-uber.jar" "$LEMMINX_JAR" && ok "скачан lemminx"
fi
LEMMINX_WRAPPER="#!/bin/bash
# XML language server Eclipse LemMinX $LEMMINX_VERSION для agent-lsp (stdio). Создан setup-agent-env.
exec \"$JAVA_HOME_DETECTED/bin/java\" -Xmx256m -jar \"$LEMMINX_JAR\" \"\$@\""
# Рабочей считается обёртка, которая ссылается на нужный jar и на существующую java.
wrapper_ok() {
  [ -x "$LEMMINX_BIN" ] && grep -qF "$LEMMINX_JAR" "$LEMMINX_BIN" || return 1
  local java; java="$(grep -oE '/[^" ]*/bin/java' "$LEMMINX_BIN" | head -1)"
  [ -n "$java" ] && [ -x "$java" ]
}
if wrapper_ok; then ok "обёртка $LEMMINX_BIN"
else
  bad "обёртка $LEMMINX_BIN отсутствует или устарела"
  if doit; then mkdir -p "$(dirname "$LEMMINX_BIN")"; printf '%s\n' "$LEMMINX_WRAPPER" > "$LEMMINX_BIN"; chmod +x "$LEMMINX_BIN"; ok "записана обёртка"; fi
fi

# ── Хуки agent-lsp ──────────────────────────────────────────────────────────
step "6. Хуки agent-lsp (~/.claude/hooks/agent-lsp)"
HOOKS_DST="$HOME/.claude/hooks/agent-lsp"
for f in "$ASSETS"/hooks/agent-lsp/*; do
  dst="$HOOKS_DST/$(basename "$f")"
  if [ -f "$dst" ] && cmp -s "$f" "$dst"; then ok "$(basename "$f")"
  else
    bad "$(basename "$f") отсутствует или отличается от версии скилла"
    if doit; then mkdir -p "$HOOKS_DST"; [ -f "$dst" ] && cp "$dst" "$dst.bak"; cp "$f" "$dst"; chmod +x "$dst"; ok "скопирован $(basename "$f")"; fi
  fi
done

# ── settings.json ───────────────────────────────────────────────────────────
step "7. ~/.claude/settings.json: хуки, запреты, bashEditDiffEnabled"
SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || { doit && echo '{}' > "$SETTINGS"; }
# Слияние: добавляются только отсутствующие обработчики и запреты, остальное не трогается.
MERGE_FILTER='
  def ident: [(.matcher // ""), (.hooks | map(.command // ((.server // "") + ":" + (.tool // ""))) | join(","))] | tostring;
  $frag[0] as $f
  | .bashEditDiffEnabled = true
  | .permissions.deny = (((.permissions.deny // []) + $f.permissions.deny) | unique)
  | .hooks = reduce ($f.hooks | to_entries[]) as $e ((.hooks // {});
      .[$e.key] = ((.[$e.key] // []) as $cur
                   | $cur + [ $e.value[] | ident as $k | select(($cur | map(ident) | index($k)) == null) ]))'
if [ -f "$SETTINGS" ]; then
  MERGED="$(jq --slurpfile frag "$ASSETS/settings-fragment.json" "$MERGE_FILTER" "$SETTINGS")"
  if [ "$(jq -S . "$SETTINGS")" = "$(jq -S . <<<"$MERGED")" ]; then ok "всё на месте"
  else
    bad "не хватает хуков/запретов (будут добавлены, остальное не трогается)"
    if doit; then cp "$SETTINGS" "$SETTINGS.bak"; printf '%s\n' "$MERGED" > "$SETTINGS"; ok "обновлён (копия: settings.json.bak)"; fi
  fi
else bad "нет $SETTINGS"; fi

# ── MCP-серверы (уровень пользователя) ──────────────────────────────────────
step "8. MCP-серверы уровня пользователя"
AGENT_LSP_JSON="$(jq -nc \
  --arg cmd "$NPM_BIN/agent-lsp" \
  --arg java "java:$BREW_PREFIX/bin/jdtls,--jvm-arg=-javaagent:$LOMBOK_JAR" \
  --arg yaml "yaml:$NPM_BIN/yaml-language-server,--stdio" \
  --arg json "json:$NPM_BIN/vscode-json-language-server,--stdio" \
  --arg docker "dockerfile:$NPM_BIN/docker-langserver,--stdio" \
  --arg sql "sql:$BREW_PREFIX/bin/postgres-language-server,lsp-proxy" \
  --arg py "python:$NPM_BIN/pyright-langserver,--stdio" \
  --arg xml "xml:$LEMMINX_BIN" \
  '{type:"stdio",command:$cmd,args:[$java,$yaml,$json,$docker,$sql,$py,$xml],env:{}}')"
JARPEEK_JSON="$(jq -nc --arg cmd "$NPM_BIN/jarpeek" --arg jh "$JAVA_HOME_DETECTED" \
  '{type:"stdio",command:$cmd,args:["mcp"],env:{JAVA_HOME:$jh}}')"
POSTGRES_JSON="$(jq -nc --arg cmd "$NPX" --arg pkg "$POSTGRES_MCP_PKG" \
  '{type:"stdio",command:$cmd,args:["-y",$pkg,"run","--no-telemetry"],env:{POSTGRES_MCP_DISABLE_CWD_ACCESS:"1"}}')"

ensure_mcp() { # name json
  local name=$1 want=$2 have
  have="$(jq -c --arg n "$name" '.mcpServers[$n] // empty' "$HOME/.claude.json" 2>/dev/null)"
  if [ -n "$have" ] && [ "$(jq -S . <<<"$have")" = "$(jq -S . <<<"$want")" ]; then ok "$name"
  else
    bad "$name: ${have:+конфигурация отличается}${have:-не зарегистрирован}"
    if doit; then
      [ -n "$have" ] && claude mcp remove "$name" -s user >/dev/null 2>&1
      claude mcp add-json "$name" "$want" -s user >/dev/null && ok "зарегистрирован $name"
    fi
  fi
}
ensure_mcp agent-lsp "$AGENT_LSP_JSON"
ensure_mcp jarpeek "$JARPEEK_JSON"
ensure_mcp postgres "$POSTGRES_JSON"

# ── Конфликтующий плагин ────────────────────────────────────────────────────
step "9. Конфликты"
PLUGIN="$(jq -r '.plugins // {} | keys[] | select(startswith("jdtls-lsp@"))' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null)"
if [ -z "$PLUGIN" ]; then ok "плагин jdtls-lsp не установлен"
else
  bad "установлен $PLUGIN — его jdtls без Lombok портит target/classes"
  doit && claude plugin uninstall "$PLUGIN" >/dev/null && ok "удалён $PLUGIN"
fi

# ── Итог ────────────────────────────────────────────────────────────────────
step "Итог"
if [ "$MODE" = check ]; then
  [ "$PROBLEMS" -eq 0 ] && echo "Окружение настроено полностью." || echo "Найдено проблем: $PROBLEMS. Исправить: $0 apply"
else
  echo "Готово. Повторная проверка: $0 check. MCP-серверы подхватятся после /mcp или перезапуска Claude Code."
fi
[ "$MODE" = apply ] || [ "$PROBLEMS" -eq 0 ]
