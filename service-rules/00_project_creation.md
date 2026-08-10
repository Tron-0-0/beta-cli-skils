---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Структура проекта и инициализация (profitcontr-objects)

**Когда читать:** При начале работы с сервисом, онбординге, или создании нового модуля.

**Что описывает:** Структура каталогов, стек технологий, Maven-конфигурация, точки входа.

**Глобальный эталон:** `rules/00_project_creation.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Многомодульный Maven-проект (objects + objects-rest-client)

Корневой `pom.xml` — агрегатор `packaging=pom`, `groupId=ru.sbrf.sbererp.profitcontr`, `artifactId=profitcontr`, `version=1.0.2-SNAPSHOT`, объявляет два модуля:
`C:\Work\profitcontr-objects\pom.xml`
```xml
<modules>
    <module>objects</module>
    <module>objects-rest-client</module>
</modules>
```
Родительский BOM — `ru.sbrf.sbererp.common:sbererp-bom:2026.05.0` (см. `pom.xml`).

### 1.2 objects-rest-client — Feign-библиотека (client-модуль) с AutoConfiguration

Отдельный Maven-модуль, подключается как зависимость в `objects/pom.xml`:
`C:\Work\profitcontr-objects\objects\pom.xml`
```xml
<dependency>
    <groupId>ru.sbrf.sbererp.profitcontr</groupId>
    <artifactId>objects-rest-client</artifactId>
    <version>${object-rest-client.version}</version>
</dependency>
```
Точка входа стартера — автоконфигурация `ObjectsClientAutoConfiguration` с `@AutoConfiguration` и `@EnableFeignClients(basePackageClasses = ObjectsClient.class)`:
`C:\Work\profitcontr-objects\objects-rest-client\src\main\java\ru\sbrf\sbererp\profitcontr\objects\client\configuration\ObjectsClientAutoConfiguration.java`

### 1.3 objects — CAP-микросервис (Spring Boot Web + JPA + Liquibase)

Модуль `objects` (`C:\Work\profitcontr-objects\objects\pom.xml`) содержит полноценный микросервис: `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-liquibase`, `springdoc-openapi`, `lombok`, `mapstruct`, OpenTelemetry/Micrometer, `ru.sbrf.sbererp:logging-starter`. Точка входа — `WebApplication` с `@SpringBootApplication`:
`C:\Work\profitcontr-objects\objects\src\main\java\ru\sbrf\sbererp\profitcontr\objects\WebApplication.java`

### 1.4 Корневая структура: статический анализ и конфигурации

В корне репозитория (`C:\Work\profitcontr-objects\`) лежат конфигурации код-контракта и инструменты: `checkstyle.xml`, `pmd.xml`, `spotbugs.xml`, `lombok.config`, корневой `pom.xml`. Плагины checkstyle/PMD/SpotBugs и JaCoCo подключены в корневом `pom.xml` (validate/test фазы). Также есть каталог `specification/` (абсолютная спецификация проекта).

### 1.5 Stack и build (из `pom.xml`)

- Java 21 (`objects/pom.xml` → `<java.version>21</java.version>`)
- Spring Boot: версии управляются BOM `sbererp-bom:2026.05.0`; собственные версии вынесены в `<properties>` корневого `pom.xml`
- SonarQube: `https://sonar.delta.sbrf.ru/sonar`, projectKey `CI06228014:CI15418320` (root `pom.xml`)

---

<!-- source: auto -->
## 2. Соглашения для агента

- Корневой пакет — строго `ru.sbrf.sbererp.profitcontr.objects` для основного модуля и `ru.sbrf.sbererp.profitcontr.objects.client` для client-модуля; новые пакеты/классы размещай внутри этих корней (`WebApplication.java`, `ObjectsClientAutoConfiguration.java`).
- Модуль `objects-rest-client` держи лёгким: только модели + Feign (`@AutoConfiguration` + `@EnableFeignClients`), не добавляй в него `spring-boot-starter-web` и тяжёлые зависимости микросервиса — они присутствуют только в `objects/pom.xml` (JPA, Liquibase, OTLP, logstash и т.д.).
- Версии зависимостей выноси в `<properties>` корневого/модульного `pom.xml`, не захардкоживай их в `<dependency>` (`objects/pom.xml` использует `${micrometer-registry-otlp.version}`, `${sbererp-starter-logging.version}` и т.д.) — и не дублируй версии, которые уже есть в `sbererp-bom`.
- Соблюдай строгий код-контракт: Javadoc для типов, без star-imports, запрещены trailing comments (plugin checkstyle в корневом `pom.xml` с `configLocation=checkstyle.xml`, `failsOnError=true`, exclude для MapStruct в `excludeGeneratedSources`).
- Используй Java 21 в новых модулях/классах, как задано в `objects/pom.xml`.

---

<!-- source: auto -->
## 3. Чек-лист

- [ ] Корневой пакет совпадает с `groupId` из `pom.xml` (`ru.sbrf.sbererp.profitcontr.objects[.client]`)
- [ ] Версия Java в `pom.xml` соответствует `maven.compiler.source/target` (Java 21)
- [ ] Parent BOM `ru.sbrf.sbererp.common:sbererp-bom:2026.05.0` указан корректно и доступен
- [ ] Версии зависимостей вынесены в `<properties>` и не дублируют версии из `sbererp-bom`
- [ ] Файл `README.md` описывает назначение сервиса и команды запуска
- [ ] Структура `src/main/java` следует слоям проекта (controller, service, repository, configuration, model)
- [ ] Сервис-модуль `objects` подключён к `objects-rest-client` как зависимость `${object-rest-client.version}`

---

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: ObjectsClientAutoConfiguration.java
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/configuration/ObjectsClientAutoConfiguration.java`

```java
@AutoConfiguration
@EnableFeignClients(
        basePackageClasses = ObjectsClient.class
)
public class ObjectsClientAutoConfiguration {
}
```

### Example 2: OpenTelemetryConfig.java (метрики через MeterFilter)
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java`

```java
@Slf4j
@ConditionalOnBooleanProperty("management.otlp.metrics.export.enabled")
@Configuration
@RequiredArgsConstructor
public class OpenTelemetryConfig {
    @Bean
    public MeterFilter nameConfigFilter() { /* ... */ }
}
```

<!-- source: auto -->
## 5. Исключения и оговорки

Соглашение о лёгкости client-модуля не применяется к `objects` — это CAP-микросервис, и ему разрешены JPA, Liquibase, springdoc, OTLP и т.п. Статус расхождения с глобальным регламентом `rules/00_project_creation.md` — см. `C:\Work\profitcontr-objects\.gigacode\service-rules\parts\gap_notes.jsonl` (rule_id `00`).