---
apply: always
mode: all
---

# Соглашение: Структура проекта и инициализация

**Когда читать:** при создании нового сервиса/модуля, онбординге в существующий репозиторий.

**Что описывает:** структуру каталогов, сборочный инструмент, версию Java, разбиение на модули, точки входа.

---

## 1. Правило

- **Сборка** — Maven (`pom.xml`) или Gradle (`build.gradle[.kts]`); выбор фиксируется один раз для организации/команды и не смешивается в рамках одного репозитория.
- **Java** — актуальная LTS-версия (21, ранее 17); версия задаётся явно (`<java.version>`/`sourceCompatibility`), а не выводится из окружения сборки.
- **Родительский BOM** — используйте `spring-boot-starter-parent` или корпоративный BOM, который управляет версиями Spring/сторонних библиотек; версии сторонних зависимостей не хардкодятся там, где ими управляет BOM.
- **groupId/artifactId** — по обратному доменному имени организации + имени сервиса (`com.example.orders:order-service`); корневой Java-пакет совпадает с `groupId.artifactId` в camelCase (`com.example.orders`).
- **Многомодульность** — оправдана, когда есть переиспользуемый клиент/контракт (например, Feign/gRPC-клиент, публикуемый в другие сервисы) или чёткая граница домена (отдельный bounded-context-модуль внутри той же монорепы). Модуль-клиент держат лёгким: только модели + клиентская автоконфигурация, без `spring-boot-starter-web`/JPA/Liquibase — эти зависимости остаются в модуле сервиса. Доменный модуль (в отличие от клиента) — полноценный сервисный модуль со своим `pom.xml`/пакетом, а не библиотека; повторяет структуру исполняемого модуля из примера ниже.
- **Границы репозитория** — один репозиторий соответствует одному деплоюмому сервису; отдельный домен/bounded-context оформляется как ещё один модуль в этой же монорепе (см. выше), а не выносится в новый репозиторий без явного архитектурного решения.
- **Точка входа** — один класс `@SpringBootApplication` на исполняемый модуль (`OrderServiceApplication`), в модуле-библиотеке точки входа нет — есть `@AutoConfiguration`.

## 2. Соглашения для агента

- Новые пакеты/классы размещай внутри корневого пакета сервиса (`com.example.orders.*`), не создавай параллельных корней.
- Версии зависимостей выноси в `<properties>`/`libs.versions.toml`, не хардкодь их в местах объявления зависимости; не дублируй версии, которыми уже управляет родительский BOM.
- Если заводишь модуль-клиент (`order-client`), не добавляй в него зависимости, специфичные для веб-приложения (JPA, Liquibase, Actuator) — это ломает его переиспользуемость как библиотеки в других сервисах.
- Держи `README.md` актуальным: назначение сервиса, команда локального запуска, ссылка на API-документацию/Swagger UI.
- Секреты и локальные `.env`-файлы — не в репозитории (см. `12_configuration.md`).
- `src/test/java` зеркалит пакеты `src/main/java` (см. `06_unit_tests_with_spring_context.md`).
- Конфигурация, миграции и логирование — в `src/main/resources`, не в `src/main/java`: `application.yml`/`application-{profile}.yml` (см. `12_configuration.md`), `db/changelog/` (см. `03_migrations.md`), `logback-spring.xml` (см. `09_logging.md`).

## 3. Чек-лист

- [ ] Корневой пакет соответствует `groupId:artifactId`
- [ ] Java-версия зафиксирована явно и совпадает с той, что используется в CI
- [ ] Версии зависимостей — в `<properties>`/version catalog, без дублирования версий из BOM
- [ ] Модуль-клиент (если есть) не тянет зависимости веб-приложения/БД
- [ ] `README.md` описывает назначение и команды запуска
- [ ] Структура `src/main/java` соответствует слоям проекта (`controller`, `service`, `repository`, `model`, см. `01_coding.md`)
- [ ] `src/test/java` зеркалит структуру `src/main/java`
- [ ] Конфигурация/миграции/логирование — в `src/main/resources`, не в `src/main/java`
- [ ] Секреты не закоммичены (см. `12_configuration.md`)

## 4. Пример структуры

Базовый случай — одномодульный сервис без публикуемого клиента (наиболее частый вариант):

```
order-service/
├── pom.xml                         # spring-boot-maven-plugin
└── src/
    ├── main/
    │   ├── java/com/example/orders/
    │   │   ├── OrderServiceApplication.java
    │   │   ├── controller/
    │   │   ├── service/
    │   │   ├── repository/
    │   │   └── model/
    │   └── resources/
    │       ├── application.yml
    │       ├── application-{profile}.yml
    │       ├── logback-spring.xml
    │       └── db/changelog/
    │           ├── db.changelog-master.xml
    │           └── ...
    └── test/
        ├── java/com/example/orders/   # зеркалит main
        │   ├── controller/
        │   ├── service/
        │   └── repository/
        └── resources/
            └── application-test.yml
```

Тот же сервис на Gradle (`kts`) — структура `src/` идентична, меняется только сборочный файл:

```
order-service/
├── settings.gradle.kts
├── build.gradle.kts                # id("org.springframework.boot"), sourceCompatibility
└── src/main/java/com/example/orders/...
```

Многомодульный вариант — когда появляется переиспользуемый клиент (см. правило выше):

```
order-service/
├── pom.xml                         # агрегатор, packaging=pom
├── order-service/                  # исполняемый модуль
│   ├── pom.xml                     # spring-boot-maven-plugin
│   └── src/main/
│       ├── java/com/example/orders/
│       │   ├── OrderServiceApplication.java
│       │   ├── controller/
│       │   ├── service/
│       │   ├── repository/
│       │   └── model/
│       └── resources/
│           ├── application.yml
│           ├── application-{profile}.yml
│           └── db/changelog/
└── order-client/                   # библиотека: модели + Feign/OpenFeign
    ├── pom.xml                     # spring-boot.repackage.skip=true
    └── src/main/java/com/example/orders/client/
        ├── OrderClientAutoConfiguration.java   # @AutoConfiguration
        └── model/
```

Автоконфигурация клиентского модуля:

```java
@AutoConfiguration
@EnableFeignClients(basePackageClasses = OrderClient.class)
public class OrderClientAutoConfiguration {
}
```

Точка входа сервисного модуля:

```java
@SpringBootApplication
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}
```

## 5. Когда пересматривать

При смене LTS-версии Java, введении/удалении модуля-клиента, смене родительского BOM или переходе Maven ↔ Gradle.
