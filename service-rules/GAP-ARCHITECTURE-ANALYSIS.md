---
apply: always
mode: all
---

# Расхождения с глобальным регламентом: profitcontr-objects

**Сгенерировано:** 2026-08-05

**Назначение:** Сводная таблица соотнесения локальных соглашений (`service-rules/`) с глобальным регламентом (`rules/`). Построена на основе детерминированного анализа (`facts/gap_report.json`, 30 проверок `analyze_gap.py`) и контекстных замечаний агентов (`gap_notes.jsonl`).

---

## Сводка

| Статус | Кол-во |
|--------|--------|
| 🔴 VIOLATION | 10 |
| 🟡 PARTIAL | 8 |
| 🟢 COMPLIANT | 14 |

**Всего проверок:** 32 (из `analyze_gap.py` + 16_refactoring)

> Примечания, уточняющие сырьё анализа (из `gap_notes.jsonl`):
> - 2 «violation» — ложные срабатывания сканера (см. `07_api.sberpdi_header`, `09_logging.logging_starter`).
> - 6 «violation/partial» по rule `11_kafka` — следствие отсутствия слоя Kafka, а не нарушений.
> - `15_fdm.fdm_validator` — плагин FDM не подключён (открытая зона), физическая модель существует без FDM-разметки.

---

## Соответствие по темам

| Тема (service-rules) | rules/ | Статус |
|----------------------|--------|--------|
| `00_project_creation` | `rules/00_project_creation.md` | **подтверждается** (sbererp-bom, Java 21, root-пакет); отклонение: `ru.sbrf.sbererp:logging-starter` вместо `core-common-logging-starter` |
| `01_coding` | `rules/01_coding.md` | **локальное отклонение**: нет интерфейсов `*ControllerApi` (Swagger через `ObjectControllerDocs`); остальное — compliant |
| `02_monitors` | `rules/02_monitors.md` | **локальное отклонение**: нет кастомных бизнес-метрик (`MeterRegistry`) и `HealthIndicator` (partial) |
| `03_migrations` | `rules/03_migrations.md` | **подтверждается**; отклонения: нет `--author` в changeset, неединый нейминг файлов, версия папки не совпадает с pom.xml |
| `04_compilation` | `rules/04_compilation.md` | **локальное отклонение**: CI не определён (нет Jenkinsfile/workflows), README пуст; команды выводятся из pom |
| `05_self_correction` | `rules/05_self_correction.md` | **подтверждается** (checkstyle/PMD/SpotBugs/JaCoCo/Pitest + актуализация specification/) |
| `06_unit_tests_with_spring_context` | `rules/06_unit_tests_with_spring_context.md` | **подтверждается** (gap-проверки compliant); отклонение: стиль unit-only без Spring-контекста, нет `@SpringBootTest`/H2/Testcontainers/MockMvc |
| `07_api_contract` | `rules/07_api_contract.md` | **локальное отклонение**: `sberpdi` через константу `SBERPDI_HEADER_KEY` (ложное срабатывание); нет `*ControllerApi`; `@JsonIgnoreProperties` только на `ObjectCreateRequest` |
| `08_database` | `rules/08_database.md` | **локальное отклонение**: отсутствуют `@Version`, `@CreatedBy/@LastModifiedBy` (аудит и optimistic locking) |
| `09_logging` | `rules/09_logging.md` | **локальное отклонение**: MDC в коде не используется; `logging-starter` подключён (ложное срабатывание) |
| `10_cloud_native` | `rules/10_cloud_native.md` | **локальное отклонение**: actuator+probes есть, но нет кастомных `HealthIndicator`/бизнес-метрик; K8s/Docker/Helm манифестов нет |
| `11_kafka` | `rules/11_kafka.md` | **не видно / не применимо**: слой Kafka отсутствует — следовать `rules/` при появлении Kafka |
| `12_configuration` | `rules/12_configuration.md` | **локальное отклонение**: нет `@ConfigurationProperties`, параметры DB pool не заданы, профильные файлы отсутствуют |
| `13_monetary` | `rules/13_monetary.md` | **подтверждается** (только BigDecimal, double/float=0); отклонение: `partner.ownership_share_value` `NUMERIC` без явной точности |
| `14_idempotency_rest` | `rules/14_idempotency_rest.md` | **локальное отклонение**: стартер `@Idempotency` не подключён; идемпотентность через натуральный ключ `contractVersionId` + `ObjectsAlreadyExistException` |
| `15_fdm_plugin` | `rules/15_fdm_plugin.md` | **не видно / не применимо**: FDM-плагин/аннотации/`fdm-attributes.json` отсутствуют — следовать `rules/` при подключении |
| `16_refactoring` | `rules/16_refactoring.md` | **critical violation**: дублирование `AssetObjectServiceImpl`/`RentalObjectServiceImpl` (80% одинакового кода), 4 идентичных `add*` в `Service`, `ObjectsDTO`/`ObjectsCreationResponse` (280-350 строк); длинные классы `ObjectControllerDocs` (~450 строк) |

