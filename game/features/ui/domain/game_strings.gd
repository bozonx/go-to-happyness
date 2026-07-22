class_name GameStrings
extends RefCounted

## Centralized user-facing strings. All Russian text lives here so it can be
## swapped to Godot tr() or a CSV translation table without touching call sites.

# --- First Person HUD: work position / toilet ---
const F_LEAVE_WORK_POSITION := "F — покинуть рабочее место"
const USING_TOILET := "Пользуемся туалетом..."

# --- First Person HUD: entrance ---
const F_MEET_ARRIVAL := "F: встретить прибывшего жителя"
const ENTRANCE_SIGN := "Входной знак"

# --- First Person HUD: fire source ---
const F_ADD_BRANCH_TO_FIRE := "F: добавить 1 ветку в костер | Shift+F: добавить все (%d)"
const NEED_BRANCHES_FOR_FIRE := "Нужны ветки в кармане, чтобы пополнить костер"

# --- First Person HUD: construction ---
const F_DELIVER_MATERIALS := "F: сдать стройматериалы (%s)"
const F_WORK_ON_CONSTRUCTION := "F: работать на стройке"

# --- First Person HUD: demolition ---
const F_DEMOLISH := "F: разбирать отмеченное здание"

# --- First Person HUD: pile ---
const POCKET_FULL := "Карман полон"
const F_TAKE_FROM_PILE := "F: взять %s из кучи | Shift+F: взять всё"

# --- First Person HUD: warehouse ---
const WAREHOUSE_REJECTS := "Склад не принимает %s"
const WAREHOUSE_FULL := "Склад заполнен"
const F_DEPOSIT_ONE := "F: сдать 1 (%s) | Shift+F: сдать всё"
const WAREHOUSE_FILL_FORMAT := "Склад: %d/%d заполнено"
const WAREHOUSE := "Склад"

# --- First Person HUD: sawmill ---
const F_DEPOSIT_WOOD_SAWMILL := "F: сдать 1 дерево на лесопилку | Shift+F: сдать всё (%d)"
const F_TAKE_BOARD := "F: взять 1 доску | Shift+F: взять до заполнения"

# --- First Person HUD: workplace ---
const OPEN_CAMPFIRE_MENU_FOR_OFFICIAL := "Откройте меню главного костра, чтобы занять место"
const F_COOK := "F — готовить еду"
const F_TEACH := "F — учить"
const F_TRADE := "F — торговать"
const F_CRAFT := "F — ремесло"
const F_OCCUPY_WORKPLACE := "F — занять рабочее место (%s)"

# --- First Person HUD: tree ---
const BRANCHES_DEPLETED := "Ветки иссякли (топор откроет полный сбор)"
const F_GATHER_BRANCHES := "F: собрать ветки (%d/%d) | Shift+F: до полноты"
const F_CHOP_TREE := "F: срубить дерево | Shift+F: рубить до полноты"

# --- First Person HUD: grass ---
const F_GATHER_GRASS := "F: собрать траву | Shift+F: собирать до полноты"
const F_GATHER_GRASS_COUNT := "F: собрать траву (%d/%d) | Shift+F: до полноты"

# --- First Person HUD: farm ---
const F_HARVEST_FARM := "F: собрать еду | Shift+F: собирать до полноты"

# --- First Person HUD: pond ---
const F_COLLECT_WATER := "F: набрать воды | Shift+F: набирать до полноты"
const NEED_BUCKET_FOR_WATER := "Нужно ведро, чтобы черпать воду. Купите его на рынке."

# --- First Person HUD: forage ---
const FORAGE_SPECIALIST_ONLY := "Лесные дары и зайца может собирать только специалист. Постройте палатку охотников-собирателей."

# --- First Person HUD: toilet ---
const F_USE_TOILET_NEED := "F: воспользоваться туалетом (потребность)"
const F_USE_TOILET := "F: воспользоваться туалетом"

# --- Hero pocket ---
const POCKET_FORMAT := "Карман %d/%d%s"
const POCKET_DROPPED := "Содержимое карманов выброшено на землю."

# --- Player controller ---
const HARVEST_CANCELLED_AWAY := "Добыча отменена: вы отошли от источника."

# --- Settlement game: state labels ---
const STATE_GOING_TO_EMPLOYMENT := "Идет в службу занятости"
const STATE_PROCESSING_EMPLOYMENT := "Оформляется на работу"
const STATE_GOING_TO_MEET_ARRIVAL := "Идет встречать прибывшего"
const STATE_MEETING_ARRIVAL := "Встречает прибывшего"
const STATE_WAITING_MORNING_AT_ENTRANCE := "Ждет утра у входа"
const STATE_ESCORTING_ARRIVAL := "Сопровождает прибывшего к регистрации"

