---
paths:
  - "src/test/**"
  - "src/main/java/**/service/impl/**"
---

# Соглашение: Тесты

**Когда читать:** при написании теста на новый или изменённый код `service.impl`.

**Что описывает:** область покрытия, способ мокирования зависимостей, структуру и читаемость тестового класса.

---

## 1. Правило

### 1.1 Область покрытия

- Пишем только unit-тесты. Запрет интеграционных тестов (импорты `@SpringBootTest` и пакета `org.testcontainers`) формализован в `checkstyle.xml` (`IllegalImport`), здесь не дублируется.
- Для нового кода в `service.impl` — писать unit-тесты на бизнес-логику.
- Тесты называются `<Класс>Test`, лежат в `src/test/java` в том же пакете, что и тестируемый класс.

### 1.2 Моки

- Зависимости (репозитории и т.п.) мокаются через Mockito: `@ExtendWith(MockitoExtension.class)`, `@Mock` на зависимости, `@InjectMocks` на тестируемый класс.
- Общая подготовка моков/тестовых данных, повторяющаяся в нескольких тестах класса, выносится в метод с `@BeforeEach`.

### 1.3 Структура и читаемость

- Наличие `@DisplayName` на тестовом классе и тестовом методе (`@Test`/`@ParameterizedTest`) формализовано в `checkstyle.xml` (`MatchXpath`, id `TestDisplayName`). Текст — на русском языке, описывает сценарий и ожидаемый результат, а не техническое имя метода.
- Если для одного метода тестируемого класса пишется больше двух тестов — сгруппировать их в `@Nested`-класс внутри тестового класса (например, `FrontWordServiceImplTest.CreateFrontWord`), у вложенного класса тоже свой `@DisplayName`.
- Где сценариев несколько и они отличаются только входными данными — использовать `@ParameterizedTest` (`@ValueSource`/`@CsvSource`/`@MethodSource`) вместо копирования почти одинаковых тестовых методов.

## 2. Соглашения для агента

- Для нового публичного метода `service.impl` — писать тест сразу, не откладывать отдельной задачей.
- Для теста бизнес-логики — только `MockitoExtension`, без поднятия Spring-контекста.
- Прежде чем писать третий похожий тестовый метод для одного и того же метода класса — оценить, не превратить ли группу в `@ParameterizedTest`.
- `@DisplayName` формулировать как исход сценария ("успешно сохраняет слово..."), а не как техническое имя метода ("testCreate").

## 3. Чек-лист

- [ ] Класс теста называется `<Класс>Test`, лежит в том же пакете в `src/test/java`
- [ ] Зависимости замоканы через `@Mock`/`@InjectMocks` с `MockitoExtension`
- [ ] `@DisplayName` — на русском, описывает сценарий и результат
- [ ] Больше двух тестов на один метод — сгруппированы в `@Nested`
- [ ] Похожие сценарии с разными входными данными — через `@ParameterizedTest`, не копипастой

## 4. Примеры кода

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("FrontWordServiceImpl")
class FrontWordServiceImplTest {

    @Mock
    private FrontWordRepository frontWordRepository;

    @InjectMocks
    private FrontWordServiceImpl frontWordService;

    @BeforeEach
    void setUp() {
        // общая подготовка моков
    }

    @Nested
    @DisplayName("Создание слова")
    class CreateFrontWord {

        @Test
        @DisplayName("успешно сохраняет слово и возвращает его с id")
        void savesWordSuccessfully() {
            // ...
        }

        @ParameterizedTest
        @DisplayName("бросает исключение при пустом значении слова")
        @ValueSource(strings = {"", " "})
        void throwsExceptionWhenWordIsBlank(String word) {
            // ...
        }
    }
}
```

## 5. Когда пересматривать

Если в проект вводятся интеграционные тесты (например, на слой репозиториев с Testcontainers) — правило дополняется отдельным разделом с их областью покрытия и структурой, текущее ограничение «только unit» при этом уточняется, а не отменяется целиком.
