---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Сборка и компиляция (profitcontr-objects)

**Когда читать:** При проблемах сборки, настройке CI, или добавлении зависимостей.

**Что описывает:** Maven-команды, профили сборки, CI/CD конфигурация, JVM-аргументы.

**Глобальный эталон:** `rules/04_compilation.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Multi-module reactor: корень pom — агрегатор, два модуля

Корень `pom.xml` — агрегатор (`<packaging>pom</packaging>`, `groupId=ru.sbrf.sbererp.profitcontr`, `artifactId=profitcontr`, `version=1.0.2-SNAPSHOT`) с модулями `objects` и `objects-rest-client`. Родитель — `sbererp-bom:2026.05.0` (`ru.sbrf.sbererp.common`), который управляет версиями Spring Boot / Spring Cloud / прочих стартеров; в корневом `<properties>` заданы только собственные версии (`pitest-maven.version=1.17.1`, `spotbugs-maven-plugin.version=4.7.3.6`, `micrometer-registry-otlp.version=1.16.6`, `spring-boot-starter-opentelemetry.version=4.0.6`, `sbererp-starter-logging.version=1.23.0-sb4.441` и др.).

`objects/pom.xml` задаёт `<java.version>21</java.version>` и содержит `spring-boot-maven-plugin` (исполнение `repackage` собирает исполняемый jar приложения). `objects-rest-client/pom.xml` — библиотека: тот же плагин отключён для repackage через `<spring-boot.repackage.skip>true</spring-boot.repackage.skip>`.

### 1.2 Фазы статического анализа из корневого pom (в `mvn verify` / `mvn test`)

В `<build><plugins>` корневого `pom.xml` настроены проверки, привязанные к фазам Maven:

| Плагин | Правила | Фаза / привязка | Локальные настройки |
|---|---|---|---|
| `maven-checkstyle-plugin` | `checkstyle.xml` | `validate` (goal `check`) | `failsOnError=true`, `consoleOutput=true`, `excludeGeneratedSources=true` (MapStruct) |
| `maven-pmd-plugin` | `pmd.xml` | default (goal `check`) | `failOnViolation=true`, `printFailingErrors=true`, `targetJdk=${java.version}` |
| `spotbugs-maven-plugin` | `spotbugs.xml` | default (goal `check`) | `excludeFilterFile=spotbugs.xml`, `failOnError=true` |

Только в модуле `objects` подключён `spring-boot-maven-plugin` (без версии — берёт из BOM). JaCoCo настроен в корневом `pom.xml` (`jacoco-maven-plugin`, `prepare-agent` + `report` в фазе `test`) и включён как поставщик покрытия SonarQube (`sonar.java.coveragePlugin=jacoco`, `sonar.projectKey=CI06228014:CI15418320`).

### 1.3 Профиль `mutation-testing` (Pitest) в корневом pom

Одноактивируемый профиль `mutation-testing` (активация по свойству `<mutationTesting>`) подключает `pitest-maven` с `pitest-junit5-plugin` (goal `mutationCoverage` в фазе `verify`), формат отчёта `HTML` + `XML`, мутаторы `DEFAULTS`. Исключены классы `ru.sbrf.sbererp.profitcontr.objects.configuration.*` и `WebApplication`. Запуск — `mvn verify -Pmutation-testing`.

### 1.4 Локальный запуск и переменные окружения

README (`README.md`) пуст — команд в нём нет (источник фраз не подтверждён в репо). Переменные окружения для запуска/компиляции документально зафиксированы в дереве проекта (см. `objects/src/main/resources/application.properties` и `accounting.env`): `DB_HOST/DB_PORT/DB_NAME/DB_USERNAME/DB_PASSWORD/DB_DRIVER/DB_PARAM/DB_SCHEMA`, `OPENTELEMETRY_EXPORT_URL`, опциональные `APPLICATION_PORT=8080`, `LIQUIBASE_ENABLED=false`, `SWAGGER_UI_ENABLED=false`, `API_DOCS_ENABLED=false`.

### 1.5 CI/CD — НЕ ОПРЕДЕЛЕНО

В репозитории нет `Jenkinsfile`, `.github/workflows/*.yml` или каталога `ci/` (scan `stack.global_rules` фиксирует только `core-gigacode-skills`, CI-файлы не найдены). Конвейеры сборки/деплоя не подтверждены — не придумывать CI-практики и не ссылаться на несуществующие `Jenkinsfile`. (SonarQube-скан задан в `pom.xml`: `sonar.host.url=https://sonar.delta.sbrf.ru/sonar`.)

<!-- source: auto -->
## 2. Соглашения для агента

1. После правок в `objects/` или `objects-rest-client/` собирай весь reactor командой `mvn clean verify` из корня (`C:\Work\profitcontr-objects\pom.xml`) — по умолчанию она прогоняет checkstyle (фаза `validate`), PMD и SpotBugs, компиляцию, все тесты и JaCoCo `/test` coverage; commit/merge без зелёного `verify` не делай.
2. До commit'а исправляй замечания трёх статических анализаторов из корневого `pom.xml` — локализуй правила в `checkstyle.xml`, `pmd.xml`, `spotbugs.xml` и прогоняй фазы: checkstyle в `validate`, PMD и SpotBugs при сборке; при точечной проверке — `mvn checkstyle:check pmd:check spotbugs:check`.
3. Версии зависимостей держи в корневых `<properties>` корневого `pom.xml` (например `<pitest-maven.version>`), а версии Spring/Spring Cloud — не хардкодь: они берутся из `sbererp-bom:2026.05.0`. Новую зависимость в `objects/pom.xml` добавляй без `<version>`, если версией управляет BOM.
4. Мутационное тестирование выполняй отдельным профилем `mvn verify -Pmutation-testing` (активация по свойству `mutationTesting`); не гоняй его в обычном `mvn verify`.
5. Исполняемый артефакт собирает только модуль `objects` (`spring-boot-maven-plugin`); `objects-rest-client` — библиотека: проверяй, что у неё остаётся `<spring-boot.repackage.skip>true</spring-boot.repackage.skip>` и она не переупаковывается в boot-jar. SDK при сборке — Java 21 (`<java.version>21</java.version>`).

<!-- source: auto -->
## 3. Чек-лист

- [ ] Проект собирается командой `mvn clean verify` из корня без ошибок (checkstyle `validate` + PMD + SpotBugs + тесты)
- [ ] Тесты и JaCoCo-отчёт проходят при стандартной итерации — `mvn test` (JaCoCo `report` привязан к фазе `test`)
- [ ] Замечания `checkstyle.xml` (фаза `validate`, star-imports, Javadoc типов, trailing comments) устранены
- [ ] Замечания PMD (`pmd.xml`, `failOnViolation=true`) и SpotBugs (`spotbugs.xml`, `failOnError=true`) устранены
- [ ] Новая зависимость имеет version в корневых `<properties>` только если её нет в `sbererp-bom:2026.05.0`; иначе `<version>` не указывается
- [ ] Мутационное покрытие проверено при необходимости командой `mvn verify -Pmutation-testing` (профиль `mutation-testing`)
- [ ] `objects-rest-client` остаётся библиотекой: `<spring-boot.repackage.skip>true</spring-boot.repackage.skip>` на месте, repackage выполняется только для `objects`
- [ ] SDКА при сборке — Java 21 (`<java.version>21</java.version>`, `targetJdk=${java.version}` для PMD)
- [ ] Переменные окружения БД/OTLP корректны (см. `accounting.env`, `application.properties`): `DB_SCHEMA=${DB_SCHEMA}`, `OPENTELEMETRY_EXPORT_URL` и др.
- [ ] CI-конфигурация (`Jenkinsfile`) актуальна — в репо её нет, любые заявления о CI помечать как `НЕ ОПРЕДЕЛЕНО` до появления файла
- [ ] Профиль `mutation-testing` из `pom.xml` задокументирован (активация по свойству `mutationTesting`)

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: ObjectsClientAutoConfiguration.java
**Путь:** `objects-rest-client/src/main/java/ru/sbrf/sbererp/profitcontr/objects/client/configuration/ObjectsClientAutoConfiguration.java`

```java
package ru.sbrf.sbererp.profitcontr.objects.client.configuration;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.cloud.openfeign.EnableFeignClients;
import ru.sbrf.sbererp.profitcontr.objects.client.ObjectsClient;

/**
 * Автоконфигурация для стартера клиента.
 */