---

## Матрица приоритетов

Проверки со статусом `violation` / `partial` из `gap_report.json` (сгруппированы по severity). Статусы скорректированы контекстом агентов (`gap_notes.jsonl`).

| # | Проверка | Rule | Статус | Severity | Приоритет | Примечание |
|---|---------|------|--------|----------|-----------|-----------|
| 1 | `@Version` optimistic locking | 08_database | 🔴 VIOLATION | HIGH | P1 | отсутствует на entity |
| 2 | MDC-трассировка (`MDC.*`) | 09_logging | 🔴 VIOLATION | HIGH | P1 | MDC/`includeMdc` выключены |
| 3 | `sberpdi` заголовок | 07_api_contract | 🔴 VIOLATION | MEDIUM | P1 | фактически реализован константой → ложное срабатывание |
| 4 | `logging-starter` в pom | 09_logging | 🔴 VIOLATION | MEDIUM | P2 | фактически есть `ru.sbrf.sbererp:logging-starter` → ложное срабатывание |
| 5 | `*ControllerApi` интерфейсы | 01_coding | 🔴 VIOLATION | MEDIUM | P2 | Swagger через `controller/swagger/ObjectControllerDocs` |
| 6 | `@CreatedBy/@LastModifiedBy` аудит | 08_database | 🔴 VIOLATION | MEDIUM | P2 | отсутствуют |
| 7 | `BaseKafkaConfig` / абстрактный конфиг | 11_kafka | 🔴 VIOLATION | LOW | P3 | слой Kafka отсутствует |
| 8 | `setObservationEnabled` (Kafka) | 11_kafka | 🔴 VIOLATION | MEDIUM | P3 | слой Kafka отсутствует |
| 9 | Кастомные `MeterRegistry` метрики | 02_monitors | 🟡 PARTIAL | LOW | P2 | нет бизнес-метрик |
| 10 | Кастомный `HealthIndicator` | 02_monitors | 🟡 PARTIAL | LOW | P2 | нет |
| 11 | `@JsonIgnoreProperties(ignoreUnknown)` | 07_api_contract | 🟡 PARTIAL | LOW | P3 | только на `ObjectCreateRequest` |
| 12 | `ErrorHandlingDeserializer` | 11_kafka | 🟡 PARTIAL | MEDIUM | P3 | слой Kafka отсутствует |
| 13 | DLT / `DeadLetterPublishingRecoverer` | 11_kafka | 🟡 PARTIAL | MEDIUM | P3 | слой Kafka отсутствует |
| 14 | Kafka event поля (`eventId`/`eventTimestamp`/`sourceSystem`) | 11_kafka | 🟡 PARTIAL | LOW | P3 | слой Kafka отсутствует |
| 15 | `client.id` / `KafkaClientIdProvider` | 11_kafka | 🟡 PARTIAL | LOW | P3 | слой Kafka отсутствует |
| 16 | `fdm-validator-maven-plugin` | 15_fdm_plugin | 🟡 PARTIAL | LOW | P3 | плагин FDM не подключён |

