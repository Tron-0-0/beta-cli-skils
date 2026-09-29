---
paths:
  - "src/main/java/**/*.java"
---

# Соглашение: Lombok

**Когда читать:** при создании новой JPA-сущности, сервиса, DTO или Kafka-события.

**Что описывает:** какой набор аннотаций (Lombok и — для DTO/событий — Swagger `@Schema`) вешать на каждый тип класса проекта.

---

## 1. Правило

- JPA-сущности (`model/entity`): `@Getter @Setter @NoArgsConstructor @AllArgsConstructor`.
  - `@Data` и `@EqualsAndHashCode` на сущностях запрещены (с JPA-прокси и лениво загружаемыми коллекциями они ломают `equals`/`hashCode`) — формализовано в `checkstyle.xml` (`MatchXpath`, id `EntityNoData`), здесь не дублируется.
- Классы `service.impl`: `@Service` + `@RequiredArgsConstructor` + `@Slf4j`.
- DTO (`model/dto`, запросы/ответы контроллеров, Kafka-события в `model/event`): `@Data @Builder @NoArgsConstructor @AllArgsConstructor @ToString`. `@Builder` требует `@AllArgsConstructor` для генерации совместимого конструктора, `@NoArgsConstructor` нужен отдельно — для фреймворков сериализации (Jackson и т.п.), которым нужен пустой конструктор.
- Описание в `@Schema(description = "...")` (`io.swagger.v3.oas.annotations.media.Schema`, зависимость `io.swagger.core.v3:swagger-annotations-jakarta`) на полях DTO/события — на русском. Само наличие `@Schema` на каждом нестатическом поле классов из `model/dto`/`model/event` формализовано в `checkstyle.xml` (`MatchXpath`, id `DtoSchema`) — независимо от статуса `09-controllers.md`.
- Не писать вручную то, что можно получить аннотацией (геттеры/сеттеры/конструкторы), но не злоупотреблять — не вешать Lombok-аннотации, которые не нужны конкретному классу.

## 2. Соглашения для агента

- Перед добавлением аннотации на новый класс — определить его роль (сущность / `service.impl` / DTO) по таблице выше, не копировать набор аннотаций с класса другой роли.
- Если классу не нужно логирование — не добавлять `@Slf4j` только потому, что он есть у соседних `service.impl`.
- Добавляя новое поле в DTO/событие — сразу писать осмысленное описание в `@Schema`, а не заглушку ради прохождения сборки.

## 3. Чек-лист

- [ ] Сущность — `@Getter @Setter @NoArgsConstructor @AllArgsConstructor`
- [ ] `service.impl` — `@Service @RequiredArgsConstructor @Slf4j`
- [ ] DTO/событие — `@Data @Builder @NoArgsConstructor @AllArgsConstructor @ToString`
- [ ] Описание в `@Schema` полей DTO/события — на русском и по смыслу поля
- [ ] На классе нет лишней Lombok-аннотации, которая ему не нужна

## 4. Примеры кода

```java
@Setter
@Getter
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "front_word")
public class FrontWord {

    @Id
    @Column(name = "front_word_id")
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID frontWordId;

    @Column(name = "word")
    private String word;
}
```

```java
@Slf4j
@RequiredArgsConstructor
@Service
public class FrontWordServiceImpl implements FrontWordService {
    private final FrontWordRepository frontWordRepository;
}
```

```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@ToString
public class PasswordChangeRequest {

    @Schema(description = "Текущий пароль студента")
    private String oldPassword;

    @Schema(description = "Новый пароль студента")
    private String newPassword;

    @Schema(description = "Повтор нового пароля для проверки совпадения")
    private String repeatedPassword;
}
```

## 5. Когда пересматривать

При появлении в проекте нового типа класса, для которого таблица выше не даёт однозначного ответа (например, отдельный неизменяемый value-object вне JPA/DTO), или при переходе части DTO на `record` — тогда для затронутого типа классов набор аннотаций фиксируется отдельной строкой правила.
