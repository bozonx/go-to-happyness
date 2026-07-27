class_name SettlementSelectionController
extends RefCounted

## Handles citizen/building selection from screen clicks and manages the
## context menu lifecycle that follows. Extracted from SettlementGame to
## reduce its method count.
## Lifecycle hooks (_input, _unhandled_input) remain on the Node and
## delegate here via input_controller.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func select_citizen_at(screen_position: Vector2) -> void:
	var visible_citizen := _citizen_at_screen_position(screen_position)
	if visible_citizen != null:
		select_citizen(visible_citizen)
		return
	var from := game.camera.project_ray_origin(screen_position)
	var to := from + game.camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 4
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# Clicking empty ground clears the current selection and its menu.
		game.input_controller.close_context_menus()
		return
	# Switching to a different building always dismisses the previously open
	# menu first, so only one context menu is ever visible at a time.
	_hide_all_selection_menus()
	var parent := hit.collider.get_parent() as Node3D
	if not hit.collider.is_in_group("school_selector"):
		game.selected_builder = null
	game.ui_manager.build_menu.visible = false
	game.build_menu_is_global = false
	# Generic building selectors share the same menu.
	if hit.collider.is_in_group("cook_campfire_selector") or hit.collider.is_in_group("construction_selector") or hit.collider.is_in_group("building_selector"):
		game.selected_building = parent
		if game.building_menu_controller != null:
			game.building_menu_controller.show_building_menu()
		return
	# Dedicated menu selectors: each sets its own selection and opens its menu.
	if hit.collider.is_in_group("entrance_selector"):
		game.selected_entrance = parent
		_open_dedicated_menu(parent, game.entrance_menu_controller, &"show_entrance_menu")
		return
	if hit.collider.is_in_group("campfire_selector"):
		game.selected_campfire = parent
		_open_dedicated_menu(parent, game.campfire_menu_controller, &"show_campfire_menu")
		return
	if hit.collider.is_in_group("market_selector"):
		game.selected_market = parent
		_open_dedicated_menu(parent, game.market_menu_controller, &"show_market_menu")
		return
	if hit.collider.is_in_group("warehouse_selector"):
		game.selected_warehouse = parent
		_open_dedicated_menu(parent, game.warehouse_menu_controller, &"show_warehouse_menu")
		return
	# Custom handlers with extra UI logic.
	if hit.collider.is_in_group("house_selector"):
		game.selected_house = parent
		game.selected_building = parent
		game.selected_builder = null
		game.ui_manager.build_menu.visible = false
		show_house_menu()
		game.update_interface("House selected. Recruit a new resident when a bed is free.")
		return
	if hit.collider.is_in_group("school_selector"):
		game.selected_school = parent
		game.selected_building = parent
		game.ui_manager.house_menu.visible = false
		game.ui_manager.build_menu.visible = false
		if game.school_menu_controller != null:
			game.school_menu_controller.show_school_menu()
		return
	if hit.collider.is_in_group("materials_factory_selector"):
		game.selected_materials_factory = parent
		game.selected_building = parent
		game.selected_house = null
		game.selected_school = null
		game.ui_manager.house_menu.visible = false
		game.ui_manager.school_menu.visible = false
		game.ui_manager.build_menu.visible = false
		_show_materials_factory_menu()
		game.update_interface("Materials factory selected. Assign workers to produce materials.")
		return
	if not hit.collider.is_in_group("citizen_selector"):
		return
	select_citizen(hit.collider.get_parent() as Citizen)


func _open_dedicated_menu(building: Node3D, menu_controller: RefCounted, show_method: StringName) -> void:
	game.selected_building = building
	if menu_controller != null:
		menu_controller.call(show_method)


func _hide_all_selection_menus() -> void:
	# Hides every building context menu and clears their selections, but leaves
	# the currently selected citizen untouched (the school menu needs it).
	var ui := game.ui_manager
	ui.house_menu.visible = false
	ui.entrance_menu.visible = false
	ui.school_menu.visible = false
	ui.materials_factory_menu.visible = false
	ui.campfire_menu.visible = false
	if ui.campfire_story_menu != null:
		ui.campfire_story_menu.visible = false
	if ui.campfire_orders_menu != null:
		ui.campfire_orders_menu.visible = false
	ui.market_menu.visible = false
	ui.warehouse_menu.visible = false
	ui.building_menu.visible = false
	if ui.research_menu != null:
		ui.research_menu.visible = false
	if ui.decision_menu != null:
		ui.decision_menu.visible = false
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.hide_workforce_menu()
	game.build_category = ""
	game.build_menu_is_job_menu = false
	game.build_menu_is_daily_order_menu = false
	game.selected_house = null
	game.selected_entrance = null
	game.selected_school = null
	game.selected_materials_factory = null
	game.selected_campfire = null
	game.selected_market = null
	game.selected_warehouse = null
	game.selected_building = null


