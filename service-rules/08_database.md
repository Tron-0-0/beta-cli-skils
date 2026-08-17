---
apply: always
mode: all
---

# Соглашение: База данных, JPA, репозитории

**Когда читать:** при работе с JPA-сущностями, репозиториями, SQL-запросами.

**Что описывает:** маппинг сущностей, связи, аудит, блокировки, производительность запросов.

---

## 1. Правило

- **Маппинг** — `@Entity @Table(name = snake_case)`, PK — суррогатный (`UUID`/`BIGINT` с `@GeneratedValue`), имя таблицы/колонки совпадает с миграцией 1:1. Случайный UUID (v4, `GenerationType.UUID`) на таблице с высокой частотой вставки фрагментирует B-tree индекс — новые строки попадают в случайные позиции, а не в конец; на таких таблицах — time-ordered UUID (v7/ULID) или `BIGINT` + `IDENTITY`/`SEQUENCE`.
- **Именование PK/FK** — поле PK в Java: `<table>Id` (`orderId`), колонка в БД: `<table>_id` (`order_id`). Поле связи (FK) в Java — объектная ссылка на связанную сущность через `@ManyToOne`/`@OneToOne` + `@JoinColumn`, именуется по сущности, **без** суффикса `Id` (`private Order order`, не `private UUID orderId`); колонка в `@JoinColumn` при этом всё равно `<table>_id`. Имя constraint для FK в миграции (см. `03_migrations.md`) — `fk_<referenced_table>`.
- **Fetch-стратегия по умолчанию — `LAZY`** для всех связей (`@ManyToOne`/`@OneToOne` по умолчанию `EAGER` в JPA — переопределяй явно). `EAGER` — осознанное исключение, а не умолчание, потому что на графе связей `EAGER` быстро превращается в непредсказуемые каскадные подгрузки.
- **`CascadeType.ALL` — не умолчание.** Каскадное удаление имеет смысл только на стороне владельца агрегата к его непосредственным дочерним сущностям, у которых нет самостоятельного жизненного цикла (order → order lines). Каскад от дочерней сущности к родителю (`@ManyToOne(cascade = ALL)`) почти всегда ошибка — удаление одной позиции не должно каскадно удалять родителя.
- **Двунаправленные связи** — только когда обе стороны реально нужны в коде; униправленная связь проще в поддержке и не требует ручной синхронизации обеих сторон.
- **N+1** — предотвращается через `JOIN FETCH`/`@EntityGraph` на запросах, где заранее известно, что связанные сущности понадобятся; не полагаться на `LAZY` + случайный доступ в цикле.
- **Пагинация** — списковые repository-методы возвращают `Page<T>`/`Slice<T>` через `Pageable`, а не неограниченный `List<T>`. Известная ловушка: `JOIN FETCH`/`@EntityGraph` на коллекции вместе с `Pageable` в одном запросе даёт постраничную выборку в памяти (Hibernate-предупреждение HHH90003004) — Hibernate не может пагинировать на уровне SQL при декартовом произведении из fetch-join коллекции; в этом случае — двухшаговый запрос (сначала ID страницей, затем `JOIN FETCH` по списку ID) либо `@EntityGraph` без комбинации с `Pageable` на коллекциях.
- **Bulk-обновления (`@Modifying`)** — `@Query` с `@Modifying` для массовых `UPDATE`/`DELETE` выполняется в обход persistence context: уже загруженные в текущей транзакции сущности не узнают об изменении. Обязателен `clearAutomatically = true` (и `flushAutomatically = true`, если до bulk-запроса в той же транзакции были неотправленные изменения) — иначе риск работать со stale-сущностями до конца транзакции.
- **Optimistic locking** (`@Version`) — добавляется **только по явному требованию пользователя**, не по умолчанию для изменяемых сущностей с частым UPDATE. Если пользователь запросил `@Version`: конфликт (`OptimisticLockException`/`ObjectOptimisticLockingFailureException`) — ожидаемая бизнес-ситуация, не баг: на границе API транслируется в `409` (см. `07_api_contract.md`), не утекает как общий `500`.
- **Транзакционные границы** — `@Transactional` ставится на методах сервиса (границе use case), не на репозитории и не на контроллере. Читающие методы — `@Transactional(readOnly = true)` (пропускает dirty checking, потенциально роутится на read-реплику). Внутри транзакции не делать вызовы к внешним системам (HTTP-клиенты, Kafka-продюсер) — они удерживают соединение/лок на время сетевого вызова и делают откат дорогим или невозможным.
- **Производные query-методы** (`findByX`, `existsByX`) — обычные абстрактные методы интерфейса, реализацию генерирует Spring Data. Если имя получается длиннее ~40 символов (много условий через `And`/`Or`) или у метода больше 4 параметров — не наращивать имя дальше, а переходить на `@Query` (JPQL) с явным телом и коротким именем метода.
- **`default`-методы репозитория** — допустимы для простой обработки результата запроса: разворачивание `Optional` (`.orElseThrow(...)`), тривиальная проверка. Внутри `default`-метода не делать ручную итерацию/`Stream`-фильтрацию коллекций (это выражается запросом, а не постобработкой в Java) и не размещать бизнес-логику (условия предметной области, оркестрацию нескольких сущностей) — она остаётся в сервисе.
- **Аудит** — `@CreatedDate`/`@LastModifiedDate`/`@CreatedBy`/`@LastModifiedBy` через `@EntityListeners(AuditingEntityListener.class)` и общий `@MappedSuperclass`, включённый `@EnableJpaAuditing` на конфигурации.
- **Open Session/EntityManager in View** — по умолчанию выключен в проде (`spring.jpa.open-in-view=false`); ленивая загрузка вне транзакции в контроллере — сигнал, что DTO-маппинг сделан в неправильном слое.
- **Денежные поля** — `BigDecimal`, см. `13_monetary.md`.