---

## Сводка по темам (1–2 строки по каждой)

### 00 — Структура проекта
Многомодульный Maven (агрегатор `pom.xml`: `objects` + `objects-rest-client`), родитель `sbererp-bom:2026.05.0`, Java 21. `objects-rest-client` — Feign-библиотека с `ObjectsClientAutoConfiguration`; `objects` — CAP-микросервис (Web+JPA+Liquibase). **Отклонение:** `ru.sbrf.sbererp:logging-starter` вместо `core-common-logging-starter:3.2.1`.

### 01 — Стиль кода
Слои соблюдены (`service/{object,mdm}+impl`, `controller`, `repository`, `configuration/mapper/{request,response}`, `model/entity`). DI через `@RequiredArgsConstructor`, MapStruct `StrictMapperConfiguration`. **Нарушение:** нет интерфейсов `*ControllerApi`; swagger-контракт в `controller/swagger/ObjectControllerDocs.java`.

### 02 — Мониторинг
Стек готов: actuator, `micrometer-registry-otlp`, `spring-boot-starter-opentelemetry`, `feign-micrometer`; OTLP-экспорт и `MeterFilter` в `OpenTelemetryConfig`. **Гэп:** нет кастомных бизнес-метрик и `HealthIndicator`.

### 03 — Миграции
Двухуровневый Liquibase master-changelog + версионный `v{major.minor.patch}` (версия = pom.xml), папки таблиц только для затронутых; formatted SQL с `COMMENT ON` и `--rollback`. **Отклонения:** нет `--author`, неединый нейминг файлов, неупомянутая версия в папке (v1.0.0 при pom 1.0.2). ФМД упоминается минимально.

### 04 — Сборка
Checkstyle (validate), PMD (`failOnViolation`), SpotBugs (`failOnError`), JaCoCo (test), Pitest (`mutation-testing`), `spring-boot-maven-plugin` в `objects`. **CI не определён** (нет Jenkinsfile/workflows).

### 05 — Самопроверка
Перед сдачей: `mvn clean verify` (весь цикл) + `mvn test` (JaCoCo) + `mvn verify -Pmutation-testing`. Есть `specification/` и Liquibase для актуализации. Чек-пункт — не логировать секреты.

### 06 — Тесты
Покрытие по типам: `*ServiceImplTest`, `*MapperTest`, `*ControllerTest`, `WebApplicationTest`. Стиль — unit-only (JUnit 5 + Mockito + AssertJ, `@ExtendWith(MockitoExtension.class)`), без Spring-контекста. **Отклонение от rules/06:** нет `@SpringBootTest`/слайсов/H2/Testcontainers/MockMvc.

### 07 — API-контракт
Тонкий `ObjectController` (GET `/…/objects/{contract-version-id}` + POST `/…/objects`), swagger через springdoc + `ObjectControllerDocs`, DTO/request — в `objects-rest-client`. **Отклонения:** `sberpdi` константой (ложное срабатывание), нет `*ControllerApi`, `@JsonIgnoreProperties` частично.

### 08 — БД/JPA
8 entity (`@Entity`+`@Table` snake_case, PK UUID), `Service`-агрегатор, репозитории `JpaRepository`. DDL согласован с миграциями 1:1. **Гэп:** отсутствуют `@Version`, `@CreatedBy`, `@CreatedDate` (аудит/optimistic locking).

### 09 — Логирование
`ru.sbrf.sbererp:logging-starter` + `logstash-logback-encoder` подключены; `logback-spring.xml` (LogstashEncoder); `@Slf4j` в 9 классах. **Гэп:** MDC в коде не используется, `<includeMdc>false</includeMdc>`.

