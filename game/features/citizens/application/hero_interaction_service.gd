class_name HeroInteractionService
extends RefCounted

## Handles hero proximity queries for nearby trees, sawmills, farms, water,
## grass patches, forage sources, rabbits, and interaction percentages.

const HarvestSourceRecord = preload("res://game/features/production/domain/harvest_source_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _player_citizen_getter: Callable
var _interaction_range: float
var _tree_positions: Array[Vector3] = []
var _tree_nodes: Dictionary = {}
var _sawmill_positions: Array[Vector3] = []
var _farm_positions: Array[Vector3] = []
var _water_source_positions_getter: Callable
var _grass_sources: Dictionary = {}
var _forage_sources: Dictionary = {}
var _rabbit_sources: Dictionary = {}
var _bush_sources: Dictionary = {}
var _cell_from_position: Callable
var _consume_grass_source: Callable


func configure(port: HeroInteractionRuntimePort) -> void:
	_player_citizen_getter = port.player_citizen_getter
	_interaction_range = port.interaction_range
	_tree_positions = port.tree_positions
	_tree_nodes = port.tree_nodes
	_sawmill_positions = port.sawmill_positions
	_farm_positions = port.farm_positions
	_water_source_positions_getter = port.water_source_positions_getter
	_grass_sources = port.grass_sources
	_forage_sources = port.forage_sources
	_rabbit_sources = port.rabbit_sources
	_bush_sources = port.bush_sources
	_cell_from_position = port.cell_from_position
	_consume_grass_source = port.consume_grass_source


func nearby_tree() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var max_dist := _interaction_range + 1.5
	for tree_position in _tree_positions:
		if player_xz.distance_to(Vector2(tree_position.x, tree_position.z)) <= max_dist:
			var tree: Node3D = _tree_nodes.get(_cell_from_position.call(tree_position))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				return true
	return false


func nearby_tree_with_branches() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var max_dist := _interaction_range + 1.5
	for tree_position in _tree_positions:
		if player_xz.distance_to(Vector2(tree_position.x, tree_position.z)) <= max_dist:
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
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var max_dist := _interaction_range + 1.5
	for sawmill_position in _sawmill_positions:
		if player_xz.distance_to(Vector2(sawmill_position.x, sawmill_position.z)) <= max_dist:
			return sawmill_position
	return Vector3.INF


func nearby_farm() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var max_dist := _interaction_range + 1.5
	for farm_position in _farm_positions:
		if player_xz.distance_to(Vector2(farm_position.x, farm_position.z)) <= max_dist:
			return true
	return false


func nearby_water_source() -> bool:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return false
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var max_dist := _interaction_range + 1.5
	for source_position: Vector3 in (_water_source_positions_getter.call() as Array):
		if player_xz.distance_to(Vector2(source_position.x, source_position.z)) <= max_dist:
			return true
	return false


func nearby_grass_source() -> bool:
	return nearby_grass_source_position() != Vector3.INF


func nearby_grass_source_position() -> Vector3:
	return _nearby_source_position(_grass_sources)


func nearby_bush_source_position() -> Vector3:
	return _nearby_source_position(_bush_sources)


## Доля оставшегося в ближайшем источнике этого вида; 0, если рядом ничего нет.
func _source_remaining_percent(sources: Dictionary) -> int:
	var pos: Vector3 = _nearby_source_position(sources)
	if pos == Vector3.INF:
		return 0
	var source: HarvestSourceRecord = sources.get(_cell_from_position.call(pos) as Vector2i)
	if source == null:
		return 0
	return clampi(int(round(float(source.remaining) / float(maxi(1, source.initial)) * 100.0)), 0, 100)


func _nearby_source_position(sources: Dictionary) -> Vector3:
	var player: Citizen = _player_citizen_getter.call()
	if player == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var max_dist: float = _interaction_range + 1.5
	var best_dist: float = max_dist
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	for cell in sources:
		var source: HarvestSourceRecord = sources[cell]
		if source == null or source.is_spent():
			continue
		var node_pos: Vector3 = Vector3.INF
		if is_instance_valid(source.node):
			node_pos = source.node.global_position
		else:
			var c: Vector2i = cell as Vector2i
			node_pos = Vector3((c.x + 0.5) * 2.0, 0.0, (c.y + 0.5) * 2.0)
		var dist: float = player_xz.distance_to(Vector2(node_pos.x, node_pos.z))
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
			# Без дерева рядом ветки всё ещё могут быть — на кусте.
			return _source_remaining_percent(_bush_sources)
		ResourceIds.GRASS:
			return _source_remaining_percent(_grass_sources)
		ResourceIds.WATER:
			return 100
		ResourceIds.FOOD:
			return 100
	return 0
