---
apply: always
mode: all
---

# Соглашение: Конфигурация и property (profitcontr-objects)

**Когда читать:** При добавлении конфигурационных параметров, настройке профилей, работе с properties.

**Что описывает:** application.properties / feign.properties, env-переменные, автоконфигурации стартера клиента, константы конфигурации, профили.

**Глобальный эталон:** `rules/12_configuration.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 application.properties — внешние переменные окружения с дефолтами

`objects/src/main/resources/application.properties` — все значения вынесены в переменные окружения
в формате `${ENV:default}` (externalized config). Ключевые группы:
- **Порт/HTTP** — `server.port=${APPLICATION_PORT:8080}`, `server.max-http-request-header-size=${HTTP_MAX_HEADER_SIZE:10MB}`
  (созвучно эталону `rules/12_configuration.md` про `max-http-request-header-size` для BFF с JWT).
  Multipart заданы жёстко (`max-file-size=50MB`, `max-request-size=300MB`).
- **Datasource** — `spring.datasource.url=${DB_DRIVER}://${DB_HOST}:${DB_PORT}/${DB_NAME}?${DB_PARAM}`,
  `username=${DB_USERNAME}`, `password=${DB_PASSWORD}`, `spring.jpa.properties.hibernate.default_schema=${DB_SCHEMA}`
  (пароли/логины из `accounting.env`, в самом `application.properties` не хардкодятся).
- **Liquibase** — `spring.liquibase.enabled=${LIQUIBASE_ENABLED:false}` (по умолчанию выключен),
  `change-log=classpath:/db/changelog/0001_changelog.xml`, `default-schema=${DB_SCHEMA}`.
- **Springdoc/Swagger** — `springdoc.swagger-ui.enabled=${SWAGGER_UI_ENABLED:false}`,
  `springdoc.api-docs.enabled=${API_DOCS_ENABLED:false}` — по умолчанию отключены; пути зафиксированы
  как `/objects-service/swagger-ui` и `/objects-service/v3/api-docs`.
- **OpenTelemetry** — `management.otlp.metrics.export.url=${OPENTELEMETRY_EXPORT_URL}`,
  `enabled=${OPENTELEMETRY_ENABLED:true}`, `step=30s`, `batchSize=15000`.
- **Логирование** — `logging.level.root=${LOG_LEVEL:INFO}`, `logging.level.org.hibernate.*=${LOGGING_LEVEL_HIBERNATE:INFO}`,
  `logging.config=${LOGBACK_CONFIG_FILEPATH:objects/}${LOGBACK_NAME:logback-spring.xml}`,
  `spring.cloud.openfeign.client.config.default.micrometer.enabled=${OPENFEIGN_MICROMETER_ENABLED:true}`.

Блок `# core-common-web-idempotency-starter` (ключи `web.idempotency.*`) целиком **закомментирован** —
идемпотентность выключена; при включении потребуются env `WEB_IDEMPOTENCY_*`.

### 1.2 feign.properties — конфигурация Feign-клиента и профиль `local`

`objects/src/main/resources/feign.properties`:
- `resilience4j.timelimiter.configs.default.timeout-duration=15s` — таймаут для вызовов.
- `mdm-client.url=${EXT_MDM_PROTOCOL:http}://${EXT_MDM_HOST}:${EXT_MDM_PORT}/api/v1/mdm/datamart` —
  адрес MDM-сервиса через env (без хардкода хостов/портов).
- Профиль `local`: `spring.config.activate.on-profile=local` + `spring.ssl.bundle.jks.profitcontr-ssl`
  (`keystore.location=${JKEYSTORE}`, `keystore.password=${JKEYSTORE_PASSWORD}`, type=JKS) — ключи и пароли
  подтягиваются из окружения, не зашиты в файл.

Профили задаются через `spring.config.activate.on-profile=local` поверх общих properties; других
профильных файлов (`application-{dev,rel,test}.yml`) в репозитории нет.

