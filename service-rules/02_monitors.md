---
apply: always
mode: all
---

# Соглашение: Мониторинг и метрики

**Когда читать:** при настройке мониторинга, добавлении бизнес-метрик, проверке health/readiness-эндпоинтов.

**Что описывает:** Spring Boot Actuator, Micrometer, health/readiness probes, кастомные метрики и health-индикаторы.

---

## 1. Правило

- **Actuator обязателен** для сервисов, работающих в оркестрируемом окружении: `spring-boot-starter-actuator` подключён, открыты как минимум `health`, `info`, `metrics`. Чувствительные endpoints (`env`, `beans`, `heapdump`, `threaddump`) в проде либо не публикуются вовсе, либо доступны только через отдельный management-порт (`management.server.port`), закрытый снаружи кластера — открытие их на публичном порту в проде — угроза утечки конфигурации и секретов.
- **Метрики экспортируются** через Micrometer в единый бэкенд (Prometheus/OTLP/StatsDB) — не собственным форматом.
- **Health vs Readiness — раздельные группы.** `liveness` и `readiness` конфигурируются как отдельные Actuator health-groups (`management.endpoint.health.group.*`); readiness обычно включает кастомные `HealthIndicator` внешних зависимостей, liveness — только `livenessState`. Семантику различия и её роль в деплое/оркестрации см. в `10_cloud_native.md` — здесь фиксируется только то, как это выражается через конфигурацию Actuator.
- **Бизнес-метрики** регистрируются через `MeterRegistry` (`Counter`/`Timer`/`Gauge`), а не через парсинг логов.
- **Кардинальность тегов** — теги метрик не должны содержать значения с неограниченной кардинальностью (ID пользователя, timestamp, UUID запроса) — это взрывает объём хранимых метрик на бэкенде. Допустимые теги: тип операции, статус, код ошибки, имя эндпоинта.

## 2. Соглашения для агента

- Новые счётчики/таймеры/gauge регистрируй через инъекцию `MeterRegistry`; имя метрики — `dot.case`, сегменты от общего к частному (`orders.created`, `orders.processing.duration`), в едином стиле с уже существующими метриками сервиса — не смешивай `dot.case` и `snake_case` в рамках одного сервиса.
- Кастомные проверки состояния — отдельные классы `HealthIndicator`, каждый проверяет ровно одну зависимость (БД, внешний API, очередь); индикаторы readiness-зависимостей перечисляй в `management.endpoint.health.group.readiness.include`, не добавляй их в liveness.
- Вызовы внешних систем внутри `health()` — с ограниченным таймаутом (переиспользуй клиент с уже настроенными таймаутами, не создавай отдельный без ограничения). Индикатор без таймаута может подвесить весь health-check пода при деградации зависимости, а не просто отрапортовать `DOWN`.
- Не проставляй в теги метрик и в детали `HealthIndicator` значения секретов, персональных данных или полных URL с credentials.
- Экспорт (адрес коллектора, batch size, шаг) конфигурируй через переменные окружения (`${OTLP_EXPORT_URL}`), не хардкодь адреса.

## 3. Чек-лист

- [ ] `spring-boot-starter-actuator` подключён, чувствительные endpoints (`env`, `beans`, `heapdump`, `threaddump`) не открыты публично в проде
- [ ] Micrometer-registry настроен на реальный бэкенд метрик
- [ ] Liveness и readiness — раздельные health-groups, readiness включает кастомные `HealthIndicator` внешних зависимостей
- [ ] Новые бизнес-метрики — через `MeterRegistry`, имя в `dot.case`, без тегов высокой кардинальности
- [ ] Внешние вызовы внутри кастомных `HealthIndicator` ограничены таймаутом
- [ ] Кастомные `HealthIndicator` не содержат секретов в `Health.Builder.withDetail(...)`
- [ ] Адреса экспорта метрик — из переменных окружения

## 4. Примеры кода

```java
@Component
@RequiredArgsConstructor
public class OrderMetrics {
    private final MeterRegistry registry;

    public void recordCreated(OrderStatus status) {
        registry.counter("orders.created", "status", status.name()).increment();
    }
}
```

```java
@Component
@RequiredArgsConstructor
public class PaymentGatewayHealthIndicator implements HealthIndicator {
    private final PaymentGatewayClient client;

    @Override
    public Health health() {
        try {
            client.ping(); // клиент сконфигурирован с connect/read-таймаутом — health() не блокируется на зависшем соединении
            return Health.up().build();
        } catch (Exception e) {
            return Health.down().withDetail("reason", e.getMessage()).build();
        }
    }
}
```

```properties
management.endpoints.web.exposure.include=health,info,metrics
# management.server.port=8081   — опция: вынести все actuator-endpoints на отдельный порт вместо точечного отключения
management.endpoint.health.probes.enabled=true
management.endpoint.health.group.readiness.include=readinessState,paymentGateway
management.otlp.metrics.export.url=${OTLP_EXPORT_URL}
```

## 5. Когда пересматривать

При смене бэкенда метрик, добавлении новых внешних зависимостей, требующих readiness-проверки, изменении политики раскрытия Actuator-эндпоинтов, или изменении границы ответственности с `10_cloud_native.md` по семантике probes.
