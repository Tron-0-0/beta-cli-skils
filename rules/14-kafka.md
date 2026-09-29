---
paths:
  - "src/main/java/**/kafka/**"
  - "src/main/java/**/model/event/**"
---

# Соглашение: Kafka

**Когда читать:** с момента добавления в проект первого продюсера/консьюмера (`spring-kafka` пока не подключён) — до этого момента правило не к чему применять.

**Что описывает:** расположение продюсеров/консьюмеров, DTO событий, именование топиков и групп, конфигурацию подключений, сериализацию, обработку ошибок.

---

## 1. Правило

### 1.1 Расположение и роль

- Пакет `kafka/` (тот же уровень, что `consoleui/`, `controller/`, `service/`), с подпакетами `kafka/producer/` и `kafka/consumer/`.
- И продюсер, и консьюмер — тонкие: без бизнес-логики. Продюсер вызывается из `service.impl` после того, как бизнес-операция уже выполнена; консьюмер, получив сообщение, сразу передаёт его в `service` — сам не принимает бизнес-решений (расширение общего правила слоёв, см. `01-layers-and-dependencies.md`). Запрет импорта `repository`/`consoleui` из `kafka` формализован в `import-control.xml`, здесь не дублируется.

### 1.2 Producer

- Как и сервисы — интерфейс в `kafka/producer/` + реализация в `kafka/producer/impl/` с суффиксом `Impl` (`FrontWordEventProducer` / `FrontWordEventProducerImpl`), см. `01-layers-and-dependencies.md`.
- `@Component` + `@RequiredArgsConstructor` + `@Slf4j` на реализации, `KafkaTemplate` внедряется через конструктор.
- Продюсер внедряется в `service.impl` через конструктор как обычная зависимость (это и позволяет мокать его в unit-тестах сервиса, см. `08-tests.md`).

### 1.3 Consumer

- Обычный `@Component` (без интерфейса — консьюмер является точкой входа, а не заменяемой зависимостью, как `controller`/`consoleui`).
- Метод обработки — `@KafkaListener(topics = "...", groupId = "...")`, тело метода — маппинг входящего события в вызов одного метода сервиса, без ветвления бизнес-правил внутри.

### 1.4 DTO событий (payload)

- Payload события — отдельный DTO в пакете `model/event` (не переиспользовать REST DTO из `model/dto` и не публиковать JPA-сущности напрямую).
- Аннотации — как у остальных DTO: `@Data @Builder @NoArgsConstructor @AllArgsConstructor @ToString` (см. `02-lombok.md`).
- Маппинг entity/DTO ↔ событие — через MapStruct, вызывается на стороне `service.impl` (см. `09-controllers.md`), а не в продюсере/консьюмере.

### 1.5 Топики и группы

- Имя топика — kebab-case, через точку `<домен>.<сущность>.<событие>`, например `flash-card.front-word.created`.
- `groupId` консьюмера — константа (`private static final String`, см. `12-general-code-conventions.md`), не строковый литерал напрямую в аннотации.

### 1.6 Конфигурация продюсеров и консьюмеров

- Конфигурация Kafka — в пакете `kafka/config/`.
- Для каждого типа подключения (то есть под каждый тип события/DTO) — своя отдельная конфигурация: свой `ProducerFactory`/`KafkaTemplate` для продюсера, свой `ConsumerFactory`/`ConcurrentKafkaListenerContainerFactory` для консьюмера. Не заводить один общий `ContainerFactory` на все типы сообщений сразу.
- Класс конфигурации называется по типу события с суффиксом `KafkaConfig` (например, `FrontWordCreatedEventKafkaConfig`) и содержит только то, что реально нужно для этого типа события — только продюсерную часть, только консьюмерную, или обе, если событие и публикуется, и потребляется в этом же приложении.
- Бины `KafkaTemplate<String, T>`/`ProducerFactory<String, T>` и `ConcurrentKafkaListenerContainerFactory<String, T>` параметризуются конкретным типом DTO события (`T` — класс из `model/event`) — это даёт типобезопасность при сериализации/десериализации на этапе компиляции. Запрет `KafkaTemplate<String, Object>` формализован в `checkstyle.xml` (`RegexpSinglelineJava`, id `KafkaTemplateObject`); для остальных фабрик — смысловое ревью.
- Общие низкоуровневые настройки, одинаковые для всех подключений (адрес брокера `bootstrap-servers` и т.п.), — в `application.properties`, читаются через `@Value`/`@ConfigurationProperties`, не дублируются как строковые литералы в коде конфигураций.

