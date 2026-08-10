---
apply: always
mode: all
---

# Соглашение: Логирование, MDC (profitcontr-objects)

**Когда читать:** При добавлении логирования, настройке MDC, или отладке проблем с логами.

**Что описывает:** Logback конфигурация, MDC-контекст, уровни логирования, формат вывода.

**Глобальный эталон:** `rules/09_logging.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Зависимости logging-starter и logstash-encoder

`ru.sbrf.sbererp:logging-starter` подключён в `objects/pom.xml` (строки 104–106,
`<artifactId>logging-starter</artifactId>`, версия через `${sbererp-starter-logging.version}`),
а рядом заявлен `net.logstash.logback:logstash-logback-encoder` (строки 115–116).
Это подтверждает GAP `09_logging.logging_starter`: скрипт-скан не нашёл строку
`"logging-starter"` по ключевым паттернам, однако зависимость **фактически есть** в пом
модуля `objects` — срабатывание ложное, стартер подтверждается.

Стартер настраивается в `application.properties` через префикс `sbererp.logging.*`
(блок `# core-common-logging-starter`): `enabled.web=${LOGGING_ENABLED_WEB:true}`,
`enabled.feign=${LOGGING_ENABLED_FEIGN:true}`, `scope=${LOGGING_SCOPE:ALL}`,
`masked-fields=password,creditCard,secret`, `masked-headers=Authorization,Set-Cookie`,
`url-patterns=/api/*,/v1/*`. Уровни переопределяются переменными окружения:
`logging.level.root=${LOG_LEVEL:INFO}` и `logging.level.org.hibernate.*`.

### 1.2 Конфигурация logback-spring.xml

`objects/logback-spring.xml` (путь задаётся через `logging.config=${LOGBACK_CONFIG_FILEPATH:objects/}${LOGBACK_NAME:logback-spring.xml}`):
- **CONSOLE** — `ConsoleAppender`, человекочитаемый паттерн `log.pattern` (уровень, PID, логгер, `%m %n%wEx`).
- **FILE** — `RollingFileAppender` в `${LOG_DIR}/log.json` (`maxFileSize=5MB`, `maxHistory=5`, `totalSizeCap=50MB`).
- **FILE-encoder** — `net.logstash.logback.encoder.LogstashEncoder`: структурированный JSON с переопределёнными именами полей (`timestamp`, `message`, `levelStr`, `loggerName`, `thread`, `stackTrace`, `mdc`), `timestampPattern=[UNIX_TIMESTAMP_AS_STRING]`.
- **MDC**: в `<fieldNames>` поле `mdc` объявлено, но `<includeMdc>false</includeMdc>` — MDC-контекст в JSON не выводится. Тихие логгеры (`org.hibernate.engine.transaction`, `ConsumerCoordinator`) вынесены на `INFO`; `root level=INFO`.

### 1.3 Корреляционные заголовки и MDC в коде

Константы заголовков заданы в
`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java`:
`REQUEST_ID_HEADER_KEY`, `CORRELATION_ID_HEADER_KEY`, `SBERPDI_HEADER_KEY`, `RESPONSE_ID_HEADER_KEY`.
`ObjectController` принимает `request-id`/`correlation-id`/`sberpdi` через `@RequestHeader` и
пробрасывает их обратно заголовками ответа — но в лог/MDC эти значения **не кладутся**.

Поиск `MDC.*` / `org.slf4j.MDC` по `src/main/java` дал **0 совпадений** (GAP `09_logging.mdc_usage = violation`):
MDC-контекст в коде сервиса не используется. Вывод строк — через SLF4J Lombok-аннотацию `@Slf4j`
(ObjectController, GlobalExceptionHandler, ServiceServiceImpl, AssetObjectServiceImpl,
RentalObjectServiceImpl, ObjectCreationServiceImpl, OrganisationServiceImpl,
PartnerBankAccountServiceImpl, OpenTelemetryConfig).

### 1.4 Трейсинг и метрики через OpenTelemetry

`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java`
(`@ConditionalOnBooleanProperty("management.otlp.metrics.export.enabled")`, класс `@Slf4j` с
`log.info("OpenTelemetry config is enabled")`) регистрирует `MeterFilter` с тегами `app/pod/stand` и
префиксом `spring.application.ci`. Экспорт OTLP настраивается в `application.properties`
(`management.otlp.metrics.export.url=${OPENTELEMETRY_EXPORT_URL}`) и обеспечивается
`spring-boot-starter-opentelemetry` в `objects/pom.xml`. Трейсинг конфигурируется там же,
MDC с trace/span id не проставляется.

<!-- source: auto -->
## 2. Соглашения для агента

- Логировать через SLF4J-`Logger`: использовать Lombok `@Slf4j` на классе —
  это фактический стиль всех `service`/`controller`/`configuration` модуля `objects`
  (`object/src/main/java/ru/sbrf/sbererp/profitcontr/objects/**`). Использовать параметризацию
  `log.info("... {}", value)` и запретить конкатенацию строк и `System.out.println`.
