# Переход к платформе пользовательских игр

**Статус: переход начат; первый runtime-каркас реализован.** Этот документ — источник правды для границы платформы,
порядка работ и ближайшего вертикального среза. Он не обещает реализацию всех
жанров; дальние направления находятся в [`../ideas.md`](../ideas.md#4-платформа-пользовательских-игр-за-пределами-среза).

## 1. Цель и границы

Go To Happyness поставляется как приложение с движком, редакторами и первой
готовой игрой — **Settlement**. Settlement не является ядром, специальным
режимом или образцом, от которого наследуют другие игры: это один game pack,
собранный из тех же публичных контрактов, что и пользовательский pack.

Автор без GDScript должен уметь создать и распространять небольшую игру на
террасном мире: выбрать карту, включить разрешённые модули, разместить сущности,
задать начальные условия и простые правила, проверить и запустить её из
редактора. Движок не обязан превратиться в универсальную замену Godot.

Подходящие рамки платформы:

- изменяемая сеточно-террасная земля, вода, здания и authored-сущности;
- одиночные локальные игры: поселения, RTS/tycoon, тактика, RPG/survival и
  песочницы, если они используют предоставленные контракты;
- пользовательские карты, правила, сущности, UI-раскладки и контент-паки;
- расширения движка на GDScript — только как доверенные built-in модули, а не
  исполняемый код из пользовательского пака.

Не входят в обещание платформы: произвольный voxel-ландшафт, полностью
динамичный платформер, сетевой rollback, массовый открытый мир или полноценный
авиасимулятор. Эти направления могут появиться позже, но не определяют архитектуру
первого перехода.

## 2. Что уже есть и что это означает

| Область | Состояние | Решение при переходе |
| --- | --- | --- |
| Мир | `TerrainGrid`, `TerrainService`, вода, чанковый мешер и `NavGrid` уже отделены от settlement-правил. | Сохранить как `world`-основу runtime; менять её только через существующие сервисы. |
| Карты и паки | `.gdmap` — пакет, `MapDocument` сохраняет неизвестные секции; есть index паков и content revision. | Развить до game definition, не заменять сценами Godot. |
| Сущности | Архетипы имеют стабильный id, class, свойства, состояния и непрозрачные компоненты; `MapEntityRuntime` пока лишь создаёт записи. | Сделать из этого границу данных; не объявлять общий набор компонентов внутри `entities`. |
| Активные зоны | Контракт зон, точек, маршрутов, прав и событий уже спроектирован. | Оставить общей геометрической/событийной подсистемой, не делать «системой поселения». |
| Маршрутизация | Есть запрос/результат, профили путешественника и оговорённые порталы. | Сохранить один контракт; новые топологии добавлять за ним только при реальном потребителе. |
| Settlement | `GameLaunchConfig`, `GameLaunchManager`, `SettlementGame` и bootstrap всё ещё владеют запуском, сутками, жителями, экономикой и UI. | Это главный монолит перехода: превратить в модуль и временный адаптер. |
| Сохранения | `SaveData` v3 перечисляет settlement, buildings, citizens, forest и camera. | Заменить секциями владельцев до появления второй игры. |
| Редакторы | Карта покрывает terrain/surface/water; building editor и Fill Mode создают authored content. | Достроить только авторинг, необходимый первому срезу; не начинать отдельные редакторы всех жанров. |

Фактический риск не в terrain. Он в том, что `SettlementGame` (826 строк) и его
bootstrapper (848 строк) задают состав сессии, а `GameLaunchConfig` содержит
поселенческие поля. Поэтому извлечение общего runtime должно предшествовать бою,
квестам, транспорту и сетевой игре.

## 3. Целевая модель

```text
Приложение
  ├── ContentIndex ── packs / зависимости / revisions
  ├── GameLaunchManager
  │     └── SessionBootstrapper
  │           └── GameRuntime
  │                 ├── WorldRuntime        карта, terrain, вода, navigation
  │                 ├── EntityRuntime       stable entity_id и lifecycle
  │                 ├── ModuleRegistry      разрешённые built-in модули
  │                 ├── GameClock           выбранная модель времени
  │                 ├── SaveCoordinator     секции сохранения
  │                 └── UI/Input host        выбранные layout и controls
  └── Редакторы

Settlement game pack
  └── подключает settlement-модуль, его стартовые правила и settlement UI
```

`GameRuntime` — composition root одной сессии, не глобальный singleton и не
суперкласс игр. Он создаёт только общие сервисы, затем запускает модули в
детерминированном порядке зависимостей. Модуль получает узкий `SessionContext`;
он не получает `SettlementGame`, дерево сцены или произвольный словарь сервисов.

### 3.1. Game definition и запуск

`GameDefinition` — authored JSON-запись в паке, а `GameSessionConfig` —
runtime-запрос запуска. Первое описывает игру, второе — конкретную сессию.

Минимальные поля `GameDefinition`:

```json
{
  "format_version": 1,
  "id": "settlement",
  "name": "Go To Happyness: Settlement",
  "modules": ["core.world", "gth.settlement"],
  "default_map": "core:green_valley",
  "clock": "realtime_pauseable",
  "input_profile": "rts",
  "ui_layout": "settlement_hud",
  "start": {"entities": [], "parameters": {}}
}
```

`GameSessionConfig` содержит ссылку на definition и карту, seed, локальных игроков,
путь сохранения и только параметры, допустимые definition. Эра, wellbeing,
население, ресурсы и профессии переезжают в `gth.settlement` как параметры его
старта. Карта перестаёт включать произвольные булевы `systems`: её `start` хранит
ссылку на game definition и map-specific overrides, которые валидирует владелец
модуля.

### 3.2. Реестр модулей

Пользовательский pack выбирает из зарегистрированных модулей, но не грузит
скрипты. Каждый built-in модуль объявляет:

- стабильные `id`, API-версию и зависимости;
- предоставляемые capability, команды, события и schema своих данных;
- фазу запуска/остановки и потребляемые сервисы;
- валидатор content и start-параметров;
- владельца save-секции и её миграций;
- UI-вклад и input/context actions, если они нужны.

Модули не проверяют `mode == "rpg"` или `mode == "shooter"`. `core.world` —
обязательный модуль; `gth.settlement` — обычный модуль поверх него. В первом
срезе реестр статичен и собирается кодом. Установка сторонних бинарных/скриптовых
модулей, разрешения и marketplace — не часть среза.

### 3.3. Сущности и capability

`EntityArchetype.components` уже правильно непрозрачен для общего слоя. Нужно
сохранить это правило: общий `EntityRuntime` владеет только identity, lifecycle,
authoring transform и ссылкой на archetype; модуль создаёт, валидирует и сохраняет
свой компонент. Presentation-нода — проекция runtime, а не источник состояния.

Минимальная общая идентичность: стабильный `entity_id`, archetype id, transform,
tags и состояние lifecycle. Health, inventory, faction, movement, interaction,
AI и citizen profile появляются исключительно с соответствующими модулями.
Так не возникает ложного «универсального Actor», который заранее зависит от всех
жанров.

Capability — публичное обещание модуля (например, `interactable`, `storage`), а не
название класса. Потребитель получает capability через контракт и команду, не
кастует объект в `Citizen`, `Building` или будущий `Zombie`.

### 3.4. Время, UI и ввод

`GameClock` задаётся definition: `realtime`, `realtime_pauseable` или `turn_based`.
Settlement-календарь остаётся реализацией `gth.settlement`, а не общей шкалой.
Первый срез реализует лишь существующее pauseable realtime за общим интерфейсом;
turn-based — следующий доказательный потребитель, не заглушка.

UI host собирает layout из объявленных модулем панелей. Input использует actions и
profile (`rts`, `first_person`, `tactical`, `editor`), а не проверки клавиш в
bootstrap. В срез входит один profile `rts` и один стандартный interaction/context
action. Существующий `UIManager` становится временной settlement-панелью.

### 3.5. Сохранения

Корень нового сохранения содержит только метаданные совместимости и секции:

```json
{
  "format_version": 1,
  "game": {"pack": "core", "id": "settlement", "revision": "..."},
  "map": {"ref": "core:green_valley", "revision": "..."},
  "engine": {"seed": 0, "clock": {}},
  "entities": {},
  "modules": {"gth.settlement": {}}
}
```

`SaveCoordinator` просит секцию только у активного владельца, вызывает его
миграцию и сообщает об отсутствующем обязательном модуле до загрузки мира.
Неизвестные секции сохраняются без потери только когда definition разрешает
редактирование/пересохранение без соответствующего модуля; иначе загрузка
отклоняется понятной диагностикой. Старый `SaveData` читается через однократный
адаптер в новый settlement save, после чего не развивается.

## 4. Ближайший вертикальный срез: «две игры, один runtime»

Это единственный обязательный результат переходной фазы. Он доказывает, что
Settlement не особенный, без преждевременного строительства RPG/RTS движка.

### Реализовано в первом инкременте

Уже существуют authored `GameDefinition` (`core:settlement`),
`GameSessionConfig`, `GameRuntime`, статический registry built-in модулей и
`SettlementGameModule`. Главное меню запускает Settlement через этот путь; game
definitions индексируются из папки `games/` content pack. Существующий
`SettlementGame` пока остаётся внутренним адаптером модуля, а старые scene tests
могут создавать его напрямую. Это намеренно не завершает срез: секционные
сохранения, UI host и вторая Showcase-игра ещё не реализованы.

### Пользовательский результат

В меню доступны две definition из core pack:

1. **Settlement** — текущая игра с тем же стартом, картой и сохранением.
2. **World Showcase** — небольшая не-settlement игра: загружает ту же `.gdmap`,
   показывает authored named entities, даёт RTS-камеру и взаимодействие с
   объектом через capability; в ней нет жителей, экономики, строительства,
   settlement UI и settlement-сохранения.

Автор может скопировать Showcase в user pack, выбрать карту и стартовые сущности,
запустить тест из редактора. Невалидная module dependency, неизвестная capability
или несовместимый save дают читаемую ошибку до сцены игры.

### Обязательные инкременты

1. Добавить `GameDefinition`, `GameSessionConfig`, статический `GameModuleRegistry`
   и `SessionBootstrapper`; `GameLaunchManager` разрешает game/map до смены сцены.
2. Вынести world-составление из `SettlementGame` в `GameRuntime`; оставить
   `settlement_game.tscn` адаптером, пока последний caller не перешёл.
3. Ввести `core.world` и перенести settlement launch fields в начальные параметры
   `gth.settlement`; сохранить map migration для старых `.gdmap`.
4. Дать `EntityRuntime` lifecycle для map entities и тонкую presentation-проекцию;
   не включать combat, inventory или общий actor framework.
5. Ввести модульные save-секции, мигратор SaveData v3 и round-trip тесты.
6. Вынести из `UIManager` только host/layout и actions, сохранить settlement
   панели как вклад `gth.settlement`.
7. Добавить Showcase definition, тестовый user pack и end-to-end scene tests для
   обеих игр, save/load и ошибок валидации.

### Критерии готовности

- `SettlementGame` не является стартовой сценой definition и не требуется
  `GameRuntime` для запуска Showcase.
- Запуск обеих игр использует один code path разрешения pack → definition → map →
  runtime; различаются только definition и набор модулей.
- `GameRuntime` не содержит полей citizen, era, wellbeing, buildings или
  settlement-ресурсов.
- Сохранение Showcase не содержит settlement-секции; Settlement-сохранение
  содержит её как модульную секцию, а старый save мигрирует.
- Showcase map с неизвестным модулем/компонентом не стартует молча.
- Существующие settlement scene tests и новый smoke-test Showcase проходят после
  import pass.

## 5. Порядок после среза

Каждая фаза начинается только после того, как предыдущая имеет тестовый пример и
не оставляет второй владельца состояния.

| Фаза | Результат | Не начинать раньше |
| --- | --- | --- |
| A. Runtime slice | Раздел 4: две игры, запуск, save-секции, UI host. | Ничего из боёв, диалогов, транспорта или multiplayer. |
| B. Авторинг игры | Project editor для definition, выбор карты/модулей/стартовых параметров, validator и test-run. | Отдельного редактора UI, квестов и поведения. |
| C. Первый новый модуль | Один vertical slice с реальным gameplay-потребителем: `interaction` + простые objectives/rules. | Универсальной боевой системы, behavior tree и inventory. |
| D. Второй жанровый proof | Пошаговая tactical-map или маленький survival сценарий; он выбирает `turn_based` либо inventory/health, но не оба набора сразу. | Vehicle, indoor graph и большие миры. |
| E. Масштабирование | Только измеренные нужды: streaming, Multimesh, дополнительные navigation topology, транспорт. | Обещаний «почти любых жанров». |

Выбор C и D должен быть отдельным решением с gameplay-документом. Цель — доказать
контракт вторым потребителем, а не по списку заранее построить все подсистемы.

## 6. Миграция существующего кода и документов

Не делать большой переписывающий коммит. Для каждого шага: сначала новый контракт,
затем перенос одного caller-а, затем тест и удаление compatibility delegate с
последним caller-ом.

| Сейчас | Переход | Конечный владелец |
| --- | --- | --- |
| `GameLaunchConfig` | Адаптер старого settlement launch к `GameSessionConfig` + `gth.settlement` parameters. | runtime + settlement module |
| `GameLaunchManager` | Сохраняет роль entry/scene transition, но не знает era/economy. | application launch |
| `SettlementGame` / bootstrapper | Разбираются на `GameRuntime` и `SettlementModule`; временная сцена лишь создаёт адаптер. | runtime + module |
| `SaveData` | Один import path в секционный формат. | `SaveCoordinator` + modules |
| `MapStart.mode/systems/economy` | Миграция в ссылку definition и module-owned start overrides. | map + owning module |
| `UIManager` | Host и routing отделяются; settlement-панели остаются settlement UI. | ui host + module UI |
| `Citizen` | Не обобщать заранее. Вынести только то, что реально нужно второму потребителю. | settlement до появления второго потребителя |

`preload` script-файлов в затронутом новом коде не вводить: использовать `class_name`
по правилам репозитория. `PackedScene` остаётся допустимым preload.

Нужные обновления соседних документов в том же наборе изменений:

- [`map_editor.md`](map_editor.md): заменить `mode/systems` на game definition и
  описать миграцию формата;
- [`content_packaging.md`](content_packaging.md): schema pack, entry games и
  dependency/API validation;
- [`map_fill_mode.md`](map_fill_mode.md): связь authored entity с lifecycle
  `EntityRuntime`, без перечисления компонентов;
- [`docs/architecture.md`](../../docs/architecture.md): после появления кода
  зафиксировать новые feature ownership и composition root.

## 7. Решения, которые пока не принимаем

- Не создаём ECS ради названия: текущая data-driven сущность + module-owned
  state достаточны, пока измеренный второй потребитель не потребует иного.
- Не объявляем все базовые компоненты (`health`, `inventory`, `combat`, `vehicle`)
  обязательными; это жанровые модули.
- Не строим визуальный rule graph, editor UI, dialogue editor, marketplace или
  user-code sandbox в runtime slice.
- Не переносим terrain в voxel и не пишем отдельные навигаторы для каждого типа
  NPC; новый topology требует явного контракта и потребителя.
- Не обещаем network/multiplayer; он требует отдельной authority, replication и
  security модели, а не флага в `GameSessionConfig`.

Эти ограничения — не отказ от направлений. Они сохраняют первый переход коротким,
проверяемым и обратимым. Дальнейшие пожелания записываются только в
[`../ideas.md`](../ideas.md#4-платформа-пользовательских-игр-за-пределами-среза),
пока не станут отдельным vertical slice.
