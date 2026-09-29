---
paths:
  - "src/main/java/**/*.java"
---

# Соглашение: Слои и зависимости

**Когда читать:** при создании нового сервиса/репозитория/UI-экрана, при рефакторинге, при code review структуры пакетов.

**Что описывает:** направление зависимостей между слоями, структуру `service`/`service.impl`, способ внедрения зависимостей, границы ответственности сервисного слоя.

---

## 1. Правило

- Направление зависимостей строго одностороннее: `consoleui` → `service` → `service.impl` → `repository` → `model.entity`. Запрещённые импорты между слоями (UI → `repository`, `service` → `consoleui`/Lanterna и т.д.) формализованы в `import-control.xml` (модуль `ImportControl` в `checkstyle.xml`) — сборка падает при нарушении, здесь не дублируются.
- Каждый сервис — это пара: интерфейс в `service/` и реализация в `service.impl/` с суффиксом `Impl` (`FrontWordService` / `FrontWordServiceImpl`). Запрет префикса `I` у интерфейса — `checkstyle.xml` (`TypeName`, id `InterfaceNoIPrefix`).
- Внедрение зависимостей — только через конструктор: `private final` поля + `@RequiredArgsConstructor`, без сеттер-инжекта. Импорт `@Autowired` запрещён `checkstyle.xml` (`IllegalImport`), неизменяемость полей проверяет `pmd.xml` (`ImmutableField`).

### 1.1 Границы ответственности service

- `service`/`service.impl` отвечает только за бизнес-логику: оркестрация вызовов репозиториев, бизнес-правила, преобразование данных между слоями.
- Если для задачи нужен паттерн проектирования (Strategy, Scenario/Step, Builder и т.п.) — реализация паттерна не пишется внутри `service.impl`, а выносится в отдельный пакет для этого паттерна (пример в проекте: `util/scenario` + `util/step` для `RegistrationStudentScenario`). Сервис в этом случае только вызывает готовую реализацию паттерна, не содержит её логику inline.
- Один пакет — один паттерн: не смешивать реализации разных паттернов в одном пакете `util/...`.

## 2. Соглашения для агента

- Перед созданием нового сервиса — найти в проекте структурно похожий существующий (`FrontWordService`/`FrontWordServiceImpl`, `StudentService`/`StudentServiceImpl`) и повторить его пакет, аннотации, стиль (см. `10-general-principles.md`).
- Новый паттерн проектирования вводить только когда он решает подтверждённую проблему (устраняет дублирование/разрастающийся `if`/`switch` по типу), не «про запас».
- При появлении REST-слоя (`09-controllers.md`) и/или Kafka-слоя (`14-kafka.md`) — те же правила направления зависимостей и constructor injection действуют и для них, они встают в цепочку на месте `consoleui`.

## 3. Чек-лист

- [ ] У сервиса есть пара интерфейс + `...Impl`
- [ ] DI — через конструктор (`private final` + `@RequiredArgsConstructor`), без сеттер-инжекта
- [ ] Реализация паттерна проектирования (если есть) — в отдельном пакете `util/...`, не инлайн в `service.impl`

## 4. Примеры кода

```java
package com.flshcrd.flashcard.service;

public interface FrontWordService {
    FrontWord createAndSaveFrontWord(String word);
}
```

```java
package com.flshcrd.flashcard.service.impl;

@Slf4j
@RequiredArgsConstructor
@Service
public class FrontWordServiceImpl implements FrontWordService {

    private final FrontWordRepository frontWordRepository;

    @Override
    public FrontWord createAndSaveFrontWord(String word) {
        FrontWord frontWord = new FrontWord();
        frontWord.setWord(word);

        return frontWordRepository.save(frontWord);
    }
}
```

Так же собран каждый существующий сервис проекта (`StudentService`/`StudentServiceImpl`, `CardService`/`CardServiceImpl`, `BackWordService`/`BackWordServiceImpl`) — новый сервис повторяет этот же скелет.

## 5. Когда пересматривать

При изменении набора технических слоёв проекта (появление REST-слоя — `09-controllers.md`, Kafka-слоя — `14-kafka.md`, второго UI поверх той же бизнес-логики) или при отказе от текущего паттерна интерфейс+`Impl` в пользу другого подхода к сервисному слою.