@AutoConfiguration
@EnableFeignClients(
        basePackageClasses = ObjectsClient.class
)
public class ObjectsClientAutoConfiguration {
}
```

### Example 2: spring-boot-maven-plugin в objects/pom.xml
**Путь:** `objects/pom.xml`

```xml
<build>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
        </plugin>
    </plugins>
</build>
```

`objects-rest-client/pom.xml` отключает переупаковку: `<spring-boot.repackage.skip>true</spring-boot.repackage.skip>`.

### Example 3: Профиль mutation-testing в корневом pom.xml
**Путь:** `pom.xml`

```xml
<profile>
    <id>mutation-testing</id>
    <activation>
        <property><name>mutationTesting</name></property>
    </activation>
    ...
    <plugin>
        <groupId>org.pitest</groupId>
        <artifactId>pitest-maven</artifactId>
        <version>${pitest-maven.version}</version>
        ...
    </plugin>
</profile>
```

---

<!-- source: auto -->
## 5. Исключения и оговорки

- Расписание/пайплайны CI в репозитории отсутствуют (нет `Jenkinsfile`, `.github/workflows`, `ci/`) — тема CI/Pipeline остаётся `НЕ ОПРЕДЕЛЕНО`: любые упоминания Jenkins-джоб или сборок в CI должны быть удалены из текста соглашения, пока файлы не появятся.
- `README.md` пуст — команды сборки в эталоне/гайде не имеют локальной привязки в README; фактически они подтверждены конфигурацией корневого `pom.xml` и `objects/pom.xml`.
- Конвенция «версии остальных библиотек в `<properties>`» относится к корневому `pom.xml`; в модуль-библиотеке `objects-rest-client` свои версии наследуются из корня/BOM.

<!-- source: auto -->
## 6. Обновление

Пересобирать при смене версии Java (сейчас 21), добавлении/изменении профилей сборки в корневом `pom.xml`, изменении BOM-версии `sbererp-bom`, а также при появлении в репозитории реальных CI-файлов (`Jenkinsfile`, `.github/workflows`), которые снимут статус `НЕ ОПРЕДЕЛЕНО` у §1.5.