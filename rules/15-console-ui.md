---
paths:
  - "src/main/java/**/consoleui/**"
  - "src/main/java/**/configuration/ConsoleLineRunner.java"
---

# Соглашение: Консольный UI-слой

**Когда читать:** при создании нового экрана, при показе ошибки пользователю, при работе с точкой запуска терминального интерфейса.

**Что описывает:** расположение экранов, единую точку запуска, централизованный показ ошибок, границу с бизнес-логикой. UI-слой реализован на Lanterna (миграция со Spring Shell завершена); конкретика оформления (палитра, тип рамок) сюда не входит — она фиксируется отдельно, в задаче про единый стиль экранов.

---

## 1. Правило

### 1.1 Расположение экранов

- Все экраны UI-слоя живут в пакете `consoleui/`, один класс/файл на экран (`StartPage`, `LoginPage`, `LoaderWords`).

### 1.2 Единая точка запуска

- Терминальный интерфейс поднимается из одного места — `ConsoleLineRunner` (`CommandLineRunner`): создаёт `Terminal`/`Screen`/`WindowBasedTextGUI` и оркестрирует переход между экранами. Запрет импорта `com.googlecode.lanterna.terminal` и `TerminalScreen` в `consoleui` формализован в `import-control.xml`, здесь не дублируется.
- Экран получает уже готовый `WindowBasedTextGUI` через параметр своего метода запуска (`run(gui)`), не создаёт его сам.

### 1.3 Показ ошибок пользователю

- Ошибки показываются через единый централизованный механизм на уровне UI-слоя — `ConsoleErrorPresenter` (`showError(gui, exception)`), а не через try-catch в каждом экране (см. `07-logging-and-errors.md`).
- `ConsoleErrorPresenter` принимает доменное исключение (`FlashCardException` и наследники), логирует его через `log.warn` и показывает пользователю модальное окно с текстом сообщения исключения.

### 1.4 Единый стиль

- Все экраны используют одну тему и один стиль рамок, заданные централизованно в одном месте.
- Конкретные значения (какие рамки, какие цвета) в этом правиле не фиксируются — они определяются отдельной задачей и не должны требовать правки этого правила при каждой смене оформления.

### 1.5 Граница с бизнес-логикой

- UI-слой не содержит бизнес-логику — только вызывает `service` (см. `01-layers-and-dependencies.md`).

## 2. Соглашения для агента

- Новый экран — новый класс в `consoleui/`, `@Component` + `@RequiredArgsConstructor`, с методом вида `run(WindowBasedTextGUI gui)`, вызываемым из `ConsoleLineRunner` или из другого экрана, а не создающим свой `Terminal`/`Screen`.
- Ошибку, полученную от вызова `service`, — передавать в `ConsoleErrorPresenter.showError(gui, exception)`, не оборачивать в собственный `try-catch` с показом диалога внутри экрана.
- Не переносить в экран бизнес-проверки (валидация домена, решения по данным) — экран собирает пользовательский ввод и передаёт его в `service`, решение принимает сервис.

## 3. Чек-лист

- [ ] Экран — класс в `consoleui/`, один класс на экран
- [ ] Экран получает готовый `gui` параметром
- [ ] Показ ошибки — через `ConsoleErrorPresenter`, не собственный `try-catch` с диалогом внутри экрана
- [ ] Экран не содержит бизнес-логику — только сбор ввода и вызов `service`

## 4. Примеры кода

```java
@Slf4j
@RequiredArgsConstructor
@Component
public class ConsoleLineRunner implements CommandLineRunner {

    private final LoginPage loginPage;
    private final StartPage startPage;

    @Override
    public void run(String... args) throws Exception {
        Terminal terminal = new DefaultTerminalFactory().createTerminal();
        Screen screen = new TerminalScreen(terminal);

        screen.startScreen();
        try {
            WindowBasedTextGUI gui = new MultiWindowTextGUI(screen);
            loginPage.run(gui);
            startPage.run(gui);
        } finally {
            screen.stopScreen();
            terminal.close();
        }
    }
}
```

```java
@Slf4j
@RequiredArgsConstructor
@Component
public class ConsoleErrorPresenter {

    private static final String ERROR_WINDOW_TITLE = "Ошибка";
    private static final String CONTINUE_HINT = "Нажмите Enter, чтобы продолжить";

    private final AppTheme appTheme;
    private final WindowPresenter windowPresenter;

    public void showError(WindowBasedTextGUI gui, FlashCardException exception) {
        log.warn("Показ ошибки пользователю: {}", exception.getMessage());

        BasicWindow window = new BasicWindow();
        window.setHints(List.of(Window.Hint.CENTERED));

        Panel panel = new Panel(new LinearLayout(Direction.VERTICAL));
        Label message = new Label(exception.getMessage());
        message.setForegroundColor(appTheme.colorOf(UiRole.ERROR));
        panel.addComponent(message);
        Button continueButton = new Button(CONTINUE_HINT, window::close);
        panel.addComponent(continueButton);

        window.setComponent(panel.withBorder(Borders.singleLine(ERROR_WINDOW_TITLE)));
        window.setFocusedInteractable(continueButton);

        windowPresenter.present(gui, window);
    }
}
```

Показ окна — через `WindowPresenter.present(gui, window)`, единую точку показа для всех экранов (см. §1.2), которая же проверяет минимальный размер терминала перед показом. Прямой вызов `addWindow`/`addWindowAndWait` вне `WindowPresenter` запрещён `checkstyle.xml` (`RegexpSinglelineJava`, id `ConsoleWindowShow`). Цвета — через `AppTheme.colorOf(UiRole...)` (см. §1.4).

## 5. Когда пересматривать

При смене UI-библиотеки (аналогично уже прошедшему переходу со Spring Shell на Lanterna) — правило переписывается под новую библиотеку целиком; конкретика оформления (палитра, рамки) фиксируется отдельной задачей и не требует правки этого файла.

## 6. Известные отклонения

- Экраны с retry-циклом повторного запроса пользовательского ввода при ошибке (`LoginPage`, `AddWordManually`, `CreateCollectionScreen`) сами ловят доменное исключение через `try-catch`, вместо того чтобы отдавать его полностью централизованному механизму (§1.3) — иначе экран не может повторить запрос ввода после ошибки, он бы просто закрылся. Показ самой ошибки при этом всё равно идёт только через `ConsoleErrorPresenter.showError(gui, exception)` — экран не рисует диалог самостоятельно. Подробнее об обосновании — `07-logging-and-errors.md` §6.
- `ChangePasswordScreen` — тот же retry-паттерн, но локальный `try-catch` ловит сразу 4 типа доменных исключений одной веткой (multi-catch), так как форма смены пароля проверяет несколько независимых условий подряд и любое из них должно приводить к одному и тому же результату — показать ошибку через `ConsoleErrorPresenter` и повторить форму. Подробнее — `07-logging-and-errors.md` §6.
