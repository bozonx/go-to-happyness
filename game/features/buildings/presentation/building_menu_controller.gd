class_name BuildingMenuController
extends RefCounted

const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const BuildingBlueprintsScript = preload("res://game/features/buildings/presentation/building_blueprints.gd")
const BuildingBlueprintLibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")
const S = preload("res://game/features/ui/domain/game_strings.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func refresh_build_menu() -> void:
	if simulation == null or simulation.ui_manager.build_menu == null:
		return
	BuildingBlueprintLibraryScript.refresh()
	simulation.ui_manager.build_menu.sync_custom_build_buttons(BuildingBlueprintLibraryScript.player_entries())
	var selected_exists: bool = is_instance_valid(simulation.selected_builder)
	var assignment_submenu_open: bool = simulation.build_menu_is_job_menu or simulation.build_menu_is_daily_order_menu
	var citizen_actions_visible: bool = selected_exists and not assignment_submenu_open and simulation.build_category.is_empty() and not simulation.build_menu_is_global

	_refresh_citizen_skills_section(selected_exists, assignment_submenu_open, citizen_actions_visible)
	var current_era_category: String = simulation.ERA_CATEGORIES[simulation.settlement.era]
	_refresh_build_buttons(current_era_category, assignment_submenu_open)
	_refresh_role_buttons(selected_exists, assignment_submenu_open)
	_refresh_build_item_positions()
	_refresh_build_title_label()


func _refresh_citizen_skills_section(selected_exists: bool, assignment_submenu_open: bool, citizen_actions_visible: bool) -> void:
	if simulation.ui_manager.build_menu.citizen_skills_label != null:
		simulation.ui_manager.build_menu.citizen_skills_label.visible = citizen_actions_visible
	if simulation.ui_manager.build_menu.manage_citizen_button != null:
		simulation.ui_manager.build_menu.manage_citizen_button.visible = citizen_actions_visible
		simulation.ui_manager.build_menu.manage_citizen_button.text = S.MANAGE if simulation.selected_builder != simulation.hero_citizen else S.MANAGE_HERO

	if simulation.ui_manager.build_menu.daily_order_submenu_btn != null:
		simulation.ui_manager.build_menu.daily_order_submenu_btn.visible = citizen_actions_visible
		simulation.ui_manager.build_menu.daily_order_submenu_btn.disabled = false
		simulation.ui_manager.build_menu.daily_order_submenu_btn.tooltip_text = ""
	if simulation.ui_manager.build_menu.job_submenu_btn != null:
		simulation.ui_manager.build_menu.job_submenu_btn.visible = citizen_actions_visible
		simulation.ui_manager.build_menu.job_submenu_btn.disabled = false
		simulation.ui_manager.build_menu.job_submenu_btn.tooltip_text = ""
	if simulation.ui_manager.build_menu.personal_night_work_button != null:
		var can_personal_night_work: bool = citizen_actions_visible and simulation.selected_builder != null and simulation.selected_builder.has_daily_order() and not simulation.selected_builder.is_employed()
		var has_overtime: bool = simulation.selected_builder != null and simulation.selected_builder.has_overtime_source("personal", simulation.day_cycle.current_day)
		simulation.ui_manager.build_menu.personal_night_work_button.visible = citizen_actions_visible
		simulation.ui_manager.build_menu.personal_night_work_button.disabled = not can_personal_night_work
		simulation.ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(has_overtime)
		simulation.ui_manager.build_menu.personal_night_work_button.tooltip_text = "Assign a job or daily order first." if not can_personal_night_work else "Continue working through the night and next workday."
	if simulation.ui_manager.build_menu.job_back_btn != null:
		simulation.ui_manager.build_menu.job_back_btn.visible = selected_exists and assignment_submenu_open


func _refresh_build_buttons(current_era_category: String, assignment_submenu_open: bool) -> void:
	for button in simulation.ui_manager.build_menu.build_buttons:
		var category_button: String = button.get_meta("category_button", "")
		if button.get_meta("category_back", false):
			button.visible = not simulation.build_category.is_empty() and not assignment_submenu_open
		elif not category_button.is_empty():
			if simulation.build_menu_is_global:
				button.visible = simulation.build_category.is_empty() and not assignment_submenu_open and category_button != current_era_category and simulation.building_availability_service.is_category_available(category_button)
			else:
				button.visible = false
		else:
			var build_type: String = button.get_meta("build_type", "")
			var menu_state: Dictionary = simulation.building_availability_service.menu_state_with_inventory(build_type, simulation.pocket)
			var has_flag: bool = simulation.village_territory_service.has_flag()
			var has_campfire: bool = simulation.village_territory_service.has_campfire()
			if not has_flag:
				if build_type != "settlement_flag":
					menu_state["enabled"] = false
					menu_state["reason"] = simulation.village_territory_service.REASON_NO_FLAG
			else:
				if build_type == "settlement_flag":
					menu_state["visible"] = false
					menu_state["enabled"] = false
				elif not has_campfire:
					if build_type != "campfire" and build_type != "warehouse":
						menu_state["enabled"] = false
						menu_state["reason"] = simulation.village_territory_service.REASON_NO_CAMPFIRE
			button.set_meta("build_menu_state", menu_state)
			if simulation.build_menu_is_global and simulation.build_category.is_empty():
				button.visible = not assignment_submenu_open and button.get_meta("category", "") == current_era_category and bool(menu_state.visible)
			else:
				button.visible = not simulation.build_category.is_empty() and button.get_meta("category", "") == simulation.build_category and not assignment_submenu_open and bool(menu_state.visible)


func _refresh_role_buttons(selected_exists: bool, assignment_submenu_open: bool) -> void:
	for button in simulation.ui_manager.build_menu.role_buttons:
		var role: String = button.get_meta("role", "")
		var hero_only: bool = button.get_meta("hero_only", false)
		var submenu: String = button.get_meta("submenu", "job")
		var is_daily_submenu: bool = submenu == "daily"
		var daily_role_enabled: bool = not is_daily_submenu or role.is_empty() or role in simulation.workforce_menu_controller.daily_order_roles() if simulation.workforce_menu_controller != null else []
		var min_era: int = simulation.min_era_for_role(role)
		var era_ok: bool = is_daily_submenu or min_era <= simulation.settlement.era
		var role_available: bool = simulation.workplace_labor_service.is_daily_order_role_available(role) if is_daily_submenu else simulation.workplace_labor_service.is_role_available(role)
		button.visible = selected_exists and ((is_daily_submenu and simulation.build_menu_is_daily_order_menu) or (not is_daily_submenu and simulation.build_menu_is_job_menu)) and daily_role_enabled and era_ok and (not hero_only or simulation.selected_builder.is_hero)
		var blocked_by_officer: bool = not is_daily_submenu and role != "official" and not simulation.player_can_manage_permanent_professions()
		button.disabled = button.visible and (blocked_by_officer or not role_available)
		if button.disabled and not role_available:
			button.tooltip_text = S.NO_WORKPLACE_FOR_ROLE
		elif button.disabled and blocked_by_officer:
			button.tooltip_text = simulation.permanent_profession_block_message()
		else:
			button.tooltip_text = ""
		if button.visible:
			var base_title: String = button.get_meta("base_title", button.text)
			if role.is_empty():
				button.text = base_title
			else:
				var skill_val := float(simulation.selected_builder.skills.get(role, 0.0))
				var active_cnt: int = simulation.workforce_menu_controller.daily_order_role_count(role) if simulation.workforce_menu_controller != null else 0 if is_daily_submenu else simulation.workforce_menu_controller.workforce_role_count(role) if simulation.workforce_menu_controller != null else 0
				var limit: int = -1 if is_daily_submenu else simulation.workforce_menu_controller.workforce_role_limit(role) if simulation.workforce_menu_controller != null else -1
				var limit_str := ""
				if limit >= 0:
					limit_str = "/%d" % limit
				button.text = "%s (Skill: %d%%) [%d%s]" % [base_title, roundi(skill_val * 100.0), active_cnt, limit_str]


func _refresh_build_item_positions() -> void:
	var row_y := 176.0
	for button in simulation.ui_manager.build_menu.build_item_buttons:
		if not button.visible:
			continue
		button.position = Vector2(16, row_y)
		row_y += 50.0
		var building_type: String = button.get_meta("build_type", "")
		var menu_state: Dictionary = button.get_meta("build_menu_state", simulation.building_availability_service.menu_state_with_inventory(building_type, simulation.pocket))
		var enabled := bool(menu_state.enabled)
		var affordable := bool(menu_state.affordable)
		button.disabled = not enabled
		button.tooltip_text = "" if enabled else (simulation.village_territory_service.placement_message(menu_state.reason) if (menu_state.reason == simulation.village_territory_service.REASON_NO_CAMPFIRE or menu_state.reason == simulation.village_territory_service.REASON_NO_FLAG) else simulation.building_availability_service.message_for_reason(menu_state.reason))
		button.modulate = Color(1, 1, 1, 1) if enabled else Color(0.55, 0.55, 0.6, 1)
		var cost_label: Label = button.get_meta("cost_label")
		if cost_label != null:
			cost_label.text = str(menu_state.cost_text)
			cost_label.add_theme_color_override("font_color", Color("cdd6df") if affordable else Color("d98a86"))


func _refresh_build_title_label() -> void:
	if simulation.ui_manager.build_menu.title_label != null:
		if simulation.build_menu_is_job_menu:
			simulation.ui_manager.build_menu.title_label.text = "Permanent Jobs\nRequires an employment officer. [n] = assigned residents."
		elif simulation.build_menu_is_daily_order_menu:
			simulation.ui_manager.build_menu.title_label.text = "Daily Orders\nNo officer required. Evening orders start next workday."
		elif not simulation.build_category.is_empty():
			simulation.ui_manager.build_menu.title_label.text = "%s buildings\nChoose a building to place." % simulation.build_category.capitalize()
		elif simulation.build_menu_is_global:
			simulation.ui_manager.build_menu.title_label.text = "%s Era Construction\nChoose a building to place." % simulation.era_name()
		else:
			simulation._show_selected_citizen_menu()


func show_building_menu() -> void:
	if simulation == null or not is_instance_valid(simulation.selected_building):
		return
	simulation.ui_manager.build_menu.visible = false
	simulation.build_menu_is_global = false
	simulation.ui_manager.building_menu.visible = true

	var is_construction: bool = simulation.is_construction_site(simulation.selected_building)

	if is_construction:
		var site_data: Variant = simulation.construction.site_for_node(simulation.selected_building)
		var type: String = site_data.building_type
		var progress: float = site_data.progress
		var builders: int = simulation._builder_count(simulation.selected_building)
		var supplied_parts: Array[String] = []
		for resource_type in site_data.required_materials:
			supplied_parts.append("%s %d/%d" % [resource_type, int(site_data.delivered_materials.get(resource_type, 0)), int(site_data.required_materials[resource_type])])
		simulation.ui_manager.building_menu_title.text = "Under Construction: %s\nMaterials: %s\nProgress: %d%%  Builders: %d" % [type.capitalize().replace("_", " "), ", ".join(supplied_parts), roundi(progress * 100.0), builders]

		simulation.ui_manager.building_cook_button.visible = false
		simulation.ui_manager.building_teacher_button.visible = false
		simulation.ui_manager.building_seller_button.visible = false
		simulation.ui_manager.building_accept_workers_button.visible = false
		simulation.ui_manager.building_dismiss_worker_button.visible = false
		simulation.ui_manager.building_upgrade_button.visible = false
		simulation.ui_manager.building_relight_button.visible = false
		simulation.ui_manager.building_demolish_button.visible = false
		simulation.ui_manager.building_cancel_construction_button.visible = true
		simulation.ui_manager.building_cancel_construction_button.position.y = 104.0
		simulation.ui_manager.building_close_button.position.y = 140.0
	else:
		var building_type: String = simulation.building_registry.building_type_for_node(simulation.selected_building)
		var definition: Dictionary = BuildingCatalogScript.definition_for(building_type)
		simulation.ui_manager.building_menu_title.text = str(definition.get("name", building_type.capitalize()))
		if BuildingTypes.is_cook_campfire(building_type):
			var cook_fire_state: Variant = simulation._fire_state_for(simulation.selected_building)
			var cook_fuel: int = cook_fire_state.total_committed_fuel()
			simulation.ui_manager.building_menu_title.text += S.COOK_FIRE_BRANCHES_FORMAT % [cook_fuel, simulation.FIRE_SUPPLY_TARGET]
		simulation.ui_manager.building_cook_button.visible = BuildingTypes.is_kitchen(building_type)
		var can_manage_professions: bool = simulation.player_can_manage_permanent_professions()
		var profession_blocked_tooltip: String = simulation.permanent_profession_block_message()
		var is_active_kitchen: bool = simulation.selected_building == simulation.canteen
		simulation.ui_manager.building_cook_button.text = "Register selected resident as permanent cook"
		simulation.ui_manager.building_cook_button.disabled = not can_manage_professions or simulation.selected_builder == null or simulation.selected_builder.is_player_controlled or not is_active_kitchen or not bool(simulation.selected_building.get_meta("accepting_workers", true))
		if not is_active_kitchen:
			simulation.ui_manager.building_cook_button.tooltip_text = "Only the active kitchen can serve meals."
		elif simulation.ui_manager.building_cook_button.disabled:
			simulation.ui_manager.building_cook_button.tooltip_text = simulation.permanent_profession_block_message() if not can_manage_professions else "Select a resident who is not under direct control."
		else:
			simulation.ui_manager.building_cook_button.tooltip_text = "Registers a permanent profession."

		simulation.ui_manager.building_teacher_button.visible = building_type == "school"
		simulation.ui_manager.building_teacher_button.disabled = not can_manage_professions or simulation.selected_builder == null or simulation.selected_builder.is_player_controlled or not bool(simulation.selected_building.get_meta("accepting_workers", true))
		simulation.ui_manager.building_teacher_button.tooltip_text = profession_blocked_tooltip if not can_manage_professions else ""

		simulation.ui_manager.building_seller_button.visible = BuildingTypes.is_market(building_type)
		simulation.ui_manager.building_seller_button.disabled = not can_manage_professions or simulation.selected_builder == null or simulation.selected_builder.is_player_controlled or not bool(simulation.selected_building.get_meta("accepting_workers", true))
		simulation.ui_manager.building_seller_button.tooltip_text = profession_blocked_tooltip if not can_manage_professions else ""

		var is_workplace: bool = simulation._is_staffed_workplace(simulation.selected_building)
		simulation.ui_manager.building_accept_workers_button.visible = is_workplace
		simulation.ui_manager.building_dismiss_worker_button.visible = is_workplace
		var next_upgrade: String = simulation.settlement.next_building_upgrade(building_type)
		simulation.ui_manager.building_upgrade_button.visible = not next_upgrade.is_empty()
		simulation.ui_manager.building_upgrade_button.text = "Upgrade to %s" % str(BuildingCatalogScript.definition_for(next_upgrade).get("name", next_upgrade))
		simulation.ui_manager.building_upgrade_button.disabled = not simulation.settlement.can_upgrade_building(building_type)
		simulation.ui_manager.building_upgrade_button.tooltip_text = "" if not simulation.ui_manager.building_upgrade_button.disabled else "Research the next level and gather its resources."
		var can_command_labor: bool = simulation.player_can_command_labor()
		var labor_blocked_tooltip: String = simulation.labor_command_block_message()
		simulation.ui_manager.building_accept_workers_button.disabled = not can_command_labor
		simulation.ui_manager.building_accept_workers_button.tooltip_text = labor_blocked_tooltip if not can_command_labor else ""
		simulation.ui_manager.building_cancel_construction_button.visible = false
		var is_demolishable: bool = BuildingCatalogScript.is_demolishable(building_type) and simulation.selected_building != simulation.entrance_stone
		simulation.ui_manager.building_demolish_button.visible = is_demolishable
		simulation.ui_manager.building_relight_button.visible = BuildingTypes.is_fire_source(building_type) and not simulation._is_fire_lit(simulation.selected_building)

		var officer: Variant = simulation._workplace_worker(simulation.selected_building)
		simulation.ui_manager.building_overtime_button.visible = is_workplace and officer != null
		var workplace_night_active: bool = simulation.citizen_daily_order_service.has_overtime_source("simulation.selected_building", simulation.selected_building) if simulation.citizen_daily_order_service != null else false
		simulation.ui_manager.building_overtime_button.disabled = not can_command_labor
		simulation.ui_manager.building_overtime_button.set_pressed_no_signal(workplace_night_active)
		simulation.ui_manager.building_overtime_button.tooltip_text = labor_blocked_tooltip if not can_command_labor else "Work through the night and the next workday."

		if is_workplace:
			var accepting: bool = bool(simulation.selected_building.get_meta("accepting_workers", true))
			simulation.ui_manager.building_accept_workers_button.text = "Stop accepting workers" if accepting else "Start accepting workers"
			simulation.ui_manager.building_accept_workers_button.tooltip_text = "This workplace is priority #%d among open workplaces of the same profession." % simulation._workplace_priority_position(simulation.selected_building) if accepting else "Reopen this workplace and move it to the front of the hiring queue."
			simulation.ui_manager.building_dismiss_worker_button.disabled = officer == null or not can_command_labor
			simulation.ui_manager.building_dismiss_worker_button.tooltip_text = labor_blocked_tooltip if not can_command_labor else ""

		var next_y := 104.0
		if simulation.ui_manager.building_accept_workers_button.visible:
			simulation.ui_manager.building_accept_workers_button.position.y = next_y
			next_y += 36.0
		if simulation.ui_manager.building_dismiss_worker_button.visible:
			simulation.ui_manager.building_dismiss_worker_button.position.y = next_y
			next_y += 36.0
		if simulation.ui_manager.building_overtime_button.visible:
			simulation.ui_manager.building_overtime_button.position.y = next_y
			next_y += 36.0
		if simulation.ui_manager.building_relight_button.visible:
			simulation.ui_manager.building_relight_button.position.y = next_y
			next_y += 36.0
		if simulation.ui_manager.building_upgrade_button.visible:
			simulation.ui_manager.building_upgrade_button.position.y = next_y
			next_y += 36.0
		if simulation.ui_manager.building_demolish_button.visible:
			simulation.ui_manager.building_demolish_button.position.y = next_y
			next_y += 36.0

		var special_button_visible: bool = simulation.ui_manager.building_cook_button.visible or simulation.ui_manager.building_teacher_button.visible or simulation.ui_manager.building_seller_button.visible
		for button in [simulation.ui_manager.building_cook_button, simulation.ui_manager.building_teacher_button, simulation.ui_manager.building_seller_button]:
			if button.visible:
				button.position.y = next_y
		if special_button_visible:
			next_y += 44.0
		else:
			next_y += 8.0
		simulation.ui_manager.building_close_button.position.y = next_y
