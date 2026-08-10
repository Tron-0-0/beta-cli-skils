---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Самопроверка и чек-лист перед сдачей (локально в сервисе) (profitcontr-objects)

**Когда читать:** Перед пушем или мерж-реквестом — финальная самопроверка.

**Что описывает:** Чек-лист перед сдачей: тесты, линтер, секреты, документация.

**Глобальный эталон:** `rules/05_self_correction.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Жёсткий код-контракт: три статических анализатора в корневом pom

Корень `pom.xml` — Maven-агрегатор (`packaging=pom`, модули `objects` + `objects-rest-client`), в `<build><plugins>` которого встроены проверки, привязанные к фазам сборки. Перед сдачей `mvn clean verify` обязан быть «зелёным», иначе commit/merge недопустим:

- **Checkstyle** (`maven-checkstyle-plugin`, конфиг `checkstyle.xml`) — goal `check` в фазе `validate`, `failsOnError=true`. Запрещает star-imports (`AvoidStarImport`), требует Javadoc на типах (`MissingJavadocType` для `INTERFACE_DEF/CLASS_DEF/ENUM_DEF/RECORD_DEF`), запрещает trailing comments (`TrailingComment`), MagicNumber вне аннотаций, `IllegalCatch`/`IllegalThrows`. MapStruct-генерация исключена (`excludeGeneratedSources=true`).
- **PMD** (`pmd.xml`, `failOnViolation=true`, `targetJdk=21`) — `UnusedImport`, `GodClass`/`NcssCount`/`NPathComplexity`, `EmptyCatchBlock`, `AvoidUsingHardCodedIP`, `HardCodedCryptoKey`.
- **SpotBugs** (`spotbugs.xml`, `failOnError=true`) — точечные исключения только `EI_EXPOSE_REP`, `EI_EXPOSE_REP2`, `URF_UNREAD_FIELD`; остальные баги падают сборку.

Точечная проверка вне полного цикла: `mvn checkstyle:check pmd:check spotbugs:check`.

### 1.2 Покрытие тестами и мутационное тестирование

- **JaCoCo** (`jacoco-maven-plugin`, `<prepare-agent>` + `<report>` в фазе `test`) — отчёт покрытия формируется при `mvn test`, он же поставщик покрытия для SonarQube (`sonar.java.coveragePlugin=jacoco`, `sonar.projectKey=CI06228014:CI15418320`).
- **Pitest** — одноактивируемый профиль `mutation-testing` (активация по свойству `mutationTesting`), командой `mvn verify -Pmutation-testing`; исключены `configuration.*` и `WebApplication`. Отдельно от обычного `mvn verify` — в обычный цикл не входит.
- Структура тестов выдерживается по типам (JUnit 5): сервис-слои `*ServiceImplTest` (`src/test/java/.../service/object/impl/ServiceServiceImplTest.java`, `ObjectCreationServiceImplTest.java`), мапперы `*MapperTest` (`.../configuration/mapper/response/ServiceToServiceResponseMapperTest.java`), контроллеры `*ControllerTest` (`.../controller/ObjectControllerTest.java`) и смоук `WebApplicationTest.java`.

### 1.3 Актуализация документации через `specification/` и Liquibase

- В репо присутствует каталог `specification/` (абсолютная спецификация): изменения, затрагивающие контракт/архитектуру, фиксируются там, а не только в коде.
- Миграции БД лежат в `objects/src/main/resources/db/changelog/` (master `0001_changelog.xml` → `include` версионного `v1.0.0/changelog.xml`, разделы по типам объектов); `application.properties` включает `spring.liquibase.change-log=classpath:/db/changelog/0001_changelog.xml`. Новые/изменённые сущности обязаны сопровождаться соответствующим `--changeset` с `--rollback`.

<!-- source: auto -->
## 2. Соглашения для агента

1. Перед пушем/мержем всегда запускай из корня reactor (`C:\Work\profitcontr-objects\pom.xml`) команду `mvn clean verify` — она по умолчанию прогоняет checkstyle (фаза `validate`), PMD и SpotBugs, компиляцию, все тесты и JaCoCo-отчёт; зелёный `verify` — обязательное условие сдачи. Если замечания анализаторов только точечны — `mvn checkstyle:check pmd:check spotbugs:check`.
2. Держи полный цикл сборки в порядке по фазам: `validate` → `test` → `verify`. При каждой итерации изменения убеждайся в прохождении `mvn test` (JaCoCo `report` привязан именно к фазе `test`); тяжёлый мутационный прогон выполняй отдельным профилем `mvn verify -Pmutation-testing`, а не в обычном `verify`.
3. Перед коммитом сверяй diff на антипаттерны по соседним локальным правилам: **не клади секреты/пароли в репозиторий** — в репо уже есть `accounting.env` с реальными credentials БД и keystore; такие файлы должны быть в `.gitignore` и не попадать в коммит/логи (маскировка полей `password`,`secret`,`creditCard` и заголовков `Authorization`, `Set-Cookie` задана в `application.yml` → `sbererp.logging.masked-*`); для DTO/entity не злоупотребляй `@Data` без необходимости (см. `01_coding`, `07_api_contract`) и проверяй соответствие API-контракта/обязательных заголовков (`X-Request-Id`, `X-Correlation-Id`, `X-SberPDI`) — см. `07_api_contract`; при изменениях сущностей/миграций не оторвай от Liquibase-скриптов и `application.yml` параметров — см. `08_database`.

## 3. Чек-лист

- [ ] Перед пушем выполнен `mvn clean verify` локально (`validate` → `test` → `verify`)
- [ ] Тесты и JaCoCo-отчёт проходят на итерации — `mvn test`; изменённый код покрыт тестами (`*ServiceImplTest`, `*MapperTest`, `*ControllerTest`)
- [ ] При необходимости изменения покрытия выполнено `mvn verify -Pmutation-testing` (профиль `mutation-testing`)
- [ ] Соблюдены checkstyle (`checkstyle.xml`, фаза `validate`: без star-imports, Javadoc типов, trailing comments), PMD (`pmd.xml`, `failOnViolation=true`), SpotBugs (`spotbugs.xml`, `failOnError=true`)
- [ ] Нет секретов/паролей в коммите и в логах (`accounting.env` в `.gitignore`; `sbererp.logging.masked-fields/masked-headers` не отключены)
- [ ] Актуализирована документация/спецификация (`specification/`) и Liquibase-миграции (`db/changelog/`) при изменении контракта, сущностей, схемы БД
- [ ] API-контракт не устарел: обязательные заголовки, OpenAPI/Swagger (`ObjectControllerDocs`, springdoc) соответствуют фактическому контроллеру
- [ ] Нет закомментированного кода или TODO без номера задачи; `Javadoc` на публичных API-методах актуален

---

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

### Example 2: checkstyle.xml — запрет star-imports и требование Javadoc типов
**Путь:** `checkstyle.xml`

```xml
<module name="AvoidStarImport"/>
...
<module name="MissingJavadocType">
    <property name="tokens" value="INTERFACE_DEF, CLASS_DEF, ENUM_DEF, RECORD_DEF"/>
</module>
```

Перед сдачей убедись, что новые типы имеют Javadoc (checkstyle), а импорты — явные, без `*`.