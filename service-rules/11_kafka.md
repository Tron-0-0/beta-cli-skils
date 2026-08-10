---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Kafka: продюсеры, консюмеры, ретраи (profitcontr-objects)

**Когда читать:** При работе с Kafka: создание consumer/producer, настройка топиков, обработка ошибок, либо при появлении Kafka-зависимости в сервисе. Сейчас сервис Kafka **не использует** — правила ниже фиксируют отсутствие Kafka-слоя и образец межсервисной интеграции через REST/Feign.

**Что описывает:** Kafka consumer/producer, Inbox/Outbox паттерн, retry/DLT, идемпотентность. В текущем сервисе Kafka-слоя нет — фактический стек интеграций построен на OpenFeign и синхронном REST.

**Глобальный эталон:** `rules/11_kafka.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Kafka-слой отсутствует

По данным `facts/scan.json` Kafka в сервисе **не используется**:

- `layers.kafka` — **пусто** (`[]`): нет классов в пакете `.../kafka/...`, `exception/kafka/`, `handler/`.
- `scheduling` — **пусто** (`[]`): нет `*KafkaInboxScheduler*` / планировщиков Inbox.
- `stack.stack_markers`: `spring_kafka: false`, `springwolf: false`, `kafka_inbox: false`.
- В `objects/pom.xml` **нет** зависимостей `spring-kafka`, `spring-kafka-test`, `kafka-inbox-starter`, `springwolf-*`.

### 1.2 Фактический стек интеграций — REST / OpenFeign

Межсервисное взаимодействие в этом сервисе асинхронно по данным реализовано **не через сообщения**, а через синхронный REST-вызов и Feign-клиенты:

- `objects-rest-client/pom.xml` — `spring-cloud-starter-openfeign` (стр. 17-19), `ssl-context-starter`, `jackson-databind`.
- `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/ObjectsClient.java` — `@FeignClient(name = "objects-client", configuration = SSLFeignClientConfiguration.class)` с методами `createObjects` (`@PostMapping`) и `getObjectsByContractVersionId` (`@GetMapping`), проброс заголовков `request-id`, `correlation-id`, `sberpdi`.
- `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/configuration/ObjectsClientAutoConfiguration.java` — `@AutoConfiguration @EnableFeignClients(basePackageClasses = ObjectsClient.class)`.
- `application.properties`: `spring.cloud.openfeign.client.config.default.micrometer.enabled=${OPENFEIGN_MICROMETER_ENABLED:true}` и `sbererp.logging.enabled.feign=true`.

Единственное упоминание Kafka — отключённые флаги логирования `sbererp.logging.enabled.kafka=false` / `enabled.sync-kafka=false` в `application.properties`, что лишь подтверждает отсутствие Kafka в рантайме.

### 1.3 Идемпотентность и корреляция без Kafka

Сквозная идентификация реализована на HTTP-уровне (заголовки), а не через Kafka-event fields:

- `WebApplicationConstants` — константы `REQUEST_ID_HEADER_KEY="request-id"`, `CORRELATION_ID_HEADER_KEY="correlation-id"`, `SBERPDI_HEADER_KEY="sberpdi"`.
- `ObjectController` и Feign `ObjectsClient` пробрасывают их через `@RequestHeader`.
- Idempotency-starter отключён (закомментирован в `application.properties`).

---

<!-- source: auto -->
## 2. Соглашения для агента

1. **Не тащить Kafka-зависимости без реальной потребности.** В `objects/pom.xml` нет `spring-kafka` — не добавлять `spring-kafka`, `kafka-inbox-starter`, `springwolf-*` в сервис без бизнес-задачи на обмен сообщениями. Пока интеграции строятся на Feign/`objects-rest-client/pom.xml` и REST (`ObjectsClient.java`).
2. **Межсервисные вызовы — через существующий Feign-контракт, а не через импровизированный обмен сообщениями.** Новые вызовы к внешним API добавлять методами в `ObjectsClient.java` (`@FeignClient`, конфигурация `SSLFeignClientConfiguration`), с обязательным пробросом `request-id` / `correlation-id` / `sberpdi`.
3. **Если Kafka всё же добавится — применять глобальный эталон `rules/11_kafka.md` целиком, а не «частично».** Внедряемые консьюмеры/продюсеры должны следовать эталону: ErrorHandlingDeserializer (Trusted Packages без `*`), ручной `AckMode.MANUAL`, DLT `{topic}-DLT`, `KafkaClientIdProvider.buildClientId(...)`, `setObservationEnabled(true)`, отдельные бины `kafkaTemplate<Сущность>` / `kafkaListenerContainerFactory<Сущность>`, иммутабельные event-DTO (`@Value @Builder @Jacksonized` с `eventId`/`eventTimestamp`/`sourceSystem`).
4. **Внешние настройки Kafka — только в `application.properties` через env-переменные** (по образцу остального `application.properties`, где все значения вынесены в `${...}`), не хардкодить топики/группы/`client.id`. Пока `spring_kafka: false`, эти ключи добавлять не требуется.
5. **Не вводить Inbox/Outbox и планировщики до появления реального event-driven потока.** В `scheduling` пусто; не добавлять `@Scheduled` Inbox-обработчики («на будущее») — это создаст мёртвый код, не подтверждённый брокером.

---

<!-- source: auto -->
## 3. Чек-лист

- [ ] В `objects/pom.xml` подтверждено отсутствие необоснованных зависимостей `spring-kafka` / `kafka-inbox-starter` / `springwolf-*` (пока Kafka не включён).
- [ ] `facts/scan.json` по теме 11: `layers.kafka` пуст, `scheduling` пуст, `stack_markers.spring_kafka=false` — не менять без реальной задачи.
- [ ] Новые интеграции идут через Feign-контракт (`ObjectsClient.java`, `objects-rest-client/pom.xml`), заголовки `request-id`/`correlation-id`/`sberpdi` пробрасываются.
- [ ] Если Kafka добавлен — консьюмер использует `ErrorHandlingDeserializer` + явный `spring.json.trusted.packages` (без `*`), `AckMode.MANUAL`, `ENABLE_AUTO_COMMIT=false`.
- [ ] Если Kafka добавлен — настроены DLT-стратегия `DeadLetterPublishingRecoverer` + `DefaultErrorHandler` (не ретраить `SerializationException`/`ConstraintViolationException`), ретраи не блокируют поток листенера (`Thread.sleep` запрещён).
- [ ] Если Kafka добавлен — `client.id` формируется через `KafkaClientIdProvider`, имя бина по формату `kafkaTemplate<Сущность>` / `kafkaListenerContainerFactory<Сущность>`, `setObservationEnabled(true)`.
- [ ] Если Kafka добавлен — event-DTO иммутабельные (`@Value @Builder @Jacksonized`) с полями `eventId`/`eventTimestamp`/`sourceSystem`; настройки топиков/групп вынесены в `application.properties` через env-переменные, секретов/адресов брокеров в коде нет.

---

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: ObjectsClient.java (фактический образец асинхронной/межсервисной интеграции)
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/ObjectsClient.java`

