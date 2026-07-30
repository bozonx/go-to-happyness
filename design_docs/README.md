# Дизайн-документы

Что строим и по каким правилам. Инженерная сторона — как это устроено в коде —
живёт в [`docs/architecture.md`](../docs/architecture.md); как работать в
репозитории — в [`AGENTS.md`](../AGENTS.md).

Раскладка по подсистемам, а не по «кому принадлежит»: `engine/` — редакторы,
форматы и мир; `citizens/` — житель, его решения и труд; `settlement/` — эры,
экономика и содержание игры.

## engine — мир, форматы, редакторы

| Документ | О чём |
| --- | --- |
| [grid_terrain_system.md](engine/grid_terrain_system.md) | Сеточно-террасный ландшафт: высоты, уклоны, каскад, вода, мешер. Родительский документ для всего, что касается земли. |
| [terrain_materials.md](engine/terrain_materials.md) | Каталог материалов поверхности, варианты, износ, снег, сезоны, текстурный бюджет. |
| [navigation_and_roads.md](engine/navigation_and_roads.md) | `NavGrid`, веса, дороги как покрытие, `RoutePlan`. |
| [weather.md](engine/weather.md) | Прогноз, две оси облачности, ветер, небо и светила, лаборатория погоды. |
| [map_editor.md](engine/map_editor.md) | Формат `.gdmap`, редактор территорий, режимы и undo. |
| [map_fill_mode.md](engine/map_fill_mode.md) | Режим наполнения карты: общая библиотека ассетов, архетипы сущностей, состояния, NPC и спавнеры, генерируемый инспектор свойств. |
| [modular_building_editor.md](engine/modular_building_editor.md) | Формат `.gdbuilding.json`, каркас, отделка, режимы редактора. |
| [active_zones.md](engine/active_zones.md) | Модель активных зон обоих редакторов: области, точки, маршруты, права и эффекты, состояние и владелец зоны, события, валидация, runtime. |
| [building_furnishing.md](engine/building_furnishing.md) | Наполнение здания: предметы, fixtures, capabilities. |
| [content_packaging.md](engine/content_packaging.md) | Паки, стили, идентификаторы, пользовательский контент, правило ревизии. |
| [content_editor.md](engine/content_editor.md) | Editor Hub, проекты-паки, владение настройками игры/карты/здания и политика эр карты. |
| [multi_purpose_engine.md](engine/multi_purpose_engine.md) | Пользовательские игры внутри одного приложения: граница хоста, game packs, общий runtime и ближайший срез «две игры, один runtime». |

## citizens — житель, решения, труд

| Документ | О чём |
| --- | --- |
| [citizen_ai.md](citizens/citizen_ai.md) | Нативный ИИ: фасад, снимок мира, приказы, цели, шаги, актуатор. |
| [unit_needs.md](citizens/unit_needs.md) | Личные потребности и их интеграция с ИИ. |
| [order_system.md](citizens/order_system.md) | Приказы: прямые, дневные и профессиональные; приоритеты и жизненный цикл. |
| [workforce_system.md](citizens/workforce_system.md) | Занятость, вакансии, профессии, границы с ИИ. |
| [workforce_rollout_plan.md](citizens/workforce_rollout_plan.md) | Оставшиеся шаги перехода к трудовой модели (рабочий бэклог). |
| [work_positions.md](citizens/work_positions.md) | Рабочие позиции, чиновник, исследователь, переход к стратегии. |
| [labour_time_and_overtime.md](citizens/labour_time_and_overtime.md) | Длительность рабочего дня, ночные приказы, цена переработки. |
| [first_person_hero_control.md](citizens/first_person_hero_control.md) | Управление героем и другими жителями от первого лица. |

## settlement — эры, экономика, содержание

| Документ | О чём |
| --- | --- |
| [eras_overview.md](settlement/eras_overview.md) | Роль каждой эры и точные условия переходов (gates). |
| [building_progression.md](settlement/building_progression.md) | Цепочки зданий, уровни и апгрейды поперёк эр. |
| [tent_era_survival.md](settlement/tent_era_survival.md) | Стартовый сценарий: первые ночи, погода, выживание. |
| [village_territory.md](settlement/village_territory.md) | Область деревни: где можно строить и как она растёт. |
| [storage_warehouses.md](settlement/storage_warehouses.md) | Склады, рюкзак, кучи, порча. |
| [food_water_progression.md](settlement/food_water_progression.md) | Еда и вода от сухпайков до столовой и кухни. |
| [fire_sources.md](settlement/fire_sources.md) | Главный костёр и костёр для готовки: топливо, состояния, последствия. |
| [event_system.md](settlement/event_system.md) | Data-driven случайные события, условия, кулдауны, цепочки. |

## Прочее

[ideas.md](ideas.md) — направления и пожелания за пределами горизонта разработки.
Не источник правды: когда идея берётся в работу, она переезжает в профильный
документ целиком.

## Правила

- Один механизм — один владеющий документ. Если правило описано в двух местах,
  одно из описаний устареет молча.
- Статус наверху документа обязателен, если реализована не вся спецификация.
- Бэклог и changelog внутри дизайн-документа стареют быстрее, чем документ
  вокруг них: незакрытые шаги выносятся в отдельный план, сделанное живёт в git.
- Поимённые списки классов, целей, шагов и команд в документе **не ведутся**.
  Такой список обязан устаревать; документ описывает границы, правила и причины,
  а перечень — задача кода. План по фазам, наоборот, остаётся в своём документе:
  он привязан к его секциям и правится вместе с ними.
- Ссылки между документами — относительные. После перемещения файла проверить,
  что все ссылки резолвятся.
