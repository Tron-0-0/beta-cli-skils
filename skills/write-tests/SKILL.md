---
name: write-tests
description: Восьмой шаг пайплайна разработки — между verify-implementation (и последующей ручной правкой багов, если она понадобилась) и update-spec. Пишет unit-тесты для новой/изменённой бизнес-логики (`service.impl` или аналог по факту проекта) и прогоняет их — единственное место в пайплайне, где тесты вообще пишутся и запускаются. Использовать, когда пользователь просит "напиши тесты", "покрой тестами", "прогони тесты" для задачи, у которой уже есть verification-report.md с «Готово к finish-task: да». Не использовать для диагностики багов (это verify-implementation) и не использовать до того, как баги из verification-report.md закрыты.
---

# Написание и прогон тестов (verification → тесты)

Восьмой этап пайплайна: [`form-intent`](../form-intent/SKILL.md) → [`form-system-intent`](../form-system-intent/SKILL.md) → [`form-plan`](../form-plan/SKILL.md) → [`execute-plan`](../execute-plan/SKILL.md) → [`run-quality-gate`](../run-quality-gate/SKILL.md) → [`align-with-rules`](../align-with-rules/SKILL.md) → [`verify-implementation`](../verify-implementation/SKILL.md) → *(ручная правка багов, без отдельного шага)* → `write-tests` → [`update-spec`](../update-spec/SKILL.md) → [`finish-task`](../finish-task/SKILL.md).

Раньше в пайплайне тесты писались по ходу `execute-plan`, а сборка/тесты гонялись ещё и в `run-quality-gate`. Теперь это единственный шаг, который пишет и запускает тесты — `execute-plan` пишет только код, `run-quality-gate` проверяет только сборку и статический анализ, `verify-implementation` только читает код и запускает приложение вручную. Смысл переноса — не гонять один и тот же тестовый прогон трижды на коде, который ещё может измениться из-за багов, найденных на `verify-implementation`.

## Порядок действий

1. Определи директорию задачи и интеграционную ветку:
   ```bash
   PROJECT_ROOT=$(git rev-parse --show-toplevel)
   cd "$PROJECT_ROOT"
   RAW_VERSION=$(awk '/<\/parent>/{f=1} f && /<version>/{gsub(/<\/?version>/,""); print; exit}' pom.xml 2>/dev/null | xargs)
   VERSION="r${RAW_VERSION%-SNAPSHOT}"
   [ -z "$RAW_VERSION" ] && VERSION="r0"
   BRANCH=$(git branch --show-current)
   TASK_DIR="specification/increment/$VERSION/$BRANCH"
   ```
   Определи интеграционную ветку проекта (`INTEGRATION_BRANCH`) — обычно `develop`, если её нет локально — `main`/`master` (первая существующая из `git show-ref --verify --quiet refs/heads/<кандидат>`); если неочевидно — спроси пользователя один раз.

2. Прочитай `$TASK_DIR/verification-report.md`. Если файла нет — скажи, что сначала нужен `verify-implementation`, и не продолжай. Если строка `**Готово к finish-task:**` — «нет» — сообщи пользователю, что сначала нужно закрыть баги (ручной правкой в диалоге, без отдельного шага пайплайна), и не продолжай.

   Проверь `$TASK_DIR/pipeline-state.md`: если файла нет, или его «Текущий шаг» — не `write-tests` и не маркер `ручная правка багов (без отдельного шага пайплайна)` — предупреди пользователя о нестандартном состоянии (шаг вызван не по порядку пайплайна), но не блокируй — пользователь мог вызвать шаг напрямую осознанно.

3. Определи набор файлов бизнес-логики для проверки — тем же способом, что `run-quality-gate` (его шаг 4): базовая ветка сравнения — `$INTEGRATION_BRANCH`. Сначала проверь, что она существует локально (`git show-ref --verify --quiet refs/heads/$INTEGRATION_BRANCH`). Если существует:
   ```bash
   git diff --name-only $(git merge-base HEAD "$INTEGRATION_BRANCH") -- '**/service/impl/*.java'
   git status --porcelain -- '**/service/impl/*.java'
   ```
   (если фактический слой сервисной реализации проекта называется иначе — ориентируйся на реальную структуру `src/main/java`, а не на этот путь буквально). Это покрывает и код из `execute-plan`, и правки `align-with-rules`, и ручные правки багов после `verify-implementation` — без необходимости сверяться с несколькими отчётами по отдельности. Если ветки нет — спроси пользователя, какую считать базовой, прежде чем продолжать.

4. Для каждого найденного `<Класс>Impl.java`:
   - Проверь наличие `src/test/java/.../<Класс>ImplTest.java` (тот же пакет, суффикс `Test`).
   - Если теста нет — напиши его по правилу [`.claude/rules/08-tests.md`](../../rules/08-tests.md) (JUnit5, Mockito, `@DisplayName`, `@Nested`/`@ParameterizedTest` где уместно) и по образцу уже существующих тестов проекта, если такие уже появились к этому моменту. Если `src/test` всё ещё пуст — ориентируйся только на правило.
   - Если тест уже есть, но поведение класса менялось после его написания (правки `align-with-rules` или ручная правка багов после `verify-implementation`) — дополни/обнови существующий тест под новое поведение, не создавай рядом дублирующий.

5. Прогони:
   ```bash
   ./mvnw test
   ```
   Это первое и единственное место пайплайна, где тесты вообще запускаются — падения чинятся здесь же итеративно, не переносятся на следующие шаги.

6. Запиши `$TASK_DIR/write-tests-report.md` по шаблону ниже.

7. Спроси пользователя, завершён ли шаг (например: «Тесты написаны и проходят, коммитим?»). При отрицательном ответе — не коммитить, продолжить правки и спросить повторно. При положительном — обнови `$TASK_DIR/pipeline-state.md` (`write-tests` → `завершён`, `Текущий шаг` → `update-spec`) и закоммить тестовые файлы вместе с отчётом и состоянием одним коммитом:
   ```bash
   git add <тестовый_файл1> <тестовый_файл2> ... "$TASK_DIR/write-tests-report.md" "$TASK_DIR/pipeline-state.md"
   git commit -m "$(cat <<'EOF'
   Add tests: <короткое имя задачи>

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

8. Скажи пользователю, что тесты готовы и следующий шаг — `update-spec`.

## Шаблон `write-tests-report.md`

```markdown
# Отчёт о тестах: <короткое имя задачи>

- Ветка: <branch> / Версия: <version>
- Основано на: verification-report.md

## Классы бизнес-логики в скоупе задачи
- `<путь до ...Impl.java>` — тест новый / тест обновлён / тест уже покрывал актуальное поведение — `<путь до ...ImplTest.java>`

## Сборка и тесты
- `./mvnw test`: <результат, включая изначально упавшие тесты и как исправлены, если были>

## Незакрытые вопросы
- ...
```
