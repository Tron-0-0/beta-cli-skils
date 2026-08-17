---
apply: always
mode: all
---

# Соглашение: Unit- и интеграционные тесты

**Когда читать:** при написании тестов, настройке тестовой инфраструктуры, выборе типа теста.

**Что описывает:** пирамиду тестов, unit vs slice vs интеграционные тесты, инструменты, именование.

---

## 1. Правило

- **Пирамида тестов:** много быстрых unit-тестов (сервисы, мапперы — без Spring-контекста), меньше slice-тестов (`@WebMvcTest`, `@DataJpaTest` — часть контекста), минимум полных интеграционных (`@SpringBootTest`, поднимают весь контекст — медленные, оставляют для критичных сквозных сценариев).
- **Unit-тесты сервисов/мапперов** — `@ExtendWith(MockitoExtension.class)`, зависимости через `@Mock`, объект под тестом — `@InjectMocks`. Без поднятия Spring-контекста.
- **Интеграционные тесты с БД** — Testcontainers с реальной СУБД, а не H2/встроенная in-memory база: H2 расходится с продовой СУБД в диалекте SQL, типах данных и поведении блокировок — тесты могут проходить на H2 и падать в проде (и наоборот).
- **`@DataJpaTest` по умолчанию сам подставляет embedded-БД** (`@AutoConfigureTestDatabase`) поверх любого datasource, заданного через Testcontainers/`@DynamicPropertySource`. С Testcontainers обязателен `@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)` — иначе тест молча переключается на H2 в обход контейнера, нарушая правило выше, при этом тест остаётся зелёным.
- **MapStruct-мапперы** — инстанцируются напрямую (`Mappers.getMapper(...)`) в unit-тестах, без контекста.
- **Контроллеры** — `@WebMvcTest` (slice) с замоканным сервисным слоем, либо чистый Mockito-тест на класс контроллера, если запросы не проверяются на уровне HTTP/сериализации.
- **Именование** — `<method>_<condition>_<expectedResult>()` (`createOrder_whenDuplicateKey_throwsConflict`). Тест-класс — `<Class>Test`, интеграционный — `<Class>IT` (отдельный от unit по соглашению сборки, если интеграционные тесты гоняются отдельным профилем/фазой).
- **`@DisplayName`** — необязательное, но рекомендуемое дополнение к техническому имени метода: читаемое описание сценария и ожидаемого результата на тестовом классе и на каждом методе. Не заменяет именование по правилу выше, а дублирует его смысл в человекочитаемой форме.
- **Группировка `@Nested`** — если для одного метода тестируемого класса набирается больше двух тестов, группируй их во вложенный `@Nested`-класс (например, `OrderServiceImplTest.CreateOrder`) со своим `@DisplayName`, а не держи все тесты плоским списком в одном классе.
- **Структура теста** — Given/When/Then (или Arrange/Act/Assert), один логический сценарий на тест; ассерты — через AssertJ (`assertThat(...)`), не голый JUnit `assertEquals` для сложных объектов.

## 2. Соглашения для агента

- Новый тест размещай в `src/test/java` зеркально пакету тестируемого класса.
- Для сервисов/мапперов — `MockitoExtension` без Spring-контекста, если тест не требует реальной транзакции/JPA-поведения.
- Тест репозитория/JPA-слоя — через `@DataJpaTest` + Testcontainers с `@AutoConfigureTestDatabase(replace = Replace.NONE)`, не через полный `@SpringBootTest`, если не нужен весь контекст целиком. `@SpringBootTest` — только когда тесту реально нужны несколько слоёв/полный контекст, а не H2 вместо Testcontainers.
- Тестовые данные — через builder/factory-методы (`createOrderRequest()`), не инлайновый хардкод в каждом тесте — снижает дублирование и упрощает изменение схемы данных.
- Мокай только внешние границы (репозитории, клиенты других сервисов); не мокай классы из того же модуля, которые можно использовать напрямую — иначе тест проверяет моки, а не поведение.
- Параметризуй тесты (`@ParameterizedTest` + `@MethodSource`/`@CsvSource`) при проверке одной логики на разных входных данных вместо копипасты похожих тестов.
- Добавляй `@DisplayName` на класс и методы теста в дополнение к техническому имени; когда для одного метода тестируемого класса появляется третий тест — группируй все его тесты в `@Nested`-класс, а не оставляй плоский список.

## 3. Чек-лист

- [ ] Unit-тест сервиса/маппера не поднимает Spring-контекст без необходимости
- [ ] Интеграционный тест с БД использует Testcontainers, а не H2
- [ ] Slice-тест (`@DataJpaTest` и т.п.) с Testcontainers использует `@AutoConfigureTestDatabase(replace = Replace.NONE)`
- [ ] Тестовые данные создаются через builder/factory, не хардкодом в каждом тесте
- [ ] Именование методов — `<method>_<condition>_<expectedResult>`
- [ ] `@DisplayName` — на тестовом классе и методах; тесты одного метода (>2) сгруппированы в `@Nested`
- [ ] Замокано только то, что действительно является внешней границей
- [ ] Похожие сценарии с разными входными данными — параметризованы, а не продублированы
- [ ] Ассерты — через AssertJ, с читаемым сообщением на сложных сравнениях

## 4. Примеры кода

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("OrderCreationServiceImpl")
class OrderCreationServiceImplTest {

    @Mock private OrderRepository orderRepository;
    @InjectMocks private OrderCreationServiceImpl service;

    @Nested
    @DisplayName("Создание заказа")
    class CreateOrder {

        @Test
        @DisplayName("бросает IllegalArgumentException при отсутствии customerId")
        void createOrder_whenCustomerIdMissing_throwsIllegalArgument() {
            var request = createOrderRequest(builder -> builder.customerId(null));

            assertThatThrownBy(() -> service.createOrder(request))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("customerId");

            verifyNoInteractions(orderRepository);
        }
    }
}
```

```java
@DataJpaTest
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class OrderRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
    }

    @Autowired private OrderRepository orderRepository;

    @Test
    void findByCustomerId_returnsPersistedOrders() {
        orderRepository.save(anOrder().customerId(CUSTOMER_ID).build());

        assertThat(orderRepository.findByCustomerId(CUSTOMER_ID)).hasSize(1);
    }
}
```

## 5. Когда пересматривать

При смене тестового стека (например, переход на JUnit 6), введении первого `@SpringBootTest` в проекте без такой практики ранее, либо при систематических расхождениях H2/прод-СУБД.
