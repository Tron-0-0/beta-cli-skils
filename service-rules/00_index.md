---
apply: always
mode: all
---

# Локальные правила разработки: profitcontr-objects

**Сгенерировано:** 2026-08-05

**Стек сервиса:** микросервисы SberERP — **Java / Spring Boot** (см. `pom.xml`). Скрипты анализа репозитория при генерации этих правил — **вспомогательные** (пакет навыка) и **не** задают стек приложения.

## Приоритет

1. **standard-rules** — обязательные нормы платформы SberERP (регламент).
2. **service-rules** (эта папка) — фактические соглашения *этого* репозитория, выведенные из кода. Они **дополняют** и **конкретизируют** стандарт, но **не снимают** требований регламента.

Глобальные **standard-rules**: `C:\Work\core-gigacode-skills\rules`.

**Корень service-rules (этот набор):** `C:\Work\profitcontr-objects\.gigacode\service-rules`

Файлы `00_*.md` … `15_*.md` в этой папке (кроме этого индекса) оформляй по **skill-rules/OUTPUT_FORMAT.md** пакета навыка: шаблон разделов, чек-лист, примеры с якорями в коде (как у **хорошо оформленного навыка Cursor** / create-skill).

## Содержимое

Полные тексты соглашений лежат в `parts/`, краткая сводка (из §1 «Наблюдения» каждого файла) сведена в колонку «Кратко».

