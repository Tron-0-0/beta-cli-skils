---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: API и контракты (REST, OpenAPI) (profitcontr-objects)

**Когда читать:** При создании/изменении REST API, обновлении контрактов, или настройке OpenAPI.

**Что описывает:** Контроллеры, DTO-валидация, обязательные заголовки, OpenAPI/Swagger, формат ошибок.

**Глобальный эталон:** `rules/07_api_contract.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Контроллер и base path

Единственный REST-контроллер — `ObjectController`
(`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java`).
Base path задаётся `@RequestMapping(DEFAULT_URL_PREFIX_API + OBJECTS_URL_PREFIX_APU)`.

Константы (в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java`):
- `DEFAULT_URL_PREFIX_API = "/api/v1/profitcontr/objects"`
- `OBJECTS_URL_PREFIX_APU = "/objects"`

Фактический base path всех эндпоинтов: **`/api/v1/profitcontr/objects/objects`**.

| Метод | URL | Назначение | Возврат |
|---|---|---|---|
| `GET` | `/api/v1/profitcontr/objects/objects/{contract-version-id}` | Поиск объектов по версии договора | `ResponseEntity<ObjectsDTO>` |
| `POST` | `/api/v1/profitcontr/objects/objects` | Создание объекта | `ResponseEntity<ObjectsCreationResponse>` |

Тело POST-запроса десериализуется в `ObjectCreateRequest` из
`objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/request/creation/ObjectCreateRequest.java`.

### 1.2 Обязательные заголовки

Контроллер принимает/возвращает сервисные заголовки (константы в `WebApplicationConstants.java`):

| Header | Ключ (константа) | Где читается | Где в ответе |
|---|---|---|---|
| `request-id` | `REQUEST_ID_HEADER_KEY` (`UUID`, required) | `@RequestHeader` в обоих методах | отдаётся как `response-id`, равный входящему |
| `correlation-id` | `CORRELATION_ID_HEADER_KEY` (`UUID`) | `@RequestHeader` | эхо-тируется в заголовок ответа |
| `sberpdi` | `SBERPDI_HEADER_KEY` (`String`) | `@RequestHeader` | эхо-тируется в заголовок ответа |
| `response-id` | `RESPONSE_ID_HEADER_KEY` | — | `.header(RESPONSE_ID_HEADER_KEY, requestId.toString())` |

Дополнительно декларируется `IDEMPOTENCY_ID_HEADER_KEY = "idempotency-key"`, но в `ObjectController` он пока не читается (идемпотентность POST не реализована в контроллере).

**Важно про scan «07_api.sberpdi_header» (count=0):** заголовок `sberpdi` фактически реализован и обязателен. Сканер ищет литерал `"sberpdi"` по raw-строке в контроллерах, а здесь значение задано константой `SBERPDI_HEADER_KEY = "sberpdi"` в `WebApplicationConstants.java` и используется через имя константы, поэтому raw-строка в контроллерах отсутствует → ложное срабатывание. Подтверждение: `@RequestHeader(value = SBERPDI_HEADER_KEY)` в `ObjectController` и `@Header(name = SBERPDI_HEADER_KEY, required = true)` в `ObjectControllerDocs`.

### 1.3 OpenAPI / Swagger (springdoc)

Зависимость `org.springdoc:springdoc-openapi-starter-webmvc-ui` — `objects/pom.xml` (строки 69–70). Swagger-документация вынесена в слой
`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/swagger/ObjectControllerDocs.java`
как **кастомные аннотации-интерфейсы** (`@interface`) с `@Target(ElementType.METHOD)`:
- `ObjectControllerDocs.GetObjectByContractVersionIdDocs`
- `ObjectControllerDocs.CreateObjectDocs`

В них используются `@Operation`, `@Parameter`, `@ApiResponse`, `@Content`, `@Schema(implementation=...)`, `@ExampleObject(...)`, `@Header`. Методы контроллера помечены этими аннотациями вместо интерфейсов `*ControllerApi` (для rule 01 отмечено как локальное отклонение).

Примеры тел запросов/ответов задаются строковыми константами `SUCCESS_EXAMPLE_GET_RESPONSE`, `REQUEST_OBJECT_EXAMPLE`, `SUCCESS_EXAMPLE_CREATE_RESPONSE`; каждый `@ApiResponse` объявляет `@Header` для `correlation-id`, `response-id`, `sberpdi`.

