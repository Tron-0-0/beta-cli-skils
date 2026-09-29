#!/usr/bin/env bash
# Копирует базовый .claude/{rules,skills,hooks,...} из репозитория-шаблона
# в целевой проект, никогда не трогая уже существующие файлы.
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/Tron-0-0/beta-cli-skils.git"
REPO_URL="$DEFAULT_REPO_URL"
TARGET_DIR="."

usage() {
  cat >&2 <<EOF
Использование: $0 [target_project_dir] [--repo <git-url>]

target_project_dir  Каталог проекта, в котором нужно завести/дополнить .claude
                     (по умолчанию — текущий каталог).
--repo <git-url>     Альтернативный репозиторий-источник вместо
                     $DEFAULT_REPO_URL
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || usage
      REPO_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Ошибка: каталог проекта не найден: $TARGET_DIR" >&2
  exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
CLAUDE_DIR="$TARGET_DIR/.claude"
mkdir -p "$CLAUDE_DIR"

TMP_CLONE="$(mktemp -d)"
trap 'rm -rf "$TMP_CLONE"' EXIT

echo "Клонирую $REPO_URL..." >&2
git clone --depth 1 --quiet "$REPO_URL" "$TMP_CLONE"

ADDED=()
SKIPPED=()
HOOKS_ADDED=0

for src_dir in "$TMP_CLONE"/*/; do
  name="$(basename "$src_dir")"
  # Пропускаем служебные каталоги репозитория (.git уже вне src_dir, .idea и т.п.)
  [[ "$name" == .* ]] && continue

  dest_dir="$CLAUDE_DIR/$name"
  mkdir -p "$dest_dir"

  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir"}"
    base="$(basename "$rel")"
    # Служебный файловый мусор (.DS_Store и т.п.), а не содержимое шаблона
    [[ "$base" == .* ]] && continue

    dest_file="$dest_dir/$rel"
    if [[ -e "$dest_file" ]]; then
      SKIPPED+=(".claude/$name/$rel")
    else
      mkdir -p "$(dirname "$dest_file")"
      cp "$file" "$dest_file"
      ADDED+=(".claude/$name/$rel")
      [[ "$name" == "hooks" ]] && HOOKS_ADDED=1
    fi
  done < <(find "$src_dir" -type f -print0)
done

echo ""
echo "Добавлено файлов: ${#ADDED[@]}"
if [[ ${#ADDED[@]} -gt 0 ]]; then
  for f in "${ADDED[@]}"; do echo "  + $f"; done
fi

echo ""
echo "Пропущено (уже существуют в проекте, не тронуты): ${#SKIPPED[@]}"
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  for f in "${SKIPPED[@]}"; do echo "  = $f"; done
fi

if [[ "$HOOKS_ADDED" -eq 1 ]]; then
  echo ""
  echo "ВНИМАНИЕ: добавлены .sh файлы хуков, но settings.json проекта не менялся." >&2
  echo "Сами по себе эти скрипты не выполняются — их нужно отдельно прописать" >&2
  echo "в .claude/settings.json (событие + команда), например через скилл update-config." >&2
fi
