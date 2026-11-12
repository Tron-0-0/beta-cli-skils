#!/bin/bash
# Общие функции хуков agent-lsp. Подключается через source; INPUT — JSON входа хука.
STATE_ROOT="${HOME}/.claude/state/agent-lsp-pending"

project_root() { printf '%s' "${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd' <<<"$INPUT")}"; }
state_dir()    { printf '%s/%s' "$STATE_ROOT" "$(jq -r '.session_id' <<<"$INPUT")"; }
agent_key()    { jq -r '.agent_id // "main"' <<<"$INPUT"; }

# Файл внутри проекта, который agent-lsp умеет диагностировать.
# Dockerfile не включён: docker-langserver диагностики не публикует. XML обслуживает lemminx.
is_lsp_file() {
  local f=$1 root
  root=$(project_root)
  case "$f" in "$root"/*) ;; *) return 1 ;; esac
  case "$f" in */target/*|*/.git/*|*/node_modules/*|*/build/*|*/.idea/*) return 1 ;; esac
  case "$f" in *.java|*.yaml|*.yml|*.json|*.sql|*.py|*.xml|*.xsd) [ -f "$f" ] ;; *) return 1 ;; esac
}