func _citizen_at_screen_position(screen_position: Vector2) -> Citizen:
	var closest: Citizen
	var closest_distance := 22.0
	for citizen in game.citizens:
		if not is_instance_valid(citizen) or game.camera.is_position_behind(citizen.global_position):
			continue
		var distance := game.camera.unproject_position(citizen.global_position + Vector3.UP * 0.9).distance_to(screen_position)
		if distance < closest_distance:
			closest = citizen
			closest_distance = distance
	return closest


func select_citizen(clicked_citizen: Citizen) -> void:
	if clicked_citizen == null:
		return
	if game.selected_builder != null and game.selected_builder.can_handle_entry_logistics() and clicked_citizen != game.selected_builder:
		game.selected_builder.courier_worker = clicked_citizen
		game.request_courier_dispatch()
		game.update_interface("%s assigned to this worker. Click another worker to reassign." % ("Courier" if game.selected_builder.is_courier() else "Daily courier"))
		return
	game.selected_builder = clicked_citizen
	_hide_all_selection_menus()
	game.build_mode = ""
	game.build_category = ""
	game.build_menu_is_global = false
	game.world_setup.selection_marker.visible = false
	game.build_controller.show_territory_overlay(false)
	game.ui_manager.build_menu.visible = true
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
	show_selected_citizen_menu()
	game.update_interface("Citizen selected. Choose a building in the lower-right menu.")


func show_selected_citizen_menu() -> void:
	if game.selected_builder == null:
		return
	var assignment := "Unregistered"
	if game.selected_builder.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
		if game.selected_builder.has_daily_order():
			assignment = "Daily order: %s" % game.selected_builder.daily_order_role.replace("_", " ")
		else:
			assignment = "No permanent work%s" % (": " + game.selected_builder.daily_order_role.replace("_", " ") if not game.selected_builder.daily_order_role.is_empty() else "")
	elif game.selected_builder.employment_state == Citizen.EmploymentState.EMPLOYED:
		assignment = "Employed: %s" % game.selected_builder.permanent_role.replace("_", " ")
	elif game.selected_builder.employment_state == Citizen.EmploymentState.REGISTERING:
		assignment = "Registering"
	if not game.selected_builder.training_role.is_empty():
		assignment = "Training %s %d/10" % [game.selected_builder.training_role.capitalize(), game.selected_builder.training_days_completed]
	var home_label := "No home" if not is_instance_valid(game.selected_builder.home) else "House"
	var effect_label := "Meal buff" if game.selected_builder.buffs.has("canteen_meal") else ("Tent debuff" if game.selected_builder.debuffs.has("tent") else "None")
	if game.build_category.is_empty():
		game.ui_manager.build_menu.title_label.text = "%s  Sat: %d/%d%%  Food: %d%%\nHome: %s  Effect: %s\nTask: %s" % [game.selected_builder.role_label(), roundi(game.selected_builder.satisfaction), roundi(game.selected_builder.get_satisfaction_cap()), roundi(game.selected_builder.hunger), home_label, effect_label, assignment]
		game.ui_manager.build_menu.citizen_skills_label.text = "Skills\nBuild %.0f%%  Wood %.0f%%\nFarm %.0f%%  Dig %.0f%%" % [float(game.selected_builder.skills.get("construction", 0.0)) * 100.0, float(game.selected_builder.skills.get("forestry", 0.0)) * 100.0, float(game.selected_builder.skills.get("farming", 0.0)) * 100.0, float(game.selected_builder.skills.get("excavation", 0.0)) * 100.0]
		game.ui_manager.build_menu.citizen_skills_label.visible = true
	game.ui_manager.build_menu.title_label.add_theme_color_override("font_color", game.selected_builder.specialization_color())


func show_house_menu() -> void:
	if game.house_menu_controller != null:
		game.house_menu_controller.show_house_menu()


func _show_materials_factory_menu() -> void:
	if game.selected_materials_factory == null:
		return
	game.ui_manager.materials_factory_menu.visible = true
	game.ui_manager.materials_factory_menu_title.text = "Materials factory\nAssign workers to produce materials."


func on_build_menu_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		return
	if not game.build_category.is_empty():
		game.build_controller.open_build_category("")
	elif game.build_menu_is_job_menu or game.build_menu_is_daily_order_menu:
		close_assignment_submenu()
	else:
		game.ui_manager.build_menu.visible = false
		game.build_menu_is_global = false
		if game.selected_builder != null:
			game.selected_builder = null
	game.get_viewport().set_input_as_handled()


func open_job_submenu() -> void:
	game.build_menu_is_job_menu = true
	game.build_menu_is_daily_order_menu = false
	game.build_category = ""
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()


func open_daily_order_submenu() -> void:
	game.build_menu_is_daily_order_menu = true
	game.build_menu_is_job_menu = false
	game.build_category = ""
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()


func close_assignment_submenu() -> void:
	game.build_menu_is_job_menu = false
	game.build_menu_is_daily_order_menu = false
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
