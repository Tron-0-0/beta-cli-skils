---
apply: always
mode: all
---

# Соглашение: API и контракты (REST, OpenAPI)

**Когда читать:** при создании/изменении REST API, обновлении контрактов, настройке OpenAPI.

**Что описывает:** контроллеры, DTO-валидацию, обязательные заголовки, формат ошибок, версионирование.

---

## 1. Правило

- **URL** — существительные во множественном числе, kebab-case (`/orders/{order-id}`), без глаголов (`/orders/cancel` — плохо, `PATCH /orders/{id}` со статусом в теле — лучше).
- **Один контроллер — один ресурс.** `OrderController` отвечает только за `/orders`, не за несколько не связанных друг с другом сущностей в одном классе («god-контроллер»). Методы контроллера называются по действию (`getById`, `create`, `update`, `delete`, `list`), а не по HTTP-глаголу (`post`/`get`).
- **HTTP-статусы** — по семантике: `200` (успех с телом), `201` + `Location` (создание), `204` (успех без тела), `400` (невалидный запрос), `401` (не аутентифицирован), `403` (аутентифицирован, но нет прав), `404` (не найдено), `409` (конфликт/дубликат), `422` (валидна структура, но невалидны данные по бизнес-правилам), `5xx` — только для реальных ошибок сервера, не для ожидаемых бизнес-исключений.
- **Формат ошибок** — единый на весь API, предпочтительно RFC 7807 `application/problem+json` (`type`, `title`, `status`, `detail`, `instance`) или эквивалентный собственный формат, но **один**, не разный для каждого контроллера.
- **Непредвиденные ошибки не раскрывают внутреннюю реализацию** — недоменное исключение (NPE, ошибка SQL-драйвера, стектрейс и т.п.) не попадает в тело ответа клиенту; наружу — общий `500` с нейтральным сообщением, детали — только в лог (см. `09_logging.md`). Доменные исключения с заранее осмысленным сообщением (`OrderAlreadyExistsException` и т.п.) — не в счёт, их текст безопасен для клиента по построению.
- **Валидация входа** — Bean Validation (`@Valid` + `jakarta.validation` аннотации на DTO), а не ручные `if`-проверки в контроллере/сервисе для структурных ограничений (обязательность, формат, диапазон).
- **Версионирование** — либо в URL (`/api/v1/...`), либо в заголовке (`Accept-Version`); выбранный способ — единый для всего API. Breaking changes (удаление/переименование поля, смена типа, изменение семантики статуса) не вносятся в существующую версию — новая версия эндпоинта или явный deprecation-период. Добавление нового необязательного поля в ответ или запрос — не breaking change и новой версии не требует.
- **Корреляция запросов** — сквозные заголовки (`X-Request-Id`/`traceparent`) принимаются и пробрасываются дальше по цепочке вызовов и в логи (см. `09_logging.md`).
- **Идемпотентность мутаций** — `POST`/`PATCH` с побочным эффектом, для которых клиент может повторить запрос при таймауте/обрыве связи, принимают `Idempotency-Key` (см. `14_idempotency_rest.md`); это часть контракта эндпоинта, а не факультативная доработка.
- **Толерантная десериализация входящих DTO** (`@JsonIgnoreProperties(ignoreUnknown = true)`) — чтобы добавление нового поля в клиенте не ломало старый сервер.
- **Пагинация** списковых эндпоинтов — курсор или offset/limit с явными параметрами (`page`, `size`) и метаданными в ответе (`totalElements`/`hasNext`), не выгрузка всего списка без ограничения.

## 2. Соглашения для агента

