# Дизайн-документ: Система случайных событий

Механика случайных событий в стиле Frostpunk: периодически игроку
предлагается сложный выбор с риском и последствиями. События влияют на
ресурсы, wellbeing, работников и могут иметь отложенные эффекты.

Связанные документы:

- [tent_era_survival.md](tent_era_survival.md) — стартовый сценарий, погода, выживание;
- [food_water_progression.md](food_water_progression.md) — прогрессия еды и воды;
- [era_progression_gates.md](era_progression_gates.md) — условия переходов между эрами.

## 1. Принципы

1. **Data-driven, не хардкод.** События описываются как данные (определения),
   а не как if/elif в контроллере. Добавление события = новый объект определения,
   без изменения игрового цикла.
2. **Домен без зависимостей.** Определения событий, условия, исходы —
   чистые value objects без ссылок на узлы, UI или сцену.
3. **Один источник решений.** `EventService` — единственный, кто выбирает
   и применяет события. UI только отображает и передаёт выбор игрока.
4. **Условия и кулдауны.** Каждое событие имеет условия доступности
   (эра, ресурсы, погода, день) и кулдаун (минимальное число дней между
   повторами). Событие не выпадает, если условия не выполнены или кулдаун
   не истёк.
5. **Отложенные последствия.** Исход может содержать отложенный эффект,
   который срабатывает через N дней (например, дым от мокрых дров на
   следующий день).
6. **Цепочки событий.** Исход может помечать флаг, который делает другое
   событие доступным или гарантированным в следующий раз (например, лесник
   предупреждает о кабанах → на следующий день приходит событие «Кабаны»).
7. **Эра-зависимость.** Каждая эра имеет свой набор событий. События
   палаточной эры не выпадают в земляной, и наоборот.

## 2. Архитектура

```text
presentation (settlement_game.gd)
    ↓ вызывает
application (EventService)
    ↓ использует
domain (GameEventDef, EventChoiceDef, EventOutcome, EventCondition,
         EventContext, EventRegistry, EventLog)
```

### 2.1. Domain-слой

#### GameEventDef

Определение события. Не содержит логики, только данные.

- `id: StringName` — стабильный идентификатор (например, `&"protect_firewood"`)
- `title: String` — заголовок для панели UI
- `description: String` — текст-описание для игрока
- `era: int` — эра, в которой событие доступно (`SettlementState.Era`)
- `weight: float` — базовый вес при случайном выборе (по умолчанию 1.0)
- `cooldown_days: int` — минимальное число дней между повторами (по умолчанию 2)
- `conditions: Array[EventCondition]` — условия доступности
- `choices: Array[EventChoiceDef]` — варианты выбора (2–3)
- `chain_flag: StringName` — если задано, событие доступно только если этот
  флаг установлен в EventLog (для цепочек)
- `sets_flag: StringName` — если задано, исход выбора устанавливает этот флаг
  в EventLog (для цепочек)

#### EventChoiceDef

Вариант выбора внутри события.

- `label: String` — текст кнопки
- `outcomes: Array[EventOutcome]` — список исходов (все применяются)
- `sets_flag: StringName` — флаг, устанавливаемый при выборе (перекрывает
  `GameEventDef.sets_flag`)

#### EventOutcome

Эффект, применяемый к состоянию игры. Типизированный record.

- `kind: Kind` — тип эффекта (см. enum ниже)
- `resource: String` — ресурс для `RESOURCE_CHANGE`
- `amount: int` — количество для `RESOURCE_CHANGE`
- `wellbeing_delta: int` — для `WELLBEING_CHANGE`
- `worker_busy_hours: float` — для `WORKER_BUSY`
- `worker_busy_label: String` — подпись статуса для `WORKER_BUSY`
- `message: String` — сообщение в лог
- `delay_days: int` — задержка в днях для отложенного эффекта
- `delayed_outcome: EventOutcome` — отложенный эффект (для `DELAYED`)
- `flag: StringName` — для `SET_FLAG`
- `random_chance: float` — шанс срабатывания (0.0–1.0) для случайных исходов
- `random_outcomes: Array[EventOutcome]` — альтернативные исходы при провале
  шанса

Enum `Kind`:
- `MESSAGE` — просто сообщение в лог
- `RESOURCE_CHANGE` — добавить/убрать ресурс
- `WELLBEING_CHANGE` — изменить wellbeing
- `WORKER_BUSY` — вывести случайного жителя из экономики на N часов
- `SET_FLAG` — установить флаг в EventLog (для цепочек)
- `DELAYED` — отложенный эффект через N дней

#### EventCondition

Условие доступности события. Типизированный record.

