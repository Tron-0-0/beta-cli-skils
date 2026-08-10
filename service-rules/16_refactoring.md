---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Рефакторинг кода (profitcontr-objects)

**Когда читать:** При рефакторинге, code review, добавлении новых сервисов или устранении дублирования.

**Что описывает:** Лимиты длины методов/классов, цикломатическая сложность, дублирование кода, generics, вложенность, параметры методов.

**Глобальный эталон:** `rules/16_refactoring.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Длинные методы

**Статус: compliant.** В проекте нет методов длиннее 30 строк. Самый длинный метод — `ObjectCreationServiceImpl.createObject()` (~35 строк, но >20 — это форматирование и логгирование), реальная бизнес-логика — ~15 строк.

| Класс | Самый длинный метод | Длина |
|---|---|---|
| `AssetObjectServiceImpl` | `createAssetObject()` | ~26 строк |
| `RentalObjectServiceImpl` | `createRentalObject()` | ~26 строк |
| `ObjectCreationServiceImpl` | `createObject()` | ~35 строк |

### 1.2 Длинные классы

**Статус: violation.** Обнаружены три класса-кандидата на рефакторинг:

| Класс | Строк | Проблема |
|---|---|---|
| `ObjectControllerDocs.java` | ~450 | 90% — JSON-примеры в `String`-константах |
| `ObjectsDTO.java` (client) | ~350 | 7 вложенных static-классов, каждый 50-100 строк |
| `ObjectsCreationResponse.java` (client) | ~280 | Дублирует структуру `ObjectsDTO` с теми же полями |

### 1.3 Цикломатическая сложность

**Статус: compliant.** Максимальная сложность — 3 (`ObjectCreationServiceImpl.createObject()` — switch с default). Методов со сложностью >5 нет.

| Метод | Сложность | Условия |
|---|---|---|
| `ObjectCreationServiceImpl.createObject()` | 3 | switch + default |
| `PartnerBankAccountServiceImpl.createPartnerAndBankAccount()` | 2 | switch |

### 1.4 Дублирование кода

**Статус: critical violation.** Это самый значительный недостаток проекта.

#### Дублирование А: `AssetObjectServiceImpl` vs `RentalObjectServiceImpl`

Два класса практически идентичны (80% одинакового кода):
- Одинаковая структура полей-зависимостей (8 полей)
- Идентичный метод `createXxxObject()` — за исключением типов DTO и enum
- Полностью идентичный `fillServiceResponse()` — один метод мог бы работать с generics
- Идентичная структура `fillXxxObjectResponse()`

**Объём дублирования:** ~60 строк на класс × 2 класса = ~120 строк, из которых ~100 — идентичные.

#### Дублирование Б: `Service.java` — 4 одинаковых метода `add*`

```java
// Service.java — строки 72-96
public void addRentalObject(RentalObject rentalObject) {
    if (this.rentalObjects == null) this.rentalObjects = new ArrayList<>();
    this.rentalObjects.add(rentalObject);
    rentalObject.setService(this);
}
// ... addAssetObject, addCapObject, addFinapObject — полностью идентичны
```

4 метода с одинаковой логикой — только разные типы.

#### Дублирование В: `ObjectsDTO` vs `ObjectsCreationResponse`

Два класса с идентичной структурой вложенных DTO:
- `ObjectsDTO.ServiceDataDTO` ↔ `ObjectsCreationResponse.ServiceResponse`
- `ObjectsDTO.RentalObjectDTO` ↔ `ObjectsCreationResponse.RentalObjectResponse`
- `ObjectsDTO.PartnerDto` ↔ `ObjectsCreationResponse.PartnerResponse`

#### Дублирование Г: Мапперы `OrganisationToOrganisationDtoMapper` и `OrganisationToOrganisationCreationResponseMapper`

Идентичная логика маппинга на разные target-типы.

### 1.5 Геттеры/сеттеры

**Статус: compliant.** Все классы используют Lombok (`@Getter`, `@Setter`, `@Data`). Ручных геттеров/сеттеров нет.

### 1.6 Глубокая вложенность

**Статус: compliant.** Максимальная вложенность — 3 уровня (два цикла `for`). Глубокой вложенности >3 нет.

### 1.7 Параметры методов

**Статус: compliant.** Максимум 4 параметра (контроллер + 3 заголовка). Методов с >5 параметров нет.

<!-- source: auto -->
## 2. Соглашения для агента

### 2.1 Ограничения на длину

- **Методы:** не больше 30 строк. Если метод длиннее — выдели логику в приватные методы.
- **Классы:** не больше 200 строк (для основных сервисов/контроллеров). DTO-классы и swagger-документация могут быть длиннее, но не больше 400 строк.
- **Цикломатическая сложность:** не больше 5. Если больше — разбей метод на части с выделением условий в отдельные методы.

### 2.2 Устранение дублирования

1. **Template-паттерн для сервисов.** Если два+ сервиса имеют идентичную структуру (`createXxxObject()` → маппинг → сохранение → fillResponse), вынеси общий код в абстрактный базовый класс или параметризированный метод.

   Пример:
   ```java
   public abstract class AbstractObjectCreationService<T extends CreateRequest> {
       protected ServiceResponse createServiceResponse(Service service, Organisation organisation) {
           // общий код для AssetObject и RentalObject
       }
       
       public abstract void createObject(T request, CreationObject creationObject);
   }
   ```

2. **Generic-методы вместо повторяющихся `add*`.** Если методы `addXxx()` идентичны кроме типа, замени на один generic-метод:
   ```java
   public <E extends BaseEntity> void addObject(List<E> list, E entity, BiConsumer<E, Service> setter) {
       if (list == null) list = new ArrayList<>();
       list.add(entity);
       setter.accept(entity, this);
   }
   ```

3. **Единые DTO.** Если два DTO имеют идентичную структуру, объедини их в один общий класс (или используй один DTO как source-of-truth).

4. **DRY в мапперах.** Если два MapStruct-маппера имеют идентичную логику, используй один маппер с разными target-типами:
   ```java
   @Mapper
   public interface OrganisationMapper {
       OrganisationDTO toDto(Organisation org);
       OrganisationResponse toResponse(Organisation org);
   }
   ```

### 2.3 Рефакторинг контроллеров

- Контроллер должен быть **thin**: валидация + делегирование в сервис. Если контроллер содержит >15 строк — вынеси логику в сервис.
- Swagger-документация (`*Docs.java`) не должна превышать 400 строк. JSON-примеры выноси в отдельные ресурсы (`src/main/resources/api-examples/`), не хардкодь в код.

### 2.4 Навигация по проектам

При добавлении нового типа объекта:
1. Проверь, можно ли复用 существующий generic-базовый класс вместо создания нового `*ServiceImpl`.
2. Не создавай новый `*Response` DTO, если есть аналог в `ObjectsDTO` — используй существующий.
3. Новые мапперы добавляй в существующий интерфейс, не создавай дублирующие мапперы.

<!-- source: auto -->
## 3. Чек-лист

- [ ] Ни один метод не превышает 30 строк (без учёта логгирования и форматирования)
- [ ] Основной сервисный класс не превышает 200 строк
- [ ] Нет дублирующегося кода между сервисами (AssetObjectServiceImpl / RentalObjectServiceImpl и подобные)
- [ ] Нет одинаковых методов `addXxx()` — используется generic-метод или делегирование
- [ ] Нет одинаковых DTO-ответов — используется единый DTO или мапперы
- [ ] Цикломатическая сложность метода ≤ 5
- [ ] Вложенность кода не превышает 3 уровня
- [ ] Параметры метода ≤ 5
- [ ] Swagger-документация ≤ 400 строк (JSON-примеры вынесены в ресурсы)
- [ ] Нет ручных геттеров/сеттеров — используется Lombok
- [ ] При рефакторинге не ломаются тесты (`*ServiceImplTest`, `*MapperTest`)

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: Дублирование — AssetObjectServiceImpl vs RentalObjectServiceImpl

**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/AssetObjectServiceImpl.java`
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/service/object/impl/RentalObjectServiceImpl.java`

```java
// AssetObjectServiceImpl.java — строки 38-64
@Service
@RequiredArgsConstructor
public class AssetObjectServiceImpl implements AssetObjectService {
    private final AssetObjectRepository assetObjectRepository;
    private final AssetObjectMapper assetObjectMapper;
    // ... ещё 6 полей

