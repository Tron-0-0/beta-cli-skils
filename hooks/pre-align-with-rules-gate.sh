#!/usr/bin/env bash
# PreToolUse-хук: блокирует вызов Skill(align-with-rules) в режиме пайплайна,
# пока для текущей задачи не пройден run-quality-gate на актуальном коммите.
set -euo pipefail

PAYLOAD=$(cat)

TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty')
SKILL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_input.skill // empty')

if [[ "$TOOL_NAME" != "Skill" || "$SKILL_NAME" != "align-with-rules" ]]; then
  exit 0
fi

RAW_VERSION=$(awk '/<\/parent>/{f=1} f && /<version>/{gsub(/<\/?version>/,""); print; exit}' pom.xml | xargs)
VERSION="r${RAW_VERSION%-SNAPSHOT}"
BRANCH=$(git branch --show-current)
TASK_DIR="specification/increment/$VERSION/$BRANCH"

# Нет execution-report.md — это не задача пайплайна на текущей ветке,
# align-with-rules вызывается в самостоятельном режиме, гейт не применяется.
if [[ ! -f "$TASK_DIR/execution-report.md" ]]; then
  exit 0
fi

REPORT="$TASK_DIR/quality-gate-report.md"

if [[ ! -f "$REPORT" ]]; then
  echo "run-quality-gate ещё не запускался для этой задачи ($TASK_DIR). Сначала вызови Skill(run-quality-gate)." >&2
  exit 2
fi

VERDICT=$(grep -A1 '^## Итог' "$REPORT" | tail -n1 | xargs)
REPORT_COMMIT=$(grep -m1 '^- Ветка / Версия / Коммит:' "$REPORT" | awk -F'/' '{print $NF}' | xargs)
CURRENT_COMMIT=$(git rev-parse HEAD)
# Свежесть гейта проверяется только по *.java (компилируемый/тестируемый код) и .claude/
# (правила/скиллы пайплайна). Правки ресурсов (application.properties, YAML и т.п.) не
# требуют пересборки/перезапуска тестов сами по себе, поэтому не считаются основанием
# для повторного run-quality-gate.
DIRTY=$(git status --porcelain -- '**/*.java' .claude/)

if [[ "$VERDICT" != "PASS" ]]; then
  echo "run-quality-gate для задачи ($TASK_DIR) завершился с итогом '$VERDICT'. Сначала исправь проблемы и повтори Skill(run-quality-gate)." >&2
  exit 2
fi

if ! git merge-base --is-ancestor "$REPORT_COMMIT" "$CURRENT_COMMIT" 2>/dev/null; then
  echo "run-quality-gate проверял коммит $REPORT_COMMIT, которого нет в истории текущей ветки. Сначала повтори Skill(run-quality-gate)." >&2
  exit 2
fi

if ! git diff --quiet "$REPORT_COMMIT" "$CURRENT_COMMIT" -- '**/*.java' .claude/; then
  echo "*.java или .claude/ менялись после run-quality-gate (коммит $REPORT_COMMIT). Сначала повтори Skill(run-quality-gate)." >&2
  exit 2
fi

if [[ -n "$DIRTY" ]]; then
  echo "В *.java или .claude/ есть незакоммиченные изменения после последней проверки run-quality-gate. Сначала закоммить их и повтори Skill(run-quality-gate)." >&2
  exit 2
fi

exit 0
