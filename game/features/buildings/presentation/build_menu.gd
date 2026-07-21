class_name BuildMenu
extends Panel

signal gui_input_received(event: InputEvent)
signal build_selected(building_type: String)
signal role_selected(role: String, is_daily: bool)
signal category_opened(category: String)
signal manage_citizen_pressed
signal job_submenu_requested
signal daily_order_submenu_requested
signal personal_night_work_toggled(pressed: bool)

@onready var title_label: Label = $TitleLabel
@onready var citizen_skills_label: Label = $CitizenSkillsLabel
@onready var manage_citizen_button: Button = $ManageCitizenButton
@onready var daily_order_submenu_btn: Button = $DailyOrderSubmenuButton
@onready var personal_night_work_button: CheckButton = $PersonalNightWorkButton
@onready var job_submenu_btn: Button = $JobSubmenuButton
@onready var job_back_btn: Button = $JobBackButton

var build_buttons: Array[Button] = []
var build_item_buttons: Array[Button] = []
var role_buttons: Array[Button] = []


func _ready() -> void:
	gui_input.connect(func(event): gui_input_received.emit(event))
	manage_citizen_button.pressed.connect(manage_citizen_pressed.emit)
	job_submenu_btn.pressed.connect(job_submenu_requested.emit)
	daily_order_submenu_btn.pressed.connect(daily_order_submenu_requested.emit)
	personal_night_work_button.toggled.connect(personal_night_work_toggled.emit)
	_create_buttons()


func add_build_button(title: String, building_type: String, y_position: float, category: String) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 44)
	button.pressed.connect(build_selected.emit.bind(building_type))
	button.set_meta("category", category)
	button.set_meta("build_type", building_type)
	button.add_theme_font_size_override("font_size", 15)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Small cost line under the building name, dimmed when unaffordable.
	var cost_label := Label.new()
	cost_label.position = Vector2(10, 24)
	cost_label.size = Vector2(252, 16)
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_label)
	button.set_meta("cost_label", cost_label)
	add_child(button)
	build_buttons.append(button)
	build_item_buttons.append(button)


func add_build_category_button(title: String, category: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 30)
	button.pressed.connect(category_opened.emit.bind(category))
	add_child(button)
	build_buttons.append(button)
	button.set_meta("category_button", category)


func add_build_category_back_button() -> void:
	var button := Button.new()
	button.text = "Back to categories"
	button.position = Vector2(16, 136)
	button.size = Vector2(272, 30)
	button.pressed.connect(category_opened.emit.bind(""))
	button.set_meta("category_back", true)
	add_child(button)
	build_buttons.append(button)


func add_role_button(title: String, role: String, y_position: float, hero_only := false, submenu := "job") -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 28)
	button.pressed.connect(role_selected.emit.bind(role, submenu == "daily"))
	button.set_meta("role", role)
	button.set_meta("base_title", title)
	button.set_meta("hero_only", hero_only)
	button.set_meta("submenu", submenu)
	add_child(button)
	role_buttons.append(button)


