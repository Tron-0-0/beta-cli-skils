---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Валидация физической модели данных (FDM Validator) (profitcontr-objects)

**Когда читать:** При работе с физической моделью данных (ФМД), добавлении таблиц/колонок, настройке валидатора физической модели или сборке дистрибутива БД-миграций.

**Что описывает:** core-fdm-plugin, fdm-attributes.json, migrationsPath, связь с миграциями Liquibase; фактический уровень валидации ФМД в репозитории.

**Глобальный эталон:** `rules/15_fdm_plugin.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Плагин FDM-валидатора не подключён

В `pom.xml` репозитория **отсутствует** Maven-плагин валидации физической модели данных. Поиск по `fdm-validator` и `core-fdm-plugin` (координаты: `ru.sbrf.sbererp.core.plugin:core-fdm-plugin`) во всех `pom.xml` (корневой `pom.xml`, `objects/pom.xml`, `objects-rest-client/pom.xml`) и в секции `<build><plugins>` — **совпадений нет** (GAP-данные `15_fdm.fdm_validator: partial`, `found=false`).

В `objects/pom.xml` (проверен) в секции `<build><plugins>` заявлен только `org.springframework.boot:spring-boot-maven-plugin`; в `<dependencies>` нет ни `core-fdm-plugin`, ни `fdm-validator-maven-plugin`. Соответственно:

- Файл утверждённого перечня атрибутов ФМД **`fdm-attributes.json` не найден** (обычно располагается в `src/main/resources` корня проекта) — в репозитории отсутствует.
- Параметр `migrationsPath` конфигурации плагина (обычно `src/main/resources/db/changelog`) **не задан** — конфигурации FDM-валидатора нет.
- В entity-классах **нет FDM-аннотаций** (`@FdmEntity`, `@FdmField` и т.п.) — поиск по `src/main/java` совпадений не дал.

Правило счесть как **«не применимо/отсутствует»**: плагин не заявлен, сборку на фазе `verify` он не ломает (в отличие от глобального эталона `rules/15_fdm_plugin.md`). Следовать глобальному эталону целиком при подключении плагина.

### 1.2 Entity-классы и миграции БД существуют без FDM

FDM-аннотаций в entity нет, однако объекты физической модели в репозитории реально присутствуют:

- **Entity**: 8 классов в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/` (`Service`, `Organisation`, `AssetObject`, `CapObject`, `FinapObject`, `RentalObject`, `Partner`, `BankAccount`). JPA-маппинг через стандартные `jakarta.persistence`-аннотации (`@Entity`, `@Table`, `@Column`, `@Id`, `@GeneratedValue`), без какой-либо FDM-разметки.
- **Миграции**: двухуровневый Liquibase-changelog в `objects/src/main/resources/db/changelog` — мастер `0001_changelog.xml` → версионный `v1.0.0/changelog.xml` (8 `include` по типам объектов) → `--changeset` по типам (см. cross-ссылка с `03_migrations` и `08_database`). SQL-схема содержит `CREATE TABLE`, `COMMENT ON TABLE/COLUMN`, индексы и `--rollback`.

Т.е. физическая модель (таблицы, атрибуты, описания) есть, но **без автоматизированной сверки с утверждённой ФМД**.

### 1.3 Итог по уровню валидации ФМД

Автоматизированная проверка перечня атрибутов ФМД (имена `NAME_MISMATCH`, типы `TYPE_MISMATCH`, описания `DESCRIPTION_MISMATCH`) в репозитории **отсутствует**. Контроль ФМД сейчас ограничен:

- **Код**: статические анализаторы на фазе `validate`/`check` — checkstyle, PMD, SpotBugs в корневом `pom.xml` (контроль Java-кода/entity, не SQL-схемы).
- **Схема**: ручное ревью чейнджлогов и соответствие entity ↔ SQL-таблиц.
- **Дистрибуция**: `objects/db-assembly.xml` (maven-assembly) собирает ZIP-архив миграций — упаковка, а не валидация ФМД.

Если в других сервисах SberERP FDM подключён, то **profitcontr-objects пока FDM не использует** (локальное отклонение от платформенного регламента) — открытая зона к `rules/15_fdm_plugin.md`.

<!-- source: auto -->
## 2. Соглашения для агента

- При подключении FDM-валидатора **применять полный глобальный эталон** `rules/15_fdm_plugin.md` целиком (координаты `ru.sbrf.sbererp.core.plugin:core-fdm-plugin`, параметры `migrationsPath`/`attributesFile`, логика `NAME/TYPE/DESCRIPTION_MISMATCH`, ломающий сборку `verify`) — как директиву и исчерпывающий источник правды.
- При появлении плагина entity-классы, участвующие в ФМД, размечать **FDM-аннотациями** (`@FdmEntity`/`@FdmField`), а файл `fdm-attributes.json` класть в `src/main/resources` корня службы; новые таблицы/колонки заявлять и в `fdm-attributes.json`, и в Liquibase-миграции (`v1.0.0/changelog.xml` + вложенные `--changeset`), сохраняя согласованность типов и `COMMENT ON` с entity (см. `08_database`).
- Плагин валидации подключить в секцию `<build><plugins>` (возможно через `add-dependency` при активированном плагине), чтобы он запускался на фазе `mvn verify`; **не** добавлять `core-fdm-plugin`/`fdm-validator-maven-plugin` в `<dependencies>` напрямую.
- Пока плагин не подключён, фактическим контролем ФМД считается **ручное ревью чейнджлогов** (`objects/src/main/resources/db/changelog`) и согласованность entity ↔ SQL-таблиц; обеспечивать корректность `-include` в `v1.0.0/changelog.xml` и `--changeset` (включая `COMMENT ON` и `--rollback`).
- **Не выдумывать** присутствие плагина, `fdm-attributes.json`, FDM-аннотаций или `migrationsPath`: считать, что автоматического FDM-валидатора в репозитории нет, пока он не появится в `pom.xml` и entity. Утверждение об обратном — ошибка.
- `fdm-attributes.json` при его появлении — единый источник правды о согласованной ФМД; изменения только через PR с ревью и после согласования с DBA/архитектором (по правилам глобального эталона).