- `kind: ConditionKind` — тип условия
- `resource: String` — для `RESOURCE_AT_LEAST` / `RESOURCE_AT_MOST`
- `value: int` — порог для ресурсных условий
- `era: int` — для `ERA_IS`
- `weather: int` — для `WEATHER_IS`
- `flag: StringName` — для `FLAG_SET` / `FLAG_NOT_SET`
- `min_day: int` — для `DAY_AT_LEAST`
- `min_population: int` — для `POPULATION_AT_LEAST`

Enum `ConditionKind`:
- `ERA_IS` — текущая эра совпадает
- `WEATHER_IS` — текущая погода совпадает
- `RESOURCE_AT_LEAST` — ресурс >= value
- `RESOURCE_AT_MOST` — ресурс <= value
- `FLAG_SET` — флаг установлен в EventLog
- `FLAG_NOT_SET` — флаг не установлен в EventLog
- `DAY_AT_LEAST` — текущий день >= min_day
- `POPULATION_AT_LEAST` — население >= min_population

#### EventContext

Снимок состояния игры, передаваемый в условия и исходы. Immutable.

- `era: int`
- `day: int`
- `weather: int`
- `resources: Dictionary` — resource_type → amount
- `wellbeing: int`
- `population: int`
- `flags: Dictionary` — StringName → true (из EventLog)

#### EventRegistry

Реестр всех определений событий.

- `register(def: GameEventDef)` — добавить определение
- `all() -> Array[GameEventDef]` — все определения
- `by_era(era: int) -> Array[GameEventDef]` — отфильтровать по эре

#### EventLog

Журнал прошедших событий и хранилище флагов.

- `entries: Array[EventLogEntry]` — история
- `flags: Dictionary` — StringName → true
- `last_day_for: Dictionary` — event_id → день последнего срабатывания
- `record(event_id, day, choice_index)` — записать событие
- `is_on_cooldown(event_id, day, cooldown_days) -> bool` — проверить кулдаун
- `has_flag(flag) -> bool`
- `set_flag(flag)`
- `clear_flag(flag)`

#### EventLogEntry

- `event_id: StringName`
- `day: int`
- `choice_index: int`

### 2.2. Application-слой

#### EventService

Координирует выбор и применение событий.

- `registry: EventRegistry` — реестр определений
- `log: EventLog` — журнал
- `pending_event: GameEventDef` — текущее ожидающее событие (или null)
- `pending_delayed: Array[DelayedEffect]` — отложенные эффекты

Методы:
- `roll_daily_event(context: EventContext, rng: RandomNumberGenerator) -> GameEventDef`
  — вызывается каждый игровой день в 06:00. Фильтрует доступные события
  (эра, условия, кулдаун), взвешенно выбирает одно, устанавливает
  `pending_event`, возвращает его (или null).
- `resolve_choice(choice_index: int, context: EventContext, rng: RandomNumberGenerator) -> Array[String]`
  — применяет исходы выбранного варианта, записывает в лог, возвращает
  список сообщений для лога игры.
- `advance_day(day: int, context: EventContext, rng: RandomNumberGenerator) -> Array[String]`
  — вызывается при смене дня. Проверяет и применяет отложенные эффекты,
  возвращает сообщения.
- `has_pending() -> bool`
- `clear_pending()`

#### DelayedEffect

- `trigger_day: int`
- `outcome: EventOutcome`
- `context: EventContext` — снимок на момент создания

### 2.3. Определения событий

События определяются в отдельных файлах по эрам:

- `tent_era_events.gd` — события палаточной эры (3 существующих + 8 новых)
- `earth_era_events.gd` — события земляной эры (будущее)

Каждый файл содержит статический метод `build() -> Array[GameEventDef]`,
который возвращает массив определений.

## 3. События палаточной эры

### 3.1. Существующие события (перенесённые из хардкода)

#### «Угроза намокания дров» (`protect_firewood`)

- **Условия:** эра = TENT, погода = RAIN, branches >= 1
- **Кулдаун:** 1 день
- **Выбор 1: «Assign a resident to protect the firewood»**
  - `WORKER_BUSY` (3 часа, "Protecting firewood")
  - `SET_FLAG` `firewood_protected_today`
  - `MESSAGE` "A resident is protecting the firewood from rain."
- **Выбор 2: «Ignore the risk»**
  - `DELAYED` (1 день) → `SET_FLAG` `smoky_firewood`
  - `MESSAGE` "The firewood was left exposed and will smoke tomorrow."

#### «Неопознанные лесные дары» (`forest_gifts`)

- **Условия:** эра = TENT, день >= 2
- **Кулдаун:** 3 дня
- **Выбор 1: «Try the berries»**
  - Случайный исход (50/50):
    - Успех: `WELLBEING_CHANGE` +20, `MESSAGE` "The berries were safe..."
    - Провал: `WORKER_BUSY` (24 часа, "Poisoned"), `MESSAGE` "The berries were poisonous..."
