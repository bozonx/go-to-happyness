class_name HeroInteractionService
extends RefCounted

## Handles hero proximity queries for nearby trees, sawmills, farms, ponds,
## grass patches, forage sources, rabbits, and interaction percentages.

const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")

var simulation: Node


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func nearby_tree() -> bool:
	if simulation.player_citizen == null:
		return false
	for tree_position in simulation.tree_positions:
		if simulation.player_citizen.global_position.distance_to(tree_position) <= float(simulation.INTERACTION_RANGE):
			var tree: Node3D = simulation.tree_nodes.get(simulation._cell_from_position(tree_position))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				return true
	return false


func nearby_tree_with_branches() -> bool:
	if simulation.player_citizen == null:
		return false
	for tree_position in simulation.tree_positions:
		if simulation.player_citizen.global_position.distance_to(tree_position) <= float(simulation.INTERACTION_RANGE):
			var tree: Node3D = simulation.tree_nodes.get(simulation._cell_from_position(tree_position))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				if int(tree.get_meta("remaining_branches", 0)) > 0:
					return true
	return false


func nearby_sawmill() -> bool:
	return nearby_sawmill_position() != Vector3.INF


func nearby_sawmill_position() -> Vector3:
	if simulation.player_citizen == null:
		return Vector3.INF
	for sawmill_position in simulation.sawmill_positions:
		if simulation.player_citizen.global_position.distance_to(sawmill_position) <= float(simulation.INTERACTION_RANGE):
			return sawmill_position
	return Vector3.INF


func nearby_farm() -> bool:
	if simulation.player_citizen == null:
		return false
	for farm_position in simulation.farm_positions:
		if simulation.player_citizen.global_position.distance_to(farm_position) <= float(simulation.INTERACTION_RANGE):
			return true
	return false


func nearby_pond() -> bool:
	if simulation.player_citizen == null:
		return false
	for pond_position in simulation.pond_positions:
		if simulation.player_citizen.global_position.distance_to(pond_position) <= float(simulation.INTERACTION_RANGE):
			return true
	return false


func nearby_grass_source() -> bool:
	return nearby_grass_source_position() != Vector3.INF


func nearby_grass_source_position() -> Vector3:
	if simulation.player_citizen == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_dist: float = float(simulation.INTERACTION_RANGE)
	for cell in simulation.grass_sources:
		var source: GrassSourceRecord = simulation.grass_sources[cell]
		if source.remaining <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = source.node.global_position
		var dist: float = simulation.player_citizen.global_position.distance_to(node_pos)
		if dist <= best_dist:
			best_dist = dist
			best = node_pos
	return best


func consume_grass_near_player(amount: int) -> void:
	var remaining_to_take := amount
	while remaining_to_take > 0:
		var pos: Vector3 = nearby_grass_source_position()
		if pos == Vector3.INF:
			return
		simulation._consume_grass_source(pos)
		remaining_to_take -= 1


func nearby_forage_source() -> bool:
	if simulation.player_citizen == null:
		return false
	var player_cell: Vector2i = simulation._cell_from_position(simulation.player_citizen.global_position)
	for cell in simulation.forage_sources:
		if (cell as Vector2i) == player_cell:
			return true
	return false


func nearby_rabbit_source() -> bool:
	if simulation.player_citizen == null:
		return false
	for source: Dictionary in simulation.rabbit_sources.values():
		var rabbit := source.get("node") as Node3D
		if is_instance_valid(rabbit) and rabbit.global_position.distance_to(simulation.player_citizen.global_position) <= float(simulation.INTERACTION_RANGE):
			return true
	return false


func resource_remaining_percent(resource_type: String) -> int:
	if simulation.player_citizen == null:
		return 0
	match resource_type:
		"wood":
			for position in simulation.tree_positions:
				if simulation.player_citizen.global_position.distance_to(position) <= float(simulation.INTERACTION_RANGE):
					var tree: Node3D = simulation.tree_nodes.get(simulation._cell_from_position(position))
					if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
						return 100
			return 0
		"branches":
			for position in simulation.tree_positions:
				if simulation.player_citizen.global_position.distance_to(position) <= float(simulation.INTERACTION_RANGE):
					var tree: Node3D = simulation.tree_nodes.get(simulation._cell_from_position(position))
					if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
						var remaining := int(tree.get_meta("remaining_branches", 0))
						var initial := maxi(1, int(tree.get_meta("initial_branches", remaining)))
						return clampi(int(round(float(remaining) / float(initial) * 100.0)), 0, 100)
			return 0
		"grass":
			var pos: Vector3 = nearby_grass_source_position()
			if pos != Vector3.INF:
				var cell: Vector2i = simulation._cell_from_position(pos)
				var source: GrassSourceRecord = simulation.grass_sources.get(cell)
				if source == null:
					return 0
				var remaining := source.remaining
				var initial := maxi(1, source.initial)
				return clampi(int(round(float(remaining) / float(initial) * 100.0)), 0, 100)
			return 0
		"water":
			return 100
		"food":
			return 100
	return 0