## 2. Соглашения для агента

- Новую сущность размещай в `model/entity/`, репозиторий — интерфейс в `repository/`, наследующий `JpaRepository<Entity, ID>`.
- Поле PK называй `<table>Id`, поле связи (FK) — по имени связанной сущности без суффикса `Id`; constraint FK в миграции — `fk_<referenced_table>`.
- Новый производный query-метод с именем длиннее ~40 символов или >4 параметрами — не наращивай дальше, переходи на `@Query` с коротким именем. Новый `default`-метод репозитория — только unwrap/тривиальная проверка, без ручных циклов/`Stream`-фильтрации и без бизнес-логики.
- Связи задавай `LAZY` явно на `@ManyToOne`/`@OneToOne`; `EAGER` — только с обоснованием в комментарии.
- Каскад `ALL`/`REMOVE` — только от родителя к владеемым дочерним сущностям без самостоятельного жизненного цикла; на обратной стороне (`@ManyToOne`) каскад не ставь.
- `@Version` не добавляй по умолчанию — только если пользователь явно попросил optimistic locking для сущности.
- Для списковых/детальных выборок с известными связями — пиши `@Query` с `JOIN FETCH` или используй `@EntityGraph`, проверяй фактическое число SQL-запросов на логировании (`spring.jpa.show-sql`/p6spy) при добавлении нового запроса с связями.
- Списковый repository-метод — `Page`/`Slice` + `Pageable`, не `List` без ограничения; `JOIN FETCH` коллекции не комбинируй с `Pageable` в одном запросе (ловушка постраничной выборки в памяти).
- `@Modifying`-запрос — всегда с `clearAutomatically = true`.
- `@Transactional` ставь на публичном методе сервиса, не на `repository`/`controller`; чтение — `readOnly = true`; внутри транзакции не вызывай внешние HTTP/Kafka-интеграции.
- Новую сущность с ожидаемой высокочастотной вставкой на большую таблицу — не выбирай случайный `UUID` PK не глядя; проверь, не нужен ли time-ordered генератор или `BIGINT`+`SEQUENCE`.
- Если в сущности есть `@Version` (добавлен по требованию пользователя) — `OptimisticLockException`/`ObjectOptimisticLockingFailureException` на уровне `@RestControllerAdvice` маппи в `409`, не оставляй как необработанный `500`.
- Не отдавай JPA-сущность напрямую в HTTP-ответ — только через DTO/маппер (см. `07_api_contract.md`).

## 3. Чек-лист