- **Выбор 2: «Discard them»**
  - `MESSAGE` "The unknown berries were discarded."

#### «Заблудившийся путник» (`traveler`)

- **Условия:** эра = TENT, food >= 3, water >= 2, день >= 3
- **Кулдаун:** 4 дня
- **Выбор 1: «Trade»**
  - `RESOURCE_CHANGE` food -3, water -2, tarp +1
  - `MESSAGE` "Traded 3 food and 2 water for a tarp roll."
  - Если ресурсов недостаточно: `MESSAGE` "Not enough food or water..."
- **Выбор 2: «Send away»**
  - `MESSAGE` "The traveler left without trading."

### 3.2. Новые события

#### «Потерянный ребёнок» (`lost_child`)

- **Условия:** эра = TENT, день >= 3, population >= 3
- **Кулдаун:** 5 дней
- **Описание:** "A child was found wandering near the road. They say their
  parents went foraging days ago and never came back."
- **Выбор 1: «Take them in»**
  - `WELLBEING_CHANGE` +10 (compassion)
  - `RESOURCE_CHANGE` food -2 (extra mouth to feed)
  - `MESSAGE` "The child joined the settlement. Wellbeing rose by 10."
- **Выбор 2: «Send them away»**
  - `WELLBEING_CHANGE` -15 (guilt)
  - `MESSAGE` "The child was sent away. The camp feels colder."

#### «Странная болезнь» (`strange_illness`)

- **Условия:** эра = TENT, день >= 4, population >= 3
- **Кулдаун:** 6 дней
- **Описание:** "One of the residents woke up with a fever and red spots.
  It could be contagious."
- **Выбор 1: «Quarantine them»**
  - `WORKER_BUSY` (48 часов, "Quarantined")
  - `WELLBEING_CHANGE` -5 (fear)
  - `MESSAGE` "The sick resident is quarantined for two days."
- **Выбор 2: «Ignore it»**
  - 50% шанс: `WORKER_BUSY` (48 часа, "Sick") для 2 жителей
  - 50% шанс: `MESSAGE` "It was just a mild cold. Everyone recovered."
- **Выбор 3: «Use the last medicine»** (только если goods >= 1)
  - `RESOURCE_CHANGE` goods -1
  - `MESSAGE` "The medicine worked. The resident recovered quickly."
  - `WELLBEING_CHANGE` +5 (relief)

#### «Дикие кабаны» (`wild_boars`)

- **Условия:** эра = TENT, флаг `boar_warning` установлен
- **Кулдаун:** 5 дней
- **Цепочка:** срабатывает только если лесник предупредил (событие `forest_ranger`)
- **Описание:** "A pack of wild boars is raiding the food storage!"
- **Выбор 1: «Chase them off»**
  - `WORKER_BUSY` (6 часов, "Chasing boars")
  - 30% шанс: `RESOURCE_CHANGE` food -2 (boars got some before chased off)
  - `MESSAGE` "Residents chased the boars away."
- **Выбор 2: «Let them take what they want»**
  - `RESOURCE_CHANGE` food -4
  - `MESSAGE` "The boars raided the storage and left."

#### «Лесник» (`forest_ranger`)

- **Условия:** эра = TENT, день >= 5
- **Кулдаун:** 7 дней
- **Описание:** "A forest ranger passes by. He warns that boar tracks
  were seen near the camp. He also offers to trade."
- **Выбор 1: «Trade and heed the warning»**
  - `RESOURCE_CHANGE` food -1, goods -1 (if available)
  - `SET_FLAG` `boar_warning` (триггерит `wild_boars` на следующий день)
  - `MESSAGE` "The ranger traded and warned about boars nearby."
- **Выбор 2: «Just listen»**
  - `SET_FLAG` `boar_warning`
  - `MESSAGE` "The ranger warned about boars. No trade was made."
- **Выбор 3: «Ignore him»**
  - `MESSAGE` "The ranger left. You dismissed his warning."

#### «Беженцы» (`refugees`)

- **Условия:** эра = TENT, день >= 6, population < 6
- **Кулдаун:** 8 дней
- **Описание:** "A small family of refugees asks to join the settlement.
  They look hungry but willing to work."
- **Выбор 1: «Welcome them»**
  - `RESOURCE_CHANGE` food -4 (immediate feeding)
  - `WELLBEING_CHANGE` +8 (community spirit)
  - `MESSAGE` "The refugees joined the settlement. Population increased."
  - (В будущей реализации: +1 citizen)
- **Выбор 2: «Turn them away»**
  - `WELLBEING_CHANGE` -10
  - `MESSAGE` "The refugees were turned away. Some residents feel guilty."

#### «Странный свет» (`strange_light`)

