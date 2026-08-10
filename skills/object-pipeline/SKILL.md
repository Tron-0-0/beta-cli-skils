---
name: object-pipeline
version: 1.0.0
description: Оркестратор pipeline-конвейера инкрементальной реализации. Определяет текущий шаг по наличию файлов-артефактов, запускает ОДИН скилл без автоматического перехода к следующему шагу. Поддерживает multi-user сценарий (git push/pull + Jira для передачи между людьми).
user-invocable: false
---

# Object Pipeline — State Machine для инкрементальной реализации

> **Версия:** 1.0.0  
> **Тип:** Helper / Orchestrator  
> **Назначение:** Маршрутизация pipeline-конвейера по наличию файлов-артефактов

## Важно

- **State machine по файлам:** Определение текущего шага — по наличию файлов-артефактов из "Карты артефактов шагов". Не по номерам шагов.
- **Manual transitions:** НЕ выполняй автоматический переход к следующему шагу. Каждый шаг = отдельная сессия GigaCode.
- **Multi-user:** Каждый шаг может быть запущен любым авторизованным пользователем. Передача между людьми через git push/pull + Jira.
- **Флаги:** `--status` — показать прогресс без запуска, `--step N` — принудительный запуск конкретного шага.


## Карта артефактов шагов

| Скилл | Артефакт | Путь | Порядок |
|-------|----------|------|---------|
| spec-intent-generation (Шаг 1) | `intent.md` | `specification/increment/{release}/{ticket}/intent.md` | 1 |
| spec-increment-from-task (Шаг 2) | `increment.md` | `specification/increment/{release}/{ticket}/increment.md` | 2 |
| spec-increment-plan (Шаг 3) | `implementation-plan.md` | `specification/increment/{release}/{ticket}/implementation-plan.md` | 3 |
| spec-increment-implement (Шаг 4) | `implementation-report.md` | `specification/increment/{release}/{ticket}/implementation-report.md` | 4 |
| spec-increment-review (Шаг 5) | `review-report.md` | `specification/increment/{release}/{ticket}/review-report.md` | 5 |
| spec-increment-test (Шаг 6) | `test-report.md` | `specification/increment/{release}/{ticket}/test-report.md` | 6 |
| spec-increment-actualize (Шаг 7) | `specification/absolut/` обновлён | `specification/absolut/index.md` | 7 (финальный) |

## Mapping скиллов по артефактам

| Есть файл | Следующий шаг | Скилл | Команда |
|-----------|---------------|-------|---------|
| Нет `intent.md` | Шаг 1 | spec-intent-generation | `/pipeline --step 1` или `/pipeline --auto` |
| Есть `intent.md`, нет `increment.md` | Шаг 2 | spec-increment-from-task | `/pipeline --step 2` или `/pipeline --auto` |
| Есть `increment.md`, нет `implementation-plan.md` | Шаг 3 | spec-increment-plan | `/pipeline --step 3` или `/pipeline --auto` |
| Есть `implementation-plan.md`, нет `implementation-report.md` | Шаг 4 | spec-increment-implement | `/pipeline --step 4` или `/pipeline --auto` |
| Есть `implementation-report.md`, нет `review-report.md` | Шаг 5 | spec-increment-review | `/pipeline --step 5` или `/pipeline --auto` |
| Есть `review-report.md`, нет `test-report.md` | Шаг 6 | spec-increment-test | `/pipeline --step 6` или `/pipeline --auto` |
| Есть `test-report.md` | Шаг 7 | spec-increment-actualize | `/pipeline --step 7` или `/pipeline --auto` |
| Всё выполнено | Финал | — | `/pipeline --status` → "✅ Pipeline завершён" |

## Шаг 0. Определить {release} и {ticket}

1. Проверить аргументы `$ARGUMENTS`:
   - Если формат `{ticket}` → `{ticket} = {ticket}`, `{release} = "01.000.02"` (default)
   - Если формат `{release}/{ticket}` → извлечь оба
   - Если просто число → `{ticket} = PROJ-{число}`, `{release} = "01.000.02"`
2. Если аргументов нет → определить из имени текущей ветки:
   - Regex: `^.*-(PROJ-\d+).*` → `{ticket} = PROJ-XXX`
   - Regex: `^(\d+\.\d+\.\d+)-.*` → `{release} = X.Y.Z`
   - Default release: `"01.000.02"`
3. Если ничего не найдено → остановиться с сообщением:
   ```
   ⛔ Не определены {release} и {ticket}.
   Используйте: /pipeline PROJ-123 или /pipeline 01.000.02/PROJ-123
   Или убедитесь, что имя ветки содержит ключ тикета (например: feature/PROJ-123-my-feature)
   ```

## Шаг 1. State machine — проверить файлы-артефакты

1. Определить базовый путь: `specification/increment/{release}/{ticket}/`
2. Выполнить Glob для проверки наличия файлов:
   ```
   Glob specification/increment/{release}/{ticket}/intent.md
   Glob specification/increment/{release}/{ticket}/increment.md
   Glob specification/increment/{release}/{ticket}/implementation-plan.md
   Glob specification/increment/{release}/{ticket}/implementation-report.md
   Glob specification/increment/{release}/{ticket}/review-report.md
   Glob specification/increment/{release}/{ticket}/test-report.md
   ```