### 10 — Cloud Native
Actuator + probes включены (`probes.enabled=true`, `startup.enabled=true`, exposure), `BufferingApplicationStartup` в `WebApplication`. **Гэп:** нет кастомных `HealthIndicator`/бизнес-метрик; K8s/Docker/Helm манифестов в репо нет.

### 11 — Kafka
**Слой Kafka отсутствует** (`layers.kafka=[]`, нет `spring-kafka`). Интеграции — REST/OpenFeign. Соглашение фиксирует запрет тянуть Kafka-зависимости без потребности; при появлении Kafka применять `rules/11_kafka.md`.

### 12 — Конфигурация
Externalized config (все параметры через `${ENV:default}`), `feign.properties`, константы в `WebApplicationConstants`/`ExtendedConstantUtil`, `@AutoConfiguration` Feign. **Отклонения:** нет `@ConfigurationProperties`, DB pool не задан, профильных файлов нет.

### 13 — Денежные суммы
Только `BigDecimal` (double/float=0, `bigdecimal_files=9`). Точности из DDL: `NUMERIC(18,2)/NUMERIC(18,4)/NUMERIC(16,2)`. **Отклонение:** `partner.ownership_share_value` — `NUMERIC` без `(precision, scale)`.

### 14 — Идемпотентность REST
Стартер/`@Idempotency` отсутствуют. Идемпотентность прикладная: `ObjectCreationServiceImpl.createObject` → `checkExistObjectsForContractVersionId` → `ObjectsAlreadyExistException` по `contractVersionId`. Константа `IDEMPOTENCY_ID_HEADER_KEY` объявлена, но не используется; блок `web.idempotency.*` закомментирован.

### 15 — FDM Validator
**Плагин FDM не подключён** (нет `core-fdm-plugin`/`fdm-validator-maven-plugin`), `fdm-attributes.json` отсутствует, FDM-аннотаций в entity нет. Контроль ФМД — ручной (ревью чейнджлогов + соответствие entity-SQL). Следовать `rules/15_fdm_plugin.md` при подключении.

### 16 — Рефакторинг
**Critical violation:** дублирование `AssetObjectServiceImpl`/`RentalObjectServiceImpl` (80% идентичного кода), 4 одинаковых `add*` в `Service`, `ObjectsDTO` (~350 строк) vs `ObjectsCreationResponse` (~280 строк) — идентичная структура. Длинные классы: `ObjectControllerDocs` (~450 строк). Решение — template-паттерн + generics.

---

## Топ-5 рекомендаций

| # | Рекомендация | Severity | Затронуто файлов | Rule |
|---|-------------|----------|-----------------|------|
| 1 | Добавить `@Version` (optimistic locking) и аудит (`@CreatedBy/@LastModifiedBy/@CreatedDate`) в entity | HIGH | 8 entity-классов | 08_database |
| 2 | Внедрить MDC-трассировку (корреляцию request-id/correlation-id) и включить `includeMdc` в `logback-spring.xml` | HIGH | конфиг логирования + сервисы/контроллеры | 09_logging |
| 3 | Устранить дублирование `AssetObjectServiceImpl`/`RentalObjectServiceImpl` через template-паттерн и generics | HIGH | 2 сервисных класса, ~120 строк | 16_refactoring |
| 4 | Задокументировать фактический API-статус: не дублировать raw-строку `sberpdi`, рассмотреть `@JsonIgnoreProperties(ignoreUnknown=true)` на все request DTO | MEDIUM | контроллер/DTO | 07_api_contract |
| 5 | Вынести swagger-контракт в интерфейс `*ControllerApi` (или зафиксировать решение «Docs-классы») | MEDIUM | 1 контроллер | 01_coding |
| 6 | Завести кастомные `HealthIndicator` и бизнес-метрики (`MeterRegistry`) для критических зависимостей (MDM/Feign/БД) | MEDIUM | сервис/конфиги | 02_monitors, 10_cloud_native |

---

## Детали по каждой проверке

