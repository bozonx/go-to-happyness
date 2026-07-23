class_name StorageRoutingService
extends RefCounted

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

## Handles warehouse routing (reachable index search, delivery position,
## route cost), storage capacity queries, pile lookups, and storage room
## checks for worker roles.

var _settlement: SettlementState
var _warehouse_positions: Array[Vector3] = []
var _resource_piles: Array[ResourcePileScript] = []
var _player_citizen_getter: Callable
var _interaction_range: float
var _is_route_reachable: Callable
var _find_path_around_houses: Callable
var _nav_grid: Variant
var _dig_sites: Array = []
var _can_work_at_dig_site: Callable
var _resource_for_depth: Callable
var _update_interface: Callable


func configure(
	p_settlement: SettlementState,
	p_warehouse_positions: Array[Vector3],
	p_resource_piles: Array[ResourcePileScript],
	p_player_citizen_getter: Callable,
	p_interaction_range: float,
	p_is_route_reachable: Callable,
	p_find_path_around_houses: Callable,
	p_nav_grid: Variant,
	p_dig_sites: Array,
	p_can_work_at_dig_site: Callable,
	p_resource_for_depth: Callable,
	p_update_interface: Callable
) -> void:
	_settlement = p_settlement
	_warehouse_positions = p_warehouse_positions
	_resource_piles = p_resource_piles
	_player_citizen_getter = p_player_citizen_getter
	_interaction_range = p_interaction_range
	_is_route_reachable = p_is_route_reachable
	_find_path_around_houses = p_find_path_around_houses
	_nav_grid = p_nav_grid
	_dig_sites = p_dig_sites
	_can_work_at_dig_site = p_can_work_at_dig_site
	_resource_for_depth = p_resource_for_depth
	_update_interface = p_update_interface


func resource_pile_for_node(pile_node: Node3D) -> ResourcePileScript:
	for pile: ResourcePileScript in _resource_piles:
		if pile.node == pile_node:
			return pile
	return null


func take_resource_from_pile_at(position: Vector3, resource_type: String, max_amount: int) -> int:
	if max_amount <= 0 or resource_type.is_empty():
		return 0
	for index in _resource_piles.size():
		var pile: ResourcePileScript = _resource_piles[index]
		var pile_node: Node3D = pile.node
		if not is_instance_valid(pile_node) or pile_node.global_position.distance_squared_to(position) > 0.25:
			continue
		var available: int = int(pile.resources.get(resource_type, 0))
		if available <= 0:
			continue
		var taken: int = mini(max_amount, available)
		pile.resources[resource_type] = available - taken
		if int(pile.resources[resource_type]) <= 0:
			pile.resources.erase(resource_type)
		var labels: Array[String] = []
		for piled_resource in pile.resources:
			var amount: int = int(pile.resources[piled_resource])
			if amount > 0:
				labels.append("%s x%d" % [str(piled_resource).to_upper(), amount])
		labels.sort()
		var label: Label3D = pile_node.get_node_or_null("PileLabel") as Label3D
		if label != null:
			label.text = "\n".join(labels)
		if pile.resources.is_empty():
			_resource_piles.remove_at(index)
			pile_node.queue_free()
		return taken
	return 0


func pile_available_resources(pile: ResourcePileScript) -> Array[String]:
	var result: Array[String] = []
	if pile == null:
		return result
	for resource_type in pile.resources:
		if int(pile.resources.get(resource_type, 0)) > 0:
			result.append(str(resource_type))
	return result


func stored_resources() -> int:
	if _warehouse_positions.is_empty():
		return 0
	return int(ceil(_settlement.storage_used_units()))


func warehouse_capacity() -> int:
	return _settlement.storage_capacity(_warehouse_positions.size())


func nearby_warehouse_index() -> int:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return -1
	for i in range(_warehouse_positions.size()):
		if player.global_position.distance_to(_warehouse_positions[i]) <= _interaction_range:
			return i
	return -1


func nearby_warehouse() -> bool:
	return nearby_warehouse_index() >= 0


func warehouse_index_for_building(building: Node3D) -> int:
	if not is_instance_valid(building):
		return -1
	var service_pos: Vector3 = building.get_meta("service_position", building.global_position)
	var index: int = _warehouse_positions.find(service_pos)
	if index >= 0:
		return index
	var best: int = -1
	var best_dist: float = 999999.0
	for i in range(_warehouse_positions.size()):
		var dist: float = _warehouse_positions[i].distance_to(service_pos)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


func has_storage_room_for_role(role: String) -> bool:
	if role == "excavation":
		for site in _dig_sites:
			if _can_work_at_dig_site.call(site):
				var next_depth: int = site.depth + 1
				var resource: String = _resource_for_depth.call(site, next_depth)
				return _settlement.can_make_room_for(resource, 1, _warehouse_positions.size())
		return _settlement.can_make_room_for(ResourceIds.SOIL, 1, _warehouse_positions.size())

	var resource_for_role := {"forestry": ResourceIds.LOGS, "farming": ResourceIds.FOOD, "gather_branches": ResourceIds.BRANCHES, "gather_grass": ResourceIds.GRASS, "gather_food": ResourceIds.FOOD, "gather_water": ResourceIds.WATER}
	if not resource_for_role.has(role):
		return true
	return _settlement.can_make_room_for(resource_for_role[role], 1, _warehouse_positions.size())


func warehouse_delivery_position(from: Vector3, resource_type: String, amount: int) -> Vector3:
	if _warehouse_positions.is_empty():
		return from
	var index: int = find_reachable_warehouse_index(from, resource_type, amount)
	if index >= 0:
		return _warehouse_positions[index]
	return from


func find_reachable_warehouse_index(from: Vector3, resource_type: String, amount: int, require_room := true) -> int:
	var best_index: int = -1
	var best_cost: float = INF
	var best_ratio: float = INF
	for index in range(mini(_warehouse_positions.size(), _settlement.warehouses.size())):
		if require_room and not resource_type.is_empty() and _settlement.warehouse_room_for(index, resource_type) < amount:
			continue
		var position: Vector3 = _warehouse_positions[index]
		if not _is_route_reachable.call(from, position, false):
			continue
		var route = _find_path_around_houses.call(from, position, false)
		if not route.reachable:
			continue
		var cost: float = route_cost(from, route)
		var ratio: float = float(_settlement.warehouses[index].amount(resource_type)) / float(maxi(1, _settlement.warehouses[index].capacity)) if not resource_type.is_empty() else 0.0
		if _settlement.balanced_warehouse_mode:
			if ratio < best_ratio or (is_equal_approx(ratio, best_ratio) and cost < best_cost):
				best_index = index
				best_ratio = ratio
				best_cost = cost
		elif cost < best_cost:
			best_index = index
			best_cost = cost
	return best_index


func route_cost(from: Vector3, route: RouteResult) -> float:
	return _nav_grid.route_cost(from, route) if _nav_grid != null else INF


func set_balanced_warehouse_mode(enabled: bool) -> void:
	_settlement.balanced_warehouse_mode = enabled
	_update_interface.call("Balanced warehouse storage %s." % ("enabled" if enabled else "disabled"))
