---
apply: always
mode: all
---

# Соглашение: Unit и интеграционные тесты (profitcontr-objects)

**Когда читать:** При написании тестов, настройке тестовой инфраструктуры, или выборе типа теста.

**Что описывает:** Unit-тесты, интеграционные тесты, тестовые профили, MockMvc, Embedded Kafka/DB.

**Глобальный эталон:** `rules/06_unit_tests_with_spring_context.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Тестовые зависимости и инструменты (pom + JaCoCo)

- В `objects/pom.xml` подключён только `org.springframework.boot:spring-boot-starter-test` (`<scope>test</scope>`, строка 54). На его основе в сервисе используются JUnit 5 (`org.junit.jupiter`), Mockito, AssertJ, MapStruct-реализации.
- В корневом `pom.xml` настроен JaCoCo: плагин `org.jacoco:jacoco-maven-plugin` с целями `prepare-agent` (перед тестами) и `report` (фаза `test`); общий блок `sonar.coverage.exclusions` пуст. SonarQube включён через `sonar.java.coveragePlugin=jacoco`, `sonar.projectKey=CI06228014:CI15418320`.
- Профиль `mutation-testing` (Pitest, цель `mutationCoverage` в фазе `verify`) описан в корневом `pom.xml`; прогоняется отдельно: `mvn verify -Pmutation-testing`.
- **Актуальные тест-классы** (21 файл в `objects/src/test/java`) полагаются только на Mockito/AssertJ — без `@SpringBootTest`, `@WebMvcTest`, `@DataJpaTest`, Testcontainers (`grep` по `**/test/**` не дал ни одного вхождения этих аннотаций).

### 1.2 Структура тестов по слоям (parallel `src/test/java`)

Тесты лежат в `objects/src/test/java/ru/sbrf/sbererp/profitcontr/objects/` **зеркально** пакетам `src/main/java`:

- **Смоук / вход:** `WebApplicationTest.java` (чёрный вызов `WebApplication.main`, статический мок через `MockedStatic`).
- **Сервисные impl** (`service/object/impl/`): `ObjectCreationServiceImplTest.java`, `ServiceServiceImplTest.java`, `AssetObjectServiceImplTest.java`, `RentalObjectServiceImplTest.java`.
- **MDM-сервисы** (`service/mdm/impl/`): `OrganisationServiceImplTest.java`, `PartnerBankAccountServiceImplTest.java`.
- **MapStruct-мапперы request (`configuration/mapper/request/`):** `creation/ServiceCreateRequestToEntityMapperTest.java`, `asset/AssetObjectCreateRequestToEntityMapperTest.java`, `request/mdm/MdmBankAccountToBankAccountMapperTest.java`, `request/mdm/MDMPartnerToPartnerMapperTest.java`.
- **MapStruct-мапперы response (`configuration/mapper/response/`):** `ServiceToServiceResponseMapperTest.java`, `AssetObjectToAssetObjectDTOMapperTest.java`, `CapObjectToCapObjectResponseMapperTest.java`, `FinapObjectToFinapObjectDTOMapperTest.java`, `OrganisationToOrganisationDTOMapperTest.java`, `PartnerToPartnerResponseMapperTest.java`, `RentalObjectToRentalObjectDTOMapperTest.java`.
- **Контроллер:** `ObjectControllerTest.java` (чистый Mockito на `ObjectController`, без `@WebMvcTest`).

> Примечание: `bundle.rules["06"].layer_stats.test = 1` учитывает только один файл (голден-сэмпл `WebApplicationTest.java`) из-за фильтрации `views/layers.py`, поэтому фактических тест-классов 21, а не 1. Структуру подтверждает полный glob `objects/src/test/java/**/*.java`.

### 1.3 Отсутствие Spring-контекста и интеграционных сценариев

- Во всех тестах используется `@ExtendWith(MockitoExtension.class)` с `@Mock` / `@Spy` / `@InjectMocks` либо plain JUnit 5.
- **НЕ ОПРЕДЕЛЕНО:** `@SpringBootTest`, slice-тесты (`@WebMvcTest` / `@DataJpaTest`), `*IT*.java`, `@MockitoBean/@MockitoSpyBean`, H2/Testcontainers, `src/test/resources/application.yml`, каталоги `src/test/resources/request` и `src/test/resources/response/{success,error}` из эталона в репозитории отсутствуют.
- **Отклонение от глобального `rules/06`:** эталон предписывает поднятие Spring-контекста, MockMvc и embedded H2, тогда как в сервисе для сервисов, мапперов и контроллера принят **чистый unit-тест без контекста** (моки одиночных зависимостей). Возможна регрессия risk: смоук только на `WebApplication.main`.

<!-- source: auto -->
## 2. Соглашения для агента

- **Размещай тест в parallel-каталоге** `objects/src/test/java/ru/sbrf/sbererp/profitcontr/objects/<package>` строго по пакету тестируемого класса из `src/main/java` (см. §1.2).
- **Именуй тест-класс по суффиксу слоя:** `*ServiceImplTest` для `service/**/impl/*Service.java`, `*MapperTest` для `configuration/mapper/**/*Mapper.java`, `*ControllerTest` для `controller/*Controller.java`, `WebApplicationTest` — для точки входа.
- **Для сервисов и контроллера используй `@ExtendWith(MockitoExtension.class)`** с `@Mock` (зависимости и репозитории) и `@InjectMocks` — без поднятия Spring-контекста, так как это фактический стиль репо (см. `ObjectCreationServiceImplTest.java`, `ObjectControllerTest.java`).
- **Для MapStruct-мапперов инстанцируй маппер** через `org.mapstruct.factory.Mappers.getMapper(XxxMapper.class)`; проверяй поля `assertThat(...).usingRecursiveComparison()` и кейсы с `null`-значениями.
- **Mocking внешних MapStruct-мапперов** внутри сервисных тестов — через `@Spy` + `Mappers.getMapper(...)`, а не `@Mock`, если сервис реально вызывает маппер (пример: `ServiceServiceImplTest.java`).
- **Начинай новый интеграционный/смоук-тест с `@SpringBootTest`, если требуется контекст;** в текущем репо таких тестов нет — при добавлении первых `@SpringBootTest` дополни `src/test/resources/application.yml` и опиши слоистую настройку среды (иначе риск падения из-за внешних зависимостей/БД).

<!-- source: auto -->
## 3. Чек-лист

- [ ] Unit-тест использует правильный слайс (`@WebMvcTest`, `@DataJpaTest`) **или** `@ExtendWith(MockitoExtension.class)` — в текущем репо принят последний вариант для service/mapper/controller
- [ ] Интеграционный тест аннотирован `@SpringBootTest` с нужным профилем **и** добавлен `src/test/resources/application.yml` (сейчас таких тестов в репо нет — первое добавление требует этой настройки)
- [ ] Моки внешних зависимостей через `@MockitoBean` / `@MockitoSpyBean` (в текущей устоявшейся практике — `@Mock`/`@Spy` + `@InjectMocks` через `MockitoExtension`)
- [ ] Тестовые данные создаются через Builder/фабричные методы (в тестах — `createXxxRequest()`, `createServiceEntity()`, `createOrganisation()`), не инлайном хардкода в каждом тесте
- [ ] Именование: `<Method>_<condition>_<expectedResult>()` (пример: `createObject_withUnknownProcessType_shouldThrowIllegalArgument`)
- [ ] Русские `@DisplayName("...")` на тесте и классе для читаемости отчётов (стиль всех текущих тестов)
- [ ] Для мапперов проверены null/пустые значения и свежесть экземпляра (`usingRecursiveComparison()`)
- [ ] Ожидаемые тела ответов для HTTP-проверок лежат в `src/test/resources/response/{success,error}` после перехода на MockMvc/интеграционные тесты
- [ ] В тесты не попадают реальные credentials/пароли из `accounting.env` (файл содержит рабочие DB/keystore-секреты и находится в `.gitignore`)

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: ObjectCreationServiceImplTest.java
**Путь:** `objects/src/test/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/ObjectCreationServiceImplTest.java`

Чистый unit-тест сервисного impl без Spring-контекста: `@ExtendWith(MockitoExtension.class)`, `@Mock` зависимости сервисов, `@InjectMocks ObjectCreationServiceImpl`; русский `@DisplayName`; верификация через `verify(...)`/`verifyNoInteractions(...)`.

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("ObjectCreationServiceImpl")
class ObjectCreationServiceImplTest {

    @Mock private RentalObjectService rentalObjectService;
    @Mock private AssetObjectService assetObjectService;
    @Mock private ServiceService serviceService;
    @InjectMocks private ObjectCreationServiceImpl service;

    @Test
    @DisplayName("createObject — неизвестный код процесса — IllegalArgumentException")
    void createObject_withUnknownProcessType_shouldThrowIllegalArgument() {
        assertThatThrownBy(() -> service.createObject(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("999");
        verify(serviceService).checkExistObjectsForContractVersionId(CONTRACT_VERSION_ID);
        verifyNoInteractions(rentalObjectService, assetObjectService);
    }
}
```

### Example 2: WebApplicationTest.java
**Путь:** `objects/src/test/java/ru/sbrf/sbererp/profitcontr/objects/WebApplicationTest.java`

Смоук-тест точки входа через статический мок `MockedStatic`; `@DisplayName("Main тест")` на русском. Единственный тест-класс, который трогает `main`.

```java
@ExtendWith(MockitoExtension.class)
class WebApplicationTest {

    @Test
    @DisplayName("Main тест")
    void main() {
        try (MockedStatic<WebApplication> mockedStatic = mockStatic(WebApplication.class)) {
            WebApplication.main(new String[]{});
            mockedStatic.verify(() -> WebApplication.main(new String[]{}));
        }
    }
}
```

<!-- source: auto -->
## 5. Исключения и оговорки

- Соглашение §2 про `@ExtendWith(MockitoExtension.class)` **не заменяет** интеграционного тестирования, требуемого глобальным регламентом `rules/06`. Если сценарий требует Spring-контекста (репозитории с БД, Feign-клиенты, полный слой MVC), добавляй `@SpringBootTest`/slice-тест и `src/test/resources/application.yml` — в текущей кодовой базе таких примеров ещё нет (`НЕ ОПРЕДЕЛЕНО`).