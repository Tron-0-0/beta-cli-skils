---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Миграции БД (Liquibase и т.д.) (profitcontr-objects)

**Когда читать:** При изменении схемы БД, добавлении миграций, или review миграционных скриптов.

**Что описывает:** Liquibase changelog, версионирование, структура папок таблиц, rollback.

**Глобальный эталон:** `rules/03_migrations.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Корневой master changelog

Liquibase настроен в `objects/src/main/resources/application.properties`:
- `spring.liquibase.change-log=classpath:/db/changelog/0001_changelog.xml`
- `spring.liquibase.enabled=${LIQUIBASE_ENABLED:false}` — по умолчанию выключено, включается переменной окружения
- `spring.liquibase.default-schema=${DB_SCHEMA}` — схема из окружения

Корневой changelog `objects/src/main/resources/db/changelog/0001_changelog.xml` содержит `<include>` на версионный `changelog.xml`:

```xml
<include file="/v1.0.2/changelog.xml" relativeToChangelogFile="true"/>
```

### 1.2 Версионирование: версия = версия проекта из pom.xml

Папки версий в `db/changelog/` соответствуют **текущей версии проекта** из `<version>` в `pom.xml` (например `1.0.2-SNAPSHOT` → папка `v1.0.2/`). При обновлении версии проекта создаётся новая папка версии (например `v1.0.3/`), а старая не удаляется.

Версионный `changelog.xml` (например `v1.0.2/changelog.xml`) подключает папки таблиц, которые затронуты в этой версии:

```xml
<databaseChangeLog ... logicalFilePath="v1.0.2">
    <include file="service/2026-07-28_01_init-migration-service.sql" relativeToChangelogFile="true"/>
    <include file="partner/2026-07-07_02_add-new-column.sql" relativeToChangelogFile="true"/>
</databaseChangeLog>
```

### 1.3 Папки таблиц: только для затронутых в данной версии

Внутри каждой версии (`v{version}/`) находятся **папки имён таблиц**, для которых в этой версии есть изменения. Если таблица не затронута в данной версии — **её папки в этой версии нет**.

Пример: если v1.0.2 меняет только `service` и добавляет колонку в `partner`, то в `v1.0.2/` будут папки `service/` и `partner/`, но не будет `asset_object/`, `rental_object/` и т.д.

```
db/changelog/
├── 0001_changelog.xml
├── v1.0.0/
│   ├── changelog.xml
│   ├── service/
│   ├── asset_object/
│   ├── rental_object/
│   ├── organisation/
│   ├── partner/
│   └── bank_account/
├── v1.0.1/
│   ├── changelog.xml
│   ├── service/          ← добавлена новая колонка
│   └── partner/          ← добавлен новый индекс
└── v1.0.2/
    ├── changelog.xml
    └── cap_object/       ← создана новая таблица
```

### 1.4 Формат SQL-файлов

Каждый DDL-файл — Liquibase `formatted SQL`:
- Хедер: `--liquibase formatted sql`
- Changeset: `--changeset id:<имя_файла>`
- Тело на SQL (CREATE TABLE / ALTER TABLE / CREATE INDEX / COMMENT)
- Завершается: `--rollback`

**Обязательные комментарии:** на каждую новую таблицу и на каждую новую колонку — `COMMENT ON`. Без комментариев на новые таблицы/колонки changeset не принимается.

Пример:

```sql
--liquibase formatted sql
--changeset id:v1.0.2_01_add-index-partner