### 1.3 Константы конфигурации в Java (UTILITY-классы)

- `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java` —
  класс `@UtilityClass`: URL-префиксы `DEFAULT_URL_PREFIX_API="/api/v1/profitcontr/objects"`,
  `OBJECTS_URL_PREFIX_APU="/objects"`, `APPLICATION_STARTUP_BUFFER_CAPACITY=2048`, ключи заголовков
  `REQUEST_ID_HEADER_KEY`, `CORRELATION_ID_HEADER_KEY`, `IDEMPOTENCY_ID_HEADER_KEY`, `SBERPDI_HEADER_KEY`,
  `RESPONSE_ID_HEADER_KEY`.
- `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/ExtendedConstantUtil.java` —
  класс `@UtilityClass` для OpenTelemetry: `POD_NAME` из env `HOSTNAME`, `STAND` из env `NAMESPACE`
  (с фолбэками `unknown-pod-name-*`/`UNKNOWN-STAND`).

Конфигурация через `@ConfigurationProperties` в коде **не обнаружена**; используются `@Value`
(OpenTelemetryConfig: `spring.application.name`, `spring.application.ci`) и структура
`@AutoConfiguration`/`@EnableFeignClients` (см. §1.4).

### 1.4 ObjectsClientAutoConfiguration — автоконфигурация стартера клиента

`objects-rest-client/src/main/java/ru/sbrf/.../client/configuration/ObjectsClientAutoConfiguration.java` —
`@AutoConfiguration` + `@EnableFeignClients(basePackageClasses = ObjectsClient.class)`. Это golden_sample
для темы «Конфигурация»: регистрирует Feign-клиента автоматически, без ручного `@EnableFeignClients` в приложении.

### 1.5 accounting.env — чувствительные параметры вне кода

`accounting.env` (в корне) содержит ключи `DB_SCHEMA`, `DB_USERNAME`, `DB_PASSWORD`, `JKEYSTORE`,
`JKEYSTORE_PASSWORD`. Значения паролей/логинов в этом документе **не приводятся**. Файл относится
к локальному запуску и не должен попадать в лог/артефакты (упомянут в 05_self_correction).

### 1.6 Сверка с глобальным эталоном rules/12_configuration.md

Эталон `core-gigacode-skills/rules/12_configuration.md` предъявляет переменные из реестра
унифицированных переменных, `APPLICATION_PORT`, DB-pool (`DB_MINIMUM_IDLE`, `DB_MAXIMUM_POOL_SIZE`,
`DB_CONNECTION_TIMEOUT`), `max-http-request-header-size`. В репозитории покрыты `APPLICATION_PORT`,
`max-http-request-header-size` и OTLP; параметры **DB pool** в `application.properties` отсутствуют —
открытая зона к `rules/12`.

<!-- source: auto -->
## 2. Соглашения для агента

- Все секреты и окружение выносить в env-переменные формата `${ENV:default}` и не хардкодить значения.
  Пароли БД/keystore (как в `accounting.env`) никогда не выводить в `application*.properties` и в этот документ.
- Новые параметры добавлять в соответствующий `.properties` с осмысленным дефолтом (`${VARIABLE:default}`
  или фиксированное нечувствительное значение) и не дублировать их в коде классов. Для чувствительных
  параметров — только внешний источник.
- Базовые URL/пути и ключи заголовков держать в констант-классах (`WebApplicationConstants`) и ссылаться
  на них из кода, не разъезжаться строками в контроллерах/клиентах.
- Конфигурацию внешних интеграций группировать в отдельный `.properties` — образец `feign.properties`
  (`mdm-client.url`, SSL-bundle JKS, таймауты resilience4j).
- Общие параметры Spring Boot управляются платформенным родительским `pom`/`sbererp-bom` + стартерами;
  локально переопределять через env, а не вступать в конфликт с библиотечным конфигом.