<!-- source: auto -->
## 3. Чек-лист

- [ ] Проверено, что `core-fdm-plugin`/`fdm-validator-maven-plugin` действительно подключён в `<build><plugins>` `pom.xml` (в текущем репо — **отсутствует**; не заявлять иначе)
- [ ] Если плагин есть/появляется: файл `fdm-attributes.json` создан в `src/main/resources` и актуален, содержит все таблицы/атрибуты
- [ ] Entity-классы, участвующие в ФМД, размечены FDM-аннотациями (`@FdmEntity`/`@FdmField`), когда плагин подключён
- [ ] Параметр `migrationsPath` плагина указывает на корректный каталог (`src/main/resources/db/changelog`)
- [ ] Валидация FDM фактически запускается при `mvn verify` (или осознанно решено, что плагина нет и `verify` её не выполняет)
- [ ] Новые таблицы/колонки согласованы: заявлены в `fdm-attributes.json` (когда он появится) и добавлены в Liquibase `v1.0.0/changelog.xml` с `--changeset`, `COMMENT ON` и `--rollback`
- [ ] Типы и `COMMENT ON`-описания в миграции совпадают с типами/описаниями ФМД и с entity (`08_database`)
- [ ] Инициализация плагина (если бандлим) только через конфигурацию `<build><plugins>`/`add-dependency` при включённом плагине, не в `<dependencies>` напрямую
- [ ] Локальное отклонение зафиксировано в `GAP-ARCHITECTURE-ANALYSIS.md` (`15_fdm` = «не применимо/отсутствует»)

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: AssetObject.java — entity без FDM-аннотаций
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/AssetObject.java`

Представитель физической модели в коде, размеченный стандартными `jakarta.persistence`-аннотациями, но **без** `@FdmEntity`/`@FdmField` (никакой привязки к FDM нет):

```java
@Entity
@Table(name = "asset_object")
public class AssetObject {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "asset_object_contract_position_id")
    private UUID assetObjectId;

    @Column(name = "asset_main_id")
    private Long assetMainId;

    @Column(name = "asset_main_inventory_number")
    private String mainInventoryNumber;
    // ...
}
```

### Example 2: 2026-07-07_01_init_migration_asset_object.sql — DDL без FDM
**Путь:** `objects/src/main/resources/db/changelog/v1.0.0/asset_object/2026-07-07_01_init_migration_asset_object.sql`

Фактическая SQL-схема таблицы `asset_object` (в этой локе роль утверждённой ФМД), создаваемая Liquibase из `v1.0.0/changelog.xml`; типы и `COMMENT ON` согласованы с `AssetObject.java` вручную:

```sql
--liquibase formatted sql
--changeset id:2026-07-07_01_init_migration_asset_object
CREATE TABLE IF NOT EXISTS asset_object (
    asset_object_contract_position_id UUID PRIMARY KEY,
    asset_main_id                     INT8,
    asset_main_inventory_number       VARCHAR(255),
    ...
);
COMMENT ON TABLE  asset_object IS '(OC объекты по договору';
COMMENT ON COLUMN asset_object.asset_object_contract_position_id IS 'Идентификатор позиции объекта ОС в договоре';
--rollback DROP TABLE IF EXISTS asset_object;
```

> Здесь видно, чем отличается текущая локальная практика от FDM: `fdm-attributes.json` отсутствует, а сверка «entity ↔ DDL ↔ COMMENT ON» — ручная. Подключение FDM-валидатора автоматизировало бы именно эту проверку.

<!-- source: auto -->
## 5. Исключения и оговорки

- Соглашение действует для **физической модели, собираемой из Liquibase-миграций** (`src/main/resources/db/changelog`). Для контроля Java/entity (компиляция, маппинг) используются другие темы (`04_compilation`, `08_database`).
- Без фактического `fdm-attributes.json`, FDM-аннотаций и плагина в `pom.xml` писать про автоматизированный FDM-валидатор **запрещено** — это выдумка. Сейчас фиксируется только отсутствие плагина на фоне существующих entity и DDL.

<!-- source: auto -->
## 6. Обновление

Перегенерировать при изменении состава FDM-валидации в репозитории: подключения `ru.sbrf.sbererp.core.plugin:core-fdm-plugin`/`fdm-validator-maven-plugin` в `pom.xml`, появления/значительного изменения `fdm-attributes.json`, появления FDM-аннотаций в entity, либо изменения каталога миграций, на который указывает `migrationsPath`.