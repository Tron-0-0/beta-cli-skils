---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Cloud Native, probes, health (profitcontr-objects)

**Когда читать:** При деплое/контейнеризации сервиса, настройке probe-эндпоинтов или включении/правке actuator и метрик OTLP.

**Что описывает:** наблюдаемые в репозитории настройки Spring Boot Actuator (`management.*`), readiness/liveness/startup probes, метрики/трейсинг OpenTelemetry; глобальный регламент — `rules/10_cloud_native.md`.

**Глобальный эталон:** `rules/10_cloud_native.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Spring Boot Actuator и probe-эндпоинты

`spring-boot-starter-actuator` объявлен в `objects/pom.xml`. В `objects/src/main/resources/application.properties` настроены probe-эндпоинты:

- `management.endpoint.health.probes.enabled=true` — readiness/liveness включены принудительно (не только в Kubernetes).
- `management.endpoint.startup.enabled=true` — включён startup.
- `management.endpoints.web.exposure.include=startup,health,info,metrics,env` — exposed список включает **оба** `startup` и `health` (требование эталона `rules/10` соблюдено).

Сервис анкерно позиционируется как cloud-native слой probes: он сконфигурирован, но готов при использовании инфраструктурой (Kubernetes/etc).

### 1.2 Точка входа и startup probe

`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/WebApplication.java` конфигурирует startup через `BufferingApplicationStartup` (капсулируется через `WebApplicationConstants.APPLICATION_STARTUP_BUFFER_CAPACITY`) — ровно так, как требует эталон для startup probe (предотвращает преждевременные liveness/readiness).

### 1.3 Метрики и трассировка

- В `objects/pom.xml`: `micrometer-registry-otlp`, `spring-boot-starter-opentelemetry`, `feign-micrometer`.
- `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java` идёт под `@ConditionalOnBooleanProperty("management.otlp.metrics.export.enabled")` и добавляет `MeterFilter`: префикс имени метрики из CI, теги `app`/`pod`/`stand`.
- Экспорт в `application.properties`: `management.otlp.metrics.export.url=${OPENTELEMETRY_EXPORT_URL}`, `step=30s`, `enabled=${OPENTELEMETRY_ENABLED:true}`.
- Кастомные бизнес-метрики (`MeterRegistry`/`Counter`/`Timer`) и кастомные `HealthIndicator` в `src/main/java` **отсутствуют** (count=0) — открытая зона к `rules/10` (рекомендация §2).

### 1.4 Kubernetes / Docker / Helm — НЕ ОПРЕДЕЛЕНО

В репозитории **нет** `Dockerfile`, `kubernetes/`, `helm/`, `*deployment*.yml`-манифестов. Поэтому локальные K8s/Docker-практики не заявляются и переноситься из других проектов не должны — при отсутствии локальных манифестов следовать `rules/10_cloud_native.md`.

---

<!-- source: auto -->
## 2. Соглашения для агента

- Probe-эндпоинты настраивать через `management.endpoint.health.probes.enabled=true`; при включении startup обязательно перечислять `startup` и `health` в `management.endpoints.web.exposure.include` (`objects/src/main/resources/application.properties`) — правило уже соблюдается.
- Для cloud-native задач всегда подключать `spring-boot-starter-actuator` (как в `objects/pom.xml`), а метрики/трейсинг — через `micrometer-registry-otlp` + OpenTelemetry config в `objects/.../configuration/OpenTelemetryConfig.java`; новые счётчики/гистограммы добавлять через `MeterRegistry`/`MeterFilter` в этом же конфиге.
- Не заявлять и не "придумывать" Kubernetes/Docker/Helm-практики и манифесты: в репо (`objects/`, корень) их нет — при отсутствии локальных манифестов следовать глобальному `rules/10_cloud_native.md` (endpoints `/actuator/health/liveness`, `/actuator/health/readiness`, `/actuator/startup`).
- **Рекомендация (открытая зона):** добавлять кастомные `AbstractHealthIndicator`/`HealthIndicator` для критических внешних зависимостей (MDM/БД/Feign-клиенты) — сейчас таких индикаторов нет; готовим при необходимости, без ломки `health` статусов по умолчанию.
- Graceful shutdown настраивать через `server.shutdown=graceful` (сейчас в `application.properties` не задано — добавлять при потребности длительной доработки фоновых задач).

---

<!-- source: auto -->
## 3. Чек-лист

- [ ] `management.endpoint.health.probes.enabled=true` выставлено в `application.properties`
- [ ] `management.endpoints.web.exposure.include` содержит `startup` вместе с `health` (оба)
- [ ] Точка входа использует `BufferingApplicationStartup` (`WebApplication.java`)
- [ ] Все изменения с пробами вносить только в `application.properties`/коде, без выдумывания K8s-манифестов (их в репо нет)
- [ ] Метрики для новых бизнес-процессов добавляются через `MeterRegistry`/`MeterFilter` (конфиг `OpenTelemetryConfig`)
- [ ] Для критических внешних зависимостей — добавлен `HealthIndicator` (рекомендация; сейчас отсутствуют)
- [ ] При изменении endpoint exposure не забыть включить и `startup`, и `health` (требование `rules/10`)
- [ ] В коде/pr не появляется значений секретов (нет реальных паролей/ключей в примерах и комментариях)

---

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: Probes/actuator в `application.properties`
**Путь:** `objects/src/main/resources/application.properties`

```
management.endpoint.health.probes.enabled=true
management.endpoint.startup.enabled=true
management.endpoints.web.exposure.include=startup,health,info,metrics,env
```

### Example 2: Startup через `BufferingApplicationStartup`
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/WebApplication.java`

```java
@SpringBootApplication
public class WebApplication {
    public static void main(String... args) {
        new SpringApplicationBuilder(WebApplication.class)
                .applicationStartup(new BufferingApplicationStartup(WebApplicationConstants.APPLICATION_STARTUP_BUFFER_CAPACITY))
                .run(args);
    }
}
```

### Example 3: OTel MeterFilter для метрик
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java`

```java
@Bean
public MeterFilter nameConfigFilter() { ... id.withName(ci + "." + name).withTags(Tags.of("app", appName, "pod", POD_NAME, "stand", STAND)); }
```

---

<!-- source: auto -->
## 5. Исключения и оговорки

- Соглашение ограничивается **конфигурацией приложения** (Spring properties + код). Платформенные K8s/Helm-манифесты не находятся в этом репозитории, поэтому вопросы деплоя и поды — зона `rules/`/платформы, не локального файла.
- Кастомные `HealthIndicator` — **рекомендация**, а не текущий факт репо (их сейчас нет); при добавлении не нарушать агрегирующий `status` по умолчанию.
- `server.shutdown=graceful` на текущий момент не настроен — добавлять при явной необходимости.

---

## 6. Обновление

Файл обновлять при: изменении `spring-boot-starter-actuator` / версии OpenTelemetry в `objects/pom.xml`, изменении probe/OTLP-настроек в `application.properties`, либо появлении в репозитории Dockerfile/kubernetes-манифестов.