<!-- source: auto -->
## 3. Чек-лист

- [ ] Новый параметр добавлен в `application.properties`/`feign.properties` с дефолтом `${ENV:default}` и описанием
- [ ] Секреты (пароли, keystore, credentials из `accounting.env`) вынесены в env — значений в properties нет
- [ ] Изменённые ключи не ломают запуск без локального `accounting.env` (дефолты работают)
- [ ] Базовые URL и заголовки берутся из констант `WebApplicationConstants`, не хардкодятся в местах вызова
- [ ] Конфигурация Feign оформлена через `@AutoConfiguration`/`@EnableFeignClients` стартера `objects-rest-client`
- [ ] Для внешних интеграций использован единый префикс (`mdm-client.*`, `spring.cloud.openfeign.*`) по образцу `feign.properties`
- [ ] При добавлении профильных значений применён `spring.config.activate.on-profile`, а не дублирование файла
- [ ] Параметры DB pool (`DB_MINIMUM_IDLE`, `DB_MAXIMUM_POOL_SIZE`, `DB_CONNECTION_TIMEOUT`) из `rules/12` — добавить при необходимости

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: application.properties (externalized config)
**Путь:** `objects/src/main/resources/application.properties`

```properties
server.port=${APPLICATION_PORT:8080}
spring.datasource.url=${DB_DRIVER}://${DB_HOST}:${DB_PORT}/${DB_NAME}?${DB_PARAM}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
spring.liquibase.enabled=${LIQUIBASE_ENABLED:false}
springdoc.swagger-ui.enabled=${SWAGGER_UI_ENABLED:false}
```

Все значения через `${ENV:default}`; критичные секреты (например `${DB_PASSWORD}`) не имеют дефолтов
в репо и приходят из окружения.

### Example 2: ObjectsClientAutoConfiguration (автоконфигурация клиента)
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/configuration/ObjectsClientAutoConfiguration.java`

```java
@AutoConfiguration
@EnableFeignClients(
        basePackageClasses = ObjectsClient.class
)
public class ObjectsClientAutoConfiguration {
}
```

Автоконфигурация Feign-клиента стартера — клиентская конфигурация оформлена автономно, без ручного
`@EnableFeignClients`/`@ConfigurationProperties` в приложении.

### Example 3: WebApplicationConstants (константы конфигурации)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java`

```java
@UtilityClass
public class WebApplicationConstants {
    public static final String DEFAULT_URL_PREFIX_API = "/api/v1/profitcontr/objects";
    public static final String OBJECTS_URL_PREFIX_APU = "/objects";
    public static final String REQUEST_ID_HEADER_KEY = "request-id";
    public static final String CORRELATION_ID_HEADER_KEY = "correlation-id";
    public static final String SBERPDI_HEADER_KEY = "sberpdi";
}
```

URL-префиксы и ключи заголовков сосредоточены в одном месте — код ссылается на константы, а не на raw-строки.

<!-- source: auto -->
## 5. Исключения и оговорки

В репозитории **нет** `@ConfigurationProperties`-классов и профильных файлов `dev/rel/test` — параметры
задаются через `@Value` (OpenTelemetryConfig) и внешнее окружение (`application.properties`). До появления
типизированных properties-классов агент не должен искусственно вводить `@ConfigurationProperties` без
запроса; локально достаточно externalized-стиля `${ENV:default}`, как делают параметры выше. Открытая зона
к `rules/12` — параметры DB pool и документирование переменных из реестра унифицированных переменных.

<!-- source: auto -->
## 6. Обновление

Пересобирать при добавлении крупного конфигурационного блока (например, включении идемпотентности —
разкомментирование `web.idempotency.*`), введении типизированных `@ConfigurationProperties`, изменении
констант в `WebApplicationConstants`/`ExtendedConstantUtil`, а также при смене базовых URL-префиксов.