| Файл | rules/ | Кратко |
|------|--------|--------|
| `00_project_creation.md` | `rules/00_project_creation.md` | Многомодульный Maven-проект: корневой `pom.xml` — агрегатор `packaging=pom` (`ru.sbrf.sbererp.profitcontr:profitcontr:1.0.2-SNAPSHOT`) с модулями `objects` (CAP-микросервис) и `objects-rest-client` (Feign-библиотека, `@AutoConfiguration` + `@EnableFeignClients` в `ObjectsClientAutoConfiguration.java`); родитель `sbererp-bom:2026.05.0`, Java 21 |
| `01_coding.md` | `rules/01_coding.md` | Слои `service/{object,mdm}+impl`, `controller`, `repository`, `configuration/mapper/{request,response}`; DI через `@RequiredArgsConstructor` (без `@Autowired`); MapStruct со `StrictMapperConfiguration` (componentModel=spring); **нет `*ControllerApi`** — Swagger через кастомные аннотации `controller/swagger/ObjectControllerDocs.java`; форматирование вызовов: <=3 params → одна строка, 4 params → каждый с новой строки, >=5 params → класс-обёртка (record) |
| `02_monitors.md` | `rules/02_monitors.md` | Actuator + Micrometer/OTLP: `management.endpoints.web.exposure.include=startup,health,info,metrics,env`, probes enabled; `OpenTelemetryConfig.MeterFilter` добавляет префикс CI и теги `app/pod/stand`; **GAP (partial)** — нет `MeterRegistry`/`Counter` и `HealthIndicator` (count=0) |
| `03_migrations.md` | `rules/03_migrations.md` | Версионирование = версия из pom.xml (v{major.minor.patch}); корневой `0001_changelog.xml` → `changelog.xml` в версии → папки таблиц только для затронутых; formatted SQL + `--changeset id:` + `COMMENT ON` + `--rollback`; минимальная привязка к ФМД |
| `04_compilation.md` | `rules/04_compilation.md` | Сборка `mvn clean verify` из корня: checkstyle (validate), PMD (`failOnViolation=true`), SpotBugs (`failOnError=true`), JaCoCo (фаза test); профиль Pitest `mvn verify -Pmutation-testing`; `objects-rest-client` — библиотека (`spring-boot.repackage.skip=true`); **CI НЕ ОПРЕДЕЛЕНО** (нет `Jenkinsfile`/`.github/workflows`) |
| `05_self_correction.md` | `rules/05_self_correction.md` | Перед сдачей обязателен «зелёный» `mvn clean verify`; три анализатора в корневом pom (Javadoc типов, без star-imports/trailing comments); риск — `accounting.env` с реальными DB/keystore-credentials (в `.gitignore`), маскировка `password/secret/creditCard` в `sbererp.logging.masked-*` |
| `06_unit_tests_with_spring_context.md` | `rules/06_unit_tests_with_spring_context.md` | 21 тест-класс (`*ServiceImplTest`, `*MapperTest`, `*ControllerTest`, `WebApplicationTest`) — чистые unit-тесты на Mockito/AssertJ; **НЕ ОПРЕДЕЛЕНО** `@SpringBootTest`/`@WebMvcTest`/`@DataJpaTest`/Testcontainers — отклонение от эталона (unit-only, моки одиночных зависимостей) |
| `07_api_contract.md` | `rules/07_api_contract.md` | Base path из констант `DEFAULT_URL_PREFIX_API` + `OBJECTS_URL_PREFIX_APU` = `/api/v1/profitcontr/objects/objects`; обязательные заголовки `request-id`/`correlation-id`/`sberpdi` заданы константами `WebApplicationConstants.*` (sberpdi через `SBERPDI_HEADER_KEY` — ложное срабатывание сканера по raw-строке) |
| `08_database.md` | `rules/08_database.md` | 8 JPA-entity в `model/entity/` (`@Table(name=snake_case)`, PK UUID `@GeneratedValue(UUID)`), согласованы с Liquibase 1:1; корень `Service` — `@OneToMany(cascade=ALL)` rental/asset/cap/finap + `@OneToOne` organisation; **аудит и `@Version` отсутствуют** (`@CreatedDate`/`@CreatedBy` count=0) |
| `09_logging.md` | `rules/09_logging.md` | Логирование `@Slf4j` (9 классов); `logging-starter` + `logstash-logback-encoder` в `objects/pom.xml` (версия `${sbererp-starter-logging.version}`); FILE-аппендер `LogstashEncoder` в `logback-spring.xml`; **GAP** — MDC в коде не используется (`MDC.*` count=0), `<includeMdc>false</includeMdc>` |
| `10_cloud_native.md` | `rules/10_cloud_native.md` | Probes включены (`health.probes.enabled=true`, `startup.enabled=true`, exposure содержит и `startup`, и `health`); startup через `BufferingApplicationStartup` в `WebApplication.java`; `OpenTelemetryConfig` (MeterFilter app/pod/stand); **K8s/Docker/Helm НЕ ОПРЕДЕЛЕНО** (нет манифестов) |
| `11_kafka.md` | `rules/11_kafka.md` | Kafka-слой отсутствует (`layers.kafka=[]`, `scheduling=[]`, `spring_kafka=false`; нет `spring-kafka` в pom) — интеграции через REST/OpenFeign: `ObjectsClient.java` (`@FeignClient`) + `ObjectsClientAutoConfiguration`; не тащить Kafka-зависимости без реальной потребности |
| `12_configuration.md` | `rules/12_configuration.md` | `application.properties` — externalized config `${ENV:default}` (порт `APPLICATION_PORT`, datasource `DB_*`, Liquibase, springdoc, OTLP); `feign.properties` (mdm-client.url, resilience4j 15s, профиль `local` через `spring.config.activate.on-profile`); константы в `WebApplicationConstants`/`ExtendedConstantUtil`; **нет `@ConfigurationProperties`** и DB-pool параметров |
| `13_monetary.md` | `rules/13_monetary.md` | Все денежные поля — `BigDecimal` (`double`/`float` count=0, compliant): `RentalObject` ↔ `NUMERIC(18,2)`/`NUMERIC(18,4)`/`NUMERIC(16,2)` в DDL; зеркальные DTO (`RentalObjectCreateRequest`, `ObjectsDTO.RentalObjectDTO`); **отклонение** — `partner.ownership_share_value NUMERIC` без `(precision, scale)` |
| `14_idempotency_rest.md` | `rules/14_idempotency_rest.md` | Стартер `core-common-web-idempotency-starter` и `@Idempotency` **НЕ подключены** (count=0); константа `IDEMPOTENCY_ID_HEADER_KEY="idempotency-key"` объявлена, но не читается; блок `web.idempotency.*` закомментирован; идемпотентность — прикладная по натуральному ключу `contractVersionId` (`ObjectsAlreadyExistException`) |
| `15_fdm_plugin.md` | `rules/15_fdm_plugin.md` | FDM-валидатор **отсутствует**: плагин `core-fdm-plugin`/`fdm-validator-maven-plugin` в pom не найден, `fdm-attributes.json` нет, `migrationsPath` не задан, FDM-аннотаций в entity нет — «не применимо/отсутствует»; контроль ФМД — ручное ревью чейнджлогов + `objects/db-assembly.xml` (ZIP-упаковка миграций) |
| `16_refactoring.md` | `rules/16_refactoring.md` | Методы ≤30 строк, классы ≤200 строк, сложность ≤5; **critical violation** — дублирование `AssetObjectServiceImpl`/`RentalObjectServiceImpl` (80% идентичного кода), 4 одинаковых `add*` в `Service`, `ObjectsDTO`/`ObjectsCreationResponse` (280-350 строк); решение — template-паттерн + generics |
| `17_enums_over_constants.md` | `rules/17_enums_over_constants.md` | **Предпочтение `enum` над константами**: типы, статусы, коды ошибок — только `enum` в `model/enums/`; константы (`static final`) — только для конфигурационных значений и заголовков |
| `GAP-ARCHITECTURE-ANALYSIS.md` | — | Сводные расхождения service-rules с глобальным регламентом `rules/`: проверки по `gap_notes.jsonl` — локальные отклонения (01 ControllerApi, 07 sberpdi, 09 MDC, 12 @ConfigurationProperties, 14 idempotency), partial (02/10 метрики и HealthIndicator), «не применимо» (11 Kafka, 15 FDM) |

## Как обновлять

Повторно запусти skill **create-development-rules** после существенных архитектурных изменений или перед онбордингом нового разработчика. Удали устаревшие выводы вручную, если анализ устарел.