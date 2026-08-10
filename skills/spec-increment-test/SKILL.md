---
name: spec-increment-test
version: 1.1.0
description: Генерация и запуск unit-тестов по инкременту — анализ затронутых методов, создание/обновление тест-классов, запуск mvn test, генерация test-report.md. Код production-кода НЕ меняется, только тесты и отчёт. Аргументы — {release} и {ticket} (или определяются из имени текущей ветки).
---

# /spec-increment-test — Генерация тестов и запуск модуля

Автоматическая генерация unit-тестов для затронутых инкрементом public-методов,
обновление существующих тестов при изменении сигнатур, запуск всех тестов модуля
и генерация `test-report.md`.

Production-код **не меняется** — этот скилл модифицирует только тесты (`src/test/java`)
и создаёт отчёт в `specification/increment/{release}/{ticket}/test-report.md`.

**Использование:** `/spec-increment-test 01.023.00 AO-12`

## Проектная документация по тестам

> ⚠️ **Приоритет:** загруженные на Шаге 0.5 конвенции из `.gigacode/service-rules/` имеют приоритет над
> краткой выжимкой ниже. Всегда проверяй, были ли rules загружены.

**Краткая выжимка по конвенциям проекта (fallback):**
- **Тест-фреймворк:** JUnit 5 + Mockito 5 + AssertJ
- **Паттерн:** чистые unit-тесты без Spring-контекста (`@ExtendWith(MockitoExtension.class)`)
- **Нет:** `@SpringBootTest`, `@WebMvcTest`, `@DataJpaTest`, Testcontainers
- **DI в тестах:** `@Mock`/`@Spy` + `@InjectMocks` через `@RequiredArgsConstructor`
- **Размещение:** `objects/src/test/java/ru/sbrf/sbererp/profitcontr/objects/<package>` — зеркально `src/main/java`
- **Именование тест-класса:** `*ServiceImplTest`, `*MapperTest`, `*ControllerTest`
- **Именование метода:** `<Method>_<condition>_<expectedResult>` (пример: `createObject_withUnknownProcessType_shouldThrowIllegalArgument`)
- **DisplayName:** русский, на тест-классе и методе
- **21 существующий тест-класс** в `objects/src/test/java`

**Примечание на будущее:** в будущих версиях правил тестирования может быть предусмотрен
переход на `@Nested` class-тесты для группировки тестов по сценариям. Данный скилл
учитывает этот формат.

## Строгие ограничения

- **Не меняй production-код.** Тесты — единственный модифицируемый код.
- **Не меняй миграции, pom.xml, конфигурацию** — только тесты и test-report.md.
- **Не запускай mvn test без mvn compile.** Сначала убедись, что проект компилируется.

## Шаг 0. Определить release, ticket и модуль

1. Извлечь `{release}` и `{ticket}`:
   - Сначала проверить аргументы вызова: `/spec-increment-test {release} {ticket}`
   - Если аргументы не переданы — извлечь из имени текущей ветки: `feature/{ticket}` или `bugfix/{ticket}` → `{ticket}`
   - `{release}` — определить из названия папки `specification/increment/{release}/` или спросить у пользователя

2. Определить модуль тестирования:
   - `objects` — **по умолчанию** (сервисы, контроллеры, мапперы, entity)
   - `objects-rest-client` — **только если** затронуты DTO, Feign-клиенты, request/response модели
   - Если есть сомнения по модулю — определить на шаге 1 при анализе `increment.md`

3. Сформировать пути:
   - `INCREMENT_PATH = specification/increment/{release}/{ticket}/increment.md`
   - `TESTS_PATH = objects/src/test/java/ru/sbrf/sbererp/profitcontr/objects/` (или `objects-rest-client/src/test/java/...`)
   - `REPORT_PATH = specification/increment/{release}/{ticket}/test-report.md`

## Шаг 0.5. Загрузка service-rules

> ⚠️ **Этот шаг ОБЯЗАТЕЛЕН перед Шагом 1.** Загрузи конвенции до анализа инкремента.

1. Прочитай `.gigacode/service-rules/00_index.md` — определи релевантные правила для тестирования.
2. Для unit-тестирования проекта **всегда применимы**:

   | Правило | Что даёт |
      |---------|----------|
   | `06_unit_tests_with_spring_context.md` | Полное соглашение по unit-тестированию: паттерны, примеры, чек-лист, размещения, именование |

