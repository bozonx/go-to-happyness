class_name SimulationTestHelper
extends RefCounted

## Shared helpers for SceneTree-based feature/smoke tests.
## Extracted from duplicated code across tests/features/ and tests/repro/.
##
## All access to SettlementGame private methods goes through these wrappers
## so tests do not couple to internal implementation names. If a private
## method is renamed, only this file needs updating.

const SettlementGameScene := preload("res://game/bootstrap/settlement_game.tscn")


static func create_simulation() -> Node:
	return SettlementGameScene.instantiate()


static func setup_simulation(tree: SceneTree) -> Node:
	var simulation := SettlementGameScene.instantiate()
	tree.root.add_child(simulation)
	await tree.process_frame
	await tree.physics_frame
	for _frame in range(10):
		await tree.physics_frame
	if not is_instance_valid(simulation.entrance_stone):
		var entrance := Node3D.new()
		entrance.position = cell_center(simulation, Vector2i(-22, 1))
		simulation.add_child(entrance)
		simulation.entrance_stone = entrance
	return simulation


static func cleanup_simulation(tree: SceneTree, simulation: Node) -> void:
	if is_instance_valid(simulation):
		tree.root.remove_child(simulation)
		simulation.free()


static func appoint_test_official(simulation: Node, citizen: Citizen) -> void:
	simulation.settlement.complete_research("official")
	if not is_instance_valid(simulation.campfire_node):
		var centre := Node3D.new()
		centre.set_meta("service_position", citizen.global_position)
		simulation.add_child(centre)
		simulation.campfire_node = centre
	citizen.global_position = employment_center_position(simulation)
	appoint_official(simulation, citizen, simulation.campfire_node)


# --- Test-facing wrappers for SettlementGame private methods ---

static func cell_center(simulation: Node, cell: Vector2i) -> Vector3:
	return simulation._cell_center(cell)

static func cell_from_position(simulation: Node, position: Vector3) -> Vector2i:
	return simulation._cell_from_position(position)

static func is_board_cell(simulation: Node, cell: Vector2i) -> bool:
	return simulation._is_board_cell(cell)

static func is_navigation_cell_blocked(simulation: Node, cell: Vector2i) -> bool:
	return simulation._is_navigation_cell_blocked(cell)

static func find_path_around_houses(simulation: Node, from: Vector3, destination: Vector3, may_enter: bool) -> RouteResult:
	return simulation._find_path_around_houses(from, destination, may_enter)

static func pond_access_position(simulation: Node, from: Vector3, pond_center: Vector3) -> Vector3:
	return simulation._pond_access_position(from, pond_center)

static func resource_access_position(simulation: Node, from: Vector3, resource_position: Vector3) -> Vector3:
	return simulation._resource_access_position(from, resource_position)

static func employment_center_position(simulation: Node) -> Vector3:
	return simulation._employment_center_position()

static func entrance_anchor_position(simulation: Node) -> Vector3:
	return simulation._entrance_anchor_position()

static func appoint_official(simulation: Node, citizen: Citizen, workplace: Node3D = null) -> bool:
	return simulation._appoint_official(citizen, workplace)

static func registration_official(simulation: Node) -> Citizen:
	return simulation._registration_official()

static func activate_employment_centre(simulation: Node, centre: Node3D) -> void:
	simulation._activate_employment_centre(centre)

static func can_start_registration(simulation: Node, citizen: Citizen) -> bool:
	return simulation._can_start_registration(citizen)

static func toggle_worker_overtime(simulation: Node, checked: bool) -> void:
	simulation._toggle_worker_overtime(checked)

static func skip_night(simulation: Node) -> void:
	simulation._skip_night()

static func guard_citizen_positions(simulation: Node) -> void:
	simulation._guard_citizen_positions()

static func start_park_rest(simulation: Node, cooks_only: bool) -> void:
	simulation._start_park_rest(cooks_only)

static func assign_daily_order(simulation: Node, citizen: Citizen, role: String) -> void:
	simulation._assign_daily_order(citizen, role)

static func get_available_researcher(simulation: Node, required_skill: String) -> Citizen:
	return simulation._get_available_researcher(required_skill)

static func handle_civic_post_assignment(simulation: Node) -> void:
	simulation._handle_civic_post_assignment()

static func set_selected_work_role(simulation: Node, role: String, daily_order := false) -> void:
	simulation._set_selected_work_role(role, daily_order)

static func refresh_build_menu(simulation: Node) -> void:
	simulation._refresh_build_menu()

static func open_job_submenu(simulation: Node) -> void:
	simulation._open_job_submenu()

static func open_daily_order_submenu(simulation: Node) -> void:
	simulation._open_daily_order_submenu()

static func close_assignment_submenu(simulation: Node) -> void:
	simulation._close_assignment_submenu()

