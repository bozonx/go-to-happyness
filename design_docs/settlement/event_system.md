# Дизайн-документ: Система случайных событий

> **Статус:** механизм и каталог палаточной эры реализованы; определения пока
> собираются кодом модуля поселения, а не данными пака (§2).

Механика случайных событий в стиле Frostpunk: периодически игроку
предлагается сложный выбор с риском и последствиями. События влияют на
ресурсы, wellbeing, работников и могут иметь отложенные эффекты.

Связанные документы:

- [tent_era_survival.md](tent_era_survival.md) — стартовый сценарий, погода, выживание;
- [food_water_progression.md](food_water_progression.md) — прогрессия еды и воды;
- [eras_overview.md](eras_overview.md) — эры и условия переходов между ними.

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

## 2. Модель

```text
presentation (панель решений)
    ↓ вызывает
application (EventService)  — единственный, кто выбирает и применяет событие
    ↓ использует
domain — определения, условия, исходы, контекст, реестр и журнал
```

Четыре понятия, и они не смешиваются:

| Понятие | Что это | Чем не является |
| --- | --- | --- |
| **Определение события** | данные: id, заголовок, текст, эра, вес, кулдаун, условия, варианты выбора, флаги цепочки | не логика: ни одного `if` внутри |
| **Исход** | типизированный эффект выбора: сообщение, изменение ресурса, изменение wellbeing, занятость жителя на N часов, установка флага, отложенный эффект | не прямая мутация состояния из UI |
| **Условие** | предикат над контекстом: эра, погода, порог ресурса, флаг, день, население | не запрос к живой сцене |
| **Контекст** | иммутабельный снимок состояния на момент проверки | не ссылка на сервисы |

Журнал (`EventLog`) хранит историю, флаги и день последнего срабатывания каждого
события; по нему считается кулдаун. Отложенные эффекты живут в `EventService` и
применяются при смене дня.

**Поимённый список полей и enum-ов здесь не ведётся** — он обязан устареть и живёт в
`game/features/events/domain/`. Ведётся правило: *новый вид условия или исхода — это
новая запись в перечислении домена плюс её обработка в `EventService`, и ничего больше;
добавление события кода не требует вовсе.*

Определения раскладываются по эрам отдельными файлами (`tent_era_events.gd`,
позже `earth_era_events.gd`), каждый со статическим `build()`.

## 3. Каталог событий палаточной эры

Двенадцать событий. Это единственное место, где они перечислены;
[tent_era_survival.md](tent_era_survival.md) §7.2 ссылается сюда.

### «Угроза намокания дров» (`protect_firewood`)

- **Условия:** эра = TENT, погода = RAIN, branches >= 1
- **Кулдаун:** 1 день
- **Выбор 1: «Assign a resident to protect the firewood»**
  - `WORKER_BUSY` (3 часа, "Protecting firewood")
  - `SET_FLAG` `firewood_protected_today`
  - `MESSAGE` "A resident is protecting the firewood from rain."
- **Выбор 2: «Ignore the risk»**
  - `DELAYED` (1 день) → `SET_FLAG` `smoky_firewood`
  - `MESSAGE` "The firewood was left exposed and will smoke tomorrow."

### «Неопознанные лесные дары» (`forest_gifts`)

- **Условия:** эра = TENT, день >= 2
- **Кулдаун:** 3 дня
- **Выбор 1: «Try the berries»**
  - Случайный исход (50/50):
    - Успех: `WELLBEING_CHANGE` +20, `MESSAGE` "The berries were safe..."
    - Провал: `WORKER_BUSY` (24 часа, "Poisoned"), `MESSAGE` "The berries were poisonous..."
- **Выбор 2: «Discard them»**
  - `MESSAGE` "The unknown berries were discarded."

### «Заблудившийся путник» (`traveler`)

- **Условия:** эра = TENT, food >= 3, water >= 2, день >= 3
- **Кулдаун:** 4 дня
- **Выбор 1: «Trade»**
  - `RESOURCE_CHANGE` food -3, water -2, tarp +1
  - `MESSAGE` "Traded 3 food and 2 water for a tarp roll."
  - Если ресурсов недостаточно: `MESSAGE` "Not enough food or water..."
- **Выбор 2: «Send away»**
  - `MESSAGE` "The traveler left without trading."

### «Потерянный ребёнок» (`lost_child`)

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

### «Странная болезнь» (`strange_illness`)

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

### «Дикие кабаны» (`wild_boars`)

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

### «Лесник» (`forest_ranger`)

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

### «Беженцы» (`refugees`)

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

### «Странный свет» (`strange_light`)

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

### «Сломанные инструменты» (`broken_tools`)

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

### «Заражённая вода» (`tainted_water`)

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

### «Тайник в лесу» (`forest_cache`)

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

Три точки, и все три — на границе `EventService`:

1. **Смена дня.** `advance_day()` применяет созревшие отложенные эффекты, затем
   `roll_daily_event()` фильтрует доступные события (эра, условия, кулдаун), взвешенно
   выбирает одно и возвращает его. Если событие выбрано — показывается панель решений.
2. **Выбор игрока.** `resolve_choice(index)` применяет исходы, пишет в журнал и
   возвращает сообщения для лога игры. UI ничего не мутирует сам.
3. **Флаги вместо переменных.** Последствия событий живут флагами журнала
   (`firewood_protected_today`, `smoky_firewood`), а не отдельными полями состояния:
   дневные правила и множитель работы от дыма читают журнал.

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
