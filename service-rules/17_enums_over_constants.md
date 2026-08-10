---
apply: always
mode: all
---

<!-- source: manual -->
# Соглашение: Предпочтение enum над константами (profitcontr-objects)

**Когда читать:** При написании нового кода, рефакторинге, или code review — особенно при добавлении новых типов, статусов, флагов, кодов ошибок или любых ограниченных множеств значений.

**Что описывает:** Требование использовать `enum` вместо наборов констант (`static final`) там, где множество значений конечно, типизировано и требует смысловой нагрузки.

**Глобальный эталон:** `rules/01_coding.md`

---

## 1. Наблюдения в репозитории

### 1.1 Текущее состояние

В проекте уже существуют `enum` в `model/enums/`:

- `ObjectTypeName` — связывает тип объекта с его JPA-сущностью (`ASSET_OBJECT`, `CAP_OBJECT`, `RENTAL_OBJECT`, `FINAP_OBJECT`).
- `ObjectStatus` — статусная модель объектов учета (`NOT_RECOGNIZED`, `RECOGNIZED`, `DISPOSED_*`).

Оба используют Lombok-аннотации `@Getter @AllArgsConstructor` и хранят смысловые поля (`value`, `description`).

### 1.2 Проблемы с константами

В коде встречаются классы-константы (`WebApplicationConstants`, `ExtendedConstantUtil`), которые необходимы для конфигурационных значений и заголовков. Однако для бизнес-сущностей (типы объектов, статусы, коды операций) следует использовать `enum`.

---

## 2. Соглашения для агента

### 2.1 Когда обязательно использовать `enum`

Используй `enum` вместо `static final` констант в следующих случаях:

1. **Типы и классификаторы** — типы объектов, типы операций, типы данных:
   ```java
   // ✅ ПРАВИЛЬНО
   public enum ObjectType {
       RENTAL("rental", RentalObject.class),
       ASSET("asset", AssetObject.class);
       
       private final String code;
       private final Class<?> entityClass;
   }
   
   // ❌ НЕПРАВИЛЬНО
   public class ObjectTypes {
       public static final String RENTAL = "rental";
       public static final String ASSET = "asset";
   }
   ```

2. **Статусы и состояния** — жизненный цикл сущностей, рабочие процессы:
   ```java
   // ✅ ПРАВИЛЬНО
   public enum ContractStatus {
       DRAFT("Черновик"),
       APPROVED("Согласован"),
       REJECTED("Отклонен");
       
       private final String description;
   }
   
   // ❌ НЕПРАВИЛЬНО
   public class ContractStatuses {
       public static final String DRAFT = "draft";
       public static final String APPROVED = "approved";
   }
   ```

3. **Коды ошибок и коды ответов** — ограниченные наборы кодов:
   ```java
   // ✅ ПРАВИЛЬНО
   public enum ErrorCode {
       NOT_FOUND(404, "Ресурс не найден"),
       DUPLICATE(409, "Дубликат");
       
       private final int httpStatus;
       private final String message;
   }
   ```

4. **Флаги-переключатели с большим числом значений** — если значений >2, используй `enum` с одним элементом или `boolean` для тривиальных случаев:
   ```java
   // ✅ >2 значений — enum
   public enum AccessLevel {
       READ, WRITE, ADMIN
   }
   
   // ✅ 2 значения — boolean или `enum` с 1 элементом
   public enum EnabledFlag {
       ENABLED;
   }
   ```

### 2.2 Когда допустимы константы

Используй `static final` константы или `@ConfigurationProperties` только для:

1. **Конфигурационных значений** — префиксы URL, имена заголовков, максимальные размеры:
   ```java
   public class WebApplicationConstants {
       public static final String DEFAULT_URL_PREFIX_API = "/api/v1/";
       public static final String IDEMPOTENCY_ID_HEADER_KEY = "idempotency-key";
   }
   ```

2. **Математических/системных констант** — PI, количество строк, пороги:
   ```java
   public class SystemConstants {
       public static final int MAX_BATCH_SIZE = 1000;
       public static final String DATE_FORMAT_PATTERN = "yyyy-MM-dd";
   }
   ```

### 2.3 Структура `enum`

Используй следующие соглашения для `enum`:

1. **Размещение** — в `model/enums/` для доменно-значимых типов; в `configuration/` или `util/` для системных/конфигурационных.