3. **Опционально, если increment.md затрагивает:**

   | Ключевые слова из increment.md | Какие rules загрузить |
      |-------------------------------|-----------------------|
   | `*ServiceImpl.java`, `*Mapper.java`, `*Controller.java` | `01_coding.md` (DI, MapStruct, слои, форматирование вызовов) |
   | `NUMERIC`, `BigDecimal`, `денежное` | `13_monetary.md` (денежные поля — только `BigDecimal`) |
   | `enum`, `ObjectStatus`, `ObjectTypeName` | `17_enums_over_constants.md` (предпочтение enum) |

4. Прочитай **ТОЛЬКО релевантные** rules через `read_file → .gigacode/service-rules/{filename}.md`.
5. Зафиксируй список загруженных rules в контексте сессии — они применяются при генерации тестов на Шаге 2.

**Если service-rules недоступны** (вызов вне pipeline, файл `00_index.md` отсутствует):
> Сервис-правила не применятся — используй общепринятые конвенции Java/Test и **краткую выжимку**
> в начале этого скилла как fallback.

## Шаг 0.6. Gate-check: проверить review-report.md

> ⛔ **НЕ выполняй шаги 1–4, если gate-check не пройден.**

1. `Glob specification/increment/{release}/{ticket}/review-report.md`

2. Если файл **не найден** → **стоп**:
   ```
   ⛔ Пропущен(ы) шаг(и) pipeline-конвейера.
   
   Не выполнен Шаг 4 (spec-increment-review): файл review-report.md не найден.
   Требует выполнения: `/spec-increment-review <базовая_ветка>`
   
   Выполните пропущенный шаг, затем повторите запуск.
   ```

3. Если файл **найден** — прочитать раздел `## Итог` в `review-report.md`:
   - **"Готово к мержу"** → ✅ gate-check пройден, продолжаем
   - **"Требует доработки"** → **стоп**:
     ```
     ⛔ Пропущен(ы) шаг(и) pipeline-конвейера.
     
     Шаг 4 (spec-increment-review) завершён со статусом "Требует доработки".
     Найдены критичные баги в diff. Сначала исправьте найденные проблемы
     и перезапустите `/spec-increment-review <базовая_ветка>`.
     ```
   - **Другое содержание** → **стоп**, запросить уточнение у пользователя

4. Если gate-check пройден → продолжить к шагу 1

## Шаг 1. Анализ increment.md

1. `read_file` → `INCREMENT_PATH`

2. Прочитать разделы:
   - **"Затронутые файлы"** — список файлов, изменённых в инкременте
   - **"Изменения в коде"** — детальное описание что и где менять (по слоям/файлам)
   - **"Цель"** — проверяемые пункты, что должно работать

3. Определить затронутые public-методы:
   - Для каждого файла из "Затронутые файлы" определить, относится ли он к `src/main/java` или `src/test/java`
   - Для production-файлов — определить public-методы, которым нужны тесты:
      - `*ServiceImpl.java` → public-методы сервиса
      - `*Controller.java` → public-endpoints контроллера
      - `*Mapper.java` → методы преобразования MapStruct
      - `*Repository.java` — **НЕ требуется** (Spring Data JPA генерирует их автоматически, в проекте 21 тест-класс не тестирует репозитории)

4. Определить, какие тест-классы уже существуют:
   - `Glob {TESTS_PATH}/**/*ServiceImplTest.java`
   - `Glob {TESTS_PATH}/**/*MapperTest.java`
   - `Glob {TESTS_PATH}/**/*ControllerTest.java`

5. Классифицировать действия:
   - **Новые тесты** — для методов без существующих тестов
   - **Обновление тестов** — для методов, тесты на которые есть, но сигнатура/логика изменились
   - **Удаление тестов** — для методов, которые были удалены

6. **Дополнительная проверка service-rules:**
   - Если "Затронутые файлы" содержат `*Mapper.java` → убедись, что `01_coding.md` загружен (раздел MapStruct)
   - Если содержат `*Controller.java` → убедись, что `01_coding.md` загружен (thin-контроллер, Swagger)
   - Если содержат `*Service.java` → убедись, что `01_coding.md` загружен (DI, слои)
   - Если rules не загружены → прочитай их через `read_file → .gigacode/service-rules/{filename}.md` перед Шагом 2

