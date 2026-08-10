---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: База данных, JPA, репозитории (profitcontr-objects)

**Когда читать:** При работе с JPA-сущностями, репозиториями, или SQL-запросами.

**Что описывает:** Entity маппинг, JPA-репозитории, связь с миграциями, fetch-стратегии.

**Глобальный эталон:** `rules/08_database.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Entity-классы и JPA-маппинг

Все JPA-сущности лежат в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/` — 8 классов:

- `Service.java` (`@Table(name = "service")`)
- `AssetObject.java` (`@Table(name = "asset_object")`)
- `RentalObject.java` (`@Table(name = "rental_object")`)
- `CapObject.java` (`@Table(name = "cap_object")`)
- `FinapObject.java` (`@Table(name = "finap_object")`)
- `Partner.java` (`@Table(name = "partner")`)
- `BankAccount.java` (`@Table(name = "bank_account")`)
- `Organisation.java` (`@Table(name = "organisation")`)

Именование таблиц и колонок — `snake_case`, совпадает с Liquibase-миграциями (`db/changelog/v1.0.0/<тип>/*.sql`). Первичные ключи — `UUID`, генерируются через `@GeneratedValue(strategy = GenerationType.UUID)`.

- `Service`:`@Id @Column(name = "service_id") @GeneratedValue(strategy = GenerationType.UUID) private UUID serviceId;`
- `AssetObject`:`@Id @Column(name = "asset_object_contract_position_id") @GeneratedValue(strategy = GenerationType.UUID) private UUID assetObjectId;`

**Аудит и оптимистичная блокировка отсутствуют полностью.** `grep` по `@Version|@CreatedDate|@LastModifiedDate|@CreatedBy|@LastModifiedBy|@EntityListeners|@MappedSuperclass` в `objects/src/main/java` — ноль совпадений. Это соответствует GAP-данным: `08_db.version_annotation` — violation (`@Version` count=0), `08_db.created_by` — violation (`@CreatedBy`/`@LastModifiedBy` count=0), `08_db.audit_timestamps` — «compliant», но фактически поля дат создания/изменения отсутствуют (count=0) — соглашение глобального эталона про `created_date`/`changed_date` и обязательные поля не выполняется в коде.

### 1.2 Связи и каскады

`Service.java` — корень агрегата: содержит `@OneToMany(mappedBy = "service", cascade = CascadeType.ALL)` для `rentalObjects`, `assetObjects`, `capObjects`, `finapObjects` и `@OneToOne(mappedBy = "service", cascade = CascadeType.ALL)` для `organisation`. Вложенные сущности владеют связью:

- `AssetObject`:`@ManyToOne(cascade = CascadeType.ALL) @JoinColumn(name = "service_id") private Service service;` (`mappedBy = "assetObject"` в родителе)

Доступны шаблонные бинаправленные хелперы `add...(...)`, которые заполняют обратную ссылку (например `Service.addAssetObject` ставит `assetObject.setService(this)`).

`Partner` и `BankAccount`: `AssetObject`/`RentalObject` держат `@OneToMany` контрагентов, `BankAccount` — `@OneToOne @JoinColumn(name = "contract_partner_id") private Partner partner;`.

### 1.3 Репозитории (Spring Data JPA)

Интерфейсы расположены в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/repository/` и наследуют Spring Data:

- `ServiceRepository extends JpaRepository<Service, UUID>` — содержит производный метод `List<Service> findByContractVersionId(UUID contractVersionId)` (используется поиском по версии договора).
- `AssetObjectRepository extends JpaRepository<AssetObject, UUID>` — пустой.
- `RentalObjectRepository extends JpaRepository<RentalObject, UUID>` — пустой.

ID-тип репозиториев — `UUID` (совпадает с PK сущностей). Бизнес-логика и кастомные `@Query`/`JpaSpecificationExecutor`/pagination в репозиториях не видны.

### 1.4 Таблицы и `entity ↔ SQL` соответствие

Хранение разделено по типам объектов; Liquibase-changelog `db/changelog/v1.0.0/<тип>/<файл>.sql` для каждого типа. `asset_object` сопоставляется 1:1 с `AssetObject.java`:

- Таблица `asset_object`, PK `asset_object_contract_position_id UUID PRIMARY KEY`.
- FK `fg_asset_object_service` → `service(service_id)`.
- `COMMENT ON TABLE / COMMENT ON COLUMN` заданы для таблицы и всех колонок — соответствует правилу эталона «комментарии обязательны».
- `--rollback` присутствует в каждом changeset.

Замечание: root-entity service мигрирован файлом `2026-07-28_01_init-migration-service.sql`, а `organisation` — `2026-07-20_01_init-migration.sql` (дефис), остальные типы — `2026-07-07_01_init_migration_*.sql` (snake_case) — расхождение нейминга файлов, уже отмечено в `gap_notes 03`.

<!-- source: auto -->
## 2. Соглашения для агента

- Новые сущности размещай в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/`, аннотируй `@Entity` + `@Table(name = "snake_case")`, PK — `UUID` c `@GeneratedValue(strategy = GenerationType.UUID)`, колонки — `@Column(name = "snake_case")`; имя таблицы/колонки должно совпадать с Liquibase-миграцией 1:1 (см. `AssetObject.java` ↔ `v1.0.0/asset_object/*.sql`).
- Новые репозитории — интерфейсы в `repository/`, наследуй `JpaRepository<Entity, UUID>`; производные методы именуй по Spring Data (`findByContractVersionId` в `ServiceRepository`). Не добавляй `@Repository` без необходимости — Spring Data сам регистрирует bean (в репо аннотация встречается непоследовательно).
- Связи агрегата веди от `Service` `@OneToMany(mappedBy = "service", cascade = CascadeType.ALL)` (rental/asset/cap/finap) и `@OneToOne` (organisation); владеющая сторона — на дочерней сущности через `@ManyToOne`/`@OneToOne` + `@JoinColumn`. Обязательно сохраняй бинаправленные хелперы `add*(...)`.
- При добавлении общих полей аудита используй `@MappedSuperclass` в `model/entity/` и аннотации `@CreatedDate`/`@LastModifiedDate`/`@CreatedBy`/`@LastModifiedBy` с `@EntityListeners(AuditingEntityListener.class)` — в текущем коде аудит и `@Version` отсутствуют, это открытая зона к глобальному `rules/08_database.md`.
- Денежные суммы в сущностях/DTO держи в `BigDecimal` (см. `ObjectsDTO.RentalObjectDTO` — `rentalObjectSquare`, `leasebackCalculationRentFairCost`, `pricePerUnit`, `balanceAmountRub`), в SQL — `numeric(16,2)` (рубли) / `numeric(18,4)` (валюта), не `float`/`double`.
- Консистентность с миграциями БД проверяй через `03_migrations.md` (Liquibase `db/changelog`), не создавай сущность/колонку без соответствующего changeset.