2. **Lombok-аннотации** — `@Getter @AllArgsConstructor` (или `@Getter @AllArgsConstructor @NoArgsConstructor` если нужен пустой конструктор).

3. **Статические фабрики** — добавляй статические методы для преобразования:
   ```java
   @Getter
   @AllArgsConstructor
   public enum ObjectStatus {
       NOT_RECOGNIZED("Объект, не прошедший первоначальное признание"),
       RECOGNIZED("Объект, прошедший первоначальное признание");
   
       private final String description;
   
       public static ObjectStatus fromDescription(String description) {
           for (ObjectStatus status : values()) {
               if (status.description.equals(description)) {
                   return status;
               }
           }
           throw new IllegalArgumentException("Unknown status: " + description);
       }
   }
   ```

4. **Имена** — во множественном числе, отражающие область значений: `ObjectStatus`, `ContractType`, `ErrorCode`.

5. **JPA-совместимость** — для маппинга в БД используй `@Enumerated(EnumType.STRING)` в сущностях, а строковое представление — через отдельное поле `value`/`code`.

---

## 3. Чек-лист

- [ ] Новые типы/статусы/коды реализованы как `enum`, а не `static final` константы.
- [ ] `enum` размещён в `model/enums/` (доменные типы) или `configuration/`/`util/` (системные).
- [ ] `enum` имеет `@Getter` и `@AllArgsConstructor` (Lombok).
- [ ] Есть статический метод преобразования из строки/кода в `enum` (`fromValue`, `fromCode`).
- [ ] В JPA-сущностях используется `@Enumerated(EnumType.STRING)` для полей с `enum`.
- [ ] Константы (`static final`) оставлены только для конфигурационных значений и заголовков.
- [ ] Имя `enum` — во множественном числе, отражающее область (`ObjectStatus`, не `ObjectType`).

---

## 4. Примеры из кода

### Example 1: Сущствующий `ObjectTypeName` — эталон
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/enums/ObjectTypeName.java`

```java
@Getter
@AllArgsConstructor
public enum ObjectTypeName {
    ASSET_OBJECT("asset", AssetObject.class),
    CAP_OBJECT("cap", CapObject.class),
    RENTAL_OBJECT("rental", RentalObject.class),
    FINAP_OBJECT("finap", FinapObject.class);

    private final String value;
    private final Class<?> aClass;
}
```

✅ Соответствует правилу: `@Getter @AllArgsConstructor`, смысловые поля `value` и `aClass`.

### Example 2: Сущствующий `ObjectStatus` — эталон
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/model/enums/ObjectStatus.java`

```java
@Getter
@AllArgsConstructor
public enum ObjectStatus {
    NOT_RECOGNIZED("Объект, не прошедший первоначальное признание"),
    RECOGNIZED("Объект, прошедший первоначальное признание"),
    DISPOSED_SCHED_W_MOD("Объект выбыл планово, с модификацией");

    private final String description;
}
```

✅ Соответствует правилу: `@Getter @AllArgsConstructor`, описание статуса в `description`.

### Example 3: Конфигурационные константы — допустимо
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/controller/WebApplicationConstants.java`

```java
public class WebApplicationConstants {
    public static final String DEFAULT_URL_PREFIX_API = "/api/v1/";
    public static final String IDEMPOTENCY_ID_HEADER_KEY = "idempotency-key";
    public static final String REQUEST_ID_HEADER_KEY = "X-Request-Id";
}
```

✅ Допустимо: конфигурационные значения и имена заголовков — не бизнес-типы.

### Example 4: Нежелательный паттерн (если бы был в проекте)
```java
// ❌ НЕПРАВИЛЬНО — бизнес-тип как константы
public class ObjectTypes {
    public static final String ASSET = "asset";
    public static final String CAP = "cap";
    public static final String RENTAL = "rental";
    public static final String FINAP = "finap";
}

// ✅ ПРАВИЛЬНО — переводим в enum
public enum ObjectType {
    ASSET("asset"),
    CAP("cap"),
    RENTAL("rental"),
    FINAP("finap");

    private final String value;

    ObjectType(String value) {
        this.value = value;
    }

    public static ObjectType fromValue(String value) {
        for (ObjectType type : values()) {
            if (type.value.equals(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown object type: " + value);
    }
}
```

---

## 5. Обновление

Пересобирать при массовом переходе на `enum` для типов/статусов, изменении соглашений по именам или структуре `enum`, или введении новых доменных типов в `model/enums/`.
