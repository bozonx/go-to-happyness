extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate() as Node
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _f in range(20):
		await physics_frame

	var c: Citizen = simulation.citizens[2]
	simulation.selected_builder = c
	print("selected=", simulation.selected_builder, " can_manage_perm=", simulation.player_can_manage_permanent_professions())
	print("daily_order_roles=", simulation.workforce_menu_controller.daily_order_roles() if simulation.workforce_menu_controller != null else [])

	# open daily order submenu the same way the UI does
	simulation.ui_manager.build_menu.visible = true
	SimHelper.open_daily_order_submenu(simulation)
	await process_frame

	print("build_menu_is_daily_order_menu=", simulation.build_menu_is_daily_order_menu, " build_menu.visible=", simulation.ui_manager.build_menu.visible)
	print("--- role buttons (daily) ---")
	for button in simulation.ui_manager.build_menu.role_buttons:
		var submenu: String = button.get_meta("submenu", "job")
		if submenu != "daily":
			continue
		var role: String = button.get_meta("role", "")
		print("role='", role, "' visible=", button.visible, " disabled=", button.disabled, " connected=", button.pressed.get_connections().size(), " tooltip='", button.tooltip_text, "'")

	quit(0)
