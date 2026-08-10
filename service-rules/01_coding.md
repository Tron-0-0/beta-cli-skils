---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Слои, стиль кода, соглашения (profitcontr-objects)

**Когда читать:** При написании нового кода, рефакторинге, или code review — особенно при добавлении сервисов, контроллеров, MapStruct-мапперов и JPA-сущностей.

**Что описывает:** Слои приложения, DI-паттерн (интерфейс+impl), constructor injection через Lombok, Lombok/MapStruct конвенции, Swagger-контракт через `ObjectControllerDocs`.

**Глобальный эталон:** `rules/01_coding.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Слои и структура пакетов

Сервис — Java 21 / Spring Boot 3 (SberERP), пакет по умолчанию `ru.sbrf.sbererp.profitcontr.objects`. В `objects/src/main/java` присутствуют слои (по `facts/scan.json` → `layers`):

- `service/object` + `service/object/impl` — сервисы типов объектов: `ObjectCreationService.java`, `ServiceService.java`, их реализации `*ServiceImpl` (`ServiceServiceImpl.java`, `AssetObjectServiceImpl.java`, `RentalObjectServiceImpl.java`, `ObjectCreationServiceImpl.java`).
- `service/mdm` + `service/mdm/impl` — MDM-сервисы: `OrganisationService.java`, `PartnerBankAccountService.java`, реализации `OrganisationServiceImpl.java`, `PartnerBankAccountServiceImpl.java`.
- `controller` — `ObjectController.java` как единственный `@RestController`; `controller/swagger/ObjectControllerDocs.java` — Swagger-аннотации.
- `configuration/mapper/request` и `configuration/mapper/response` — MapStruct-мапперы; базовый конфиг `configuration/mapper/StrictMapperConfiguration.java`.
- `model/entity` — JPA-сущности (`Service`, `RentalObject`, `AssetObject`, `CapObject`, `FinapObject`, `Organisation`, `Partner`, `BankAccount`); `model/enums` — `ObjectTypeName`, `RentalObjectStatusName`, `ObjectTypeByClassification`.
- `repository/` — Spring Data: `ServiceRepository`, `AssetObjectRepository`, `RentalObjectRepository`.

Границы вызовов: `controller` → `service` → `repository`; мапперы (`configuration/mapper`) используются сервис-слоем, контроллер остаётся thin (только валидация `@Valid` + делегирование + заголовки). Заметных слоёв Kafka нет (слой `kafka` пуст); Feign-клиент вынесен в модуль `objects-rest-client` (слой `client`).

### 1.2 DI и Lombok: constructor injection

Во всех прочитанных impl-классах (`OrganisationServiceImpl.java`, `ServiceServiceImpl.java`) используется constructor injection через `@RequiredArgsConstructor` + `private final` поля и `@Service`. `@Autowired` не используется.

Пример — `service/object/impl/ServiceServiceImpl.java`:

```java
@Slf4j
@org.springframework.stereotype.Service
@RequiredArgsConstructor
public class ServiceServiceImpl implements ServiceService {
    private final ServiceRepository serviceRepository;
    private final ServiceToServiceDtoMapper serviceDtoMapper;
    private final OrganisationToOrganisationDtoMapper organisationMapper;
```

### 1.3 MapStruct и мапперы

Все мапперы — интерфейсы `@Mapper(config = StrictMapperConfiguration.class)` с `componentModel = "spring"`. Центральный конфиг — `configuration/mapper/StrictMapperConfiguration.java` (`@MapperConfig(componentModel = SPRING, unmappedTargetPolicy = ERROR)`). Для явного маппинга применяется `@BeanMapping(ignoreByDefault = true)` и `@Mappings({@Mapping(target=..., source=...)})`. Пример — `configuration/mapper/request/creation/ServiceCreateRequestToEntityMapper.java`. Мапперы разбиты на `request` (creation + mdm) и `response` (creation + dto), совпадают с скан-слоем `mapping`.

### 1.4 Entities и иерархия `Service`

`model/entity/Service.java` — корневая сущность: `@Entity @Table(name = "service")`, `@Id @GeneratedValue(strategy = GenerationType.UUID)`; держит списки дочерних объектов через `@OneToMany(mappedBy = "service", cascade = CascadeType.ALL)`: `rentalObjects`, `assetObjects`, `capObjects`, `finapObjects` и `@OneToOne` `organisation`; hand-rolled методы `addRentalObject(...)`, `addAssetObject(...)`, `addCapObject(...)`, `addFinapObject(...)`, `setOrganisation(...)` поддерживают двустороннюю привязку. Энумы — `model/enums` (например `ObjectTypeName` связывает тип объекта с его классом).

### 1.5 Контроллер и Swagger-контракт

`controller/ObjectController.java` — единственный REST-контроллер: `@RestController @RequestMapping(DEFAULT_URL_PREFIX_API + OBJECTS_URL_PREFIX_APU)`, endpoints `GET /{contract-version-id}` и `POST`. Внутри — тонкая логика: валидация `@Valid`, обязательные заголовки `X-Request-Id`, `X-Correlation-Id`, `X-SberPDI` (`requestId`, `correlationId`, `sberId`) и делегирование в сервис.

**Нарушение (по `facts/gap_report.json` → `01_coding.controller_api_interface` = violation, count=0):** в `src/main/java` **отсутствуют** интерфейсы `*ControllerApi` (паттерн «ControllerApi» не найден). Swagger-контракт реализован не через интерфейс-контракт, а через **кастомные swagger-аннотации** в `controller/swagger/ObjectControllerDocs.java` (`@ObjectControllerDocs.GetObjectByContractVersionIdDocs`, `@ObjectControllerDocs.CreateObjectDocs`).

### 1.6 Compliant-проверки (по gap_report, rule 01)

- `01_coding.data_on_dto` — **compliant**: `@Data` на DTO не найдено (count=0); DTO в `objects-rest-client` иммутабельны.
- `01_coding.autowired_injection` — **compliant**: `@Autowired` на полях не найдено (count=0); DI через `@RequiredArgsConstructor`.
- `01_coding.max_dependencies` — **compliant**: классов >7 `private final` зависимостей нет (count=0).
- `01_coding.value_annotation` — **compliant**: россыпи `@Value("${...}")` нет (count=0).

### 1.7 Форматирование вызовов методов и порог параметров

**Статус: compliant, но правило зафиксировано.** В текущем коде нет методов с >5 параметрами (максимум 4 в контроллере: `ObjectController.createObject`).

Соглашение по параметрам и форматированию вызовов:

- **<=3 параметра** — вызов в одну строку:
  ```java
  serviceService.getServiceByContractVersionId(contractVersionId, requestId);
  ```

- **4 параметра** — каждый аргумент с новой строки, перенос до первого и после последнего:
  ```java
  objectCreationService.createObject(
          request,
          requestId,
          correlationId,
          sberId
  );
  ```

- **>=5 параметров** — создать класс-обёртку для параметров. Использовать только если вложенность методов становится нечитаемой:
  ```java
  public record CreateUserParams(String name, String email, String role, UUID deptId, UUID managerId) {}
  
