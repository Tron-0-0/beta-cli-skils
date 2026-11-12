#!/bin/bash
# Stop / SubagentStop: не даёт завершить работу, пока изменённые файлы не проверены get_diagnostics.
# Повторная остановка (stop_hook_active) пропускается с предупреждением пользователю — защита от цикла.
source "$(dirname "$0")/common.sh"
INPUT=$(cat)
dir=$(state_dir); [ -d "$dir" ] || exit 0

if [ "$(jq -r '.hook_event_name' <<<"$INPUT")" = "SubagentStop" ]; then
  lists="$dir/$(agent_key)"
else
  lists="$dir/*"
fi
pending=""
for s in $lists; do
  [ -f "$s" ] || continue
  while IFS= read -r f; do
    [ -f "$f" ] && pending="$pending- $f"$'\n'   # удалённые файлы не требуют проверки
  done < "$s"
done
if [ -z "$pending" ]; then
  if [ "$lists" = "$dir/*" ]; then rm -rf "$dir"; else rm -f "$lists"; fi
  exit 0
fi

if [ "$(jq -r '.stop_hook_active // false' <<<"$INPUT")" = "true" ]; then
  jq -n --arg p "$pending" '{systemMessage:("agent-lsp: агент завершил работу, не проверив файлы:\n" + $p)}'
  exit 0
fi
jq -n --arg p "$pending" '{decision:"block",
  reason:("Не проверены через agent-lsp изменённые файлы:\n" + $p
  + "Вызови mcp__agent-lsp__get_diagnostics с file_path для каждого и исправь ошибки, затем заверши работу.")}'
