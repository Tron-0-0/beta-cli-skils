#!/bin/bash
# PostToolUse (mcp__agent-lsp__get_diagnostics): снимает проверенный файл с очереди.
# Вызов без file_path ничего не снимает: он показывает только открытые в LSP документы.
source "$(dirname "$0")/common.sh"
INPUT=$(cat)
f=$(jq -r '.tool_input.file_path // empty' <<<"$INPUT"); [ -n "$f" ] || exit 0
case "$f" in /*) ;; *) f="$(project_root)/$f" ;; esac
response=$(jq -r '.tool_response | tostring' <<<"$INPUT")
notes=""

# postgres-language-server 0.28.2 на корректных CREATE/INSERT/UPDATE отдаёт сбой декодирования
# собственного парсера. Это не ошибка в SQL — агент не должен её «исправлять».
if grep -q 'failed to decode Protobuf' <<<"$response"; then
  notes="Ошибки «Error decoding result: failed to decode Protobuf message» — сбой самого postgres-language-server, а не ошибка в SQL: игнорируй их и не меняй из-за них код. Настоящие синтаксические ошибки сервер сообщает как «Invalid statement: syntax error ...»."
fi

dir=$(state_dir)
queued=false
grep -qxF "$f" "$dir"/* 2>/dev/null && queued=true

# Сервер ещё не прислал диагностику (типично для первого открытия файла) — это не проверка.
if $queued && grep -q 'No diagnostics received' <<<"$response"; then
  notes="Сервер ещё не опубликовал диагностику для $f — повтори mcp__agent-lsp__get_diagnostics для этого файла. $notes"
elif $queued; then
  for s in "$dir"/*; do
    [ -f "$s" ] || continue
    grep -vxF "$f" "$s" > "$s.tmp"; mv "$s.tmp" "$s"
    [ -s "$s" ] || rm -f "$s"
  done
fi

[ -n "$notes" ] && jq -n --arg n "$notes" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$n}}'
exit 0