- **Условия:** эра = TENT, день >= 4
- **Кулдаун:** 5 дней
- **Описание:** "During the night, a strange pulsing light was seen in
  the forest. It might be worth investigating."
- **Выбор 1: «Investigate»**
  - `WORKER_BUSY` (12 часов, "Investigating")
  - 60% шанс: `RESOURCE_CHANGE` goods +2, `MESSAGE` "The search party found
    abandoned supplies."
  - 40% шанс: `WORKER_BUSY` (24 часа, "Lost"), `MESSAGE` "The investigator
    got lost and took a day to return."
- **Выбор 2: «Ignore it»**
  - `MESSAGE` "The light faded by morning. Nothing happened."

#### «Сломанные инструменты» (`broken_tools`)

- **Условия:** эра = TENT, день >= 5, есть хотя бы один tool = true
- **Кулдаун:** 6 дней
- **Описание:** "A tool broke during work. It can be repaired, but it
  will take time and materials."
- **Выбор 1: «Repair it»**
  - `WORKER_BUSY` (4 часа, "Repairing tools")
  - `RESOURCE_CHANGE` branches -2
  - `MESSAGE` "The tool was repaired with branches and effort."
- **Выбор 2: «Work without it»**
  - `WELLBEING_CHANGE` -5 (frustration)
  - `MESSAGE` "Work continues without the tool. Morale dropped slightly."

#### «Заражённая вода» (`tainted_water`)

- **Условия:** эра = TENT, день >= 4, water >= 3
- **Кулдаун:** 6 дней
- **Описание:** "The water supply looks cloudy and smells odd. It might
  be contaminated."
- **Выбор 1: «Boil it all»**
  - `WORKER_BUSY` (3 часа, "Boiling water")
  - `RESOURCE_CHANGE` branches -1
  - `MESSAGE` "The water was boiled and is now safe."
- **Выбор 2: «Risk it»**
  - 40% шанс: `WORKER_BUSY` (12 часов, "Sick") для 1 жителя
  - 60% шанс: `MESSAGE` "The water was fine. No one got sick."

#### «Тайник в лесу» (`forest_cache`)

- **Условия:** эра = TENT, день >= 7
- **Кулдаун:** 10 дней
- **Описание:** "A forager stumbled upon a hidden cache in the forest.
  It could contain valuable supplies — or something dangerous."
- **Выбор 1: «Open it»**
  - 50% шанс: `RESOURCE_CHANGE` goods +3, `MESSAGE` "The cache contained
    preserved goods."
  - 30% шанс: `RESOURCE_CHANGE` food +4, `MESSAGE` "The cache had canned
    food."
  - 20% шанс: `WORKER_BUSY` (24 часа, "Trapped"), `MESSAGE` "It was a trap!
    A forager got caught and took a day to free themselves."
- **Выбор 2: «Leave it»**
  - `MESSAGE` "The cache was left untouched. Better safe than sorry."

## 4. Интеграция с игровым циклом

### 4.1. Вызов события

В `_handle_day_cycle_event` для `DAILY_SETTLEMENT_UPDATE`:

1. Построить `EventContext` из текущего состояния.
2. Вызвать `event_service.advance_day()` для отложенных эффектов.
3. Вызвать `event_service.roll_daily_event()`.
4. Если событие выбрано — показать панель решений с вариантами.

### 4.2. Разрешение выбора

При нажатии кнопки выбора:

1. Построить `EventContext`.
2. Вызвать `event_service.resolve_choice(choice_index)`.
3. Применить возвращённые сообщения в лог.
4. Скрыть панель.

### 4.3. Отложенные эффекты

При смене дня `event_service.advance_day()` проверяет все отложенные
эффекты, чей `trigger_day` <= текущего дня, и применяет их. Возвращает
сообщения для лога.

### 4.4. Существующие механики

- `protected_firewood_day` — заменяется флагом `firewood_protected_today`
  в EventLog.
- `smoky_firewood_day` — заменяется флагом `smoky_firewood` в EventLog.
  Проверка в `_apply_daily_settlement_rules` и `fire_smoke_work_multiplier`
  читает флаг из EventLog вместо переменной.

## 5. Инварианты

1. События — чистые данные. Логика применения — в `EventService`.
2. UI не мутирует состояние напрямую, только через `EventService`.
3. Кулдаун проверяется по `EventLog.last_day_for`, не по отдельным
   переменным.
4. Цепочки событий — через флаги в `EventLog`, не через глобальные
   переменные.
5. Отложенные эффекты хранятся в `EventService.pending_delayed` и
   применяются при смене дня.
6. Каждое событие имеет хотя бы одно условие (минимум — эра).
7. Случайность в исходах использует переданный `RandomNumberGenerator`,
   не глобальный `randf()`.
