extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Verifies initial settlement state: citizens, economy, AI, hero, build menu,
## officer delegation, and citizen validation.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	# Core settlement state
	assert(simulation.citizens.size() == simulation.POPULATION)
	assert(simulation.settlement.money == SettlementState.TENT_STARTING_MONEY)
	assert(simulation.settlement.amount("food") == SettlementState.TENT_STARTING_FOOD)
	assert(simulation.settlement.amount("water") == SettlementState.TENT_STARTING_WATER)
	assert(simulation.settlement.branches == 0)
	assert(is_instance_valid(simulation.citizen_ai))
	assert(simulation.citizen_ai.brain_count() == simulation.citizens.size())
	assert(simulation.citizen_ai.goal_count() == 16)
	assert(simulation.citizen_needs_service != null)
	assert(simulation.citizen_ai.director.provider_count() == 10)
	# Bootstrap dependencies that retain object references must be constructed in
	# dependency order. In particular, fire management reads event flags.
	assert(simulation.event_service != null)
	assert(simulation.fire_management_service.event_service == simulation.event_service)

	# Natural objects are owned by the terrain scene but retain their registered
	# source records, so moving presentation ownership cannot make them inert.
	var landscape_objects := simulation.get_node("WorldTerritory/LandscapeObjects") as Node3D
	assert(not simulation.tree_nodes.is_empty())
	assert(not simulation.grass_sources.is_empty())
	assert(not simulation.forage_sources.is_empty())
	assert(not simulation.rabbit_sources.is_empty())
	assert(simulation.tree_nodes.values()[0].get_parent() == landscape_objects)
	assert((simulation.grass_sources.values()[0] as GrassSourceRecord).node.get_parent() == landscape_objects)
	assert((simulation.forage_sources.values()[0] as ForageSourceRecord).node.get_parent() == landscape_objects)
	assert((simulation.rabbit_sources.values()[0] as RabbitSourceRecord).node.get_parent() == landscape_objects)
	assert(simulation.resource_piles.any(func(pile): return pile.node.get_parent() == landscape_objects))

	# Hero citizen
	assert(is_instance_valid(simulation.hero_citizen))
	assert(simulation.hero_citizen.is_hero)
	assert(simulation.hero_citizen.specialization == "unassigned")
	assert(simulation.hero_citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK)
	assert(simulation.is_first_person)
	assert(simulation.player_citizen == simulation.hero_citizen)
	assert(SimHelper.player_can_command_labor(simulation))
	# Hero proximity checks must share the live natural-resource registries.
	# A stale empty registry makes first-person grass gathering cancel at once.
	var hero_start_position: Vector3 = simulation.hero_citizen.global_position
	var grass_source: GrassSourceRecord = simulation.grass_sources.values()[0]
	simulation.hero_citizen.global_position = grass_source.node.global_position
	assert(simulation.hero_interaction_service.nearby_grass_source())
	simulation.hero_citizen.global_position = hero_start_position

	# Build menu submenus
	simulation.selected_builder = simulation.hero_citizen
	SimHelper.refresh_build_menu(simulation)
	assert(simulation.ui_manager.build_menu.daily_order_submenu_btn.visible)
	assert(not simulation.ui_manager.build_menu.daily_order_submenu_btn.disabled)
	assert(simulation.ui_manager.build_menu.job_submenu_btn.visible)
	assert(not simulation.ui_manager.build_menu.job_submenu_btn.disabled)
	SimHelper.open_job_submenu(simulation)
	assert(simulation.build_menu_is_job_menu)
	SimHelper.open_daily_order_submenu(simulation)
	assert(simulation.build_menu_is_daily_order_menu)

	# Daily order role buttons visible and enabled
	var construction_daily_button: Button = null
	for button in simulation.ui_manager.build_menu.role_buttons:
		if str(button.get_meta("submenu", "")) == "daily" and str(button.get_meta("role", "")) == "construction":
			construction_daily_button = button
			break
	assert(construction_daily_button != null)
	assert(construction_daily_button.visible)
	assert(not construction_daily_button.disabled)
	construction_daily_button.emit_signal("pressed")
	assert(simulation.hero_citizen.daily_order_role == "construction")
	assert(not simulation.build_menu_is_daily_order_menu)
	simulation.selected_builder = simulation.hero_citizen
	SimHelper.open_daily_order_submenu(simulation)
	var cleaning_daily_button: Button = null
	for button in simulation.ui_manager.build_menu.role_buttons:
		if str(button.get_meta("submenu", "")) == "daily" and str(button.get_meta("role", "")) == "cleaning":
			cleaning_daily_button = button
			break
	assert(cleaning_daily_button != null)
	assert(cleaning_daily_button.visible)
	assert(not cleaning_daily_button.disabled)
	SimHelper.close_assignment_submenu(simulation)

	# Officer appointment and delegation
	SimHelper.appoint_test_official(simulation, simulation.hero_citizen)
	var delegated_officer: Citizen = simulation.citizens[1]
	SimHelper.appoint_test_official(simulation, delegated_officer)
	assert(SimHelper.player_can_command_labor(simulation))
	SimHelper.appoint_test_official(simulation, simulation.hero_citizen)
	assert(SimHelper.player_can_command_labor(simulation))

	# A daily order releases first-person control but does not break the permanent job.
	simulation.selected_builder = simulation.hero_citizen
	simulation.hero_citizen.set_player_controlled(true)
	SimHelper.set_selected_work_role(simulation, "gather_grass", true)
	assert(not simulation.hero_citizen.is_player_controlled)
	assert(simulation.hero_citizen.employment_state == Citizen.EmploymentState.EMPLOYED)
	assert(simulation.hero_citizen.permanent_role == "official")
	assert(simulation.hero_citizen.daily_order_role == "gather_grass")
	SimHelper.appoint_test_official(simulation, simulation.hero_citizen)

	# Citizen validation
	assert(is_instance_valid(simulation.entrance_stone))
	var hero_count := 0
	for citizen in simulation.citizens:
		hero_count += 1 if citizen.is_hero else 0
	assert(hero_count == 1)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.is_inside_tree())
		assert(citizen.is_in_group("citizens"))
		assert(citizen.home == null)
		assert(is_finite(citizen.global_position.x) and is_finite(citizen.global_position.y) and is_finite(citizen.global_position.z))
		assert(citizen.global_position.y > -1.0)
		assert(citizen.get_children().any(func(child): return child is MeshInstance3D))
		assert(citizen.global_position.distance_to(SimHelper.entrance_anchor_position(simulation)) < 5.0)
		if not citizen.is_hero:
			assert(citizen.specialization == "unassigned")
			assert(citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK)

	# Gather labels are keyed by stable IDs so deleting their source cannot leave
	# a freed Godot object as a Dictionary key during the next fade update.
	var temporary_gather_source := Node3D.new()
	simulation.add_child(temporary_gather_source)
	var temporary_source_id: int = temporary_gather_source.get_instance_id()
	simulation.foraging_service.ensure_gather_progress_label(temporary_gather_source)
	assert(simulation.gather_progress_labels.has(temporary_source_id))
	temporary_gather_source.queue_free()
	await process_frame
	simulation.label_distance_fade_controller.update_label_distance_fading()
	simulation.foraging_service.update_gathering_indicators(false, "", "", 0.0, null, [])
	assert(not simulation.gather_progress_labels.has(temporary_source_id))

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