  userService.createUser(new CreateUserParams(name, email, role, deptId, managerId));
  ```

<!-- source: auto -->
## 2. Соглашения для агента

- Размещай сервис-логику в `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/` в подпакете по домену: `service/object/*` для объектов договора и `service/mdm/*` для MDM-данных; реализацию в том же `service/*/impl/` с суффиксом `Impl` (как `service/mdm/impl/OrganisationServiceImpl.java`, `service/object/impl/ServiceServiceImpl.java`). Интерфейс объявляй рядом в корне пакета (`service/mdm/OrganisationService.java`).
- Впрыскивай зависимости только через constructor injection: для `private final` полей класса используй `@RequiredArgsConstructor` + `private final` (`@Service`) — так же, как в `OrganisationServiceImpl`, никогда не используй `@Autowired` на полях (в репо count=0).
- Для преобразований используй MapStruct-мапперы в `configuration/mapper/`, разделяй на `request/` и `response/` (`ServiceCreateRequestToEntityMapper` в `request/creation`, `ServiceToServiceDtoMapper` в `response/dto`); каждый маппер `@Mapper(config = StrictMapperConfiguration.class)` из `configuration/mapper/StrictMapperConfiguration.java` со `componentModel = "spring"`.
- Класть JPA-сущности в `model/entity/`, енумы в `model/enums/`; репозитории в `repository/` наследуют `JpaRepository<T, UUID>` (пример `repository/ServiceRepository.java`).
- Swagger-контракт выноси в отдельный класс-аннотаций `controller/swagger/*Docs` и аннотируй методы контроллера составными аннотациями (как `ObjectControllerDocs`), поскольку паттерн `*ControllerApi` интерфейсов не используется и не генерируется в этом репо.
- Держи контроллер thin: только валидация `@Valid`, проброс обязательных заголовков (`X-Request-Id`, `X-Correlation-Id`, `X-SberPDI`) и вызов сервиса; не пиши бизнес-логику в контроллере.

<!-- source: auto -->
## 3. Чек-лист

- [ ] Реализация сервиса — в `service/{domain}/impl/` с суффиксом `Impl`, интерфейс — в `service/{domain}/` (или уже существующий интерфейс расширяется).
- [ ] DI через constructor injection (`@RequiredArgsConstructor`, `private final`), а не `@Autowired` на полях.
- [ ] Новые классы размещай в правильном пакете-слое (`service`, `controller`, `repository`, `model/entity`, `model/enums`, `configuration/mapper/*`).
- [ ] MapStruct-маппер — `@Mapper(config = StrictMapperConfiguration.class)` со `componentModel = "spring"`; дочерние маппинги игнор через `@BeanMapping(ignoreByDefault = true)`.
- [ ] Контроллеры — thin: валидация + делегирование в сервис; Swagger-контракт — через `controller/swagger/*Docs`.
- [ ] Новые энумы — в `model/enums/`, новые entity — в `model/entity/` с annotations Lombok (`@Getter/@Setter`) и JPA (`@Entity`, `@Table`, `@Id @GeneratedValue`).
- [ ] При отсутствии паттерна `*ControllerApi` — не вводить его в качестве обязательного; следовать текущей схеме `ObjectController` + `ObjectControllerDocs`.
- [ ] <=3 параметра — вызов в одну строку; 4 параметра — каждый аргумент с новой строки, перенос до первого и после последнего; >=5 параметров — класс-обёртка (record/class).

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: `services.mdm.OrganisationService` (интерфейс + impl)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/mdm/OrganisationService.java`

```java
public interface OrganisationService {
    Organisation createOrganisation(OrganisationCreateRequest organisationCreateRequest);
}
```

Реализация `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/mdm/impl/OrganisationServiceImpl.java` — `@Slf4j @Service @RequiredArgsConstructor`, строит entity через builder.

### Example 2: `configuration.mapper` (MapStruct со строгим конфигом)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/mapper/request/creation/ServiceCreateRequestToEntityMapper.java`

```java
@Mapper(config = StrictMapperConfiguration.class)
public interface ServiceCreateRequestToEntityMapper {
    @BeanMapping(ignoreByDefault = true)
    @Mappings({ @Mapping(target = "contractId", source = "creationObject.contractId"),
                @Mapping(target = "serviceId", ignore = true) })
    Service toService(DataService serviceRequest, Organisation organisation, CreationObject creationObject);
}
```

### Example 3: `controller` — `ObjectController` + Swagger-docs
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java` и `.../swagger/ObjectControllerDocs.java`

Thin-контроллер: `@RestController`, `@RequiredArgsConstructor`, два сервиса как `private final`, метод-аннотации `@ObjectControllerDocs.GetObjectByContractVersionIdDocs` / `@ObjectControllerDocs.CreateObjectDocs`, проброс заголовков и возврат `ObjectsDTO` / `ObjectsCreationResponse`.

### Example 4: Форматирование вызовов методов
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/ObjectController.java`

Вызов метода с 4 параметрами — каждый аргумент с новой строки:

```java
@PostMapping
public ResponseEntity<ObjectsCreationResponse> createObject(
        @RequestBody @Valid ObjectCreateRequest objectCreateRequest,
        @RequestHeader(value = REQUEST_ID_HEADER_KEY) UUID requestId,
        @RequestHeader(value = CORRELATION_ID_HEADER_KEY) UUID correlationId,
        @RequestHeader(value = SBERPDI_HEADER_KEY) String sberId
) {
    return ResponseEntity.status(HttpStatus.CREATED)
            .header(RESPONSE_ID_HEADER_KEY, requestId.toString())
            .body(objectCreationService.createObject(
                    objectCreateRequest,
                    requestId,
                    correlationId,
                    sberId
            ));
}
```

Если бы параметров стало 5+, создался бы record-обёртка:
```java
public record CreateObjectParams(
        ObjectCreateRequest request,
        UUID requestId,
        UUID correlationId,
        String sberId,
        UUID tenantId
) {}

objectCreationService.createObject(
        new CreateObjectParams(request, requestId, correlationId, sberId, tenantId)
);
```

### Example 5: Вызов с <=3 параметрами — в одну строку
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/ServiceServiceImpl.java`

```java
public ObjectsDTO getServiceByContractVersionId(UUID contractVersionId, UUID requestId) {
    List<Service> services = serviceRepository.findByContractVersionId(contractVersionId);
    return serviceMapper.toObjectsDTO(services); // 2 параметра — одна строка
}
```

<!-- source: auto -->
## 5. Исключения и оговорки

Соглашение про слои и DI подтверждается локальным кодом. Разделы про Kafka (`kafka` слой пуст) и клиентский контракт (`objects-rest-client`) здесь не детализируются — см. глобальный регламент `rules/01_coding.md` и отдельные темы. Если в новом коде появится Kafka-слой или генерация `*ControllerApi`, этот документ следует пересмотреть.

<!-- source: auto -->
## 6. Обновление

Пересобирать при крупном рефакторинге пакетной структуры, введении паттерна `ControllerApi`-интерфейсов, изменении политики MapStruct/конфигурации `StrictMapperConfiguration`, либо после массового добавления новых сущностей/энумов.