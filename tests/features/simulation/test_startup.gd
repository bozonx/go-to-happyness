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

	# Natural objects are owned by the terrain scene but retain their registered
	# source records, so moving presentation ownership cannot make them inert.
	var landscape_objects := simulation.get_node("Terrain3dWorld/LandscapeObjects") as Node3D
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
	assert(simulation._player_can_command_labor())

	# Build menu submenus
	simulation.selected_builder = simulation.hero_citizen
	simulation._refresh_build_menu()
	assert(simulation.build_menu.daily_order_submenu_btn.visible)
	assert(not simulation.build_menu.daily_order_submenu_btn.disabled)
	assert(simulation.build_menu.job_submenu_btn.visible)
	assert(not simulation.build_menu.job_submenu_btn.disabled)
	simulation._open_job_submenu()
	assert(simulation.build_menu_is_job_menu)
	simulation._open_daily_order_submenu()
	assert(simulation.build_menu_is_daily_order_menu)

	# Daily order role buttons visible and enabled
	var construction_daily_button: Button = null
	for button in simulation.build_menu.role_buttons:
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
	simulation._open_daily_order_submenu()
	var cleaning_daily_button: Button = null
	for button in simulation.build_menu.role_buttons:
		if str(button.get_meta("submenu", "")) == "daily" and str(button.get_meta("role", "")) == "cleaning":
			cleaning_daily_button = button
			break
	assert(cleaning_daily_button != null)
	assert(cleaning_daily_button.visible)
	assert(not cleaning_daily_button.disabled)
	simulation._close_assignment_submenu()

	# Officer appointment and delegation
	SimHelper.appoint_test_official(simulation, simulation.hero_citizen)
	var delegated_officer: Citizen = simulation.citizens[1]
	SimHelper.appoint_test_official(simulation, delegated_officer)
	assert(simulation._player_can_command_labor())
	SimHelper.appoint_test_official(simulation, simulation.hero_citizen)
	assert(simulation._player_can_command_labor())

	# A daily order releases first-person control but does not break the permanent job.
	simulation.selected_builder = simulation.hero_citizen
	simulation.hero_citizen.set_player_controlled(true)
	simulation._set_selected_work_role("gather_grass", true)
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
		assert(citizen.global_position.distance_to(simulation._entrance_anchor_position()) < 5.0)
		if not citizen.is_hero:
			assert(citizen.specialization == "unassigned")
			assert(citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