Ниже — evidence из `facts/gap_report.json` с пояснениями из `gap_notes.jsonl`. Реальные значения counts могут не совпадать из-за ограничений инструментов; приоритет — фактология §1/§2 соответствующих `service-rules/NN_*.md`.

### 08_database

#### Проверка: `@Version` optimistic locking
| Параметр | Значение |
|----------|----------|
| Rule | 08_database |
| Факт | `@Version` count=0 в `src/main/java` (entity) |
| Статус | 🔴 VIOLATION |
| Рекомендация | Добавить `@Version` в JPA-сущности для optimistic locking |

#### Проверка: `@CreatedBy / @LastModifiedBy`
| Параметр | Значение |
|----------|----------|
| Rule | 08_database |
| Факт | `@CreatedBy|@LastModifiedBy` count=0 |
| Статус | 🔴 VIOLATION |
| Рекомендация | Добавить аудит-поля и аннотации (или `@MappedSuperclass`) |

#### Проверка: `@CreatedDate / @CreationTimestamp`
| Параметр | Значение |
|----------|----------|
| Rule | 08_database |
| Факт | count=0 (статус аналитиком помечен compliant, но фактически отсутствует) |
| Статус | 🟢 COMPLIANT (фактически открытая зона) |
| Рекомендация | При внедрении аудита использовать `@CreationTimestamp`/`@UpdateTimestamp`/`@CreatedDate` |

### 09_logging

#### Проверка: `sbererp-logging-starter` в pom
| Параметр | Значение |
|----------|----------|
| Rule | 09_logging |
| Факт | скан-скрипт не нашёл «logging-starter»; **фактически** `ru.sbrf.sbererp:logging-starter` есть в `objects/pom.xml` |
| Статус | 🔴 VIOLATION (ложное срабатывание) |
| Рекомендация | Подтвердить зависимость `ru.sbrf.sbererp:logging-starter` |

#### Проверка: MDC-трассировка
| Параметр | Значение |
|----------|----------|
| Rule | 09_logging |
| Факт | `MDC.*` count=0 в `src/main/java`; `includeMdc=false` в `logback-spring.xml` |
| Статус | 🔴 VIOLATION |
| Рекомендация | Использовать MDC для корреляции (request-id/correlation-id); включить `includeMdc` |

### 07_api_contract

#### Проверка: заголовок `sberpdi`
| Параметр | Значение |
|----------|----------|
| Rule | 07_api_contract |
| Факт | count=0 по raw-строке; **фактически** заголовок задан константой `SBERPDI_HEADER_KEY` в `WebApplicationConstants.java` и используется `@RequestHeader(SBERPDI_HEADER_KEY)` |
| Статус | 🔴 VIOLATION (ложное срабатывание) |
| Рекомендация | Не дублировать raw-строку; следовать константе |

#### Проверка: `@Schema` без example
| Параметр | Значение |
|----------|----------|
| Rule | 07_api_contract |
| Факт | `@Schema(description)` на DTO, тела — в `@ExampleObject` |
| Статус | 🟢 COMPLIANT |

#### Проверка: `@JsonIgnoreProperties(ignoreUnknown)`
| Параметр | Значение |
|----------|----------|
| Rule | 07_api_contract |
| Факт | Присутствует только на `ObjectCreateRequest` (count=1), остальные DTO без него |
| Статус | 🟡 PARTIAL |
| Рекомендация | Рассмотреть на всех request DTO |

### 01_coding

#### Проверка: интерфейсы `*ControllerApi`
| Параметр | Значение |
|----------|----------|
| Rule | 01_coding |
| Факт | `ControllerApi` count=0; swagger-контракт в `controller/swagger/ObjectControllerDocs.java` |
| Статус | 🔴 VIOLATION |
| Рекомендация | Вынести API в `*ControllerApi` или явно зафиксировать решение «Docs-классы» |

### 02_monitors