### 1.7 Сериализация

- Формат сообщений — JSON: `JsonSerializer` на продюсере, `JsonDeserializer` на консьюмере (с явно указанными доверенными пакетами, `spring.json.trusted.packages`), без Avro/Schema Registry.

### 1.8 Обработка ошибок и логирование

- Продюсер: неуспешную отправку (ошибка в callback `KafkaTemplate.send`) логировать через `log.error` с контекстом (топик, ключ/id сущности), см. `07-logging-and-errors.md`.
- Консьюмер: при ошибке обработки сообщения — логировать через `log.error` с контекстом (топик, partition/offset, id сущности из payload) и **пропускать** сообщение (без retry и без dead-letter топика) — обработка следующего сообщения продолжается.
- Начало и результат обработки сообщения консьюмером логировать через `log.info` (получено событие / событие обработано), по аналогии с началом/концом бизнес-операции (см. `07-logging-and-errors.md`).

## 2. Соглашения для агента

- Первый продюсер/консьюмер в проекте — сигнал, что это правило переходит из планового состояния в действующее.
- Не заводить общую фабрику на все события «для простоты» — каждому типу события своя типизированная конфигурация в `kafka/config/`.
- Продюсер вызывать из `service.impl` после успешного выполнения бизнес-операции, не из контроллера/consoleui и не до сохранения в БД.
- Payload события — свой DTO в `model/event`, не переиспользовать `model/dto`/`model.entity`.

## 3. Чек-лист

- [ ] Продюсер — интерфейс + `Impl`, консьюмер — обычный `@Component`
- [ ] Продюсер/консьюмер не содержат бизнес-логику — только отправка/маппинг + делегирование в сервис
- [ ] DTO события — в `model/event`, с аннотациями по `02-lombok.md`, не переиспользован `model/dto`/`model.entity`
- [ ] Имя топика — kebab-case `<домен>.<сущность>.<событие>`; `groupId` — константа, не строковый литерал в аннотации
- [ ] На каждый тип события — своя типизированная конфигурация в `kafka/config/`
- [ ] Сериализация — JSON с указанными `trusted.packages`
- [ ] Ошибка продюсера/консьюмера логируется через `log.error` с контекстом; ошибка консьюмера — сообщение пропускается, без retry/DLT

## 4. Примеры кода

```java
package com.flshcrd.flashcard.kafka.producer.impl;

@Component
@RequiredArgsConstructor
@Slf4j
public class FrontWordEventProducerImpl implements FrontWordEventProducer {

    private static final String TOPIC = "flash-card.front-word.created";

    private final KafkaTemplate<String, FrontWordCreatedEvent> kafkaTemplate;

    @Override
    public void publishCreated(FrontWordCreatedEvent event) {
        kafkaTemplate.send(TOPIC, event.getFrontWordId().toString(), event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Не удалось отправить событие: topic={}, id={}", TOPIC, event.getFrontWordId(), ex);
                    }
                });
    }
}
```

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class FrontWordEventConsumer {

    private static final String GROUP_ID = "flash-card-front-word-consumer";

    private final FrontWordService frontWordService;

    @KafkaListener(topics = "flash-card.front-word.created", groupId = GROUP_ID)
    public void onFrontWordCreated(FrontWordCreatedEvent event) {
        log.info("Получено событие: id={}", event.getFrontWordId());
        frontWordService.handleCreatedEvent(event);
        log.info("Событие обработано: id={}", event.getFrontWordId());
    }
}
```

## 5. Когда пересматривать

Правило описывает целевое состояние на момент появления первого продюсера/консьюмера — пересматривать его тогда же, если реальная нагрузка потребует retry/dead-letter топик вместо простого пропуска сообщения при ошибке.