static func player_can_command_labor(simulation: Node) -> bool:
	return simulation.player_can_command_labor()

static func toggle_hero_view(simulation: Node) -> void:
	simulation.player_controller.toggle_hero_view()

static func select_citizen(simulation: Node, citizen: Citizen) -> void:
	simulation._select_citizen(citizen)

static func take_control_of_selected_citizen(simulation: Node) -> void:
	simulation._take_control_of_selected_citizen()

static func unhandled_input(simulation: Node, event: InputEvent) -> void:
	simulation._unhandled_input(event)

static func update_couriers(simulation: Node) -> void:
	simulation._update_couriers()

static func create_construction_site(simulation: Node, cell: Vector2i, building_type: String, position: Vector3, rotation_quarters := 0, blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> ConstructionSite:
	return simulation._create_construction_site(cell, building_type, position, rotation_quarters, blueprint, occupied_footprint)

static func is_construction_site(simulation: Node, node: Node3D) -> bool:
	return simulation._is_construction_site(node)

static func create_resource_pile(simulation: Node, position: Vector3, resources: Dictionary, is_backpack_pile := false) -> Node3D:
	return simulation._create_resource_pile(position, resources, is_backpack_pile)

static func complete_building(simulation: Node, cell: Vector2i, building_type: String, position: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	simulation._complete_building(cell, building_type, position, building, blueprint)

static func available_employer_capacity(simulation: Node, role: String) -> int:
	return simulation._available_employer_capacity(role)

static func employer_for_role(simulation: Node, role: String) -> Node3D:
	return simulation._employer_for_role(role)

static func required_staff_for_building(simulation: Node, building: Node3D) -> Dictionary:
	return simulation._required_staff_for_building(building)

static func is_staffed_workplace(simulation: Node, building: Node3D) -> bool:
	return simulation._is_staffed_workplace(building)

static func assign_unemployed_worker(simulation: Node, role: String) -> void:
	simulation._assign_unemployed_worker(role)

static func demolition_ready(simulation: Node, site: DemolitionSite) -> bool:
	return simulation._demolition_ready(site)

static func reserve_player_gather_storage(simulation: Node, resource_type: String, requested: int) -> int:
	return simulation._reserve_player_gather_storage(resource_type, requested)

static func reconcile_construction_reservations(simulation: Node, site: ConstructionSite) -> void:
	simulation._reconcile_construction_reservations(site)

# --- Housing ---

static func requeue_interrupted_arrivals(simulation: Node) -> void:
	simulation._requeue_interrupted_arrivals()

static func cancel_arrivals_for_house(simulation: Node, house: Node3D) -> void:
	simulation._cancel_arrivals_for_house(house)

static func total_housing_slots(simulation: Node) -> int:
	return simulation._total_housing_slots()

static func unhoused_citizen_count(simulation: Node) -> int:
	return simulation._unhoused_citizen_count()

static func house_initial_residents(simulation: Node, tent: Node3D) -> void:
	simulation._house_initial_residents(tent)

static func show_house_menu(simulation: Node) -> void:
	simulation._show_house_menu()

static func spawn_house_citizen(simulation: Node) -> void:
	simulation._spawn_house_citizen()

# --- Day cycle ---

static func update_skip_night_button(simulation: Node) -> void:
	simulation._update_skip_night_button()

static func skip_to_workday_start(simulation: Node) -> void:
	simulation._skip_to_workday_start()

static func send_selected_resident_to_outside_work(simulation: Node) -> void:
	simulation._send_selected_resident_to_outside_work()

static func return_outside_workers(simulation: Node) -> void:
	simulation._return_outside_workers()

# --- Overtime & workday ---

static func activate_citizen_overtime(simulation: Node, citizen: Citizen, source: String) -> bool:
	return simulation._activate_citizen_overtime(citizen, source)

static func handle_day_cycle_event(simulation: Node, event: SimulationDayEvent) -> void:
	simulation._handle_day_cycle_event(event)

static func set_workday_hours(simulation: Node, hours: int) -> void:
	simulation._set_workday_hours(hours)

# --- Build mode ---

static func select_build_mode(simulation: Node, mode: String) -> void:
	simulation._select_build_mode(mode)

static func place_building(simulation: Node, world_position: Vector3) -> void:
	simulation._place_building(world_position)

# --- Navigation & citizens ---

static func refresh_navigation_grid(simulation: Node) -> void:
	simulation._refresh_navigation_grid()

static func add_citizen(simulation: Node, position: Vector3, role := "") -> void:
	simulation._add_citizen(position, role)

static func placement_key(simulation: Node, world_position: Vector3) -> Vector2i:
	return simulation._placement_key(world_position)

# --- Construction priority ---

static func preferred_construction_site(simulation: Node) -> ConstructionSite:
	return simulation._preferred_construction_site()
