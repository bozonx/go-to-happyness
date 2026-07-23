extends SceneTree

func _appoint_test_official(simulation: Node, citizen: Citizen) -> void:
	simulation.settlement.complete_research("official")
	if not is_instance_valid(simulation.campfire_node):
		var centre := Node3D.new()
		centre.set_meta("service_position", citizen.global_position)
		simulation.add_child(centre)
		simulation.campfire_node = centre
	citizen.global_position = simulation._employment_center_position()
	simulation._appoint_official(citizen, simulation.campfire_node)


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame

	simulation.selected_builder = simulation.hero_citizen
	_appoint_test_official(simulation, simulation.hero_citizen)
	simulation._refresh_build_menu()

	simulation._open_job_submenu()
	assert(simulation.build_menu_is_job_menu)

	# In the tent era, permanent jobs tied to later-era buildings are hidden.
	var hidden_in_tent := ["forestry", "farming"]
	for button in simulation.build_menu.role_buttons:
		if str(button.get_meta("submenu", "")) != "job":
			continue
		var role := str(button.get_meta("role", ""))
		if role in hidden_in_tent:
			assert(not button.visible, "Role %s should be hidden in TENT era" % role)

	# Advance to the wood era: wood-era jobs become visible but disabled
	# because no sawmill or farm has been built yet.
	simulation.settlement.era = SettlementState.Era.WOOD
	simulation._refresh_build_menu()

	for button in simulation.build_menu.role_buttons:
		if str(button.get_meta("submenu", "")) != "job":
			continue
		var role := str(button.get_meta("role", ""))
		if role in hidden_in_tent:
			assert(button.visible, "Role %s should be visible in WOOD era" % role)
			assert(button.disabled, "Role %s should be disabled without a workplace" % role)

	# Daily orders remain visible alongside the job menu.
	simulation._open_daily_order_submenu()
	assert(simulation.build_menu_is_daily_order_menu)
	var construction_daily_button: Button = null
	for button in simulation.build_menu.role_buttons:
		if str(button.get_meta("submenu", "")) == "daily" and str(button.get_meta("role", "")) == "construction":
			construction_daily_button = button
			break
	assert(construction_daily_button != null)
	assert(construction_daily_button.visible)
	assert(not construction_daily_button.disabled)

	print("Permanent job menu tests passed.")
	quit(0)
