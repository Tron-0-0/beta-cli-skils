#!/bin/bash
# PostToolUse (Edit|Write|MultiEdit|Bash|правки agent-lsp): ставит изменённые файлы
# в очередь на проверку get_diagnostics и напоминает агенту её выполнить.
source "$(dirname "$0")/common.sh"
INPUT=$(cat)

[ "$(jq -r '.tool_input.dry_run // false' <<<"$INPUT")" = "true" ] && exit 0

files=$(jq -r '
  [ .tool_input.file_path?,
    (.tool_response | objects | .filePath?),
    (.tool_response | objects | .bashEditDiff?
       | if type == "string" then (try fromjson catch null) else . end
       | objects | .changedFiles? // [] | .[]),
    (.tool_input.workspace_edit? | objects
       | ((.changes? // {} | keys[]), (.documentChanges? // [] | .[] | .textDocument?.uri?))
       | strings | sub("^file://"; "") | @text)
  ] | map(strings) | unique | .[]' <<<"$INPUT" 2>/dev/null)

dir=$(state_dir); key=$(agent_key); added=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  f=$(printf '%b' "${f//%/\\x}")          # декодирование %20 и т.п. из URI
  is_lsp_file "$f" || continue
  mkdir -p "$dir"
  grep -qxF "$f" "$dir/$key" 2>/dev/null || printf '%s\n' "$f" >> "$dir/$key"
  added="$added- $f"$'\n'
done <<<"$files"

[ -n "$added" ] || exit 0
extra=""
case "$(jq -r '.tool_name' <<<"$INPUT")" in
  mcp__agent-lsp__rename_symbol)
    extra=" rename_symbol мог затронуть и другие файлы — проверь их тоже." ;;
  Bash)
    # Edit/Write закрывает документ хук mcp_tool; после Bash серверы (JSON, jdtls) могут держать
    # старое содержимое и отвечать устаревшей диагностикой.
    extra=" Файлы изменены командой Bash: перед get_diagnostics вызови mcp__agent-lsp__close_document для каждого, иначе диагностика может оказаться устаревшей." ;;
esac
jq -n --arg files "$added" --arg extra "$extra" '{hookSpecificOutput:{hookEventName:"PostToolUse",
  additionalContext:("Изменены файлы, которые проверяет agent-lsp:\n" + $files
  + "Вызови mcp__agent-lsp__get_diagnostics с file_path для каждого (схему загрузи через ToolSearch, если ещё не загружена) и исправь ошибки. Пока файлы не проверены, завершить работу не получится. Ложные ошибки Lombok сверяй сборкой Maven." + $extra)}}'