- [ ] `@Entity`/`@Table`/`@Id`+`@GeneratedValue` заданы, имена совпадают с миграцией
- [ ] Именование PK/FK соблюдено (`<table>Id`/`<table>_id`, поле связи без суффикса `Id`, constraint `fk_<referenced_table>`)
- [ ] Длинные производные query-методы (>~40 символов/>4 параметров) заменены на `@Query`; `default`-методы репозитория не содержат ручных циклов/`Stream`-фильтрации и бизнес-логики
- [ ] Связи — `LAZY` по умолчанию, `EAGER` обоснован явно
- [ ] Каскад `ALL`/`REMOVE` — только родитель → дочерние сущности без своего жизненного цикла
- [ ] `@Version` добавлен только если пользователь явно запросил optimistic locking, не по умолчанию
- [ ] Аудит-поля (`@CreatedDate`/`@LastModifiedDate`) — на изменяемых сущностях
- [ ] Запросы с известными связями используют `JOIN FETCH`/`@EntityGraph`, N+1 проверен
- [ ] Списковые repository-методы возвращают `Page`/`Slice`, не неограниченный `List`
- [ ] `JOIN FETCH` коллекции не скомбинирован с `Pageable` в одном запросе
- [ ] `@Modifying`-запросы — с `clearAutomatically = true`
- [ ] `@Transactional` — на сервисе, `readOnly = true` на читающих методах, без внешних вызовов внутри транзакции
- [ ] `OptimisticLockException` транслируется в `409`, не утекает как `500`
- [ ] `spring.jpa.open-in-view=false`, ленивая загрузка не происходит в контроллере
- [ ] Денежные поля — `BigDecimal`, не `double`/`float`

## 4. Примеры кода

```java
@Entity
@Table(name = "orders")
@Getter @Setter
public class Order {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Version                                    // только по явному запросу пользователя, не по умолчанию
    private Long version;

    @Enumerated(EnumType.STRING)
    private OrderStatus status;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderLine> lines = new ArrayList<>();

    @CreatedDate
    private Instant createdAt;
}

@Entity
@Table(name = "order_lines")
@Getter @Setter
public class OrderLine {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)          // без cascade — дочерняя сторона не каскадирует к родителю
    @JoinColumn(name = "order_id")
    private Order order;
}
```

```java
public interface OrderRepository extends JpaRepository<Order, UUID> {

    @EntityGraph(attributePaths = "lines")
    Optional<Order> findWithLinesById(UUID id);          // без Pageable — JOIN FETCH коллекции + пагинация считались бы в памяти

    Page<Order> findByStatus(OrderStatus status, Pageable pageable);   // список — всегда Page/Slice, не List

    @Modifying(clearAutomatically = true)
    @Query("UPDATE Order o SET o.status = :status WHERE o.id IN :ids")
    int bulkUpdateStatus(@Param("ids") List<UUID> ids, @Param("status") OrderStatus status);

    default Order getByIdOrThrow(UUID id) {                  // default-метод: только unwrap, без бизнес-логики
        return findById(id).orElseThrow(() -> new EntityNotFoundException(id));
    }
}
```

```java
@Service
@RequiredArgsConstructor
public class OrderServiceImpl implements OrderService {

    private final OrderRepository orderRepository;

    @Transactional(readOnly = true)
    public OrderResponse getOrder(UUID id) {
        return mapper.toResponse(orderRepository.findWithLinesById(id)
                .orElseThrow(() -> new EntityNotFoundException(id)));
    }

    @Transactional
    public void cancelOrder(UUID id) {                       // транзакция только вокруг БД
        var order = orderRepository.findById(id).orElseThrow(() -> new EntityNotFoundException(id));
        order.setStatus(OrderStatus.CANCELLED);
    }
}

@Service
@RequiredArgsConstructor
public class OrderCancellationOrchestrator {                // не @Transactional — оркестрирует шаги, не сам меняет БД

    private final OrderService orderService;
    private final ShippingClient shippingClient;

    public void cancel(UUID id) {
        orderService.cancelOrder(id);                        // отдельный бин — вызов идёт через прокси, транзакция реально применяется
        shippingClient.notifyCancellation(id);               // вне транзакции — внешний вызов не удерживает соединение/лок
    }
}
```

## 5. Когда пересматривать

При массовом рефакторинге модели данных, появлении первых проблем N+1 в проде, изменении политики каскадов/аудита, либо при пересмотре подхода к пагинации/bulk-операциям или границам транзакций.