    @Override
    public ServiceResponse createAssetObject(AssetObjectCreateRequest request, CreationObject creationObject) {
        log.info("Создание объекта ОС для contractId={}", request.getContractId());
        var org = organisationService.createOrganisation(request.getOrganisation());
        var service = serviceMapper.toService(request, org, creationObject);
        var serviceResponse = new ServiceResponse();
        service.setObjectTypeName(ObjectTypeName.ASSET_OBJECT);
        service.setOrganisation(org);
        
        for (Map<String, Object> object : request.getObjects()) {
            AssetObjectCreateRequest assetObjectRequest = objectMapper.convertValue(object, AssetObjectCreateRequest.class);
            for (PartnerCreateRequest partnerRequest : assetObjectRequest.getPartners()) {
                Partner partner = partnerBankAccountService.createPartnerAndBankAccount(...);
                assetObject.addPartner(partner);
            }
            assetObjectRepository.save(assetObject);
            fillAssetObjectResponse(...);
        }
        return fillServiceResponse(serviceResponse, service, org);
    }
}
```

**Решение:** вынести `fillServiceResponse` и общую логику `createXxxObject` в базовый класс с generics.

### Example 2: Дублирование — 4 метода add* в Service.java

**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/entity/Service.java`

```java
// Строки 72-96 — 4 идентичных метода
public void addRentalObject(RentalObject rentalObject) {
    if (this.rentalObjects == null) this.rentalObjects = new ArrayList<>();
    this.rentalObjects.add(rentalObject);
    rentalObject.setService(this);
}

public void addAssetObject(AssetObject assetObject) {
    if (this.assetObjects == null) this.assetObjects = new ArrayList<>();
    this.assetObjects.add(assetObject);
    assetObject.setService(this);
}
// ... addCapObject, addFinapObject — полностью идентичны
```