#### Проверка: кастомные метрики `MeterRegistry`
| Параметр | Значение |
|----------|----------|
| Rule | 02_monitors |
| Факт | count=0 (`MeterRegistry|Counter.builder|Timer.builder|Gauge.builder`) |
| Статус | 🟡 PARTIAL |
| Рекомендация | Добавить бизнес-метрики (Counter/Timer/Gauge) |

#### Проверка: кастомный `HealthIndicator`
| Параметр | Значение |
|----------|----------|
| Rule | 02_monitors |
| Факт | count=0 (`AbstractHealthIndicator|HealthIndicator`) |
| Статус | 🟡 PARTIAL |
| Рекомендация | Создать `HealthIndicator` для критических зависимостей |

### 11_kafka (все проверки — отсутствие слоя)

`ErrorHandlingDeserializer`, DLT/`DeadLetterPublishingRecoverer`, Kafka-поля (`eventId`/`eventTimestamp`/`sourceSystem`), `BaseKafkaConfig`, `client.id`/`KafkaClientIdProvider`, `setObservationEnabled` — все `🟡 PARTIAL`/`🔴 VIOLATION` с count=0, потому что слой Kafka в сервисе **отсутствует**. Следовать `rules/11_kafka.md` при появлении Kafka.

### 15_fdm_plugin

#### Проверка: `fdm-validator-maven-plugin` / `core-fdm-plugin`
| Параметр | Значение |
|----------|----------|
| Rule | 15_fdm_plugin |
| Факт | плагин не найден (grep по pom = 0); `fdm-attributes.json` и FDM-аннотаций нет |
| Статус | 🟡 PARTIAL |
| Рекомендация | Подключить `core-fdm-plugin` и применять `rules/15_fdm_plugin.md` при необходимости валидации ФМД |

### 06_unit_tests_with_spring_context

#### Проверка: нейминг тестов `method_condition_result`
| Параметр | Значение |
|----------|----------|
| Rule | 06_unit_tests_with_spring_context |
| Факт | паттерн соблюдается (ratio=1.0 по `gap_report.json`) |
| Статус | 🟢 COMPLIANT |

#### Проверка: `@DisplayName` на русском
| Параметр | Значение |
|----------|----------|
| Rule | 06_unit_tests_with_spring_context |
| Факт | `@DisplayName` присутствует на тестах/классах (20 тест-классов, `WebApplicationTest` в т.ч.) |
| Статус | 🟢 COMPLIANT |

#### Проверка: `RestApiErrorTestConfig` в `@WebMvcTest`
| Параметр | Значение |
|----------|----------|
| Rule | 06_unit_tests_with_spring_context |
| Факт | `@WebMvcTest` не используется (стиль unit-only без Spring-контекста) |
| Статус | 🟢 COMPLIANT |
| Рекомендация | Сохранять unit-стиль; при первом внедрении среза добавить `@Import(RestApiErrorTestConfig.class)` |

### 01_coding (прочие проверки стиля)

#### Проверка: `@Data` на DTO
| Параметр | Значение |
|----------|----------|
| Rule | 01_coding |
| Факт | count=0 (`@Data` не используется в `src/main/java`) |
| Статус | 🟢 COMPLIANT |
| Рекомендация | При новых DTO использовать `@Value @Builder @Jacksonized` |

#### Проверка: `@Autowired` на полях
| Параметр | Значение |
|----------|----------|
| Rule | 01_coding |
| Факт | count=0; DI через `@RequiredArgsConstructor` (constructor injection) |
| Статус | 🟢 COMPLIANT |

#### Проверка: классы с >7 зависимостей
| Параметр | Значение |
|----------|----------|
| Rule | 01_coding |
| Факт | count=0 (нет классов с >7 `private final` полей) |
| Статус | 🟢 COMPLIANT |

#### Проверка: `@Value("${...}")` вместо `@ConfigurationProperties`
| Параметр | Значение |
|----------|----------|
| Rule | 01_coding |
| Факт | count=0; в коде только `@Value` в `OpenTelemetryConfig.java` |
| Статус | 🟢 COMPLIANT (см. правило 12_configuration) |

