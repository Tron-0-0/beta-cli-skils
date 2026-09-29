---
paths:
  - "src/main/java/**/controller/**"
  - "src/main/java/**/model/dto/**"
  - "src/main/java/**/mapper/**"
  - "src/main/java/**/swagger/**"
---

# Соглашение: Controller (REST-слой)

**Когда читать:** с момента добавления в проект первого `@RestController` (`spring-boot-starter-web` пока не подключён, есть только консольный интерфейс на Lanterna) — до этого момента правило не к чему применять.

**Что описывает:** расположение и роль контроллеров, DTO и маппинг через MapStruct, пагинацию, валидацию и обработку ошибок, именование эндпоинтов, документирование Swagger/OpenAPI.

---

## 1. Правило

### 1.1 Расположение и роль

- Пакет `controller/` (тот же уровень, что `consoleui/`, `service/`, `repository/`) — точка входа для REST-запросов, аналог `consoleui` для HTTP.
- Контроллер — только маршрутизация запроса и вызов сервиса. Никакой бизнес-логики или ручной работы с транзакциями в контроллере. Запрет импорта `repository` из `controller` формализован в `import-control.xml`, здесь не дублируется.
- Зависимость: `controller` → `service` → `service.impl` → `repository` → `model.entity` (расширение общего правила слоёв, см. `01-layers-and-dependencies.md`).
- Версионирование API — в пути: `/api/v1/...`. При несовместимых изменениях контракта — новая версия (`/api/v2/...`), старая какое-то время остаётся рабочей, а не правится на месте.

### 1.2 Структура класса

- Аннотации: `@RestController`, `@RequestMapping("/api/v1/<ресурс>")` на классе, `@RequiredArgsConstructor` + `@Slf4j` — как у остальных Spring-компонентов проекта (см. `02-lombok.md`).
- Один контроллер — один ресурс (`FrontWordController`, `CardController`), без «god-контроллеров» на несколько сущностей.
- Методы — тонкие: валидация входа (аннотациями), вызов одного метода сервиса, возврат уже готового DTO/страницы.

### 1.3 DTO вместо сущностей и маппинг через MapStruct

- В контроллер передаются и из него возвращаются только DTO из `model/dto` (например, `FrontWordRequest` / `FrontWordResponse`), с аннотациями по `02-lombok.md`. Запрет импорта `model.entity` из `controller` формализован в `import-control.xml`.
- Маппинг entity ↔ DTO — через MapStruct (`@Mapper(componentModel = "spring")`), интерфейсы мапперов лежат в пакете `mapper/` (`FrontWordMapper` и т.п.), реализация генерируется MapStruct.
- Маппер вызывается на стороне `service.impl`, а не в контроллере: сервис принимает/отдаёт DTO снаружи, а внутри использует маппер для конвертации в/из сущности. Маппер внедряется в сервис через конструктор, как обычная Spring-зависимость.

### 1.4 Пагинация

- Списочные эндпоинты (`list`) принимают `Pageable` и возвращают `Page<T>` (`Page<FrontWordResponse>`), а не голый `List<T>`.

### 1.5 Валидация и ошибки

- Валидация входных DTO — аннотациями `jakarta.validation` (`@NotNull`, `@NotBlank` и т.п.) + `@Valid` на параметре метода.
- Ошибки обрабатываются централизованно через `@RestControllerAdvice`/`@ExceptionHandler`, с кастомными исключениями проекта (см. `07-logging-and-errors.md`), а не try-catch в каждом методе контроллера.
- Коды ответа — стандартные HTTP-статусы через `ResponseEntity<T>` или `@ResponseStatus`: `200/201` успех, `400` невалидный запрос, `404` не найдено, `409` конфликт.

### 1.6 Именование

- REST-эндпоинты — kebab-case, множественное число для коллекций: `/api/v1/front-words`, `/api/v1/front-words/{id}`.
- Методы контроллера называются по действию, а не по HTTP-глаголу: `getById`, `create`, `update`, `delete`, `list`.

### 1.7 Документация Swagger/OpenAPI

- `@Operation` не вешается на метод контроллера напрямую — вместо этого над каждым методом контроллера висит своя кастомная составная (meta-)аннотация, которая уже включает в себя `@Operation` (и при необходимости `@ApiResponses`/`@Parameter` и т.п.).
- Такие кастомные аннотации группируются в отдельном пакете `swagger`, в классе, названном по контроллеру с припиской `Docs` (для `FrontWordController` — `FrontWordControllerDocs`). Внутри класса — по одному вложенному `@interface` на каждый метод контроллера.

## 2. Соглашения для агента

- Первый `@RestController` в проекте — сигнал, что это правило переходит из планового состояния в действующее: применять его сразу, а не по факту накопления нескольких контроллеров.
- Не отдавать данные сущности из метода контроллера обходными путями (`toString()`, `Map` с полями сущности и т.п.) — всегда DTO + MapStruct.
- Маппер вызывать в `service.impl`, не добавлять его как зависимость контроллера.
- Документацию Swagger добавлять сразу при создании метода контроллера, через кастомную аннотацию в `{Controller}Docs`, не голым `@Operation`.

## 3. Чек-лист

- [ ] Контроллер — один на ресурс, только маршрутизация и вызов сервиса, без бизнес-логики
- [ ] На вход/выход — DTO из `model/dto`
- [ ] Маппинг entity ↔ DTO — через MapStruct-маппер, вызываемый в `service.impl`
- [ ] Списочный эндпоинт принимает `Pageable`, возвращает `Page<T>`
- [ ] Валидация — `@Valid` + `jakarta.validation` на DTO, не ручные `if` в контроллере
- [ ] Ошибки — через `@RestControllerAdvice`, HTTP-статус соответствует семантике результата
- [ ] URL — kebab-case, множественное число; метод контроллера назван по действию, не по HTTP-глаголу
- [ ] Документация — кастомная аннотация из `{Controller}Docs`, не голый `@Operation`
- [ ] Javadoc на классе/методах — на русском (см. `04-comments-and-javadoc.md`)

## 4. Примеры кода

```java
package com.flshcrd.flashcard.swagger;

import io.swagger.v3.oas.annotations.Operation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

public final class FrontWordControllerDocs {

    private FrontWordControllerDocs() {
    }

    @Target(ElementType.METHOD)
    @Retention(RetentionPolicy.RUNTIME)
    @Operation(summary = "Получить слово по id")
    public @interface GetById {
    }

    @Target(ElementType.METHOD)
    @Retention(RetentionPolicy.RUNTIME)
    @Operation(summary = "Создать слово")
    public @interface Create {
    }
}
```

```java
@FrontWordControllerDocs.GetById
@GetMapping("/{id}")
public ResponseEntity<FrontWordResponse> getById(@PathVariable UUID id) {
    ...
}
```

## 5. Когда пересматривать

Правило уже описывает целевое состояние REST-слоя — пересматривать его при появлении первого реального контроллера, если фактическая реализация вынуждает уточнить детали (формат ошибок, схема версионирования), не покрытые здесь. До этого момента правило служит планом, а не чек-листом по существующему коду.