- Корреляционные идентификаторы (`request-id`, `correlation-id`) принимать/прокидывать
  через константы из `WebApplicationConstants.java` (не хардкодить raw-строки в местах вызовов) —
  образец — `ObjectController.getObjectByContractVersionId` (`@RequestHeader(CORRELATION_ID_HEADER_KEY)`).
  Новый код должен класть эти значения в MDC в начале обработки, если требуется их видимость в логах.
- Не логировать секреты и персональные данные: пароли, токены, данные карт (например, из
  `accounting.env` / datasource `password`). Для HTTP-полей и заголовков использовать
  маскирование стартера — `sbererp.logging.masked-fields=password,creditCard,secret`,
  `sbererp.logging.masked-headers=Authorization,Set-Cookie` в `application.properties`.
- Поддерживать структурированный формат: изменения в `logback-spring.xml` должны сохранять
  `LogstashEncoder` для FILE-аппендера и не ломать поля (`timestamp`, `levelStr`, `stackTrace`, `mdc`).
- Общие требования (уровни, язык сообщений, URL-паттерны) применять по глобальному
  `rules/09_logging.md` в `core-gigacode-skills` — локально поверх него конкретизируется только
  фактическая конфигурация репозитория.

<!-- source: auto -->
## 3. Чек-лист

- [ ] Логгер — через `@Slf4j` (Lombok), сообщения параметризованы (`{}`), без конкатенации строк и `System.out.println`
- [ ] Уровни соответствуют конвенции: ERROR — сбои, WARN — recoverable, INFO — бизнес-события
- [ ] Критичные исключения логируются со стеком (`log.error("Ошибка", e)`), а не только `e.getMessage()`
- [ ] Секреты и персональные данные не попадают в лог; маскирование поля/заголовки настроены в `application.properties`
- [ ] Корреляционные заголовки read/reply через константы `WebApplicationConstants` (`REQUEST_ID_HEADER_KEY`, `CORRELATION_ID_HEADER_KEY`)
- [ ] Формат логов совместим с `logstash-logback-encoder` (FILE-аппендер в `logback-spring.xml`)
- [ ] Новый MDC-код проставляет контекст в начале обработки и удаляет после (`MDC.remove`), при необходимости — с включением `<includeMdc>true</includeMdc>`

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: ObjectsClientAutoConfiguration.java
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/configuration/ObjectsClientAutoConfiguration.java`

```java
@AutoConfiguration
@EnableFeignClients(
        basePackageClasses = ObjectsClient.class
)
public class ObjectsClientAutoConfiguration {
}
```

Автоконфигурация Feign-клиента; входящие/исходящие HTTP-запросы клиента логируются
стартером `logging-starter` (`sbererp.logging.enabled.feign=true`), без ручного MDC.

### Example 2: OpenTelemetryConfig.java (лог на старте)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java`

```java
@Slf4j
@ConditionalOnBooleanProperty("management.otlp.metrics.export.enabled")
@Configuration
@RequiredArgsConstructor
public class OpenTelemetryConfig {

    @PostConstruct
    void init() {
        log.info("OpenTelemetry config is enabled");
    }
}
```

Пример использования `@Slf4j` + `log.info(...)` без конкатенации — канонический стиль
логирования в модуле `objects`; конфигурация трейсинга через `spring-boot-starter-opentelemetry`.

### Example 3: logback-spring.xml (Logstash-encoder, FILE)
**Путь:** `objects/logback-spring.xml`

```xml
<encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <fieldNames>
        <timestamp>timestamp</timestamp>
        <message>message</message>
        <level>levelStr</level>
        <thread>threadName</thread>
        <mdc>mdc</mdc>
    </fieldNames>
    <includeMdc>false</includeMdc>
</encoder>
```

Структурированный JSON-вывод в `${LOG_DIR}/log.json`; поле `mdc` объявлено, но не заполняется
(`includeMdc=false`) — согласуется с отсутствием MDC-кода в `src/main/java`.

<!-- source: auto -->
## 5. Исключения и оговорки

Соглашение по MDC носит характер **открытой зоны**: в текущем коде MDC не используется
(GAP `09_logging.mdc_usage = violation`, проверка по `src/main/java` дала count=0).
До внедрения MDC-кода корреляция в логах не проставляется автоматически — для отладки
полагаться на `request-id`/`correlation-id` на уровне HTTP-заголовков и логи стартера.
При первом добавлении MDC обновить `logback-spring.xml` (`<includeMdc>true</includeMdc>`),
иначе MDC-поля в JSON-логах не появятся.

<!-- source: auto -->
## 6. Обновление

Пересобирать при смене логирующего стека (обновление версии `sbererp-starter-logging.version`
или `logstash-logback-encoder` в `objects/pom.xml`), изменении аппендеров/полей в
`logback-spring.xml`, либо при первом внедрении MDC-кода (включение `includeMdc`, добавление
соответствующих `MDC.put/remove` в слои `service`/`controller`).