#### Проверка: Entity-суффикс на entity-классах
| Параметр | Значение |
|----------|----------|
| Rule | 01_coding |
| Факт | entity-классы (`AssetObject`, `RentalObject` и др.) не используют суффикс `Entity` (ratio=1.0 на отсутствие суффикса) |
| Статус | 🟢 COMPLIANT |
| Рекомендация | Зафиксировать доменное именование entity без суффикса как соглашение сервиса |

### 11_kafka — прочие проверки (слой отсутствует)

#### Проверка: `ErrorHandlingDeserializer`
| Параметр | Значение |
|----------|----------|
| Rule | 11_kafka |
| Факт | count=0 (слой Kafka отсутствует) |
| Статус | 🟡 PARTIAL |
| Рекомендация | Применять при появлении Kafka |

#### Проверка: DLT / `DeadLetterPublishingRecoverer`
| Параметр | Значение |
|----------|----------|
| Rule | 11_kafka |
| Факт | count=0 (слой Kafka отсутствует) |
| Статус | 🟡 PARTIAL |
| Рекомендация | Применять при появлении Kafka |

#### Проверка: Kafka event поля (`eventId`/`eventTimestamp`/`sourceSystem`)
| Параметр | Значение |
|----------|----------|
| Rule | 11_kafka |
| Факт | found=0 (слой Kafka отсутствует) |
| Статус | 🟡 PARTIAL |
| Рекомендация | Применять при появлении Kafka |

#### Проверка: `client.id` / `KafkaClientIdProvider`
| Параметр | Значение |
|----------|----------|
| Rule | 11_kafka |
| Факт | count=0 (слой Kafka отсутствует) |
| Статус | 🟡 PARTIAL |
| Рекомендация | Применять при появлении Kafka |

#### Проверка: deprecated `RETRIES_CONFIG`
| Параметр | Значение |
|----------|----------|
| Rule | 11_kafka |
| Факт | count=0 (запрещённая настройка не используется) |
| Статус | 🟢 COMPLIANT |

#### Проверка: Kafka DTO `@Data`
| Параметр | Значение |
|----------|----------|
| Rule | 11_kafka |
| Факт | `@Data` count=0 (слой Kafka и Kafka-DTO отсутствуют) |
| Статус | 🟢 COMPLIANT |

### 16_refactoring

#### Проверка: дублирование сервисов
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | `AssetObjectServiceImpl` и `RentalObjectServiceImpl` — 80% идентичного кода (~120 строк) |
| Статус | 🔴 CRITICAL VIOLATION |
| Рекомендация | Вынести общий код в template-паттерн с generics |

#### Проверка: дублирование методов add* в Service
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | 4 метода `addRentalObject`, `addAssetObject`, `addCapObject`, `addFinapObject` — идентичны |
| Статус | 🔴 CRITICAL VIOLATION |
| Рекомендация | Заменить на generic-метод |

#### Проверка: дублирование DTO
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | `ObjectsDTO` (~350 строк) vs `ObjectsCreationResponse` (~280 строк) — идентичная структура |
| Статус | 🔴 CRITICAL VIOLATION |
| Рекомендация | Объединить в один DTO |

#### Проверка: длины методов
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | Максимум ~26 строк (compliant) |
| Статус | 🟢 COMPLIANT |

#### Проверка: цикломатическая сложность
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | Максимум 3 (compliant) |
| Статус | 🟢 COMPLIANT |

#### Проверка: глубокая вложенность
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | Максимум 3 уровня (compliant) |
| Статус | 🟢 COMPLIANT |

#### Проверка: параметры методов
| Параметр | Значение |
|----------|----------|
| Rule | 16_refactoring |
| Факт | Максимум 4 параметра (compliant) |
| Статус | 🟢 COMPLIANT |