## Шаг 2. Генерация новых тестов

Для каждого метода из "Новые тесты" (шаг 1):

### 2.1 Сервис-тесты (`*ServiceImplTest`)

1. Определить пакет тестируемого сервиса из `src/main/java/.../service/{domain}/impl/`
2. Создать тест в зеркальном пакете `src/test/java/.../service/{domain}/impl/`
3. Структура тест-класса:
   ```java
   @ExtendWith(MockitoExtension.class)
   @DisplayName("{Название сервиса}")
   class {ClassName}ServiceImplTest {
       
       @Mock private DependencyRepository dependencyRepository;
       @Mock private DependencyService dependencyService;
       @InjectMocks private {ClassName}ServiceImpl service;
       
       @Test
       @DisplayName("Описание сценария — результат")
       void methodName_withCondition_shouldExpectedResult() {
           // Given
           // When
           // Then
       }
   }
   ```
4. Для каждого public-метода сервиса создать **один или несколько** `@Test`-методов:
   - Позитивные сценарии — "нормальный путь"
   - Негативные сценарии — исключения, пустые значения, граничные условия
5. Использовать **Builder/фабричные методы** для создания тестовых данных, не инлайн хардкода
6. Русский `@DisplayName` на тест-классе и каждом `@Test`
7. Верификация через `verify(...)`, `verifyNoInteractions(...)`, `assertThat(...).usingRecursiveComparison()`

### 2.2 Controller-тесты (`*ControllerTest`)

1. Тест для `ObjectController.java`:
   ```java
   @ExtendWith(MockitoExtension.class)
   @DisplayName("ObjectController")
   class ObjectControllerTest {
       @Mock private ObjectCreationService objectCreationService;
       @Mock private ObjectReadService objectReadService;
       @InjectMocks private ObjectController controller;
       
       @Test
       @DisplayName("createObject — успешное создание — 201 CREATED")
       void createObject_validRequest_shouldReturnCreated() {
           // Given
           // When
           // Then — проверка ResponseEntity и вызова сервиса
       }
   }
   ```
2. Тестировать обязательные заголовки (`X-Request-Id`, `X-Correlation-Id`, `X-SberPDI`)

### 2.3 MapStruct-мапперы (`*MapperTest`)

1. Инстанцирование через `org.mapstruct.factory.Mappers.getMapper(XxxMapper.class)`
2. Проверка:
   - Преобразование всех полей `usingRecursiveComparison()`
   - `null`-значения — не падают
   - Пустые коллекции/объекты
   ```java
   @Test
   @DisplayName("toDto — null input — null output")
   void toDto_nullInput_shouldReturnNull() {
       assertThat(mapper.toDto(null)).isNull();
   }
   ```

### 2.4 Пример из проекта

**Пример негативного теста** (`ObjectCreationServiceImplTest`):
```java
@Test
@DisplayName("createObject — неизвестный код процесса — IllegalArgumentException")
void createObject_withUnknownProcessType_shouldThrowIllegalArgument() {
   assertThatThrownBy(() -> service.createObject(request))
           .isInstanceOf(IllegalArgumentException.class)
           .hasMessageContaining("999");
   verify(serviceService).checkExistObjectsForContractVersionId(CONTRACT_VERSION_ID);
   verifyNoInteractions(rentalObjectService, assetObjectService);
}
```

## Шаг 3. Обновление существующих тестов

Для каждого метода из "Обновление тестов" (шаг 1):

1. `read_file` → существующий тест-класс
2. Определить, что изменилось:
   - **Сигнатура метода** — обновить `@Mock`, `@InjectMocks`, вызовы в `@Test`
   - **Удалённый метод** — удалить затронутые `@Test`-методы
   - **Изменившаяся логика** — обновить `Given/When/Then` assertions
3. `write_file` → обновить тест-файл целиком (не partial)
4. Сохранить стиль: русский `@DisplayName`, паттерн `@Mock`/`@InjectMocks`, фабрики данных

**Пример обновления сигнатуры:**
- Если добавился новый `@Mock`-зависимость в сервисе → добавить `@Mock` в тест
- Если изменился порядок параметров в `@Test` → обновить вызов
- Если метод-зависимость был удалён → `verifyNoInteractions(...)` убрать для удалённого мока