**Решение:** заменить на generic-метод:
```java
public <T> void addObject(List<T> list, T entity, Consumer<T> setter, FieldGetter getter) {
    if (list == null) list = getter.getList(this);
    list.add(entity);
    setter.accept(entity, this);
}
```

### Example 3: Дублирование — ObjectsDTO vs ObjectsCreationResponse

**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/dto/ObjectsDTO.java`
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/model/response/ObjectsCreationResponse.java`

```java
// ObjectsDTO.java — ~350 строк
@Data @Builder public class ObjectsDTO {
    @Schema(description = "Данные услуги")
    private ServiceDataDTO service;
    @Schema(description = "Объекты аренды")
    private List<RentalObjectDTO> rentalObjects;
    // ... ещё 5 вложенных static-классов с идентичными полями
    
    @Data @Builder public static class ServiceDataDTO { ... }
    @Data @Builder public static class RentalObjectDTO { ... }
    // ... ещё 5 классов
}

// ObjectsCreationResponse.java — ~280 строк, дублирует ObjectsDTO
@Data @Builder public class ObjectsCreationResponse {
    private ServiceResponse service;
    private List<RentalObjectResponse> rentalObjects;
    // ... идентичная структура
}
```

**Решение:** объединить в один DTO или использовать один как source-of-truth с маппингом.

<!-- source: auto -->
## 5. Исключения и оговорки

- DTO-классы в `objects-rest-client` (`ObjectsDTO`, `ObjectsCreationResponse`) могут быть длиннее 200 строк из-за вложенных static-классов — их лимит — 400 строк.
- Swagger-документация (`ObjectControllerDocs.java`) может содержать JSON-примеры — лимит 400 строк.
- Lombok (`@Data`, `@Getter`, `@Setter`) генерирует код автоматически — он не учитывается в лимитах длины методов/классов.
- `ObjectCreationServiceImpl.createObject()` может быть до 40 строк — это допустимо из-за switch по типам и маппинга.

<!-- source: auto -->
## 6. Обновление

Пересобирать при:
- Добавлении нового типа объекта с дублированием существующих сервисов
- Росте DTO/Response более 400 строк
- Появлении методов с цикломатической сложностью >5
- Увеличении вложенности >3 уровней
- Появлении методов с >5 параметрами