### 1.4 DTO / request / response модели

Все внешние модели — в модуле **`objects-rest-client`**, пакет `ru.sbrf.sbererp.profitcontr.objects.client.model`:
- `dto/ObjectsDTO.java` — ответ GET;
- `request/creation/*.java` — `ObjectCreateRequest`, `RentalObjectCreateRequest`, `AssetObjectCreateRequest`, `ConditionsCreateRequest`, `ReservationTermsCreateRequest`, `OrganisationCreateRequest`, `PartnerCreateRequest`;
- `response/ObjectsCreationResponse.java` — ответ POST.

Характерно: `@Schema(description=...)` на каждом свойстве, `@ArraySchema(maxItems=1000)`, алиасы полей через `@JsonProperty` (например `accountingSubjectDto` ↔ `organisation`, `dataServices` ↔ `services`), `@Builder`/`@Data`. `@JsonIgnoreProperties(ignoreUnknown = true)` присутствует **только** в `ObjectCreateRequest` (для rule 07 `json_ignore_unknown` — partial: остальные request/response DTO без него).

### 1.5 Обработка ошибок

`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/exception/GlobalExceptionHandler.java` — `@RestControllerAdvice`, обрабатывает:
- `EntityNotFoundException` → `404`
- `ObjectTypeMismatchException` → `400`
- `ObjectsAlreadyExistException` → `400`

Во всех случаях возвращает `ErrorResponse` из внешней библиотеки `ru.sbrf.sbererp.profitcontr.utility2.model.response.ErrorResponse` (`new ErrorResponse(e.getMessage())`).

### 1.6 Feign-клиент (objects-rest-client)

`objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/ObjectsClient.java` — `@FeignClient(name = "objects-client", configuration = SSLFeignClientConfiguration.class)`:
- `POST /objects` — `createObjects`
- `GET /objects/{contract-version-id}` — `getObjectsByContractVersionId`

Оба метода принимают и пробрасывают заголовки `request-id`, `correlation-id`, `sberpdi`. Автоконфигурация — `ObjectsClientAutoConfiguration` (`@AutoConfiguration` + `@EnableFeignClients(basePackageClasses = ObjectsClient.class)`).

---

<!-- source: auto -->
## 2. Соглашения для агента

- Swagger-контракт описывай в `ru.sbrf.sbererp.profitcontr.objects.controller.swagger` через кастомные аннотации-интерфейсы (`@Target(ElementType.METHOD)`), которые навешиваешь на методы контроллера, — **не создавай** интерфейсы `*ControllerApi` (это принятый в репозитории стиль, что отмечено как локальное отклонение от `rules/01`).
- Контроллер делай **тонким**: только `@RequestHeader` для `request-id`/`correlation-id`/`sberpdi`, `@Valid` для request body и делегирование в `service/object/…`; возвращай `ResponseEntity<T>` с `HttpStatus` и эхом сервисных заголовков (`response-id`, `correlation-id`, `sberpdi`).
- Все request/response/DTO-модели размещай в модуле `objects-rest-client` в `client/model/{request,response,dto}` с `@Schema(description=...)`, `@JsonProperty`-алиасами и `@JsonIgnoreProperties(ignoreUnknown = true)` на входящих запросах для tolerant-десериализации.
- Ошибки обрабатывай через `@RestControllerAdvice` (`GlobalExceptionHandler`) и возвращай `ErrorResponse` (`ru.sbrf.sbererp.profitcontr.utility2.model.response.ErrorResponse`); HTTP-статус задавай `@ResponseStatus`.
- Сервисные заголовки задавай через константы `WebApplicationConstants.*_HEADER_KEY` (`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java`), а не raw-строкой — единый источник истины и централизованное обновление.

<!-- source: auto -->
## 3. Чек-лист