# --- Settlement game: messages ---
const PILE_EMPTY_NO_RESOURCES := "Куча пуста или в ней нет подходящих ресурсов."
const TOOK_FROM_PILE := "Взяли из кучи. %s"
const NO_WAREHOUSE_BELOW_90 := "Нет складов с заполненностью меньше 90%."
const BRANCHES_GATHERED_TREE_STANDING := "Собрано веток: %d. Дерево стоит."
const TREE_NO_BRANCHES_LEFT := "У дерева не осталось веток для ручного сбора."
const TOOK_FROM_WAREHOUSE := "Взяли %d %s со склада."
const CITIZEN_LEFT_OFFICER_POST := "%s покинул пост управляющего."
const WARNING_NO_OFFICER := "Предупреждение: В службе занятости нет чиновника! Оформление жителей приостановлено."

# --- Building menu ---
const MANAGE := "Управлять"
const MANAGE_HERO := "Управлять героем"
const NO_WORKPLACE_FOR_ROLE := "Нет рабочего места для этой роли."

# --- Campfire menu ---
const CAMPFIRE_ERA_FORMAT := "Campfire (Era: %s)\nВетки: %d/%d"
const CAMPFIRE_NO_OFFICER_HINT := "\nУправление трудом: officer не назначен. Резерв простаивает, но стройка доступна.\n"
const CAMPFIRE_OCCUPY_OFFICIAL := "Занять место чиновника"
const CAMPFIRE_OCCUPY_RESEARCHER := "Занять место исследователя"
const CAMPFIRE_OFFICIAL_TAKEN := "Место уже занято чиновником."

# --- Fire management ---
const FIRE_NAME_MAIN := "Главный костер"
const FIRE_NAME_COOKING := "Костер для готовки"
const FIRE_DYING_FORMAT := "%s догорает: топлива осталось примерно на 4 часа."
const FIRE_EMBERS_FORMAT := "%s превратился в угли. Доставьте ветки в течение 2 часов, чтобы он разгорелся сам."
const FIRE_OUT_MAIN_CONSEQUENCE := "Оформление жителей и исследования приостановлены."
const FIRE_OUT_COOK_CONSEQUENCE := "Следующий прием пищи будет сырым рационом."
const FIRE_OUT_FORMAT := "%s погас. %s"
const FIRE_RELIT_FORMAT := "%s снова горит."

# --- Workplace labor ---
const AUTOMATION_REQUIRES_OFFICER := "Автоматизация труда требует чиновника. Назначьте свободного жителя исследователем, изучите технологию «Чиновник», затем повысьте его у поста."

# --- Building lifecycle ---
const TENT_REPLACED_BY_HOUSE := "Палатка снесена, так как построен дом."

# --- Player controller: interaction ---
const WORKING_FORMAT := "Работаем: %s..."
const USING_TOILET_PERCENT := "Пользуемся туалетом %d%%"
const ACTION_CANCELLED_AWAY := "Действие прервано: вы отошли от клетки."
const HARVEST_CANCELLED_AWAY_SOURCE := "Добыча отменена: вы отошли от источника."
const GATHERED_FORMAT := "Собрано %s. %s"
const POCKET_FULL_CANNOT_GATHER := "Карман полон. Невозможно собрать %s."
const ONLY_HERO_CAN_ACT := "Только герой может выполнять действия. Остальными жителями можно только двигаться."
const WORKING_CONSTRUCTION := "Работаем: стройка..."
const WORKING_DEMOLITION := "Работаем: снос..."
const FORAGE_SPECIALIST_ONLY_SHORT := "Лесные дары и зайца может собирать только специалист. Постройте палатку охотников-собирателей."
const POCKET_FULL_TREE_HINT := "Карман полон. Дерево — на лесопилку, еду — на склад."
const POCKET_FULL_SHORT := "Карман полон."

# --- Building menu: cook campfire ---
const COOK_FIRE_BRANCHES_FORMAT := "\nВетки: %d/%d"

# --- Building lifecycle ---
const MATERIALS_YARD_READY := "Двор стройматериалов готов. Работники собирают ветки и траву (что в дефиците), или это сделает свободный житель."

# --- House menu ---
const HOUSE_NAME_STRAW_TENT := "Соломенная палатка"
const HOUSE_NAME_TARP_TENT := "Брезентовая палатка"
const HOUSE_NAME_TENT := "Палатка"
const HOUSE_NAME_HOUSE := "House"

