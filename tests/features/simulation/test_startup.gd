extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Verifies initial settlement state: citizens, economy, AI, hero, build menu,
## officer delegation, and citizen validation.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	# A session is always backed by the chosen authored map: the runtime adopts
	# the exact grids, rather than constructing a fallback board.
	assert(simulation.launch_config.map_document != null)
	assert(simulation.board_cells == simulation.launch_config.map_document.board_cells())
	assert(simulation.world_setup.terrain_grid == simulation.launch_config.map_document.terrain)
	assert(simulation.world_setup.water_grid == simulation.launch_config.map_document.water)

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
	# Opening the campfire menu must use the workplace service's public officer
	# query; the composition root deliberately has no private compatibility API.
	simulation.selected_campfire = simulation.campfire_node
	simulation.campfire_menu_controller.refresh_campfire_menu()

	# Natural objects are owned by the terrain scene but retain their registered
	# source records, so moving presentation ownership cannot make them inert.
	# Every one of them now comes from authored `entities[]`: startup never
	# invents grass, forage, rabbits or fireflies the map did not place.
	var landscape_objects := simulation.get_node("WorldTerritory/LandscapeObjects") as Node3D
	assert(not simulation.tree_nodes.is_empty())
	assert(not simulation.grass_sources.is_empty())
	assert(not simulation.forage_sources.is_empty())
	assert(not simulation.rabbit_sources.is_empty())
	assert(not simulation.fireflies.is_empty())
	assert(simulation.tree_nodes.values()[0].get_parent() == landscape_objects)
	assert((simulation.grass_sources.values()[0] as GrassSourceRecord).node.get_parent() == landscape_objects)
	assert((simulation.forage_sources.values()[0] as ForageSourceRecord).node.get_parent() == landscape_objects)
	assert((simulation.rabbit_sources.values()[0] as RabbitSourceRecord).node.get_parent() == landscape_objects)
	# Authored firefly placements are rendered by MapEntityPresenter and forwarded
	# into the weather controller's list, so they are live FirefliesEffect nodes.
	assert(simulation.fireflies[0] is FirefliesEffect)
	assert(is_instance_valid(simulation.fireflies[0]))
	assert(simulation.resource_piles.any(func(pile): return pile.node.get_parent() == landscape_objects))

	# The runtime count of every natural kind matches the map's authored records
	# exactly — no startup fabrication, nothing dropped.
	_count_natural_entities(simulation)

	# Hero citizen
	assert(is_instance_valid(simulation.hero_citizen))
	assert(simulation.hero_citizen.is_hero)
	assert(simulation.hero_citizen.specialization == "unassigned")
	assert(simulation.hero_citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK)
	assert(simulation.is_first_person)
	assert(simulation.player_citizen == simulation.hero_citizen)
	assert(SimHelper.player_can_command_labor(simulation))
	# Every member of the starting party comes from its own authored map anchor
	# and is snapped to the live terrain field — no entrance-sign or y=0 fallback.
	var spawn_service := MapSpawnService.new()
	var expected_starts: Array[Vector3] = [spawn_service.hero_spawn_position(simulation.launch_config.map_document.zones)]
	expected_starts.append_array(spawn_service.companion_spawn_positions(simulation.launch_config.map_document.zones).slice(0, simulation.POPULATION - 1))
	assert(expected_starts.size() == simulation.POPULATION)
	for index in simulation.POPULATION:
		var expected := expected_starts[index]
		var citizen: Citizen = simulation.citizens[index]
		assert(is_equal_approx(citizen.global_position.x, expected.x))
		assert(is_equal_approx(citizen.global_position.z, expected.z))
		# Physics settles a CharacterBody from the 8 cm launch clearance onto the
		# collider during the helper's first frames, so assert terrain attachment
		# rather than the transient clearance exactly.
		assert(absf(citizen.global_position.y - simulation.terrain_height_at(expected.x, expected.z, expected.y)) <= 0.12)
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

	await SimHelper.cleanup_simulation(self, simulation)
	quit(0)


## Every natural object at runtime must trace back to an authored `entities[]`
## record. This is the end-to-end guard against reintroducing a procedural
## startup generator: if a count drifts, startup invented or dropped something.
func _count_natural_entities(simulation: Node) -> void:
	var document: MapDocument = simulation.launch_config.map_document
	assert(document != null)
	var expected := {
		&"tree": 0, &"grass_source": 0, &"forage_source": 0,
		&"rabbit": 0, &"fireflies": 0, &"starter_loot": 0, &"backpack": 0,
	}
	for placed: MapEntityRecord in document.entities.entities:
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype == null or not archetype.has_component(&"settlement_natural"):
			# Fireflies carry no settlement_natural component (the presenter owns
			# them), so match them by archetype id instead.
			if String(placed.archetype_id) == "core:fireflies":
				expected[&"fireflies"] += 1
			continue
		var kind := StringName(archetype.component_data(&"settlement_natural").get("kind", ""))
		if expected.has(kind):
			expected[kind] += 1
	# starter_loot becomes resource piles; the party stash is a single pile.
	assert(simulation.tree_nodes.size() == expected[&"tree"])
	assert(simulation.grass_sources.size() == expected[&"grass_source"])
	assert(simulation.forage_sources.size() == expected[&"forage_source"])
	assert(simulation.rabbit_sources.size() == expected[&"rabbit"])
	assert(simulation.fireflies.size() == expected[&"fireflies"])