- Контроллер — тонкий: `@Valid` на теле запроса, обязательные заголовки через `@RequestHeader`, делегирование в сервис, статус ответа по семантике таблицы выше.
- Ошибки — через `@RestControllerAdvice` + единый формат тела ошибки; не формируй тело ошибки вручную в каждом контроллере. Помимо обработчиков доменных исключений добавляй fallback-обработчик на `Exception.class`, возвращающий общий `500` без `e.getMessage()`/стектрейса в теле — полную информацию логируй через `log.error(..., e)`.
- Request/response DTO — отдельные от JPA-сущностей классы; не отдавай entity напрямую наружу (утечка внутренней структуры БД в контракт, риск сериализации ленивых связей).
- Документируй эндпоинт через `springdoc-openapi` аннотации (`@Operation`, `@ApiResponse`) на контроллере, через выделенный контракт-интерфейс, либо через кастомные составные (meta-)аннотации, сгруппированные в отдельном классе `{Controller}Docs` (каждая уже включает `@Operation`/`@ApiResponse`, вешается на метод контроллера вместо голого `@Operation`) — выбранный подход единый для всего сервиса.
- Не убирай существующее обязательное поле из ответа и не меняй его тип без версионирования — это breaking change для потребителей; новое необязательное поле добавляй свободно, версия не нужна.
- На новом мутирующем эндпоинте (`POST`/`PATCH` с побочным эффектом) — принимай `Idempotency-Key`, не откладывай это на потом как отдельную задачу (подробности реализации — `14_idempotency_rest.md`).

## 3. Чек-лист

- [ ] URL — kebab-case существительные, HTTP-метод отражает действие
- [ ] Один контроллер — один ресурс (без god-контроллеров); методы названы по действию (`getById`/`create`/`update`/`delete`/`list`), не по HTTP-глаголу
- [ ] HTTP-статус соответствует семантике результата
- [ ] Ошибки — единый формат на весь API (RFC 7807 или согласованный аналог)
- [ ] Валидация входа — через Bean Validation, а не ручные проверки в контроллере
- [ ] Request/response DTO отделены от JPA-сущностей
- [ ] Входящие DTO толерантны к неизвестным полям
- [ ] Списковые эндпоинты — пагинированы
- [ ] Breaking change — только через новую версию/deprecation, не в текущем контракте
- [ ] Корреляционные заголовки (`X-Request-Id`/`traceparent`) принимаются и пробрасываются дальше
- [ ] Непредвиденные (недоменные) исключения не отдают клиенту `message`/стектрек — только общий статус, детали в логе
- [ ] Мутирующие эндпоинты с побочным эффектом (`POST`/`PATCH`) принимают `Idempotency-Key`
- [ ] OpenAPI-документация соответствует фактическим сигнатурам

## 4. Примеры кода

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @RequestBody @Valid OrderCreateRequest request,
            @RequestHeader(REQUEST_ID_HEADER) UUID requestId) {
        var response = orderService.createOrder(request);
        return ResponseEntity
                .created(URI.create("/api/v1/orders/" + response.id()))
                .body(response);
    }
}
```

Альтернатива документированию голыми `@Operation` — составные аннотации в отдельном классе `{Controller}Docs`:

```java
public final class OrderControllerDocs {
    private OrderControllerDocs() {
    }

    @Target(ElementType.METHOD)
    @Retention(RetentionPolicy.RUNTIME)
    @Operation(summary = "Создать заказ")
    public @interface Create {
    }
}
```

```java
@OrderControllerDocs.Create
@PostMapping
public ResponseEntity<OrderResponse> create(@RequestBody @Valid OrderCreateRequest request) { ... }
```

```java
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(OrderAlreadyExistsException.class)
    public ProblemDetail handleConflict(OrderAlreadyExistsException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.getMessage());
    }

    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception e) {
        log.error("Unexpected error", e);
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Внутренняя ошибка сервера");
    }
}
```

```java
@JsonIgnoreProperties(ignoreUnknown = true)
public record OrderCreateRequest(
        @NotNull UUID customerId,
        @NotEmpty List<@Valid OrderLineRequest> lines
) {}
```

## 5. Когда пересматривать

При изменении стратегии версионирования API, смене формата ошибок, появлении публичных внешних потребителей, требующих более строгих гарантий обратной совместимости, либо при обнаружении утечки внутренних деталей ошибки (сообщение исключения, стектрейс) в ответе API наружу.
