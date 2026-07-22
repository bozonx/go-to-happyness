class_name StorageRoutingService
extends RefCounted

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

## Handles warehouse routing (reachable index search, delivery position,
## route cost), storage capacity queries, pile lookups, and storage room
## checks for worker roles.

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func resource_pile_for_node(pile_node: Node3D) -> ResourcePileScript:
	for pile: ResourcePileScript in simulation.resource_piles:
		if pile.node == pile_node:
			return pile
	return null


func take_resource_from_pile_at(position: Vector3, resource_type: String, max_amount: int) -> int:
	if max_amount <= 0 or resource_type.is_empty():
		return 0
	for index in simulation.resource_piles.size():
		var pile: ResourcePileScript = simulation.resource_piles[index]
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
			simulation.resource_piles.remove_at(index)
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
	if simulation.warehouse_positions.is_empty():
		return 0
	return int(ceil(simulation.settlement.storage_used_units()))


func warehouse_capacity() -> int:
	return simulation.settlement.storage_capacity(simulation.warehouse_positions.size())


func nearby_warehouse_index() -> int:
	if simulation.player_citizen == null:
		return -1
	for i in range(simulation.warehouse_positions.size()):
		if simulation.player_citizen.global_position.distance_to(simulation.warehouse_positions[i]) <= simulation.INTERACTION_RANGE:
			return i
	return -1


func nearby_warehouse() -> bool:
	return nearby_warehouse_index() >= 0


func warehouse_index_for_building(building: Node3D) -> int:
	if not is_instance_valid(building):
		return -1
	var service_pos: Vector3 = building.get_meta("service_position", building.global_position)
	var index: int = simulation.warehouse_positions.find(service_pos)
	if index >= 0:
		return index
	var best: int = -1
	var best_dist: float = 999999.0
	for i in range(simulation.warehouse_positions.size()):
		var dist: float = simulation.warehouse_positions[i].distance_to(service_pos)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


func has_storage_room_for_role(role: String) -> bool:
	if role == "excavation":
		for site in simulation.dig_sites:
			if simulation._can_work_at_dig_site(site):
				var next_depth: int = site.depth + 1
				var resource: String = simulation._resource_for_depth(site, next_depth)
				return simulation.settlement.can_make_room_for(resource, 1, simulation.warehouse_positions.size())
		return simulation.settlement.can_make_room_for(ResourceIds.SOIL, 1, simulation.warehouse_positions.size())

	var resource_for_role := {"forestry": ResourceIds.LOGS, "farming": ResourceIds.FOOD, "gather_branches": ResourceIds.BRANCHES, "gather_grass": ResourceIds.GRASS, "gather_food": ResourceIds.FOOD, "gather_water": ResourceIds.WATER}
	if not resource_for_role.has(role):
		return true
	return simulation.settlement.can_make_room_for(resource_for_role[role], 1, simulation.warehouse_positions.size())


func warehouse_delivery_position(from: Vector3, resource_type: String, amount: int) -> Vector3:
	if simulation.warehouse_positions.is_empty():
		return from
	var index: int = find_reachable_warehouse_index(from, resource_type, amount)
	if index >= 0:
		return simulation.warehouse_positions[index]
	return from


func find_reachable_warehouse_index(from: Vector3, resource_type: String, amount: int, require_room := true) -> int:
	var best_index: int = -1
	var best_cost: float = INF
	var best_ratio: float = INF
	for index in range(mini(simulation.warehouse_positions.size(), simulation.settlement.warehouses.size())):
		if require_room and not resource_type.is_empty() and simulation.settlement.warehouse_room_for(index, resource_type) < amount:
			continue
		var position: Vector3 = simulation.warehouse_positions[index]
		if not simulation._is_route_reachable(from, position, false):
			continue
		var route = simulation._find_path_around_houses(from, position, false)
		if not route.reachable:
			continue
		var cost: float = route_cost(from, route)
		var ratio: float = float(simulation.settlement.warehouses[index].amount(resource_type)) / float(maxi(1, simulation.settlement.warehouses[index].capacity)) if not resource_type.is_empty() else 0.0
		if simulation.settlement.balanced_warehouse_mode:
			if ratio < best_ratio or (is_equal_approx(ratio, best_ratio) and cost < best_cost):
				best_index = index
				best_ratio = ratio
				best_cost = cost
		elif cost < best_cost:
			best_index = index
			best_cost = cost
	return best_index


func route_cost(from: Vector3, route: RouteResult) -> float:
	if route == null or not route.reachable:
		return INF
	var cost: float = 0.0
	var previous: Vector3 = from
	for waypoint: Vector3 in route.waypoints:
		var segment: float = simulation.nav_grid.segment_cost(previous, waypoint)
		if not is_finite(segment):
			return INF
		cost += segment
		previous = waypoint
	return cost


func set_balanced_warehouse_mode(enabled: bool) -> void:
	simulation.settlement.balanced_warehouse_mode = enabled
	simulation._update_interface("Balanced warehouse storage %s." % ("enabled" if enabled else "disabled"))
