class_name SettlementCitizenFactory
extends RefCounted

## Handles citizen spawning, wiring, AI registration, starter backpack creation,
## and citizen lookup by AI id. Extracted from SettlementGame to reduce monolithic
## file size.

const CitizenActorScene = preload("res://game/features/citizens/presentation/citizen_actor.tscn")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func create_citizens() -> void:
	var map_document: MapDocument = game.launch_config.map_document if game.launch_config != null else null
	if map_document == null:
		push_error("[spawn] SettlementGame requires map-authored party spawn points")
		return
	var cell_size := map_document.meta.cell_size
	var starts: Array[Vector3] = []
	var facing := 0.0
	if game.launch_config.has_spawn_override():
		# Editor test run "from here" (map_start.md §4.5): the override replaces the
		# whole spawn group, so the party is laid out around the requested cell and
		# the map's authored places are neither used nor required.
		starts = _party_ring(game.launch_config.spawn_override, cell_size, game.POPULATION)
	else:
		var group := map_document.zones.spawn_group_by_id(game.launch_config.spawn_group)
		var plan := MapSpawnService.new().plan_party(
			map_document.zones, group, game.POPULATION, cell_size)
		if not plan.ok:
			# A party that does not fit blocks the launch (§4.3). Placing fewer
			# settlers than the player asked for is a bug wearing a fallback's coat.
			push_error("[spawn] %s" % plan.reason)
			return
		for placement: MapSpawnService.PartyPlacement in plan.placements:
			starts.append(placement.position)
		facing = plan.placements[0].facing if not plan.placements.is_empty() else 0.0
	for index in range(game.POPULATION):
		var spawn_position: Vector3 = starts[index]
		var terrain_height := game.terrain_height_at(spawn_position.x, spawn_position.z, 0.0)
		if not is_nan(terrain_height):
			spawn_position.y = terrain_height + 0.08
		add_citizen(spawn_position, "unassigned")
	# The hero looks the way the author drew the leader's place; the rest of the
	# party takes the same bearing so a party start reads as one group.
	if not is_zero_approx(facing):
		for citizen in game.citizens:
			citizen.rotation.y = deg_to_rad(facing)
	if not game.citizens.is_empty():
		game.citizens[game.random.randi_range(0, game.citizens.size() - 1)].is_jack_of_all_trades = true
	if game.hero_citizen != null:
		for citizen in game.citizens:
			citizen.set_squad(&"hero_squad", game.hero_citizen.ai_id, true)


## Party layout for a spawn override: the hero on the requested cell, everyone
## else on the ring of cells around it. Deliberately trivial — a test run is a
## look at the map, not a scenario, and an authored map still places every member
## by hand.
func _party_ring(centre: Vector3, cell_size: float, population: int) -> Array[Vector3]:
	const RING: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	var starts: Array[Vector3] = []
	for index in range(population):
		var offset := RING[index % RING.size()]
		var lap := index / RING.size() + 1
		starts.append(centre + Vector3(
			float(offset.x) * cell_size * lap, 0.0, float(offset.y) * cell_size * lap))
	return starts


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
	citizen.ai_id = game.next_ai_citizen_id
	game.next_ai_citizen_id += 1
	game.citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuator.new(citizen, ai_target_for_key))
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
	citizen.setup_navigation(game.find_path_around_houses, func(from): return game.logistics_controller.get_nearest_delivery_position(from), func(citizen, destination): return game.building_queue_service.resolve(citizen, destination), game.movement_speed_modifier_at, game.navigation_revision, func(citizen_id, position_on_board): game.world_navigation_controller.record_trail_movement(citizen_id, position_on_board), game.is_route_reachable, func(citizen, destination): game.building_queue_service.complete_arrival(citizen, destination), func(citizen): game.building_queue_service.release(citizen), game.find_recovery_path, game.is_route_path_clear)
	citizen.setup_registration_service(game.can_start_registration, game.registration_duration)
	if game.actuator_bridge != null:
		game.actuator_bridge.wire_citizen(citizen)
	citizen.tree_harvested.connect(game.on_tree_harvested)
	citizen.employment_processing_finished.connect(game.on_employment_processing_finished)
	citizen.arrival_greeter_ready.connect(func(greeter): game.citizen_lifecycle_service.on_arrival_greeter_ready(greeter))
	citizen.outside_work_departed.connect(func(worker): game.outside_work_controller.on_outside_work_departed(worker))
	citizen.citizen_leaving_departed.connect(func(citizen): game.citizen_lifecycle_service.on_citizen_leaving_departed(citizen))


## The starting supplies, read off every container the map marked
## `core:party_stash` (`map_start.md` §6.5).
##
## What this replaces is a lookup through four hardcoded archetype ids that took
## the *first* match and called it the starter backpack. "Starting" is not a kind
## of object — it is a role an author gives an object — so a chest, a cart or a
## barrel now works with no code at all, and two marked containers are summed
## instead of one being silently ignored.
func create_starter_backpack() -> void:
	if game.settlement.warehouse_ever_built:
		return
	if game.launch_config == null or game.launch_config.map_document == null:
		return
	var spawn: MapEntityRecord = null
	for entity: MapEntityRecord in game.launch_config.map_document.entities.entities:
		if entity.function != MapEntityFunction.PARTY_STASH:
			continue
		if not game.launch_config.includes_map_entity(entity):
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(entity.archetype_id)
		var props := archetype.resolved_properties(entity.props) if archetype != null else entity.props
		for key in props:
			var amount := int(props[key])
			if amount > 0:
				game.settlement.backpack[str(key)] = int(game.settlement.backpack.get(str(key), 0)) + amount
		if spawn == null:
			spawn = entity
	if spawn == null:
		# A stash is an optional placement; without one the party starts with no
		# ground pile, exactly as a map that never placed a backpack always did.
		return
	game.backpack_position = spawn.position
	var terrain_height := game.terrain_height_at(game.backpack_position.x, game.backpack_position.z, 0.0)
	if not is_nan(terrain_height):
		game.backpack_position.y = terrain_height + 0.08
	game.resource_pile_service.create_resource_pile(game.backpack_position, game.settlement.backpack, true)
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
				if is_instance_valid(building) and game.cell_from_position(building.global_position) == cell:
					return building
		"construction":
			for site: ConstructionSite in game.construction_sites:
				if site.cell == cell and is_instance_valid(site.node):
					return site.node
		"demolition":
			for site: DemolitionSite in game.demolition_sites:
				if is_instance_valid(site.building) and game.cell_from_position(site.building.global_position) == cell:
					return site.building
		"dig":
			var site := game.excavation_service.dig_site_at(cell)
			return site.node if is_instance_valid(site.node) else null
		"factory":
			for factory: Node3D in game.factories:
				if is_instance_valid(factory) and game.cell_from_position(factory.global_position) == cell:
					return factory
	return null