CREATE INDEX IF NOT EXISTS idx_partner_accounting_code ON partner (accounting_code);
COMMENT ON COLUMN partner.accounting_code IS 'Код учётного предмета';
--rollback DROP INDEX IF EXISTS idx_partner_accounting_code;
```

### 1.5 ФМД (физическая модель данных)

Каждая новая таблица или колонка в миграции должна соответствовать утверждённой ФМД. Файл `fdm-attributes.json` и плагин `core-fdm-plugin` пока не подключены — контроль осуществляется ручным ревью чейнджлогов. При подключении FDM-валидатора следуй `rules/15_fdm_plugin.md`.

---

<!-- source: auto -->
## 2. Соглашения для агента

### 2.1 Новая мажорная/минорная версия

1. Определи новую версию из `<version>` в `pom.xml` (например `1.0.3-SNAPSHOT` → `v1.0.3/`).
2. Создай каталог `db/changelog/v{version}/` и файл `changelog.xml` внутри:
   ```xml
   <databaseChangeLog ... logicalFilePath="v{version}">
       <!-- include по затронутым таблицам -->
   </databaseChangeLog>
   ```
3. Добавь `<include>` для версионного changelog в `0001_changelog.xml` (если старая версия была с другой версией):
   ```xml
   <include file="/v1.0.3/changelog.xml" relativeToChangelogFile="true"/>
   ```
4. Не удаляй старые версионные папки (`v1.0.0/`, `v1.0.1/` и т.д.) — они часть истории миграций.

### 2.2 Новая миграция для существующей версии

Если версия ещё не выпущена (например `v1.0.2` активна, но не закоммичена как релиз):

1. Создай папку таблицы (если её ещё нет в этой версии):
   ```
   db/changelog/v1.0.2/<таблица>/
   ```
2. Создай SQL-файл в формате: `<YYYY-MM-DD>_<NN>_<описание>.sql`
3. Добавь `<include>` в `v{version}/changelog.xml` с `relativeToChangelogFile="true"`.
4. Файл должен содержать `--rollback` (симметрично DDL).
5. **Каждую новую таблицу и каждую новую колонку — `COMMENT ON`.** Без комментариев на новые таблицы/колонки changeset не принимается.

### 2.3 Новая мажорная версия схемы

Если схема БД существенно меняется (пересоздание, разделение на части):

1. Создай новую папку версии `v{next_major}/` (например `v2.0.0/`).
2. Включи в `0001_changelog.xml` новую версию:
   ```xml
   <include file="/v2.0.0/changelog.xml" relativeToChangelogFile="true"/>
   ```
3. В `v2.0.0/changelog.xml` — include для **всех** таблиц модели данных.

---

<!-- source: auto -->
## 3. Чек-лист

- [ ] Версия папки changelog соответствует версии проекта из `pom.xml` (`v{major}.{minor}.{patch}`)
- [ ] Новая миграция добавлена в `<include>` версионного `changelog.xml` (`relativeToChangelogFile="true"`)
- [ ] Папка таблицы есть в версии только если миграция её затрагивает
- [ ] SQL-файл содержит `--rollback` (симметрично DDL: DROP → CREATE)
- [ ] Имя файла уникально: `<YYYY-MM-DD>_<NN>_<описание>.sql`
- [ ] **На каждую новую таблицу и каждую новую колонку есть `COMMENT ON`** — без комментариев changeset не принимается
- [ ] Изменения совместимы с предыдущей версией (backward compatible)
- [ ] Миграция соответствует ФМД (утверждённый перечень атрибутов)

---

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: Корневой changelog 0001_changelog.xml

**Путь:** `objects/src/main/resources/db/changelog/0001_changelog.xml`

```xml
<databaseChangeLog
        xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.4.xsd"
        logicalFilePath="path-independent">
    <include file="/v1.0.2/changelog.xml" relativeToChangelogFile="true"/>
</databaseChangeLog>
```

### Example 2: Версионный changelog v1.0.2

**Путь:** `objects/src/main/resources/db/changelog/v1.0.2/changelog.xml`

```xml
<databaseChangeLog
        xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.4.xsd"
        logicalFilePath="v1.0.2">
    <include file="service/2026-07-28_01_init-migration-service.sql" relativeToChangelogFile="true"/>
    <include file="partner/2026-07-07_01_init_migration_partner.sql" relativeToChangelogFile="true"/>
</databaseChangeLog>
```

### Example 3: SQL-миграция новой таблицы

**Путь:** `objects/src/main/resources/db/changelog/v1.0.2/cap_object/2026-08-06_01_init_migration_cap_object.sql`

```sql
--liquibase formatted sql
--changeset id:2026-08-06_01_init_migration_cap_object

CREATE TABLE IF NOT EXISTS cap_object (
    cap_object_id         UUID PRIMARY KEY,
    service_id            UUID NOT NULL,
    description           VARCHAR(500),
    CONSTRAINT fg_cap_object_service FOREIGN KEY (service_id) REFERENCES service (service_id)
);
COMMENT ON TABLE cap_object IS 'Капитальные вложения';
COMMENT ON COLUMN cap_object.cap_object_id IS 'Идентификатор капвложения';
COMMENT ON COLUMN cap_object.service_id IS 'Идентификатор родительской услуги';
--rollback DROP INDEX IF EXISTS idx_cap_object_service;
--rollback DROP TABLE IF EXISTS cap_object;
```

---

<!-- source: auto -->
## 5. Исключения и оговорки

- Старые версионные папки (`v1.0.0/`, `v1.0.1/` и т.д.) **не удаляются** — они часть истории миграций и применяются Liquibase по порядку.
- Если версия проекта обновляется (например `1.0.2-SNAPSHOT` → `1.0.3-SNAPSHOT`), создаётся новая папка `v1.0.3/`. Старая `v1.0.2/` остаётся.
- В `COMMENT ON TABLE asset_object` в старых миграциях видны незакрытые скобки (`'(OC объекты по договор'`) — в новых миграциях проверяй синтаксис.
- **Комментарии обязательны:** `COMMENT ON` нужен на каждую новую таблицу и каждую новую колонку. Это не опция, а блокирующее требование — changeset без комментариев не принимается.
- Автор (`--changeset id:author:filename`) не проставляется локально — факт, не нарушение.

---

<!-- source: auto -->
## 6. Обновление

Пересобирать при:
- Смене версии проекта в `pom.xml` (создание новой папки `v{version}/`)
- Добавлении/изменении таблиц в существующей версии
- Появлении новой мажорной версии схемы (v2, v3)
- Подключении FDM-валидатора (следовать `rules/15_fdm_plugin.md`)
