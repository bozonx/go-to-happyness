class_name SettlementCitizenFactory
extends RefCounted

## Handles citizen spawning, wiring, AI registration, starter backpack creation,
## and citizen lookup by AI id. Extracted from SettlementGame to reduce monolithic
## file size.

const CitizenActorScene = preload("res://game/features/citizens/presentation/citizen_actor.tscn")
const SettlementCitizenActuatorScript = preload("res://game/features/decision/presentation/settlement_citizen_actuator.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func create_citizens() -> void:
	var spawn_anchor: Vector3 = game._entrance_anchor_position() + Vector3(0.0, 0.0, 2.0)
	var columns := 3
	for index in range(game.POPULATION):
		var col := index % columns
		var row := index / columns
		var spawn_position := spawn_anchor + Vector3((col - 1) * 1.5, 0.0, row * 1.4)
		var terrain_height := game._terrain_height_at(spawn_position.x, spawn_position.z, 0.0)
		if not is_nan(terrain_height):
			spawn_position.y = terrain_height + 0.08
		add_citizen(spawn_position, "unassigned")
	if not game.citizens.is_empty():
		game.citizens[game.random.randi_range(0, game.citizens.size() - 1)].is_jack_of_all_trades = true
	if game.hero_citizen != null:
		for citizen in game.citizens:
			citizen.set_squad(&"hero_squad", game.hero_citizen.ai_id, true)


func bind_hero_squad_to_settlement(squad_settlement_id: StringName) -> void:
	if game.hero_citizen == null:
		return
	for citizen in game.citizens:
		if citizen.squad_state.is_in_squad() and citizen.squad_state.squad_leader_id == game.hero_citizen.ai_id:
			citizen.settlement_id = squad_settlement_id


func add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	var citizen: Citizen = CitizenActorScene.instantiate()
	citizen.position = spawn_position
	if game.citizens.size() < game.POPULATION:
		citizen.gender = "male" if game.citizens.size() % 2 == 0 else "female"
	if game.hero_citizen == null:
		citizen.gender = "male"
		citizen.skin_color = Color("f1c09a")
		citizen.hair_color = Color("3b2219")
		citizen.shirt_color = Color("1e3d59")
		citizen.pants_color = Color("ff6e40")
	citizen.random = game.random
	game.add_child(citizen)
	citizen.simulation = game
	citizen.setup_specialization(primary_specialization if not primary_specialization.is_empty() else "unassigned")
	wire_citizen(citizen)
	game.citizens.append(citizen)
	citizen.ai_id = game._next_ai_citizen_id
	game._next_ai_citizen_id += 1
	game.citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuatorScript.new(citizen, ai_target_for_key))
	citizen.tree_exiting.connect(on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)
	if game.citizens.size() > game.POPULATION:
		game.settlement.add(ResourceIds.FOOD, game.random.randi_range(2, 5))
	if game.hero_citizen == null:
		game.hero_citizen = citizen
		citizen.set_hero(true)
		citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	else:
		# Before the first campfire the settlement has no administration. Initial
		# residents can receive explicit daily orders to bootstrap it.
		citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK if not is_instance_valid(game.campfire_node) else Citizen.EmploymentState.UNREGISTERED
	if game.citizen_needs_service != null:
		game.citizen_needs_service.schedule_toilet(citizen.ai_id)


## Attaches navigation, the registration service and every gameplay signal to a
## citizen. The caller must already have added the node to the tree, set
## `simulation` and chosen the specialization. Shared by initial spawning and
## save restore so a new signal only needs to be registered in one place.
func wire_citizen(citizen: Citizen) -> void:
	citizen.setup_navigation(game._find_path_around_houses, game._get_nearest_delivery_position, game._resolve_building_queue_position, game._movement_speed_modifier_at, game._navigation_revision, game._record_trail_movement, game._is_route_reachable, game._complete_building_queue_arrival, game._release_building_queue_entry, game._find_recovery_path, game._is_route_path_clear)
	citizen.setup_registration_service(game._can_start_registration, game._registration_duration)
	if game.actuator_bridge != null:
		game.actuator_bridge.wire_citizen(citizen)
	citizen.tree_harvested.connect(game._on_tree_harvested)
	citizen.employment_processing_finished.connect(game._on_employment_processing_finished)
	citizen.arrival_greeter_ready.connect(game._on_arrival_greeter_ready)
	citizen.outside_work_departed.connect(game._on_outside_work_departed)
	citizen.citizen_leaving_departed.connect(game._on_citizen_leaving_departed)


func create_starter_backpack() -> void:
	if game.settlement.warehouse_ever_built:
		return
	var anchor := game._entrance_anchor_position() + Vector3(0.0, 0.0, 2.0)
	game.backpack_position = anchor + Vector3(-1.5, 0.0, 0.7)
	var terrain_height := game._terrain_height_at(game.backpack_position.x, game.backpack_position.z, 0.0)
	if not is_nan(terrain_height):
		game.backpack_position.y = terrain_height + 0.08
	game._create_resource_pile(game.backpack_position, game.settlement.backpack, true)
	if not game.resource_piles.is_empty():
		game.backpack_node = game.resource_piles[game.resource_piles.size() - 1].node


func on_ai_citizen_exiting(citizen_id: int) -> void:
	if game.trail_field != null:
		game.trail_field.forget_walker(citizen_id)
	if is_instance_valid(game.citizen_ai):
		game.citizen_ai.unregister_citizen(citizen_id)
	if game.canteen_service != null:
		game.canteen_service.remove_citizen(citizen_id)
	if game.citizen_needs_service != null:
		game.citizen_needs_service.remove_citizen(citizen_id)


func is_ai_citizen_id_alive(citizen_id: int) -> bool:
	for citizen in game.citizens:
		if is_instance_valid(citizen) and citizen.ai_id == citizen_id:
			return true
	return false


func citizen_for_ai_id(citizen_id: int) -> Citizen:
	if citizen_id <= 0:
		return null
	for citizen in game.citizens:
		if is_instance_valid(citizen) and citizen.ai_id == citizen_id:
			return citizen
	return null


func ai_target_for_key(target_key: StringName) -> Node3D:
	var parts := String(target_key).split(":")
	if parts.size() != 3:
		return null
	var cell := Vector2i(int(parts[1]), int(parts[2]))
	match parts[0]:
		"building":
			for record in game.building_registry.records():
				var building := record.node as Node3D
				if is_instance_valid(building) and game._cell_from_position(building.global_position) == cell:
					return building
		"construction":
			for site: ConstructionSite in game.construction_sites:
				if site.cell == cell and is_instance_valid(site.node):
					return site.node
		"demolition":
			for site: DemolitionSite in game.demolition_sites:
				if is_instance_valid(site.building) and game._cell_from_position(site.building.global_position) == cell:
					return site.building
		"dig":
			var site := game.excavation_service.dig_site_at(cell)
			return site.node if is_instance_valid(site.node) else null
		"factory":
			for factory: Node3D in game.factories:
				if is_instance_valid(factory) and game._cell_from_position(factory.global_position) == cell:
					return factory
	return null