```java
@FeignClient(
        name = "objects-client",
        configuration = SSLFeignClientConfiguration.class
)
public interface ObjectsClient {
    String REQUEST_ID_HEADER_KEY = "request-id";
    String CORRELATION_ID_HEADER_KEY = "correlation-id";
    String SBERPDI_HEADER_KEY = "sberpdi";

    @PostMapping("/objects")
    ObjectsCreationResponse createObjects(
            @RequestBody ObjectCreateRequest request,
            @RequestHeader(value = REQUEST_ID_HEADER_KEY) UUID requestId,
            @RequestHeader(value = CORRELATION_ID_HEADER_KEY) UUID correlationId,
            @RequestHeader(value = SBERPDI_HEADER_KEY) String sberPDI);

    @GetMapping("/objects/{contract-version-id}")
    ObjectsDTO getObjectsByContractVersionId(
            @PathVariable("contract-version-id") UUID contractVersionId,
            @RequestHeader(value = REQUEST_ID_HEADER_KEY) UUID requestId,
            @RequestHeader(value = CORRELATION_ID_HEADER_KEY) UUID correlationId,
            @RequestHeader(value = SBERPDI_HEADER_KEY) String sberPDI);
}
```

### Example 2: ObjectsClientAutoConfiguration.java (подключение Feign-клиента)
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/configuration/ObjectsClientAutoConfiguration.java`

Назначение: автоконфигурация клиента для внешнего потребления; аналог того, как подключается интеграционный слой без Kafka.

```java
@AutoConfiguration
@EnableFeignClients(
        basePackageClasses = ObjectsClient.class
)
public class ObjectsClientAutoConfiguration {
}
```

> Если в будущем появится Kafka, образец event-driven-кода (продюсер/консьюмер/DLT) следует брать из глобального эталона `rules/11_kafka.md` в `core-gigacode-skills`, а не из этого файла — здесь Kafka-паттернов нет.