3. Заполнить статус:
   ```
   [x] intent.md        - {существует/отсутствует}
   [x] increment.md     - {существует/отсутствует}
   [x] implementation-plan.md - {существует/отсутствует}
   [x] implementation-report.md - {существует/отсутствует}
   [x] review-report.md - {существует/отсутствует}
   [x] test-report.md   - {существует/отсутствует}
   ```
4. Определить текущий шаг (первый отсутствующий файл):
   - Если `intent.md` отсутствует → Шаг 1 (spec-intent-generation)
   - Если `increment.md` отсутствует → Шаг 2 (spec-increment-from-task)
   - Если `implementation-plan.md` отсутствует → Шаг 3 (spec-increment-plan)
   - Если `implementation-report.md` отсутствует → Шаг 4 (spec-increment-implement)
   - Если `review-report.md` отсутствует → Шаг 5 (spec-increment-review)
   - Если `test-report.md` отсутствует → Шаг 6 (spec-increment-test)
   - Если все 6 файлов существуют → Шаг 7 (spec-increment-actualize)
   - Если `specification/absolut/` обновлён → Финал

## Шаг 2. Показать прогресс

1. Отобразить состояние:
   ```
   ## Pipeline Progress: {release}/{ticket}

   ### Текущий статус
   - Артефакты: [3/6] выполнено
   - Текущий шаг: Шаг 3 (spec-increment-plan)
   - Следующий шаг: spec-increment-plan

   ### Детальный прогресс
   [x] intent.md        ✅ Создан
   [x] increment.md     ✅ Создан
   [ ] implementation-plan.md  ❌ Требуется создание
   [ ] implementation-report.md  ⏸ Не начат
   [ ] review-report.md  ⏸ Не начат
   [ ] test-report.md   ⏸ Не начат
   ```
2. Отобразить рекомендации:
   ```
   ### Рекомендации
   1. Запустить Шаг 3: /pipeline {ticket} --step 3
   2. Или авто-определение: /pipeline {ticket} --auto
   3. Для проверки статуса: /pipeline {ticket} --status
   ```

## Шаг 3. Запустить нужный скилл (один раз, БЕЗ auto-transition)

> **ВАЖНО:** Запускать ТОЛЬКО один скилл. НЕ проверять наличие артефактов следующего шага и НЕ запускать автоматический переход.

1. Определить целевой скилл (по текущему шагу из Шага 2 или по `--step N`):
   - Шаг 1 → spec-intent-generation
   - Шаг 2 → spec-increment-from-task
   - Шаг 3 → spec-increment-plan
   - Шаг 4 → spec-increment-implement
   - Шаг 5 → spec-increment-review
   - Шаг 6 → spec-increment-test
   - Шаг 7 → spec-increment-actualize
2. Запустить выбранный скилл:
   - Вызвать `/spec-increment-{name} {ticket}` (или `{release}/{ticket}`)
   - Или передать контекст через subagent с промптом, содержащим SKILL.md целевого скилла
3. После выполнения → **ОСТАНОВИТЬСЯ**. НЕ проверять наличие следующего артефакта и НЕ запускать следующий шаг.

## Шаг 4. Показать результат и что делать дальше

1. Отобразить результат:
   ```
   ## Результат: Шаг {N} завершён

   ### Изменения
   - Создан/обновлён: {артефакт}
   - Путь: {full_path}

   ### Что делать дальше
   1. Проверить изменения: `git diff` / `git status`
   2. Закоммитить: `git add . && git commit -m "feat: {ticket} - {название шага}"`
   3. Передать следующему человеку: `git push`
   4. Проверить статус: `/pipeline {ticket} --status`
   ```
2. Предложить следующий шаг:
   ```
   ### Следующий шаг
   - Текущий прогресс: [{N+1}/6]
   - Скилл: {название следующего скилла}
   - Команда: `/pipeline {ticket} --step {N+1}`
   ```
3. **ОСТАНОВИТЬСЯ**. Не запускать автоматический переход.

---

## Режимы запуска

### По умолчанию (interact mode)

```bash
/pipeline PROJ-123
→ Шаг 1: State machine check
→ Шаг 2: Показ прогресса
→ Шаг 3: Запуск одного скилла (step 3)
→ Шаг 4: Результат + рекомендации
→ ОСТАНОВКА
```

### Только статус (no-run mode)

```bash
/pipeline PROJ-123 --status
→ Шаг 1: State machine check
→ Шаг 2: Показ прогресса
→ ОСТАНОВКА (скилл НЕ запускается)
```

### Принудительный шаг (force step mode)

```bash
/pipeline PROJ-123 --step 5
→ Шаг 0: Определить {release}/{ticket}
→ Шаг 2: Показ прогресса (игнорирует state machine)
→ Шаг 3: Запуск spec-increment-review (step 5)
→ Шаг 4: Результат + рекомендации
→ ОСТАНОВКА
```