# --- Pocket take menu ---
const TAKE_FROM_WAREHOUSE_FORMAT := "Взять товары со склада (карман %d/%d)"

# --- Settlement game: HUD hints ---
const HUD_FIRST_PERSON_HINT := "R: герой/обзор  WASD: ходить  Пробел: прыжок  Shift: бег  Мышь: осмотр  F: действие  Shift+F: всё  ПКМ: копать%s"
const HUD_OVERVIEW_HINT := "R: вид от героя. Выберите жителя и нажмите Управлять. ПКМ+перетаскивание: поворот  СКМ: панорама  Колесо: масштаб"
const HUD_BUILD_HINT_FP := "  B: стройка"
const HUD_BUILD_ROTATE_HINT := "  Q/E: поворот"

# --- Settlement game: toilet ---
const TOILET_IN_USE := "Туалет используется."
const HERO_NAME := "Герой"
const TOILET_NEED_HINT := "%s хочет в туалет. Подойдите к туалету и нажмите F, либо передайте управление ИИ."

# --- Settlement game: build ---
const ONLY_HERO_CAN_APPROVE_BUILD := "Только герой может утверждать строительство."

# --- Settlement game: gather action names ---
const GATHER_ACTION_WOOD := "Срубить дерево"
const GATHER_ACTION_BRANCHES := "Собрать ветки"
const GATHER_ACTION_GRASS := "Собрать траву"
const GATHER_ACTION_WATER := "Набрать воду"
const GATHER_ACTION_FOOD := "Собрать еду"
const GATHER_ACTION_DEFAULT := "Действие"

# --- Settlement game: harvest source info ---
const SOURCE_INFO_BRANCHES := "ветки %d/%d"
const SOURCE_INFO_GRASS := "трава %d/%d"
const SOURCE_INFO_WOOD := "дерево"
const SOURCE_INFO_WATER := "вода"
const SOURCE_INFO_FOOD := "еда"

# --- Settlement game: warehouse delivery ---
const WAREHOUSE_REJECTS_FORMAT := "Склад не принимает %s."
const DELIVERED_TO_WAREHOUSE_SUMMARY := "Сдано на склад: %s."
const POCKET_EMPTY := "Карман пуст."
const WAREHOUSE_NO_ROOM := "Нет места на складе. Постройте или расширьте склад."
const WAREHOUSE_NO_ROOM_FOR_RESOURCE := "Нет места для %s на складе."
const WAREHOUSE_NO_ROOM_IN_THIS := "Нет места для %s в этом складе."
const DELIVERED_ONE_TO_WAREHOUSE := "Сдано %d %s на склад. %s"

# --- Settlement game: work position ---
const LEFT_OFFICER_POST_FORMAT := "%s покинул пост управляющего."
const LEFT_WORKPLACE_FORMAT := "%s покинул рабочее место."
const OFFICER_POSITION_TAKEN := "Это место уже занято чиновником."
const HERO_BECAME_OFFICER := "Ваш герой стал чиновником. Переключитесь на вид сверху для управления посёлком — клавиша R."
const HERO_TOOK_RESEARCHER := "Ваш герой занял позицию исследователя."
const TOOK_TEMP_ROLE_FORMAT := "%s занял временную должность %s."

# --- Settlement game: pocket ---
const POCKET_FORMAT_INTERNAL := "Карман %d/%d%s"
const POCKET_DROPPED_INTERNAL := "Содержимое карманов выброшено на землю."
const HOME_OCCUPANCY_FORMAT := "Дом: %d/%d"
const CLOSE_MENU_HINT := "F / Esc / ПКМ — закрыть меню"
const OBSERVE_HINT := "Наблюдение: WASD — двигаться, ПКМ — выйти в обзор"
const DROP_POCKET_HINT := "T: выбросить карманы на землю"

# --- Settlement game: sawmill ---
const DELIVERED_WOOD_TO_SAWMILL := "Сдано %d дерева на лесопилку."
const TOOK_BOARDS_FROM_SAWMILL := "Взяли %d досок с лесопилки."

# --- Settlement game: construction ---
const MATERIALS_DELIVERED_TO_SITE := "Материалы сданы на стройплощадку."
const SITE_FULLY_SUPPLIED := "Стройплощадка уже полностью снабжена."
const POCKET_MISSING_MATERIALS := "В кармане нет нужных материалов: %s."

# --- Settlement game: fire refuel ---
const NO_BRANCHES_FOR_FIRE := "В кармане нет веток для костра."
const BRANCHES_ADDED_TO_FIRE := "В костер добавлено веток: %d."

# --- Settlement game: arrival ---
const NO_ONE_TO_MEET := "Никого не нужно встречать у входа."
