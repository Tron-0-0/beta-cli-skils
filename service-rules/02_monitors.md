---
apply: always
mode: all
---

<!-- source: auto -->
# Соглашение: Мониторинг и метрики (profitcontr-objects)

**Когда читать:** При настройке мониторинга, добавлении бизнес-метрик, или проверке health/readiness-эндпоинтов.

**Что описывает:** Actuator, Micrometer/OTLP, Eskibi/MeterFilter, health/readiness probes, custom-метрики и custom-HealthIndicator.

**Глобальный эталон:** `rules/02_monitors.md`

---

<!-- source: auto -->
## 1. Наблюдения в репозитории

### 1.1 Стек мониторинга (модуль `objects`)

Мониторинг построен на Spring Boot Actuator + Micrometer c экспортом метрик по OTLP. В `objects/src/main/resources/application.properties`:

- `management.endpoints.web.exposure.include=startup,health,info,metrics,env` — открыты основные Actuator-эндпоинты;
- `management.endpoint.health.probes.enabled=true` и `management.endpoint.startup.enabled=true` — включены liveness/readiness/startup-пробы.

Зависимости (`objects/pom.xml`): `spring-boot-starter-actuator`, `micrometer-registry-otlp`, `spring-boot-starter-opentelemetry`, `feign-micrometer`.

### 1.2 Конфигурация OTLP-экспорта

Параметры вынесены в переменные окружения (`objects/src/main/resources/application.properties`):

```properties
management.otlp.metrics.export.url=${OPENTELEMETRY_EXPORT_URL}
management.otlp.metrics.export.batchSize=15000
management.otlp.metrics.export.aggregationTemporality="DELTA"
management.otlp.metrics.export.step=30s
management.otlp.metrics.export.enabled=${OPENTELEMETRY_ENABLED:true}
```

### 1.3 Обогащение метрик через MeterFilter

`OpenTelemetryConfig` (`objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java`, `@ConditionalOnBooleanProperty("management.otlp.metrics.export.enabled")`) регистрирует `MeterFilter`, который добавляет префикс CI к имени метрики и теги `app`, `pod`, `stand`:

```java
id.withName(String.format("%s.%s", ci, id.getName().replace('.', '_')))
        .withTags(Tags.of(
                Tag.of("app", appName),
                Tag.of("pod", POD_NAME),
                Tag.of("stand", STAND)));
```

### 1.4 GAP: кастомные бизнес-метрики и HealthIndicator не обнаружены

- `02_monitors.custom_metrics`: partial — в `src/main/java` нет использования `MeterRegistry` / `Counter` / `Timer` / `Gauge` (count=0). Бизнес-метрик в коде нет.
- `02_monitors.custom_health`: partial — нет классов `HealthIndicator` / `AbstractHealthIndicator` (count=0). Кастомных health-индикаторов нет.

Модуль `objects-rest-client` (библиотека Feign-клиент) не содержит Actuator/Micrometer и не требует метрик — его `pom.xml` включает только `spring-cloud-starter-openfeign`, `lombok`, `spring-boot-autoconfigure`, `ssl-context-starter`, swagger и jackson.

<!-- source: auto -->
## 2. Соглашения для агента

- Новые бизнес-метрики (счётчики, таймеры, gauges) регистрируй через `io.micrometer.core.instrument.MeterRegistry` (`Counter`, `Timer`, `Gauge`). Это соответствует глобальному `rules/02_monitors.md` (micrometer-registry-otlp) и привязано к `objects/src/main/java` — кастомных метрик пока нет, но конфигурация экспорта уже готова.
- Кастомные проверки состояния выноси в отдельные классы, реализующие `HealthIndicator` / наследовавшие `AbstractHealthIndicator`. Используй готовые пробы liveness/readiness (`management.endpoint.health.probes.enabled=true` в `application.properties`) — не дублируй их вручную.
- Бизнес-метрики обогащай через существующий `MeterFilter` в `OpenTelemetryConfig` (теги `app` / `pod` / `stand` и префикс CI) — не создавай второй фильтр с другим набором тегов.
- Трассировку и метрики выводи через OTLP-экспорт (`management.otlp.metrics.export.*` в `application.properties`); параметры URL выноси в `${OPENTELEMETRY_EXPORT_URL}` без хардкода адресов.
- Не записывай в метрики, теги и health-детали значения секретов, паролей и персональных данных — как это исключено из `application.properties` и регламентом.

<!-- source: auto -->
## 3. Чек-лист

- [ ] `spring-boot-starter-actuator` подключён и нужные endpoints (`startup,health,info,metrics,env`) доступны
- [ ] Micrometer-зависимость присутствует: `micrometer-registry-otlp` и `spring-boot-starter-opentelemetry` в `objects/pom.xml`
- [ ] OTLP-экспорт настроен в `application.properties` (`management.otlp.metrics.export.*` через `${OPENTELEMETRY_EXPORT_URL}`)
- [ ] Liveness/readiness пробы включены (`management.endpoint.health.probes.enabled=true`)
- [ ] Новые бизнес-метрики зарегистрированы через `MeterRegistry` (`Counter`/`Timer`/`Gauge`), а не через лог или поле
- [ ] Теги метрики соответствуют существующему `MeterFilter` из `OpenTelemetryConfig` (app/pod/stand, префикс CI)
- [ ] Кастомные HealthIndicator (если есть) покрывают критические зависимости и не содержат секретов в detail
- [ ] Логирование метрик не дублирует данные Actuator
- [ ] После правок перегенерированы сгенерированные классы и проверено покрытие тестами

<!-- source: auto -->
## 4. Примеры из кода

### Example 1: OpenTelemetryConfig.java — обогащение метрик
**Путь:** `objects/src/main/java/ru/sbrf/sbererp/profitcontr/objects/configuration/OpenTelemetryConfig.java`

```java
@Bean
public MeterFilter nameConfigFilter() {
    return new MeterFilter() {
        @Override
        public Meter.@NonNull Id map(Meter.@NonNull Id id) {
            return id.withName(String.format("%s.%s", ci, id.getName().replace('.', '_')))
                    .withTags(Tags.of(
                            Tag.of("app", appName),
                            Tag.of("pod", POD_NAME),
                            Tag.of("stand", STAND)));
        }
    };
}
```

### Example 2: OTLP-экспорт из application.properties
**Путь:** `objects/src/main/resources/application.properties`

```properties
management.otlp.metrics.export.url=${OPENTELEMETRY_EXPORT_URL}
management.otlp.metrics.export.step=30s
management.otlp.metrics.export.enabled=${OPENTELEMETRY_ENABLED:true}
management.endpoint.health.probes.enabled=true
management.endpoints.web.exposure.include=startup,health,info,metrics,env
```

<｜DSML｜tool_calls>
<｜DSML｜invoke name="edit">
<｜DSML｜parameter name="file_path" string="true">C:\Work\profitcontr-objects\.gigacode\service-rules\parts\gap_notes.jsonl