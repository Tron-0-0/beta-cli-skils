---
paths:
  - "src/**/*.java"
---

# Соглашение: Именование

**Когда читать:** при создании нового класса, поля, пакета, PK/FK-колонки сущности.

**Что описывает:** регистр идентификаторов, именование пакетов, именование PK/FK-полей в Java-коде и в БД.

---

## 1. Правило

- Регистр идентификаторов (классы/интерфейсы — `PascalCase`, поля/методы/переменные — `camelCase`, константы — `UPPER_SNAKE_CASE`) и регистр/разделитель пакетов (`lowercase`, слова слитно, без `_`) — формализованы в `checkstyle.xml` (модули `TypeName`, `MethodName`, `MemberName`, `ParameterName`, `LocalVariableName`, `ConstantName`, `PackageName`), сборка падает при нарушении. Здесь как справочник не дублируется.
- Идентификаторы (классы/методы/переменные) — только на английском, без сокращений ради экономии символов.
- Интерфейсы — без префикса `I`: формализовано в `checkstyle.xml` (`TypeName`, id `InterfaceNoIPrefix`).
- PK-поля сущностей: `<таблица>_id` в БД (snake_case), `<таблица>Id` в Java-коде (`frontWordId`). Тип `UUID` и генерация через `GenerationType.UUID` формализованы в `checkstyle.xml` (`MatchXpath`, id `PkUuid`).
- FK-поля сущностей — объектная ссылка на связанную сущность через `@ManyToOne`/`@OneToOne` + `@JoinColumn(name = "<table>_id")`, имя поля — по имени сущности в camelCase (`private Student student`, `private BackWord backWord`). В БД (в `@JoinColumn`) колонка называется `<table>_id`. Запрет суффикса `Id` у поля с `@JoinColumn` формализован в `checkstyle.xml` (`MatchXpath`, id `FkNoIdSuffix`).

## 2. Соглашения для агента

- Перед именованием нового поля/класса — свериться с этим правилом, а не по аналогии с именованием в других стеках/проектах (например, не называть FK-поле по колонке БД).
- Название пакета для новой сущности/фичи — только `lowercase`, слова слитно без разделителя (`_` запрещён `checkstyle.xml`), без camelCase-пакетов даже для составных доменных имён.
- Имя FK-поля сущности — всегда имя связанной сущности (`student`, `backWord`), не имя колонки БД (`studentId`) — колонка и Java-поле здесь называются по разным правилам сознательно (см. §1).

## 3. Чек-лист

- [ ] Идентификаторы — на английском, без сокращений
- [ ] PK-поле сущности — `<table>_id` в БД, `<table>Id` в Java
- [ ] FK-поле сущности — имя связанной сущности в Java (`student`, `backWord`), `<referenced_table>_id` в `@JoinColumn`

## 4. Примеры кода

```java
@Id
@Column(name = "front_word_id")
@GeneratedValue(strategy = GenerationType.UUID)
private UUID frontWordId;

@ManyToOne
@JoinColumn(name = "student_id")
private Student student;

@OneToOne
@JoinColumn(name = "back_word_id")
private BackWord backWord;
```

## 5. Когда пересматривать

При смене стратегии генерации PK (например, отказ от `UUID` в пользу `Long`/`BIGSERIAL` для конкретной таблицы) — тогда исключение фиксируется здесь явно, а не остаётся молчаливым расхождением с этим правилом.

## 6. Известные отклонения

- **`Student.mainCollection`** (`model/entity/Student.java`) и constraint `fk_main_collection` (`db/changelog/v1.0.0/student/06-09-2026_01_add-field-main-collection.sql`) — сознательное отклонение от §1 (FK-поле = имя связанной сущности, `fk_<referenced_table>` для constraint). Поле указывает не на отношение владения, а на «текущую основную коллекцию» студента — отдельный по смыслу указатель, а не просто ссылку на связанную сущность `Collection` (см. `system-intent.md` задачи «создание коллекции»), поэтому имя `mainCollection`/`fk_main_collection` точнее отражает роль поля, чем буквальное `collection`/`fk_collection`.
