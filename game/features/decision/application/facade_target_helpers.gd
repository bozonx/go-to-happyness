class_name FacadeTargetHelpers
extends RefCounted

## Stateless route and target utilities shared by the facade and per-role fact
## collectors. Each method reads from the simulation node but holds no mutable
## state of its own.

## Route finding is the expensive part of source selection. A worker only needs
## one target, so inspect a small, deterministic set of nearby sources instead
## of pathfinding to every tree or grass clump on every snapshot.
const MAX_ROUTE_CANDIDATES := 12

var simulation: Node
var route_cache: RouteCandidateCache


func _init(next_simulation: Node = null, next_route_cache: RouteCandidateCache = null) -> void:
	simulation = next_simulation
	route_cache = next_route_cache


func target_key(kind: StringName, position: Vector3) -> StringName:
	var cell: Vector2i = simulation._cell_from_position(position)
	return StringName("%s:%d:%d" % [kind, cell.x, cell.y])


## The reachable approach point for a home. AI move steps drive the capsule to a
## fixed world point without house-entry, so they must target the walkable
## entrance marker the sleep FSM uses, not the (possibly blocked) building centre.
func home_entrance_position(home: Node3D) -> Vector3:
	if not is_instance_valid(home):
		return Vector3.INF
	if not home.is_inside_tree():
		return home.position
	return home.get_meta("entrance_position", home.global_position)


func resource_access_position(resource_position: Vector3, from: Vector3 = Vector3.INF) -> Vector3:
	if from != Vector3.INF:
		return simulation._resource_access_position(from, resource_position)
	var resource_cell: Vector2i = simulation._cell_from_position(resource_position)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = resource_cell + offset
		if simulation._is_board_cell(cell) and not simulation._is_navigation_cell_blocked(cell):
			return simulation._cell_center(cell)
	return Vector3.INF


func route_cost(from: Vector3, destination: Vector3) -> float:
	if from == Vector3.INF or destination == Vector3.INF:
		return INF
	var route: RouteResult = simulation._find_path_around_houses(from, destination, false)
	return simulation._route_cost(from, route)


func workplace_target_key(workplace: Node3D) -> StringName:
	if not is_instance_valid(workplace):
		return &""
	var dig_site = simulation._dig_site_for_node(workplace)
	if dig_site != null and dig_site.node == workplace:
		return target_key(&"dig", workplace.global_position)
	return target_key(&"building", workplace.global_position)


func storage_position_for(from: Vector3, resource_type: String) -> Vector3:
	var index: int = simulation._find_reachable_warehouse_index(from, resource_type, 1)
	return simulation.warehouse_positions[index] if index >= 0 else Vector3.INF


func cached_route_candidates(key: StringName, origin: Vector3, producer: Callable) -> Array[Dictionary]:
	var topology_revision: int = int(simulation.nav_grid.topology_revision()) if simulation.nav_grid != null else -1
	var origin_cell: Vector2i = simulation._cell_from_position(origin)
	var now := float(simulation.runtime_seconds)
	return route_cache.get_or_produce(key, topology_revision, origin_cell, now, producer)


func insert_nearby_gathering_candidate(candidates: Array[Dictionary], candidate: Dictionary) -> void:
	var distance := float(candidate.get(&"direct_distance", INF))
	var insert_at := candidates.size()
	for index in candidates.size():
		var existing := candidates[index]
		var existing_distance := float(existing.get(&"direct_distance", INF))
		if distance < existing_distance or (is_equal_approx(distance, existing_distance) and str(candidate[&"id"]) < str(existing[&"id"])):
			insert_at = index
			break
	candidates.insert(insert_at, candidate)
	if candidates.size() > MAX_ROUTE_CANDIDATES:
		candidates.pop_back()
