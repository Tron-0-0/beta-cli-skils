---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Идемпотентность REST-запросов (profitcontr-objects)

**Когда читать:** При реализации идемпотентных REST-эндпоинтов или настройке стартера идемпотентности.

**Что описывает:** @Idempotency, core-common-web-idempotency-starter, ключи web.idempotency.*.

**Глобальный эталон:** `rules/14_idempotency_rest.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Стартер `core-common-web-idempotency-starter` в pom.xml НЕ подключён

Файл: `objects/pom.xml`. Среди зависимостей блока `<dependencies>` отсутствует
`ru.sbrf.sbererp.common:core-common-web-idempotency-starter` (поиск `idempotency`/`Idempotency` — 0 совпадений).
Стек integration ограничен REST/OpenFeign (`spring-cloud-starter-openfeign`, `objects-rest-client`).
Аннотация `@Idempotency` в `src/main/java` не встречается ни на одном контроллере.

TODO-блоки также подтверждают, что стартер **только задекларирован в конфиге, но не подключён**
(см. 1.3) — реального механизма идемпотентности через starter в репо нет.

### 1.2 Мутирующий эндпоинт POST без защиты `@Idempotency`

Файл: `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java`.
Метод `createObject` (`@PostMapping`, возвращает `201 Created`) — единственный мутационный эндпоинт сервиса.
В сигнатуре метода читаются только `request-id`, `correlation-id`, `sberpdi`
(`@RequestHeader(REQUEST_ID_HEADER_KEY / CORRELATION_ID_HEADER_KEY / SBERPDI_HEADER_KEY)`), аннотации
`@Idempotency` нет, заголовок `idempotency-key` в `createObject` не читается.

### 1.3 Константа `idempotency-key` определена, но не используется

Файл: `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java`.
Определена константа `IDEMPOTENCY_ID_HEADER_KEY = "idempotency-key"` (строка 18), однако она не задействована
ни в `ObjectController`, ни в `ObjectControllerDocs`, ни в swagger-документации — это подготовка к будущему
включению idempotency, а не действующая механика.

### 1.4 Закомментированный блок `web.idempotency.*` в application.properties

Файл: `objects/src/main/resources/application.properties`, строки 71–82 (комментарий `# core-common-web-idempotency-starter`).
Все настройки закомментированы префиксом `#` и содержат значения по умолчанию из env:
`web.idempotency.enabled=${WEB_IDEMPOTENCY_ENABLED:true}`, `ttl=1h`, `cacheable-statuses=200,201`,
`redis.*` (addresses/node-name/connection-* / redis-*). Это описывает ожидаемую конфигурацию стартера,
**но не активная** — при `spring.config.activate.on-profile` блок выключен, т.к. закомментирован.
Статус: заготовка под включение стартера, реальной idempotency нет.

### 1.5 Естественно-ключевая проверка на дубликат есть — `ObjectsAlreadyExistException`

Файлы:
- `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/exception/ObjectsAlreadyExistException.java`
- `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/ServiceServiceImpl.java` (`checkExistObjectsForContractVersionId`)
- `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/ObjectCreationServiceImpl.java` (`@Transactional createObject`)

Создание объекта идемпотентно по **натуральному ключу `contractVersionId`**: `ObjectCreationServiceImpl.createObject`
начинает с `serviceService.checkExistObjectsForContractVersionId(request.getContractVersionId())`, которая ищет
`serviceRepository.findByContractVersionId` и при непустом результате бросает `ObjectsAlreadyExistException`
(«Объекты аренды для версии договора с id … уже созданы»). Это прикладной механизм защиты от повторного
создания через версию договора — аналог idempotency без стартера.

---

<!-- source: auto -->
## 2. Соглашения для агента