## Шаг 4. Запуск тестов модуля

1. **Сначала компиляция:**
   ```bash
   mvn -pl objects compile
   # или
   mvn -pl objects-rest-client compile
   ```
   Зафиксировать: ✅ успех / ❌ провал с ключевыми строками ошибок

2. **Запуск тестов:**
   ```bash
   mvn -pl objects test
   # или
   mvn -pl objects-rest-client test
   ```

3. Зафиксировать:
   - **Всего тестов** — из вывода `BUILD SUCCESS: Tests run: X`
   - **Пройдено** — `Tests run` (если все прошли)
   - **Провалено** — список упавших тестов с ключевыми строками
   - **Пропущено** — `Tests run: X (skipped: Y)`

4. Если `mvn test` провалился:
   - **НЕ останавливаемся** — просто фиксируем в отчёте
   - Проанализировать: упавшие тесты — из-за production-кода или из-за наших новых тестов?
   - Если из-за новых тестов — это ожидаемо (новое покрытие нашло баг или тест написан неверно)
   - В `test-report.md` пометить: "Новые тесты выявили N проблем"

## Шаг 5. Генерация test-report.md

**Путь:** `specification/increment/{release}/{ticket}/test-report.md`

**Если файл уже существует** — перезаписать целиком (отчёт актуализируется при каждом запуске).

**Шаблон:**

```markdown
# Отчёт тестирования — {ticket}: {Название инкремента}

**Ветка:** `{текущая ветка}`
**Дата:** {дата/время}
**Модуль:** `objects` / `objects-rest-client`
**increment.md:** `specification/increment/{release}/{ticket}/increment.md`

## Компиляция

{✅ Успех / ❌ Провал — {ключевые строки ошибок компиляции}}

## Результаты тестов

| Метрика | Значение |
|---------|----------|
| Всего тестов | {X} |
| Пройдено | {Y} |
| Провалено | {Z} |
| Пропущено | {W} |

**Результат mvn test:** {код завершения, BUILD SUCCESS/FAILURE}

## Упавшие тесты

{список упавших тестов с ключевыми строками ошибок или "нет"}

## Новые тесты

{перечень созданных тест-классов и методов или "нет"}

| Тест-класс | Тест-метод | Покрытие |
|-----------|------------|----------|
| `ServiceServiceImplTest.java` | `methodName_withCondition_shouldExpectedResult()` | сервисный метод |
| ... | ... | ... |

## Обновлённые тесты

{перечень изменённых существующих тестов или "нет"}

| Тест-класс | Тест-метод | Причина обновления |
|-----------|------------|--------------------|
| `ObjectCreationServiceImplTest.java` | `createObject_withUnknownProcessType_shouldThrowIllegalArgument()` | изменилась сигнатура метода |
| ... | ... | ... |

## Итог

{Все прошли / Требуют доработки}

{Если "Требуют доработки" — краткое обоснование: количество упавших тестов, критичность}
{Если "Все прошли" — подтверждение: все N тестов прошли, новых проблем не выявлено}
```

## Шаг 6. Сообщить пользователю

Кратко (2-4 предложения):
- Результат компиляции и запуска тестов
- Количество новых/обновлённых тестов
- Итог: "Все прошли" / "Требуют доработки"
- Путь к `test-report.md`

## Важно

- **Gate-check:** не выполняй шаги 1–4, если не пройден Шаг 0.6 (review-report.md отсутствует или статус "Требует доработки").
- **Обязательный Шаг 0.5:** всегда загружай service-rules на Шаге 0.5 перед анализом инкремента.
- **Код не меняется** — только тесты и test-report.md. Production-код трогать запрещено.
- **Не изменяй pom.xml, миграции, конфигурацию** — только тесты.
- **Не используй `@SpringBootTest`, `@WebMvcTest`, `@DataJpaTest`** — только чистые unit-тесты на Mockito.
- **Не меняй существующие тесты без необходимости** — обновляй только при изменении сигнатур/логики.
- Пропуск шагов запрещён, кроме `--skip-gate-checks` (только для отладки).
- В будущем правила тестирования могут перейти на `@Nested` class-тесты — скилл готов к этой эволюции.
