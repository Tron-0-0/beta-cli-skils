---
apply: always
mode: all
---

# Соглашение: Сборка и статический анализ

**Когда читать:** при проблемах сборки, настройке CI, добавлении зависимостей.

**Что описывает:** команды сборки, статический анализ, проверку зависимостей на уязвимости, покрытие тестами, CI-конвейер.

---

## 1. Правило

- **Единая команда локальной сборки**, эквивалентная CI: `./mvnw clean verify` (Maven) или `./gradlew check` (Gradle) — прогоняет компиляцию, статический анализ, тесты. Команда запускается через закоммиченный в репозиторий wrapper (`mvnw`/`gradlew`), а не через локально установленный Maven/Gradle — иначе версия инструмента у разработчика и в CI может разойтись, и «зелёная локально» сборка не гарантирует «зелёную» в CI. Мерж без зелёной сборки — недопустим.
- **Статический анализ** — минимум связка Checkstyle (стиль) + PMD или SpotBugs (баги/анти-паттерны); настройки — в конфиг-файлах репозитория, а не по умолчанию инструмента. Нарушения ломают сборку (`failOnViolation=true`/`failOnError=true`), а не просто логируются. Лимиты длины/сложности из `16_refactoring.md` (метод ≤30 строк, цикломатическая сложность ≤5, вложенность ≤3, параметров ≤5) — не только договорённость на ревью, а конкретные правила PMD (`ExcessiveMethodLength`, `CyclomaticComplexity`, `ExcessiveParameterList`) в конфиге статического анализа, ломающие сборку при нарушении.
- **Проверка зависимостей на уязвимости** — отдельный шаг сборки (OWASP Dependency-Check или аналог), сверяющий транзитивные зависимости с базой CVE; порог (например, CVSS ≥ 7) ломает сборку. Отдельный от Checkstyle/PMD/SpotBugs шаг — те проверяют качество своего кода, этот проверяет уязвимости в чужом.
- **Покрытие тестами** — JaCoCo, привязан к фазе `test`; порог покрытия (если задан) — по изменённым строкам (diff coverage) предпочтительнее общего порога по всему проекту — иначе легаси-код с низким покрытием блокирует любой PR. JaCoCo сам по себе diff coverage не считает — только общий/по-файловый отчёт; расчёт по изменённым строкам нужен через отдельный механизм: Quality Gate на New Code в SonarQube (если используется) или внешний скрипт (например, `diff-cover`), парсящий `jacoco.xml` вместе с `git diff`.
- **Версии зависимостей** — управляются BOM/родителем там, где возможно; версия задаётся в `<dependency>` только если её нет в BOM.
- **Мутационное тестирование** (Pitest) — опциональный тяжёлый профиль, отдельная команда, не часть обычного `verify` (иначе сборка становится слишком медленной для повседневной разработки).
- **CI-конвейер** воспроизводит те же команды, что разработчик гоняет локально — не должно быть шагов, существующих только в CI и непроверяемых локально.

## 2. Соглашения для агента

1. После правок собирай проект локальной командой через wrapper (`./mvnw`/`./gradlew`), эквивалентной CI, прежде чем предлагать изменение как готовое.
2. Исправляй замечания статического анализа до коммита, а не подавляй их аннотациями `@SuppressWarnings`/`NOPMD` без причины в комментарии; превышение лимитов длины/сложности из `16_refactoring.md` — рефактори метод/класс, а не поднимай порог в конфиге анализатора.
3. Новую зависимость добавляй без явной версии, если ей управляет родительский BOM; если версии в BOM нет — версию выносить в `<properties>`.
4. Новую зависимость с известной уязвимостью (по отчёту dependency-check) не добавляй без явного согласования — ищи версию без известного CVE или обоснуй исключение (suppression) со ссылкой на причину.
5. Не запускай мутационное тестирование в обычном цикле проверки — это отдельный, осознанно вызываемый шаг.
6. Генерируемый код (MapStruct, Lombok) исключай из проверки статического анализа и покрытия — не тратить бюджет ревью на сгенерированные файлы.

## 3. Чек-лист

- [ ] Проект собирается локальной командой через wrapper (`./mvnw`/`./gradlew`), эквивалентной CI, без ошибок
- [ ] Статический анализ проходит без подавленных без причины предупреждений
- [ ] Лимиты длины/сложности (`16_refactoring.md`) включены в конфиг статического анализа, а не только на словах
- [ ] Проверка зависимостей на уязвимости (dependency-check или аналог) проходит без новых CVE выше порога
- [ ] Тесты и отчёт покрытия проходят
- [ ] Новая зависимость не дублирует версию, управляемую BOM
- [ ] CI выполняет ровно то же, что можно запустить локально
- [ ] Мутационное тестирование (если используется) — в отдельном профиле, не в стандартном `verify`

## 4. Пример конфигурации (Maven)

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <configuration>
        <configLocation>checkstyle.xml</configLocation>
        <failsOnError>true</failsOnError>
        <excludeGeneratedSources>true</excludeGeneratedSources>
    </configuration>
    <executions>
        <execution><phase>validate</phase><goals><goal>check</goal></goals></execution>
    </executions>
</plugin>
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <executions>
        <execution><goals><goal>prepare-agent</goal></goals></execution>
        <execution><id>report</id><phase>test</phase><goals><goal>report</goal></goals></execution>
    </executions>
</plugin>
<plugin>
    <!-- pmd.xml включает ExcessiveMethodLength (30), CyclomaticComplexity (5),
         ExcessiveParameterList (5) — те же лимиты, что в 16_refactoring.md -->
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-pmd-plugin</artifactId>
    <configuration>
        <rulesets><ruleset>pmd.xml</ruleset></rulesets>
        <failOnViolation>true</failOnViolation>
    </configuration>
    <executions>
        <execution><phase>verify</phase><goals><goal>check</goal></goals></execution>
    </executions>
</plugin>
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
    </configuration>
    <executions>
        <execution><phase>verify</phase><goals><goal>check</goal></goals></execution>
    </executions>
</plugin>
```

Мутационное тестирование — отдельным профилем:

```bash
./mvnw verify -Pmutation-testing
```

## 5. Когда пересматривать

При смене версии Java, изменении набора статических анализаторов, введении/изменении порога покрытия или CVSS-порога сканирования зависимостей, либо появлении нового CI-провайдера.
