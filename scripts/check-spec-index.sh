#!/usr/bin/env bash
# Проверяет specification/ на соответствие правилу .claude/rules/17-specification-files.md:
# у каждого .md есть тег своего раздела, в каждой папке есть index.md,
# каждый файл и подпапка упомянуты в index.md своей папки.
# Выводит нарушения построчно, код выхода 1 — если они есть.
set -u
ROOT="$(git rev-parse --show-toplevel)/specification"
cd "$ROOT" || exit 2
problems=0
report() { echo "$1"; problems=1; }

expected_tag() {
  case "$1" in
    ./index.md) echo "" ;;
    ./increment/*) echo "increment" ;;
    ./roadmap/*|./ideas.md) echo "tasks" ;;
    *) echo "specification" ;;
  esac
}

while IFS= read -r f; do
  tag="$(expected_tag "$f")"
  [ -z "$tag" ] && continue
  fm="$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1{print}' "$f")"
  echo "$fm" | grep -qE "^[[:space:]]*-[[:space:]]*${tag}[[:space:]]*$" \
    || report "нет тега '${tag}': ${f#./}"
done < <(find . -name '*.md' -not -path './.obsidian/*')

while IFS= read -r d; do
  idx="$d/index.md"
  if [ ! -f "$idx" ]; then report "нет index.md: ${d#./}/"; continue; fi
  for entry in "$d"/*; do
    name="$(basename "$entry")"
    [ "$name" = "index.md" ] && continue
    if [ -d "$entry" ]; then
      grep -qF "]($name/" "$idx" || report "папка не упомянута в ${idx#./}: $name/"
    elif [[ "$name" == *.md ]]; then
      grep -qF "]($name)" "$idx" || report "файл не упомянут в ${idx#./}: $name"
    fi
  done
done < <(find . -type d -not -path './.obsidian*')

exit $problems
