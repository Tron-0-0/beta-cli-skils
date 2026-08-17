---
apply: always
mode: all
---

# Соглашение: Kafka — продюсеры, консюмеры, ретраи

**Когда читать:** при работе с Kafka — создание consumer/producer, настройка топиков, обработка ошибок, добавление первой Kafka-зависимости в сервис.

**Что описывает:** producer/consumer конфигурацию, обработку ошибок и DLT, идемпотентность сообщений, Outbox-паттерн.

---

## 1. Правило

- **Не добавляй Kafka "про запас".** Зависимость (`spring-kafka`) подключается только под реальную задачу обмена сообщениями; межсервисные синхронные вызовы (REST/gRPC) — не повод заводить Kafka.
- **Producer — идемпотентный** (`enable.idempotence=true`, по умолчанию включено в современных версиях клиента) — защита от дублей при ретраях на сетевых сбоях.
- **Отправка — не fire-and-forget.** `KafkaTemplate.send(...)` возвращает `CompletableFuture` — результат отправки нужно проверять (callback/`whenComplete`, лог ошибки, метрика), иначе сбой отправки (недоступность брокера, timeout) проходит незамеченным и событие теряется без единого следа.
- **Partition key — идентификатор агрегата** (например `orderId`), не пустой/случайный ключ — иначе события одной сущности могут разойтись по разным партициям и обрабатываться не по порядку; порядок в Kafka гарантируется только в пределах одной партиции по одному ключу.
- **Publish и изменение состояния — атомарны через Outbox-паттерн:** запись бизнес-события и отправка в Kafka не должны быть независимыми шагами без гарантии согласованности — при падении между шагами событие теряется или дублируется без возможности восстановления. Событие сначала пишется в outbox-таблицу в той же транзакции, что и бизнес-изменение, отдельный процесс публикует его в Kafka и помечает как отправленное.
- **Consumer десериализация безопасна:** `ErrorHandlingDeserializer` оборачивает целевой десериализатор, `spring.json.trusted.packages` — явный список пакетов, не `*` (widcard допускает десериализацию произвольных классов из сообщения — риск инъекции).
- **Ack mode — ручной** (`AckMode.MANUAL`/`MANUAL_IMMEDIATE`), `enable.auto.commit=false` — коммит offset только после успешной обработки, чтобы падение между чтением и обработкой не теряло сообщение.
- **Ошибки обработки — через DLT** (`DeadLetterPublishingRecoverer` + `DefaultErrorHandler`), с чётким разделением retryable/non-retryable исключений: `SerializationException`/`ConstraintViolationException`-подобные структурные ошибки не ретраятся (повтор не поможет), временные (сеть, недоступность зависимости) — ретраятся с backoff перед уходом в DLT.
- **Слушатель не блокируется** — никакого `Thread.sleep` внутри обработчика; ретраи — через механизм error handler'а, не ручной цикл в коде листенера. Обработка одного батча укладывается в `max.poll.interval.ms` — консюмер, не успевший обработать батч в это окно, считается зависшим и выкидывается из группы с последующей ребалансировкой; долгую обработку (тяжёлые внешние вызовы, агрегации) не компенсировать увеличением интервала "про запас" без анализа фактической длительности.
- **Consumer идемпотентен на уровне бизнес-логики** — обработка одного и того же события повторно (из-за at-least-once семантики Kafka) не должна приводить к дублирующим побочным эффектам; дедупликация по `eventId` на стороне потребителя.
- **Event DTO — неизменяемые**, с обязательными полями `eventId`, `eventTimestamp`, `sourceSystem` для трассируемости и дедупликации.
- **Корреляция в логах** — MDC в листенере проставляется в начале обработки сообщения (например, из `eventId` или заголовка сообщения), не наследуется автоматически из HTTP-фильтра — консюмер работает на собственном потоке (см. `09_logging.md`).
- **Graceful shutdown листенера** — на остановке контейнера уже начатая обработка сообщения должна довершиться до коммита offset, а не оборваться на середине; жизненный цикл listener container'а настраивается отдельно от graceful shutdown HTTP-сервера (см. `10_cloud_native.md`).
- **`client.id`** — уникален и осмыслен для каждого продюсера/консюмера (сервис + назначение), чтобы метрики и логи брокера были отличимы по клиенту.
- **Типизированные фабрики на тип события** — `ProducerFactory<String, T>`/`KafkaTemplate<String, T>` и `ConsumerFactory<String, T>`/`ConcurrentKafkaListenerContainerFactory<String, T>`, параметризованные конкретным типом события (`T` — класс из `model/event`), не `Object`; отдельная конфигурация на каждый тип события, а не один общий `KafkaTemplate<String, Object>`/`ContainerFactory` на все сообщения сразу — это даёт типобезопасность на этапе компиляции.
- **Имя топика** — kebab-case, точечная нотация `<домен>.<сущность>.<событие>` (например `orders.order.created`).
- **`groupId`** консюмера — именованная константа (`private static final String`), не строковый литерал напрямую в `@KafkaListener`.

## 2. Соглашения для агента

