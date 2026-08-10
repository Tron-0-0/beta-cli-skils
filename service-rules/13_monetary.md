---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Денежные суммы и точность (profitcontr-objects)

**Когда читать:** При работе с денежными суммами, ставками, ценой/площадью объектов, числовой точностью или финансовыми расчётами в объектах договора.

**Что описывает:** BigDecimal, масштаб/точность, SQL NUMERIC/DECIMAL, округление, представление денежных полей в entity/DTO.

**Глобальный эталон:** `rules/13_monetary.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Только BigDecimal для денежных/числовых финансовых полей (double/float отсутствуют)

Факт из `facts/gap_report.json`: проверка `13_monetary.bigdecimal_money` — **compliant**, в `src/main/java` entity количество `double`/`float` для потенциальных денежных полей равно `0`. Прочитаны entity/DTO — все финансовые поля объявлены как `java.math.BigDecimal`, `double`/`float` в домене не используются.

Подтверждено по коду (`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/RentalObject.java` и `Partner.java`): импортируется `java.math.BigDecimal`, поля сумм/ставок/долей — именно `BigDecimal`.

### 1.2 RentalObject — денежные поля и их точность из миграций

Entity `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/RentalObject.java`, таблица `rental_object`. Колонки и их JDBC-тип в `objects/src/main/resources/db/changelog/v1.0.0/rental_object/2026-07-07_01_init_migration_rental_object.sql`:

| Поле (Java) | Колонка (SQL) | Тип в DDL |
|---|---|---|
| `square` | `square` | `NUMERIC(18, 2)` |
| `leasebackCalculationRentFairCost` | `leaseback_calculation_rent_fair_cost` | `NUMERIC(18, 4)` |
| `pricePerUnit` | `price_per_unit` | `NUMERIC(18, 4)` |
| `cadastralValueRub` | `cadastral_amount_rub` | `NUMERIC(16, 2)` |
| `balanceAmountRub` | `balance_amount_rub` | `NUMERIC(16, 2)` |

Везде в `RentalObject.java` тип `BigDecimal`; в DDL — `NUMERIC` с явной точностью (precision, scale). Масштаб в SQL различается: ставки/справедливая стоимость — `scale 4`, суммы — `scale 2`.

### 1.3 RentalObjectCreateRequest и Partner — зеркальные DTO запроса

Запрос-объект `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/request/creation/RentalObjectCreateRequest.java` повторяет денежные поля объекта аренды как `BigDecimal`: `rentalObjectSquare`, `leasebackCalculationRentFairCost`, `balanceAmountRub`, `pricePerUnit`, `rentalObjectCadastralAmountRub`. Аналогично `PartnerCreateRequest.java` содержит `ownershipShareValue` (`BigDecimal`).

Ответный DTO `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/dto/ObjectsDTO.java` (nested `RentalObjectDTO` и `PartnerDto`) использует `BigDecimal` для тех же полей: `rentalObjectSquare`, `leasebackCalculationRentFairCost`, `pricePerUnit`, `rentalObjectCadastralAmountRub`, `balanceAmountRub`, `ownershipShareValue`.

### 1.4 Partner.ownershipShareValue — NUMERIC без явной точности

Entity `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/Partner.java`, колонка `ownership_share_value`. В `partner/2026-07-07_01_init_migration_partner.sql` тип — `NUMERIC` **без** явных `(precision, scale)`, в отличие от полей `rental_object`. Это единственное «денежное/долевое» поле, где точность задана не на уровне DDL, а остаётся на усмотрение JDBC-маппинга.

### 1.5 Где денежных полей НЕТ

- Entity `AssetObject.java` (таблица `asset_object`) и `AssetObjectCreateRequest.java` и `AssetObjectDTO` — **не содержат денежных полей**: все поля справочные/идентификационные (`String`, `Long`, `UUID`). Подтверждено DDL `asset_object/2026-07-07_01_init_migration_asset_object.sql` (нет колонок NUMERIC).
- Entity `Service.java` (таблица `service`) и `ObjectsServiceDataDTO` — денежных полей нет (только `UUID`, `String`, `Enum`). Подтверждено `service/2026-07-28_01_init-migration-service.sql`.
- В прочитанном коде **не обнаружено**: явных `RoundingMode`/`setScale`, валютного поля/кода валюты, конвертации валют, арифметики над суммой. Деньги хранятся и передаются как есть; бизнес-вычислений сумм в этих слоях нет.

<!-- source: auto -->
## 2. Соглашения для агента

1. **Денежные/финансовые поля всегда `BigDecimal`** — не `double`, не `float`, не `String` (см. `RentalObject.leasebackCalculationRentFairCost`, `Partner.ownershipShareValue`; `facts/gap_report.json` rule 13 — compliant). При добавлении нового поля суммы/ставки/цены используй `java.math.BigDecimal` и в entity, и в request/response DTO.
2. **Масштаб задавай в соответствии с DDL миграций**: ставки/справедливая стоимость — `NUMERIC(18, 4)` (`leaseback_calculation_rent_fair_cost`, `price_per_unit`), суммы/площадь — `NUMERIC(18, 2)`/`NUMERIC(16, 2)` (`square`, `cadastral_amount_rub`, `balance_amount_rub`). Если в новой миграции заводится денежная колонка — приведи её к явному `NUMERIC(p, s)` (как в `rental_object`), не оставляй «голый» `NUMERIC` без точности (сейчас так сделано для `partner.ownership_share_value`).
3. **Округление — только явным `RoundingMode`** при арифметике (например `setScale(2, RoundingMode.HALF_UP)`); не полагайся на неявное поведение JDBC/Jackson. Если расчёты появляются — константа масштаба в `configuration/constants/WebApplicationConstants.java` или аналогичном.
4. **Не выполняй арифметику над «денежными» значениями через примитивные `double`/`float`** и не приводи `BigDecimal` к ним для расчётов (потеря точности денег недопустима).
5. **Не выдумывай валюту/курсы/округления**: в коде нет валютного поля и конвертации — не добавляй соглашение о валюте/справочнике курсов без реального подтверждения в репозитории (после `rules/13_monetary.md` и `anti_patterns` бандла).

<!-- source: auto -->
## 3. Чек-лист

- [ ] Денежные суммы/ставки представлены `BigDecimal`, а не `double`/`float`/`String`
- [ ] Масштаб (scale) и `RoundingMode` заданы явно при любой арифметике с деньгами
- [ ] SQL-колонки для сумм имеют тип `NUMERIC`/`DECIMAL` с явной точностью (`NUMERIC(16,2)`, `NUMERIC(18,2)`, `NUMERIC(18,4)`), согласованно с entity
- [ ] DTO и для запроса, и для ответа используют `BigDecimal` для денежных полей (см. `RentalObjectCreateRequest`, `ObjectsDTO.RentalObjectDTO`)
- [ ] Тип `BigDecimal` в Java ≠ тип колонки в изменяемом `db/changelog/*.sql` не расходится (проверить по migration)
- [ ] Нет арифметики над деньгами через `double`/`float` и нет приведения BigDecimal к ним
- [ ] Валюта/курсы/округление не вымышлены; если появились — только на основе фактического кода и `rules/13_monetary.md`

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: Entity с денежными полями (RentalObject)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/RentalObject.java` (таблица `rental_object`, DDL `objects/src/main/resources/db/changelog/v1.0.0/rental_object/2026-07-07_01_init_migration_rental_object.sql`)

```java
@Schema(description = "Расчетная рыночная стоимость, руб")
@Column(name = "leaseback_calculation_rent_fair_cost")
private BigDecimal leasebackCalculationRentFairCost;   // NUMERIC(18, 4)

@Schema(description = "Кадастровая стоимость за 1 кв. метр")
@Column(name = "cadastral_amount_rub")
private BigDecimal cadastralValueRub;                  // NUMERIC(16, 2)

@Schema(description = "Балансовая стоимость объекта аренды")
@Column(name = "balance_amount_rub")
private BigDecimal balanceAmountRub;                   // NUMERIC(16, 2)
```

### Example 2: Request DTO денежных полей (RentalObjectCreateRequest)
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/request/creation/RentalObjectCreateRequest.java`

```java
@Schema(description = "Расчетная рыночная стоимость, руб")
private BigDecimal leasebackCalculationRentFairCost;

@Schema(description = "Балансовая стоимость объекта аренды")
private BigDecimal balanceAmountRub;

@Schema(description = "Цена (тариф) за единицу измерения")
private BigDecimal pricePerUnit;
```

### Example 3: Доля владения (PartnerCreateRequest / Partner)
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/request/creation/PartnerCreateRequest.java`

```java
@Schema(description = "Доля владения объектом")
private BigDecimal ownershipShareValue;
```

Колонка `ownership_share_value NUMERIC` в `objects/src/main/resources/db/changelog/v1.0.0/partner/2026-07-07_01_init_migration_partner.sql` — **без** явной точности (в отличие от полей `rental_object`), это единственное отклонение от практики явного масштаба.

---

<!-- source: auto -->
## 5. Исключения и оговорки

- В прочитанном коде **не обнаружено** реальных финансовых вычислений, округлений и валюты — соглашение фиксирует только факт «BigDecimal + точность из DDL». Любые правила про конвертацию валют или конкретный `RoundingMode` применять **только** при появлении подтверждённого кода/требований SberERP; иначе следовать глобальному `rules/13_monetary.md`.
- `AssetObject`/`Service` и их DTO **не содержат денежных полей** — для этих сущностей правило 13 формально «не ОПРЕДЕЛЕНО», при добавлении суммы в них применяй §2 (BigDecimal + `NUMERIC(p,s)` в миграции).
- `partner.ownership_share_value` оставлен `NUMERIC` без `(precision, scale)` в текущей миграции — перед изменением уточни требуемую точность (по `rules/13` и бизнес-требованиям), не задавай scale наобум.

<!-- source: auto -->
## 6. Обновление

Пересобрать при появлении в домене новых денежных полей/сущностей, арифметики над суммой, валюты либо изменении типов NUMERIC в `db/changelog/v1.0.0/*.sql`, а также при смене версии/starter, влияющей на JDBC/Jackson-маппинг BigDecimal.