<!-- source: auto -->
## 3. Чек-лист

- [ ] JPA entity использует правильные аннотации маппинга: `@Entity`, `@Table(name=snake_case)`, `@Id`+`@GeneratedValue(UUID)`, `@Column(name=snake_case)`
- [ ] Repository наследует `JpaRepository<Entity, UUID>` (ID-тип совпадает с PK)
- [ ] Именование таблиц/колонок в entity совпадает с Liquibase-миграциями 1:1
- [ ] Каскады и fetch-стратегии заданы явно (`cascade = CascadeType.ALL`, `mappedBy`/`@JoinColumn`)
- [ ] N+1 проблемы проверены (JOIN FETCH или EntityGraph при необходимости)
- [ ] `@Version` добавлен на ключевые сущности при необходимости оптимистичной блокировки (сейчас отсутствует — расхождение с `rules/08_database.md`)
- [ ] Поля аудита (`created_date`/`changed_date` + `*_by`) и `@EntityListeners(AuditingEntityListener.class)` добавлены, если требуется отслеживание изменений
- [ ] Денежные поля объявлены как `BigDecimal` (SQL `numeric(16,2)`/`numeric(18,4)`), без плавающей точки
- [ ] Для новых таблиц/колонок есть `COMMENT ON` и `--rollback` в соответствующем changeset
- [ ] Нет выдуманных соответствий SQL↔Java: каждая колонка сущности подтверждена DDL миграции

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: `AssetObject.java` ↔ `2026-07-07_01_init_migration_asset_object.sql`

**Path:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/AssetObject.java`

```java
@Entity
@Table(name = "asset_object")
public class AssetObject {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "asset_object_contract_position_id")
    private UUID assetObjectId;

    @ManyToOne(cascade = CascadeType.ALL)
    @JoinColumn(name = "service_id")
    private Service service;

    @OneToMany(mappedBy = "assetObject", cascade = CascadeType.ALL)
    private List<Partner> partners;
}
```

**Path:** `objects/src/main/resources/db/changelog/v1.0.0/asset_object/2026-07-07_01_init_migration_asset_object.sql`

```sql
CREATE TABLE IF NOT EXISTS asset_object (
    asset_object_contract_position_id UUID PRIMARY KEY,
    ...
    service_id UUID,
    CONSTRAINT fg_asset_object_service FOREIGN KEY (service_id) REFERENCES service (service_id)
);
COMMENT ON TABLE asset_object IS '(OC объекты по договору';
```

Entity и DDL согласованы: PK `asset_object_contract_position_id` = `assetObjectId`, FK `service_id` = `@JoinColumn(name = "service_id")`.

### Example 2: `Service.java` — корень агрегата и `ServiceRepository`

**Path:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/Service.java`

```java
@Table(name = "service")
@Entity
public class Service {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "service_id")
    private UUID serviceId;

    @OneToMany(mappedBy = "service", cascade = CascadeType.ALL)
    private List<AssetObject> assetObjects;
    @OneToOne(mappedBy = "service", cascade = CascadeType.ALL)
    private Organisation organisation;
}
```

**Path:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/repository/ServiceRepository.java`

```java
@Repository
public interface ServiceRepository extends JpaRepository<Service, UUID> {
    List<Service> findByContractVersionId(UUID contractVersionId);
}
```

<!-- source: auto -->
## 5. Исключения и оговорки

- Соглашение о JPA/Auditing из глобального `rules/08_database.md` (обязательные `created_date`/`changed_date`, `@CreatedDate`/`@LastModifiedDate`, `@Version`, `@MappedSuperclass`) в текущем коде фактически не реализовано — audit-поля и optimistic locking отсутствуют. Локальное правило: следуй глобальному эталону при добавлении новых сущностей, пока аудит/версионирование не внедрено.
- Именование многих-ко-многим через `имя1_имя2_lnk` (таблицы-линки) в репозитории не используется — связи строятся только через `@JoinColumn` на дочерней стороне (FK `service_id`, `contract_partner_id`).
- Имена файлов-миграций неоднородны (`init-migration` дефис в service/organisation vs `init_migration` snake_case у остальных) — зафиксировано в `gap_notes 03` и `03_migrations.md`.

<!-- source: auto -->
## 6. Обновление

Пересобирать при крупном рефакторинге модели (`model/entity`), массовом добавлении/удалении таблиц в `db/changelog/v1.0.0/`, внедрении аудита (`@MappedSuperclass`/`@EntityListeners`) или optimistic locking (`@Version`).