# Компоненты окружения агента

Справка к `setup-agent-env`: что ставится, откуда, почему именно так и какие проблемы
известны. Читай, когда `setup.sh` сообщает о проблеме, которую не исправляет сам,
или когда нужно обновить версию компонента.

## Состав

| Компонент | Откуда | Версия | Зачем |
|---|---|---|---|
| agent-lsp | npm `@blackwell-systems/agent-lsp` | 0.24.2 | MCP-сервер: диагностика, навигация, рефакторинг через LSP |
| jdtls | Homebrew `jdtls` | любая | Java; запускается с `-javaagent` Lombok |
| Lombok | Maven Central → `~/.m2` | 1.18.46 | агент для jdtls, иначе ложные ошибки на `@Getter`, `@Slf4j` и т.п. |
| yaml-language-server | npm | 2.0.0 | YAML (application.yaml, changelog Liquibase, compose) |
| vscode-json-language-server | npm `vscode-langservers-extracted` | 4.10.0 | JSON |
| docker-langserver | npm `dockerfile-language-server-nodejs` | 0.15.0 | Dockerfile (диагностику не публикует, см. ниже) |
| postgres-language-server | Homebrew | 0.28.2 | SQL (есть ложные ошибки, см. ниже) |
| pyright | npm | 1.1.414 | Python |
| LemMinX | repo.eclipse.org, uber-jar + обёртка `~/.local/bin/lemminx` | 0.31.2 | XML/XSD (pom.xml) |
| jarpeek | npm `jarpeek` | 0.4.8 | MCP-сервер: исходники классов из зависимостей Maven; нужен `JAVA_HOME` |
| postgres MCP | npm `@microsoft/postgres-mcp` (через npx) | 0.3.0 | MCP-сервер: запросы к БД, профиль на каждую БД |
| хуки agent-lsp | `assets/hooks/agent-lsp` → `~/.claude/hooks/agent-lsp` | — | заставляют проверять правленые файлы |

Версии закреплены, потому что именно этот набор проверен вместе. Переопределить —
переменными окружения `setup.sh` (`AGENT_LSP_VERSION`, `PYRIGHT_VERSION`,
`LEMMINX_VERSION`, `LOMBOK_VERSION`, `POSTGRES_MCP_VERSION` и т.д.). После обновления
прогони проверку серверов из SKILL.md.

## Принятые решения

- **Все MCP-серверы — на уровне пользователя** (`claude mcp … -s user`), подключения к БД —
  отдельными профилями postgres-mcp. Так решил пользователь: один сервер на все проекты.
- **Lombok-версия в агенте jdtls одна на всех.** Хук `env-check.py` при старте сессии
  сравнивает её с версией проекта (pom.xml или BOM Spring Boot) и предупреждает о расхождении.
  Тогда: `LOMBOK_VERSION=<версия> setup.sh apply`.
- **Плагин Claude Code `jdtls-lsp` запрещён.** Он запускает jdtls без Lombok в тот же
  `target/classes`, что и Maven, и заменяет классы заглушками: приложение падает с
  `Unresolved compilation problem` при зелёной сборке. `setup.sh` удаляет его.
- **postgres MCP только на чтение.** Профиль `access_mode: ro` плюс запрет в
  `settings.json` на `postgres_mcp_modify`, `bulk_load_csv`, `add_connection`,
  `remove_connection` — чтобы агент не мог ни писать, ни снять ограничение, пересоздав
  профиль. `POSTGRES_MCP_DISABLE_CWD_ACCESS=1` закрывает чтение файлов через CSV-инструменты.
  Отдельной роли PostgreSQL только на чтение нет (выбор пользователя).
- **Хуки agent-lsp:**
  - `track-edit.sh` ставит правленые файлы проекта (`.java .yaml .yml .json .sql .py .xml .xsd`)
    в очередь `~/.claude/state/agent-lsp-pending/<session>/`; правки через Bash берутся из
    `bashEditDiff` (поэтому `bashEditDiffEnabled: true`);
  - хук `mcp_tool` вызывает `close_document` после Edit/Write: иначе JSON-сервер и jdtls
    отдают диагностику старой версии файла;
  - `clear-checked.sh` снимает файл с очереди после `get_diagnostics` с `file_path`;
  - `stop-gate.sh` не даёт завершить работу (и субагенту), пока очередь не пуста;
  - `env-check.py` при старте сессии проверяет бинарники, Lombok, плагин `jdtls-lsp`.

## Известные проблемы

- **postgres-language-server 0.28.2** на корректных `CREATE`/`INSERT`/`UPDATE` выдаёт
  `Error decoding result: failed to decode Protobuf message` — сбой самого сервера.
  Настоящие ошибки приходят как `Invalid statement: syntax error ...`. Хук подсказывает
  агенту это различие. Проверить, исправлено ли в новой версии: `brew upgrade
  postgres-language-server` и диагностика `CREATE TABLE t (id BIGINT);`.
- **docker-langserver** диагностику не публикует; Dockerfile в хуки не включён.
- **Java вне classpath проекта** (например, в `sandbox/`) jdtls проверяет только на синтаксис.
- **Первый `get_diagnostics`** для свежеоткрытого файла может ответить «No diagnostics
  received» — повторить; хук такой ответ проверкой не считает.
- **pom.xml при первом открытии** может дать временную `cvc-elt.1.a`, пока lemminx скачивает
  XSD Maven в `~/.lemminx/cache`.
- **Postgres MCP Pro (crystaldba `postgres-mcp`)** из PyPI не ставится: исчезла его
  зависимость `pglast==7.2.0`. Поэтому используется сервер Microsoft.

## Что не автоматизировано

- Homebrew, Claude Code CLI и вход в аккаунт — ставятся вручную до запуска скилла.
- Docker Desktop — нужен для локальных БД проектов, ставится вручную.
- Секреты проектов (`~/.config/<проект>/*.env`) в репозитории не хранятся — их нужно
  перенести со старого компьютера (или из менеджера паролей) до создания профилей БД.
