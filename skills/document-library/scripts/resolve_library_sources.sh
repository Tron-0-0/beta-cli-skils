#!/usr/bin/env bash
# Находит и распаковывает материалы для анализа Java-библиотеки по Maven-координате,
# перебирая уровни детализации от лучшего к худшему:
#   sources  — реальный исходный код (лучший источник для внутренней механики)
#   javadoc  — только описания API, без тела методов
#   bytecode — только сигнатуры (javap), когда ни sources, ни javadoc не опубликованы
#
# Использование:
#   resolve_library_sources.sh <groupId:artifactId:version> <output_dir>
#
# Печатает в stdout строки TIER=<sources|javadoc|bytecode|none> и PATH=<каталог с результатом>.
# TIER сообщает вызывающему скиллу, на какую глубину можно рассчитывать при анализе:
# если TIER=bytecode или TIER=none, внутреннюю механику нужно достраивать через
# WebSearch/WebFetch по документации/репозиторию библиотеки, а не выдумывать её из сигнатур.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Использование: $0 <groupId:artifactId:version> <output_dir>" >&2
  exit 2
fi

COORD="$1"
OUT="$2"
IFS=':' read -r GROUP ARTIFACT VERSION <<< "$COORD"

if [[ -z "$GROUP" || -z "$ARTIFACT" || -z "$VERSION" ]]; then
  echo "Координата должна быть вида groupId:artifactId:version, получено: $COORD" >&2
  exit 2
fi

mkdir -p "$OUT"
GROUP_PATH="$(echo "$GROUP" | tr '.' '/')"
REPO_DIR="$HOME/.m2/repository/$GROUP_PATH/$ARTIFACT/$VERSION"

fetch_classifier() {
  local classifier="$1"
  mvn -q dependency:get -Dartifact="$GROUP:$ARTIFACT:$VERSION:jar:$classifier" >/dev/null 2>&1 || return 1
  find "$REPO_DIR" -maxdepth 1 -name "*-${classifier}.jar" 2>/dev/null | head -n1
}

jar_path="$(fetch_classifier sources || true)"
if [[ -n "$jar_path" ]]; then
  mkdir -p "$OUT/sources"
  unzip -oq "$jar_path" -d "$OUT/sources"
  echo "TIER=sources"
  echo "PATH=$OUT/sources"
  exit 0
fi

jar_path="$(fetch_classifier javadoc || true)"
if [[ -n "$jar_path" ]]; then
  mkdir -p "$OUT/javadoc"
  unzip -oq "$jar_path" -d "$OUT/javadoc"
  echo "TIER=javadoc"
  echo "PATH=$OUT/javadoc"
  exit 0
fi

mvn -q dependency:get -Dartifact="$GROUP:$ARTIFACT:$VERSION" >/dev/null 2>&1 || true
main_jar="$(find "$REPO_DIR" -maxdepth 1 -name "${ARTIFACT}-${VERSION}.jar" 2>/dev/null | head -n1)"
if [[ -n "$main_jar" ]]; then
  mkdir -p "$OUT/classes"
  unzip -oq "$main_jar" -d "$OUT/classes"
  api_summary="$OUT/api-summary.txt"
  : > "$api_summary"
  while IFS= read -r class_file; do
    class_name="${class_file#"$OUT"/classes/}"
    class_name="${class_name%.class}"
    class_name="${class_name//\//.}"
    [[ "$class_name" == *'$'* ]] && continue
    javap -classpath "$main_jar" "$class_name" >> "$api_summary" 2>/dev/null || true
    echo >> "$api_summary"
  done < <(find "$OUT/classes" -name '*.class')
  echo "TIER=bytecode"
  echo "PATH=$api_summary"
  echo "JAR=$main_jar"
  exit 0
fi

echo "TIER=none"
exit 1