### Batch mode (все шаги подряд, с подтверждением)

```bash
/pipeline PROJ-123 --batch
→ Шаг 1: State machine check
→ Шаг 2: Показ прогресса
→ Шаг 3: Запуск одного скилла
→ Шаг 4: Результат + "Продолжить следующий шаг? [y/N]"
→ Если y → возврат к Шагу 1
→ Если N → ОСТАНОВКА
```

---

## Примеры использования

### Сценарий 1: Аналитик запускает Шаг 1

```bash
# Аналитик: /pipeline PROJ-123
→ State machine: intent.md отсутствует
→ Текущий шаг: Шаг 1 (spec-intent-generation)
→ Запускаю spec-intent-generation...
→ intent.md создан
→ "Проверь изменения, закоммить, передай следующему"
```

### Сценарий 2: Разработчик запускает Шаг 3

```bash
# Разработчик: git pull, /pipeline PROJ-123 --status
→ [x] intent.md ✅
→ [x] increment.md ✅
→ [ ] implementation-plan.md ❌
→ Текущий шаг: Шаг 3 (spec-increment-plan)
→ Команда: /pipeline PROJ-123 --step 3
→ ...
→ implementation-plan.md создан
→ "Проверь изменения, закоммить, передай следующему"
```

### Сценарий 3: Код-ревьюер запускает Шаг 5

```bash
# Код-ревьюер: git pull, /pipeline PROJ-123
→ [x] intent.md ✅
→ [x] increment.md ✅
→ [x] implementation-plan.md ✅
→ [x] implementation-report.md ✅
→ [ ] review-report.md ❌
→ Текущий шаг: Шаг 5 (spec-increment-review)
→ Запускаю spec-increment-review...
→ review-report.md создан
→ "Проверь изменения, закоммить, передай следующему"
```

### Сценарий 4: Тестировщик запускает Шаг 6

```bash
# Тестировщик: /pipeline PROJ-123
→ [x] intent.md ✅
→ [x] increment.md ✅
→ [x] implementation-plan.md ✅
→ [x] implementation-report.md ✅
→ [x] review-report.md ✅
→ [ ] test-report.md ❌
→ Текущий шаг: Шаг 6 (spec-increment-test)
→ Запускаю spec-increment-test...
→ test-report.md создан
→ "Проверь изменения, закоммить, передай следующему"
```

### Сценарий 5: DevOps запускает Шаг 7 (actualize)

```bash
# DevOps: /pipeline PROJ-123
→ [x] intent.md ✅
→ [x] increment.md ✅
→ [x] implementation-plan.md ✅
→ [x] implementation-report.md ✅
→ [x] review-report.md ✅
→ [x] test-report.md ✅
→ Текущий шаг: Шаг 7 (spec-increment-actualize)
→ Запускаю spec-increment-actualize...
→ specification/absolut/ обновлён
→ "Pipeline завершён! Инкремент закрыт."
```

---

## Интеграция с Jira (опционально)

> ⚠️ **NOT IMPLEMENTED YET** — future work

### Концепция передачи между пользователями

1. **Шаг N выполнен:**
   - Object-pipeline создаёт/обновляет Jira issue:
     ```json
     {
       "key": "PROJ-123",
       "status": "in-progress",
       "current-step": 3,
       "last-completed-by": "analyst@example.com",
       "next-assignee": "dev@example.com"
     }
     ```
2. **Другой пользователь:**
   - Получает уведомление (email / Jira / Slack)
   - Запускает: `/pipeline PROJ-123 --status`
   - Видит: "Текущий шаг: Шаг 3 (spec-increment-plan)"
   - Запускает: `/pipeline PROJ-123 --step 3`

3. **Гипотетическое расширение:**
   ```bash
   /pipeline PROJ-123 --transfer dev@example.com
   → Обновить Jira: next-assignee = dev@example.com
   → Отправить уведомление
   → Добавить комментарий в Jira
   ```

---

## Ограничения

| Ограничение | Описание | Обходной путь |
|-------------|----------|---------------|
| Нет auto-transition | Pipeline НЕ переходит автоматически к следующему шагу | Запускать `/pipeline --auto` каждый раз |
| Нет parallel execution | Каждый шаг выполняется последовательно | git push/pull для передачи между людьми |
| Нет встроенной авторизации | Не проверяет, кто запускает шаг | Передача через Jira / git commit author |
| Нет notifications | Не отправляет уведомления о завершении шага | Внешняя интеграция с Jira/Slack/email |

## Зависимости

- **7 pipeline скиллов:** spec-intent-generation, spec-increment-from-task, spec-increment-plan, spec-increment-implement, spec-increment-review, spec-increment-test, spec-increment-actualize
- **State machine файлы:** `specification/increment/{release}/{ticket}/{artifact}`
- **Git:** git add, git commit, git push, git pull
- **Jira (опционально):** Jira API для передачи между пользователями

---

**Текущий статус:** v1.0.0 — state machine + manual transitions + multi-user support
