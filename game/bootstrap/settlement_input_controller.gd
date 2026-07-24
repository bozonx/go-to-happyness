class_name SettlementInputController
extends RefCounted

## Handles keyboard/mouse input routing for SettlementGame.
## Extracted from SettlementGame to reduce its method count.
## Lifecycle hooks (_input, _unhandled_input) remain on the Node
## and delegate here.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if handle_menu_right_click():
			game.get_viewport().set_input_as_handled()


func handle_menu_right_click() -> bool:
	var ui := game.ui_manager
	if ui.build_menu.visible:
		if not game.build_category.is_empty():
			game._open_build_category("")
		elif game.build_menu_is_job_menu or game.build_menu_is_daily_order_menu:
			game._close_assignment_submenu()
		else:
			ui.build_menu.visible = false
			game.build_menu_is_global = false
			if game.selected_builder != null:
				game.selected_builder = null
			if game.building_menu_controller != null:
				game.building_menu_controller.refresh_build_menu()
		if game.is_first_person and not is_first_person_menu_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return true
	if game.pocket_menu_open:
		if game.pocket_take_menu_controller != null:
			game.pocket_take_menu_controller.close_pocket_take_menu()
		return true
	if ui.campfire_orders_menu != null and ui.campfire_orders_menu.visible:
		ui.campfire_orders_menu.visible = false
		ui.campfire_menu.visible = true
		return true
	if ui.campfire_story_menu != null and ui.campfire_story_menu.visible:
		ui.campfire_story_menu.visible = false
		ui.campfire_menu.visible = true
		return true
	if ui.research_menu != null and ui.research_menu.visible:
		ui.research_menu.visible = false
		ui.campfire_menu.visible = true
		return true
	if ui.workforce_menu != null and ui.workforce_menu.visible:
		if game.workforce_menu_controller != null:
			game.workforce_menu_controller.hide_workforce_menu()
		ui.campfire_menu.visible = true
		return true
	if ui.entrance_order_modal != null and ui.entrance_order_modal.visible:
		ui.entrance_order_modal.visible = false
		ui.entrance_menu.visible = true
		return true
	if ui.message_log_panel != null and ui.message_log_panel.is_modal_visible():
		ui.message_log_panel.close_modal()
		return true
	var any_menu_visible := (
			ui.entrance_menu.visible or ui.house_menu.visible
			or ui.school_menu.visible or ui.materials_factory_menu.visible
			or ui.campfire_menu.visible or ui.market_menu.visible
			or ui.warehouse_menu.visible or ui.building_menu.visible)
	if ui.decision_menu != null and ui.decision_menu.visible:
		any_menu_visible = true
	if any_menu_visible:
		close_context_menus()
		return true
	return false


func handle_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_5 and event.pressed and not event.echo:
		if SettlementGame.SaveGameServiceScript.save_quicksave(game):
			game._update_interface("Игра сохранена (клавиша 5)")
		else:
			game._update_interface("Ошибка сохранения игры")
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_6 and event.pressed and not event.echo:
		if SettlementGame.SaveGameServiceScript.has_quicksave():
			if SettlementGame.SaveGameServiceScript.load_quicksave(game):
				game._update_interface("Игра загружена (клавиша 6)")
			else:
				game._update_interface("Ошибка загрузки игры")
		else:
			game._update_interface("Сохранение не найдено")
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_F and event.ctrl_pressed and event.pressed and not event.echo:
		if OS.is_debug_build():
			game._grant_debug_resources()
			game.get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_DELETE and event.pressed and not event.echo:
		if game.is_instance_valid(game.selected_building):
			game.building_lifecycle_service.mark_building_for_demolition(game.selected_building)
			game.get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		game.player_controller.toggle_hero_view()
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_B and event.pressed and not event.echo:
		if game._can_hero_build():
			game._toggle_global_build_menu()
			if game.is_first_person:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if game.ui_manager.build_menu.visible else Input.MOUSE_MODE_CAPTURED)
		else:
			game._update_interface(SettlementGame.S.ONLY_HERO_CAN_APPROVE_BUILD)
		game.get_viewport().set_input_as_handled()
		return
	if not game.build_mode.is_empty() and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Q or event.keycode == KEY_E):
		game.build_rotation_quarters = posmod(game.build_rotation_quarters + (-1 if event.keycode == KEY_Q else 1), 4)
		game._move_selection(game.selected_world_position)
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if game.pocket_menu_open:
			if game.pocket_take_menu_controller != null:
				game.pocket_take_menu_controller.close_pocket_take_menu()
			game.get_viewport().set_input_as_handled()
			return
	if game.is_first_person:
		_handle_first_person_input(event)
		return
	_handle_overview_input(event)


func _handle_first_person_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_T and event.pressed and not event.echo:
		if not is_first_person_menu_open():
			if game.hero_pocket_service != null:
				game.hero_pocket_service.drop_pocket_on_ground()
		game.get_viewport().set_input_as_handled()
		return
	elif event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		game.player_controller.start_interaction(event.shift_pressed)
		game.get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseMotion:
		if not is_first_person_menu_open():
			game.player_yaw -= event.relative.x * 0.0035
			game.player_pitch = clampf(game.player_pitch - event.relative.y * 0.003, deg_to_rad(-70.0), deg_to_rad(65.0))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not game.build_mode.is_empty() and not is_first_person_menu_open():
			var viewport_center := game.get_viewport().get_visible_rect().size * 0.5
			var build_point: Variant = game._terrain_point_at_screen_position(viewport_center)
			if build_point != null:
				game._place_building(build_point)
		elif not is_first_person_menu_open():
			game._first_person_select_at_crosshair()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if game.pocket_menu_open:
			if game.pocket_take_menu_controller != null:
				game.pocket_take_menu_controller.close_pocket_take_menu()
		elif not game.build_mode.is_empty():
			game._cancel_build_action()
		else:
			game.player_controller.leave_first_person_to_hero_overview()
	game.get_viewport().set_input_as_handled()