- [ ] Контроллер содержит `@Operation`-документацию через аннотации из `controller/swagger/…` (напр. `@ObjectControllerDocs.GetObjectByContractVersionIdDocs`)
- [ ] Base path собран из констант `DEFAULT_URL_PREFIX_API` + `OBJECTS_URL_PREFIX_APU` (`/api/v1/profitcontr/objects/objects`)
- [ ] Обязательные заголовки `request-id`, `correlation-id`, `sberpdi` принимаются и пробрасываются, отдаётся `response-id`
- [ ] Request body на POST отмечен `@Valid`; на DTO заданы `@JsonProperty`-алиасы для сервисных имён полей
- [ ] Входящие request DTO имеют `@JsonIgnoreProperties(ignoreUnknown = true)` для tolerant-десериализации
- [ ] Ошибки — через `GlobalExceptionHandler` с HTTP-статусом и `ErrorResponse`
- [ ] OpenAPI/springdoc перегенерируется при изменении сигнатур метода/DTO без ручной правки спецификации
- [ ] Примеры тел (`@ExampleObject`) в `ObjectControllerDocs` актуальны JSON

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: ObjectController.java
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java`

```java
@RestController
@RequestMapping(DEFAULT_URL_PREFIX_API + OBJECTS_URL_PREFIX_APU)
public class ObjectController {
    @ObjectControllerDocs.GetObjectByContractVersionIdDocs
    @GetMapping("/{contract-version-id}")
    public ResponseEntity<ObjectsDTO> getObjectByContractVersionId(
            @PathVariable("contract-version-id") UUID contractVersionId,
            @RequestHeader(REQUEST_ID_HEADER_KEY) UUID requestId,
            @RequestHeader(CORRELATION_ID_HEADER_KEY) UUID correlationId,
            @RequestHeader(SBERPDI_HEADER_KEY) String sberId) {
        return ResponseEntity.status(HttpStatus.OK)
                .header(RESPONSE_ID_HEADER_KEY, requestId.toString())
                .header(CORRELATION_ID_HEADER_KEY, correlationId.toString())
                .header(SBERPDI_HEADER_KEY, sberId)
                .body(serviceService.getServiceByContractVersionId(contractVersionId, requestId));
    }
}
```

### Example 2: ObjectControllerDocs.java (Swagger-аннотации)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/swagger/ObjectControllerDocs.java`

```java
@Operation(
        summary = "Получение объектов по идентификатору версии договора",
        parameters = @Parameter(name = "contract-version-id", required = true, example = CONTRACT_VERSION_ID_EXAMPLE),
        responses = @ApiResponse(
                responseCode = "200",
                content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE,
                        schema = @Schema(implementation = ObjectsResponse.class)),
                headers = {
                        @Header(name = CORRELATION_ID_HEADER_KEY, required = true),
                        @Header(name = RESPONSE_ID_HEADER_KEY, required = true),
                        @Header(name = SBERPDI_HEADER_KEY, required = true)
                }))
@Target(ElementType.METHOD)
public @interface GetObjectByContractVersionIdDocs { ... }
```

### Example 3: request DTO с tolerant-десериализацией
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/request/creation/ObjectCreateRequest.java`

```java
@Data @Builder @NoArgsConstructor @AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class ObjectCreateRequest {
    @Schema(description = "Идентификатор договора")
    private UUID contractId;

    @ArraySchema(schema = @Schema(description = "Услуги"), maxItems = 1000)
    @JsonProperty("dataServices")
    private List<DataService> services;
}
```

---

<!-- source: auto -->
## 5. Исключения и оговорки

- Заголовок `sberpdi` реализован через константу и в коде фактически присутствует (scan count=0 — артефакт поиска по raw-строке). НЕ создавай «дублирующий» raw-string параметр ради прохождения проверки.
- `idempotency-key` задекларирован в константах, но в `ObjectController` не обрабатывается — идемпотентность POST требует отдельной доработки (см. `rules/14_idempotency_rest.md`).
- Base path — `/api/v1/profitcontr/objects/objects` (повтор сегмента `objects/objects` из-за склейки `DEFAULT_URL_PREFIX_API` и `OBJECTS_URL_PREFIX_APU`); при изменении пути правь обе константы согласованно.
- Интерфейсы `*ControllerApi` не используются: Swagger-слой через кастомные аннотации — намеренный стиль репо (rule 07 и rule 01 отмечены как локальные отклонения).

---

<!-- source: auto -->
## 6. Обновление

Пересоберите документ при изменении сигнатур контроллера/dto, base path, добавлении новых эндпоинтов или смене версии springdoc в `objects/pom.xml`.