- Обеспечивать идемпотентность **новых** мутационных эндпоинтов (`POST`) двумя механизмами: заголовком
  `idempotency-key` (константа `IDEMPOTENCY_ID_HEADER_KEY` в
  `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/constants/WebApplicationConstants.java`)
  **и** прикладной проверкой существующей записи по натуральному ключу (пример — `checkExistObjectsForContractVersionId`
  в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/ServiceServiceImpl.java`),
  чтобы повторный `POST` возвращал существующий объект/`409 Conflict` без создания дублей.

- **Использовать натуральный ключ** как основу идемпотентности для операций создания объекта: как
  `contractVersionId` уже гарантирует уникальность (сущность версии контракта). Сверять повторный `POST`
  по `request.getContractVersionId()` до вставки, а не полагаться только на idempotency-ключ.

- **Применять аннотацию `@Idempotency`** (если стартер будет подключён) только на мутационные эндпоинты
  (`POST`/`PATCH`), как `createObject` в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java`,
  и **не** на GET-запросы.

- **Не использовать один `idempotency-key` для разных бизнес-операций** — каждый уникальный `Idempotency-Key`
  соответствует одной бизнес-операции (один `contractVersionId`), согласно `rules/14_idempotency_rest.md`.

- **Секреты Redis** настраивать только через переменные окружения / Vault, а не в `application.properties`.
   В репо блок `web.idempotency.redis.*` (строки 75–82 `application.properties`) закомментирован и содержит
   значения по умолчанию — не активировать их без реальной потребности.

- **При закомментированном свойстве `web.idempotency.enabled`** — не включать стартер без реальной потребности:
   сейчас стартер и аннотация отсутствуют (см. §1.2), идемпотентность реализуется на уровне приложения через
   `ObjectsAlreadyExistException`. Если потребность в Redis-idempotent появится — добавить зависимость
   `core-common-web-idempotency-starter` в `objects/pom.xml` и раскомментировать блок `web.idempotency.*`
   (без значений/паролей Redis в репо).

---

<!-- source: auto -->
## 3. Чек-лист

- [ ] Зависимость `core-common-web-idempotency-starter` присутствует в `pom.xml` (сейчас **отсутствует** — если нужна Redis-idempotency, добавить по образцу `rules/14_idempotency_rest.md`)
- [ ] Контроллеры с мутирующими операциями (POST/PUT/PATCH) аннотированы `@Idempotency`
- [ ] Ключи `web.idempotency.*` настроены в `application*.yml` (имена ключей; в репо заблокированы в `application.properties`, строки 71–83)
- [ ] TTL и стратегия хранения ключей idempotency задокументированы
- [ ] Повторные вызовы возвращают тот же результат без побочных эффектов
- [ ] Прикладная проверка существования по натуральному ключу (`checkExistObjectsForContractVersionId`) выполняется **до** записи в transaction, чтобы повторный `POST` не плодил дубли
- [ ] Константа `idempotency-key` (`IDEMPOTENCY_ID_HEADER_KEY`) фактически используется в контроллере, а не только объявлена в `WebApplicationConstants.java`

---

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: POST-создание объекта в контроллере (без `@Idempotency` на текущий момент)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java`

```java
@ObjectControllerDocs.CreateObjectDocs
@PostMapping
public ResponseEntity<ObjectsCreationResponse> createObject(
        @RequestBody @Valid ObjectCreateRequest objectCreateRequest,
        @RequestHeader(value = REQUEST_ID_HEADER_KEY) UUID requestId,
        @RequestHeader(value = CORRELATION_ID_HEADER_KEY) UUID correlationId,
        @RequestHeader(value = SBERPDI_HEADER_KEY) String sberId
) {
    return ResponseEntity.status(HttpStatus.CREATED)
            .header(RESPONSE_ID_HEADER_KEY, requestId.toString())
            .body(objectCreationService.createObject(objectCreateRequest));
}
```
Создаётся объект; заголовок `idempotency-key` пока не читается — при развитии добавить
`@RequestHeader(IDEMPOTENCY_ID_HEADER_KEY)`.

### Example 2: сервис создания с прикладной проверкой уникальности по версии договора
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/ObjectCreationServiceImpl.java`
и `ServiceServiceImpl.java`

```java
@Override
@Transactional
public ObjectsCreationResponse createObject(ObjectCreateRequest request) {
    serviceService.checkExistObjectsForContractVersionId(request.getContractVersionId());  // -> ObjectsAlreadyExistException
    ...
}

// ServiceServiceImpl:
public void checkExistObjectsForContractVersionId(UUID contractVersionId) {
    if (!serviceRepository.findByContractVersionId(contractVersionId).isEmpty()) {
        throw new ObjectsAlreadyExistException(String.format(
                "Объекты аренды для версии договора с id %s уже созданы", contractVersionId));
    }
}
```
Естественный ключ `contractVersionId` защищает от повторного создания — прикладная идемпотентность без стартера.

<!-- source: auto -->
## 5. Исключения и оговорки

- Сейчас idempotent-стартер **не подключён** и `@Idempotency` не используется — рекомендация ограничивает
  локальный прикладной механизм (`ObjectsAlreadyExistException`), не требуя немедленного ввода Redis.
- Если появится требование включить `core-common-web-idempotency-starter` (blocking MVC, Redis Sentinel,
  заголовок `Idempotency-Key`), следует раскомментировать блок `web.idempotency.*` с реальными значениями
  через env, добавить аннотацию `@Idempotency` на `createObject` и перечитать глобальный эталон
  `rules/14_idempotency_rest.md`.