func _handle_overview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if game.get_viewport().gui_get_hovered_control() != null:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		game.camera_distance = maxf(3.0, game.camera_distance - 2.0)
		if game.camera_controller != null:
			game.camera_controller.apply_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		game.camera_distance = minf(80.0, game.camera_distance + 2.0)
		if game.camera_controller != null:
			game.camera_controller.apply_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		game.is_panning_camera = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and (not game.build_mode.is_empty() or (game.selected_builder != null and game.dig_mode)):
			game._cancel_build_action()
			game.get_viewport().set_input_as_handled()
			return
		if event.pressed:
			game.is_rotating_camera = true
			game.right_mouse_dragged = false
		else:
			game.is_rotating_camera = false
			if not game.right_mouse_dragged:
				close_context_menus()
	elif event is InputEventMouseMotion:
		if game.is_rotating_camera:
			if event.relative.length_squared() > 0.0:
				game.right_mouse_dragged = true
			if game.camera_controller != null:
				game.camera_controller.rotate_yaw_pitch(event.relative)
		elif game.is_panning_camera:
			if game.camera_controller != null:
				game.camera_controller.pan(event.relative)
		elif not game.build_mode.is_empty() or (game.selected_builder != null and game.dig_mode):
			if game.get_viewport().gui_get_hovered_control() == null:
				var terrain_point: Variant = game._terrain_point_at_screen_position(event.position)
				if terrain_point != null:
					game._move_selection(terrain_point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if game.selected_builder != null and game.dig_mode:
			var dig_point: Variant = game._terrain_point_at_screen_position(event.position)
			if dig_point != null:
				game.excavation_service.place_dig_site(dig_point)
		elif not game.build_mode.is_empty():
			var build_point: Variant = game._terrain_point_at_screen_position(event.position)
			if build_point != null:
				game._place_building(build_point)
		else:
			game._select_citizen_at(event.position)


func is_first_person_menu_open() -> bool:
	if not game.is_first_person:
		return false
	var ui := game.ui_manager
	if game.pocket_menu_open or ui.build_menu.visible:
		return true
	if (
			ui.entrance_menu.visible or ui.house_menu.visible
			or ui.school_menu.visible or ui.materials_factory_menu.visible
			or ui.campfire_menu.visible or ui.market_menu.visible
			or ui.warehouse_menu.visible or ui.building_menu.visible
	):
		return true
	if ui.entrance_order_modal != null and ui.entrance_order_modal.visible:
		return true
	if ui.campfire_orders_menu != null and ui.campfire_orders_menu.visible:
		return true
	if ui.campfire_story_menu != null and ui.campfire_story_menu.visible:
		return true
	if ui.research_menu != null and ui.research_menu.visible:
		return true
	if ui.workforce_menu != null and ui.workforce_menu.visible:
		return true
	if ui.decision_menu != null and ui.decision_menu.visible:
		return true
	if ui.message_log_panel != null and ui.message_log_panel.is_modal_visible():
		return true
	return false


func update_first_person_mouse_and_crosshair() -> void:
	if not game.is_first_person:
		return
	var menu_open := is_first_person_menu_open()
	if game.ui_manager.crosshair != null:
		game.ui_manager.crosshair.visible = not menu_open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED)


func close_context_menus() -> void:
	var ui := game.ui_manager
	game.build_mode = ""
	game.dig_mode = false
	game.world_setup.selection_marker.visible = false
	game._show_territory_overlay(false)
	game.is_rotating_camera = false
	ui.entrance_menu.visible = false
	if ui.entrance_order_modal != null:
		ui.entrance_order_modal.visible = false
	ui.house_menu.visible = false
	ui.school_menu.visible = false
	ui.materials_factory_menu.visible = false
	ui.build_menu.visible = false
	ui.campfire_menu.visible = false
	if ui.campfire_orders_menu != null:
		ui.campfire_orders_menu.visible = false
	ui.market_menu.visible = false
	ui.warehouse_menu.visible = false
	ui.building_menu.visible = false
	if ui.research_menu != null:
		ui.research_menu.visible = false
	if ui.decision_menu != null:
		ui.decision_menu.visible = false
	if ui.campfire_story_menu != null:
		ui.campfire_story_menu.visible = false
	if ui.message_log_panel != null:
		ui.message_log_panel.close_modal()
	if game.pocket_take_menu_controller != null:
		game.pocket_take_menu_controller.close_pocket_take_menu()
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.hide_workforce_menu()
	game.selected_house = null
	game.selected_entrance = null
	game.selected_school = null
	game.selected_materials_factory = null
	game.selected_campfire = null
	game.selected_market = null
	game.selected_warehouse = null
	game.selected_building = null
	game.selected_builder = null
	game.build_category = ""
	game.build_menu_is_job_menu = false
	game.build_menu_is_daily_order_menu = false
	game.build_menu_is_global = false
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
	if game.is_first_person and not is_first_person_menu_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func on_context_menu_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close_context_menus()
		game.get_viewport().set_input_as_handled()