func _create_buttons() -> void:
	job_back_btn.pressed.connect(category_opened.emit.bind(""))

	# Daily orders do not require an employment officer.
	add_role_button("Clear daily order", "", 136, false, "daily")
	add_role_button("Courier", "courier", 170, false, "daily")
	add_role_button("Construction", "construction", 204, false, "daily")
	add_role_button("Gather branches", "gather_branches", 238, false, "daily")
	add_role_button("Gather grass", "gather_grass", 272, false, "daily")
	add_role_button("Collect water", "gather_water", 306, false, "daily")
	add_role_button("Cleaning", "cleaning", 340, false, "daily")
	add_role_button("Cook", "cook", 374, false, "daily")
	add_role_button("Research", "researcher", 408, false, "daily")

	# Permanent jobs require an employment officer, except the first officer
	# after its profession has been researched.
	add_role_button("Assign: construction", "construction", 136, false, "job")
	add_role_button("Assign: forestry (logs/timber)", "forestry", 170, false, "job")
	add_role_button("Assign: farming", "farming", 204, false, "job")
	add_role_button("Assign: excavation", "excavation", 238, false, "job")
	add_role_button("Assign: gather branches", "gather_branches", 272, false, "job")
	add_role_button("Assign: forage food", "gather_food", 306, false, "job")
	add_role_button("Assign: courier", "courier", 340, false, "job")
	add_role_button("Assign: craftsman", "craftsman", 374, false, "job")
	add_role_button("Assign: employment officer", "official", 408, false, "job")

	# Era category buttons (shown on main build menu)
	add_build_category_button("Tent era", "tent", 136)
	add_build_category_button("Earth era", "earth", 170)
	add_build_category_button("Clay era", "clay", 204)
	add_build_category_button("Wood era", "wood", 238)
	add_build_category_button("Stone era", "stone", 272)
	add_build_category_button("Brick era", "brick", 306)
	add_build_category_back_button()

	add_build_button("Флаг поселения", "settlement_flag", 142, "tent")
	add_build_button("Campfire", "campfire", 176, "tent")
	add_build_button("Campfire Level 2", "campfire_lvl2", 200, "tent")
	add_build_button("Campfire Level 3", "campfire_lvl3", 200, "tent")
	add_build_button("Бадминтонная площадка", "gathering_place", 193, "tent")
	add_build_button("Костер для готовки ур. 1", "cook_campfire", 227, "tent")
	add_build_button("Временная палатка на 4 жителя", "tent", 244, "tent")
	add_build_button("Соломенная палатка", "straw_tent", 278, "tent")
	add_build_button("Брезентовая палатка", "tarp_tent", 312, "tent")
	add_build_button("Соломенная палатка собирателя", "straw_forager_tent", 346, "tent")
	add_build_button("Брезентовая палатка собирателя", "tarp_forager_tent", 380, "tent")
	add_build_button("Соломенный двор материалов", "straw_materials_yard", 414, "tent")
	add_build_button("Брезентовый двор материалов", "tarp_materials_yard", 448, "tent")
	add_build_button("Соломенная ремесленная палатка", "straw_craft_tent", 482, "tent")
	add_build_button("Брезентовая ремесленная палатка", "tarp_craft_tent", 516, "tent")
	add_build_button("Сборщик росы", "dew_collector", 550, "tent")
	add_build_button("Улучшенный сборщик росы", "advanced_dew_collector", 584, "tent")
	add_build_button("Куча материалов (Склад ур. 1)", "warehouse", 618, "tent")
	add_build_button("Склад с соломенным навесом", "straw_warehouse", 652, "tent")
	add_build_button("Склад с брезентовым навесом", "tarp_warehouse", 686, "tent")
	add_build_button("Соломенный торговый шатер", "straw_trade_tent", 720, "tent")
	add_build_button("Брезентовый торговый шатер", "tarp_trade_tent", 754, "tent")
	add_build_button("Соломенный общественный туалет", "toilet_tent", 788, "tent")
	add_build_button("Брезентовый общественный туалет", "tarp_toilet", 822, "tent")
	add_build_button("Столб границы", "boundary_post", 856, "tent")

	add_build_button("Dugout", "dugout", 176, "earth")
	add_build_button("Earth house", "earth_house", 210, "earth")
	add_build_button("Smithy", "smithy", 244, "earth")
	add_build_button("Hide workshop", "hide_worker", 278, "earth")
	add_build_button("Earth market", "earth_market", 312, "earth")
	add_build_button("Earth Assembly", "earth_assembly", 346, "earth")
	add_build_button("Dugout kitchen", "dugout_kitchen", 380, "earth")
	add_build_button("Земляной туалет ур. 1", "toilet_earth", 414, "earth")
	add_build_button("Земляной туалет ур. 2", "toilet_earth_lvl2", 448, "earth")
	add_build_button("Земляной туалет ур. 3", "toilet_earth_lvl3", 482, "earth")

	add_build_button("Clay house", "clay_house", 176, "clay")
	add_build_button("Clay workshop", "clay_workshop", 210, "clay")
	add_build_button("Clay market", "clay_market", 244, "clay")
	add_build_button("Clay lodge", "clay_lodge", 278, "clay")
	add_build_button("Clay bakery", "clay_bakery", 312, "clay")
	add_build_button("School", "school", 346, "clay")
	add_build_button("Глиняный туалет ур. 1", "toilet_clay", 380, "clay")
	add_build_button("Глиняный туалет ур. 2", "toilet_clay_lvl2", 414, "clay")
	add_build_button("Глиняный туалет ур. 3", "toilet_clay_lvl3", 448, "clay")

	add_build_button("Sawmill - logs + kit", "sawmill", 176, "wood")
	add_build_button("Farm", "farm", 210, "wood")
	add_build_button("Canteen", "canteen", 244, "wood")
	add_build_button("Wood house", "house", 278, "wood")
	add_build_button("Wood house Level 2", "house_lvl2", 278, "wood")
	add_build_button("Wood house Level 3", "house_lvl3", 278, "wood")
	add_build_button("Park", "park", 312, "wood")
	add_build_button("Wood market", "wood_market", 346, "wood")
	add_build_button("Wooden town hall", "wood_town_hall", 380, "wood")
	add_build_button("Деревянный туалет ур. 1", "toilet_wood", 414, "wood")
	add_build_button("Деревянный туалет ур. 2", "toilet_wood_lvl2", 448, "wood")
	add_build_button("Деревянный туалет ур. 3", "toilet_wood_lvl3", 482, "wood")

	add_build_button("Stone house", "stone_house", 176, "stone")
	add_build_button("Masonry workshop", "masonry_workshop", 210, "stone")
	add_build_button("Stone market", "stone_market", 244, "stone")
	add_build_button("Stone prefecture", "stone_prefecture", 278, "stone")
	add_build_button("Stone tavern", "stone_tavern", 312, "stone")
	add_build_button("Гильдия строителей", "builders_guild", 346, "stone")
	add_build_button("Каменный туалет ур. 1", "toilet_stone", 380, "stone")
	add_build_button("Каменный туалет ур. 2", "toilet_stone_lvl2", 414, "stone")
	add_build_button("Каменный туалет ур. 3", "toilet_stone_lvl3", 448, "stone")

	add_build_button("Brick kiln", "brick_factory", 176, "brick")
	add_build_button("Materials factory", "materials_factory", 210, "brick")
	add_build_button("Brick market", "brick_market", 244, "brick")
	add_build_button("Brick City Hall", "brick_city_hall", 278, "brick")
	add_build_button("Brick restaurant", "brick_restaurant", 312, "brick")
	add_build_button("Brick house", "brick_house", 346, "brick")
	add_build_button("Строительная фирма", "construction_company", 380, "brick")
	add_build_button("Кирпичный туалет ур. 1", "toilet_brick", 414, "brick")
	add_build_button("Кирпичный туалет ур. 2", "toilet_brick_lvl2", 448, "brick")
	add_build_button("Кирпичный туалет ур. 3", "toilet_brick_lvl3", 482, "brick")