1. Не подключай `spring-kafka` без конкретной задачи асинхронного обмена сообщениями.
2. Публикация события, связанная с изменением состояния в БД, — через Outbox-таблицу в той же транзакции, не прямой вызов `KafkaTemplate.send(...)` посреди бизнес-транзакции.
3. Отправку через `KafkaTemplate.send(...)` — с обработкой результата (`whenComplete`/callback: лог ошибки, метрика), не оставляй возвращённый `CompletableFuture` без обработки.
4. Ключ сообщения при отправке — идентификатор агрегата (`orderId` и т.п.), не `null` и не случайное значение, если порядок обработки по этой сущности важен.
5. Новый consumer — `ErrorHandlingDeserializer` с явным `trusted.packages`, `AckMode.MANUAL`, `DefaultErrorHandler` с DLT-рекавери и различением retryable/non-retryable исключений.
6. Event-DTO — `record`/`@Value @Builder` с `eventId`/`eventTimestamp`/`sourceSystem`; обработчик проверяет `eventId` на дубликат перед применением побочных эффектов.
7. Листенер — в начале обработки сообщения проставляет MDC для корреляции в логах (см. `09_logging.md`); долгую обработку одного сообщения соотноси с `max.poll.interval.ms`, чтобы не спровоцировать ребалансировку.
8. Настройки топиков/групп — через переменные окружения, не хардкод в коде; при 3+ связанных параметрах — `@ConfigurationProperties`-класс в своём неймспейсе, а не россыпь `@Value` (см. `12_configuration.md`).
9. Новый тип события — своя конфигурация продюсера/консюмера, типизированная на его класс (`ProducerFactory<String, OrderEvent>` и т.п.), не расширение общего `Object`-конфига; имя топика — `<domain>.<entity>.<event>`; `groupId` — константа.

## 3. Чек-лист

- [ ] Producer использует идемпотентную отправку
- [ ] Результат `KafkaTemplate.send(...)` обрабатывается (не fire-and-forget), сбой отправки логируется/метрицируется
- [ ] Ключ сообщения — идентификатор агрегата, если важен порядок обработки по сущности
- [ ] Событие публикуется через Outbox, если связано с изменением состояния в той же транзакции
- [ ] Consumer — `ErrorHandlingDeserializer` + явный `trusted.packages` (не `*`)
- [ ] `AckMode.MANUAL`, `enable.auto.commit=false`
- [ ] DLT настроен, retryable/non-retryable исключения различены
- [ ] Листенер не блокируется (`Thread.sleep` отсутствует), обработка укладывается в `max.poll.interval.ms`
- [ ] Consumer дедуплицирует по `eventId`
- [ ] Event-DTO неизменяемы, содержат `eventId`/`eventTimestamp`/`sourceSystem`
- [ ] MDC проставляется в начале обработки сообщения листенером
- [ ] `client.id` осмыслен и уникален для продюсера/консюмера
- [ ] Фабрики продюсера/консюмера типизированы на конкретный тип события, не `Object`; отдельная конфигурация на тип события
- [ ] Имя топика — `<domain>.<entity>.<event>` в kebab-case; `groupId` — именованная константа, не литерал

## 4. Примеры кода

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class OrderEventPublisher {
    private static final String ORDER_CREATED_TOPIC = "orders.order.created"; // <domain>.<entity>.<event>

    private final KafkaTemplate<String, OrderEvent> kafkaTemplate; // типизирован на OrderEvent, не Object

    public void publish(OrderEvent event) {
        kafkaTemplate.send(ORDER_CREATED_TOPIC, event.orderId().toString(), event) // ключ — id агрегата, не null
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish order event {}", event.eventId(), ex);
                    }
                });
    }
}
```

```java
public final class OrderEventKafkaConfig {
    public static final String GROUP_ID = "order-service"; // константа, не литерал в @KafkaListener

    private OrderEventKafkaConfig() {
    }
}

@Bean
public ConsumerFactory<String, OrderEvent> orderEventConsumerFactory() { // типизирован на OrderEvent, не Object
    var deserializer = new ErrorHandlingDeserializer<>(new JsonDeserializer<>(OrderEvent.class));
    var props = Map.of(
            ConsumerConfig.GROUP_ID_CONFIG, OrderEventKafkaConfig.GROUP_ID,
            ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false,
            JsonDeserializer.TRUSTED_PACKAGES, "com.example.orders.event"
    );
    return new DefaultKafkaConsumerFactory<>(props, new StringDeserializer(), deserializer);
}

@Bean
public DefaultErrorHandler errorHandler(KafkaTemplate<String, Object> template) { // DLT-recoverer — легитимное исключение из типизации: пересылает произвольные failed-записи как есть
    var recoverer = new DeadLetterPublishingRecoverer(template);
    var handler = new DefaultErrorHandler(recoverer, new FixedBackOff(1000L, 3));
    handler.addNotRetryableExceptions(DeserializationException.class, ConstraintViolationException.class);
    return handler;
}
```

```java
public record OrderEvent(
        UUID eventId,
        Instant eventTimestamp,
        String sourceSystem,
        UUID orderId,
        OrderStatus status
) {}

@KafkaListener(topics = "orders.order.created", groupId = OrderEventKafkaConfig.GROUP_ID, containerFactory = "orderEventListenerFactory")
public void onOrderEvent(OrderEvent event, Acknowledgment ack) {
    MDC.put("eventId", event.eventId().toString()); // консюмер — свой поток, контекст из HTTP-фильтра сюда не долетает
    try {
        if (processedEvents.contains(event.eventId())) {
            ack.acknowledge();
            return;
        }
        handle(event);
        ack.acknowledge();
    } finally {
        MDC.clear();
    }
}
```

## 5. Когда пересматривать

При смене клиента Kafka на альтернативный брокер сообщений, изменении гарантий доставки (at-least-once → exactly-once через транзакции), при систематических дублях/потерях сообщений в проде, либо при ребалансировках из-за превышения `max.poll.interval.ms`.
