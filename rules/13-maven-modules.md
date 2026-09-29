---
paths:
  - "**/pom.xml"
---

# Соглашение: Maven — корневой pom и модули

**Когда читать:** с момента появления в проекте первого дочернего Maven-модуля (сейчас проект одномодульный — один `pom.xml`, без `<modules>`) — до этого момента правило не к чему применять.

**Что описывает:** роль корневого `pom.xml` как агрегатора, что хранится в нём против pom модуля, единый источник версий зависимостей.

---

## 1. Правило

### 1.1 Корневой pom

- Корневой `pom.xml` — агрегатор, `<packaging>pom</packaging>`, содержит `<modules>` со списком модулей.
- В корневом pom хранится:
  - Maven-настройки и `<build><plugins>`/`<pluginManagement>`, общие для всех модулей.
  - `<properties>` с версиями всех используемых зависимостей (`<lanterna.version>`, `<lombok.version>` и т.п.) и прочими общими свойствами (`java.version` и т.д.).
  - `<dependencyManagement>`, где зависимости перечислены с версией — версия берётся из `<properties>` того же pom (`${lanterna.version}`), не хардкодится напрямую в `<dependencyManagement>`.

### 1.2 pom модуля

- У каждого модуля свой `pom.xml` с `<parent>`, указывающим на корневой pom.
- В `<dependencies>` модуля зависимости объявляются без `<version>` — версия разрешается из `<dependencyManagement>` корневого pom.
- Если модулю нужна новая зависимость, которой ещё нет в корневом pom — сначала добавить версию в `<properties>` и запись в `<dependencyManagement>` корневого pom, и только потом подключить зависимость (без версии) в pom модуля.

### 1.3 Общий принцип

- Версия зависимости не должна быть захардкожена ни в одном pom модуля — единственное место, где фигурирует конкретная версия, это `<properties>` корневого pom.

## 2. Соглашения для агента

- При разбиении проекта на первый дополнительный модуль — сразу перевести корневой `pom.xml` в режим агрегатора (`<packaging>pom</packaging>`, `<modules>`), не оставлять его «наполовину» модулем и «наполовину» агрегатором.
- Добавляя новую зависимость в любой pom модуля — сначала проверить, есть ли она уже в `<dependencyManagement>` корня; если нет, завести её там (версия через `<properties>`), и только затем подключать без версии в модуле.
- Не копировать версию зависимости из внешнего примера/документации прямо в pom модуля — версия живёт только в корне.

## 3. Чек-лист

- [ ] Корневой pom — `<packaging>pom</packaging>`, содержит `<modules>`
- [ ] Версии всех зависимостей — в `<properties>` корневого pom, используются через `${...}` в `<dependencyManagement>`
- [ ] pom модуля ссылается на корневой через `<parent>`
- [ ] В `<dependencies>` модуля нет ни одной зависимости с явно указанной `<version>`
- [ ] Новая зависимость сначала добавлена в `<dependencyManagement>` корня, потом подключена в модуле

## 4. Примеры кода

```xml
<!-- корневой pom.xml -->
<packaging>pom</packaging>

<properties>
    <lanterna.version>3.1.1</lanterna.version>
</properties>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.googlecode.lanterna</groupId>
            <artifactId>lanterna</artifactId>
            <version>${lanterna.version}</version>
        </dependency>
    </dependencies>
</dependencyManagement>

<modules>
    <module>flash-card-core</module>
</modules>
```

```xml
<!-- pom.xml модуля -->
<parent>
    <groupId>com.flsh_crd</groupId>
    <artifactId>flash-card</artifactId>
    <version>${revision}</version>
</parent>

<dependencies>
    <dependency>
        <groupId>com.googlecode.lanterna</groupId>
        <artifactId>lanterna</artifactId>
    </dependency>
</dependencies>
```

## 5. Когда пересматривать

Правило описывает целевое состояние на момент появления первого дочернего модуля — пересматривать его тогда же, если фактическое разбиение (например, по слоям vs по доменам) потребует уточнить структуру модулей, не покрытую здесь.
