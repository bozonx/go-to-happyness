class_name HeroInteractionService
extends RefCounted

## Handles hero proximity queries for nearby trees, sawmills, farms, ponds,
## grass patches, forage sources, rabbits, and interaction percentages.

const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _player_citizen_getter: Callable
var _interaction_range: float
var _tree_positions: Array[Vector3] = []
var _tree_nodes: Dictionary = {}
var _sawmill_positions: Array[Vector3] = []
var _farm_positions: Array[Vector3] = []
var _pond_positions: Array[Vector3] = []
var _grass_sources: Dictionary = {}
var _forage_sources: Dictionary = {}
var _rabbit_sources: Dictionary = {}
var _cell_from_position: Callable
var _consume_grass_source: Callable


func configure(
	p_player_citizen_getter: Callable,
	p_interaction_range: float,
	p_tree_positions: Array[Vector3],
	p_tree_nodes: Dictionary,
	p_sawmill_positions: Array[Vector3],
	p_farm_positions: Array[Vector3],
	p_pond_positions: Array[Vector3],
	p_grass_sources: Dictionary,
	p_forage_sources: Dictionary,
	p_rabbit_sources: Dictionary,
	p_cell_from_position: Callable,
	p_consume_grass_source: Callable
) -> void:
	_player_citizen_getter = p_player_citizen_getter
	_interaction_range = p_interaction_range
	_tree_positions = p_tree_positions
	_tree_nodes = p_tree_nodes
	_sawmill_positions = p_sawmill_positions
	_farm_positions = p_farm_positions
	_pond_positions = p_pond_positions
	_grass_sources = p_grass_sources
	_forage_sources = p_forage_sources
	_rabbit_sources = p_rabbit_sources
	_cell_from_position = p_cell_from_position
	_consume_grass_source = p_consume_grass_source


func nearby_tree() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	for tree_position in _tree_positions:
		if player.global_position.distance_to(tree_position) <= _interaction_range:
			var tree: Node3D = _tree_nodes.get(_cell_from_position.call(tree_position))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				return true
	return false


func nearby_tree_with_branches() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	for tree_position in _tree_positions:
		if player.global_position.distance_to(tree_position) <= _interaction_range:
			var tree: Node3D = _tree_nodes.get(_cell_from_position.call(tree_position))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				if int(tree.get_meta("remaining_branches", 0)) > 0:
					return true
	return false


func nearby_sawmill() -> bool:
	return nearby_sawmill_position() != Vector3.INF


func nearby_sawmill_position() -> Vector3:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return Vector3.INF
	for sawmill_position in _sawmill_positions:
		if player.global_position.distance_to(sawmill_position) <= _interaction_range:
			return sawmill_position
	return Vector3.INF


func nearby_farm() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	for farm_position in _farm_positions:
		if player.global_position.distance_to(farm_position) <= _interaction_range:
			return true
	return false


func nearby_pond() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	for pond_position in _pond_positions:
		if player.global_position.distance_to(pond_position) <= _interaction_range:
			return true
	return false


func nearby_grass_source() -> bool:
	return nearby_grass_source_position() != Vector3.INF


func nearby_grass_source_position() -> Vector3:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_dist: float = _interaction_range
	for cell in _grass_sources:
		var source: GrassSourceRecord = _grass_sources[cell]
		if source.remaining <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = source.node.global_position
		var dist: float = player.global_position.distance_to(node_pos)
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
		_consume_grass_source.call(pos)
		remaining_to_take -= 1


func nearby_forage_source() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	var player_cell: Vector2i = _cell_from_position.call(player.global_position)
	for cell in _forage_sources:
		if (cell as Vector2i) == player_cell:
			return true
	return false


func nearby_rabbit_source() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	for source: Dictionary in _rabbit_sources.values():
		var rabbit := source.get("node") as Node3D
		if is_instance_valid(rabbit) and rabbit.global_position.distance_to(player.global_position) <= _interaction_range:
			return true
	return false


func resource_remaining_percent(resource_type: String) -> int:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return 0
	match resource_type:
		ResourceIds.WOOD:
			for position in _tree_positions:
				if player.global_position.distance_to(position) <= _interaction_range:
					var tree: Node3D = _tree_nodes.get(_cell_from_position.call(position))
					if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
						return 100
			return 0
		ResourceIds.BRANCHES:
			for position in _tree_positions:
				if player.global_position.distance_to(position) <= _interaction_range:
					var tree: Node3D = _tree_nodes.get(_cell_from_position.call(position))
					if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
						var remaining := int(tree.get_meta("remaining_branches", 0))
						var initial := maxi(1, int(tree.get_meta("initial_branches", remaining)))
						return clampi(int(round(float(remaining) / float(initial) * 100.0)), 0, 100)
			return 0
		ResourceIds.GRASS:
			var pos: Vector3 = nearby_grass_source_position()
			if pos != Vector3.INF:
				var cell: Vector2i = _cell_from_position.call(pos)
				var source: GrassSourceRecord = _grass_sources.get(cell)
				if source == null:
					return 0
				var remaining := source.remaining
				var initial := maxi(1, source.initial)
				return clampi(int(round(float(remaining) / float(initial) * 100.0)), 0, 100)
			return 0
		ResourceIds.WATER:
			return 100
		ResourceIds.FOOD:
			return 100
	return 0
