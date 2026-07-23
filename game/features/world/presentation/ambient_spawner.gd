class_name AmbientSpawner
extends Node3D

const FirefliesEffectScene = preload("res://game/features/world/presentation/fireflies_effect.tscn")
const PondScene = preload("res://game/features/world/presentation/pond.tscn")
const TreeScene = preload("res://game/features/world/presentation/tree.tscn")
const GrassSourceScene = preload("res://game/features/world/presentation/grass_source.tscn")
const ForageSourceScene = preload("res://game/features/world/presentation/forage_source.tscn")
const RabbitScene = preload("res://game/features/world/presentation/rabbit.tscn")
const EntranceSignScene = preload("res://game/features/world/presentation/entrance_sign.tscn")
const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")
const ForageSourceRecord = preload("res://game/features/production/domain/forage_source_record.gd")
const RabbitSourceRecord = preload("res://game/features/production/domain/rabbit_source_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var simulation: Node


func setup(p_simulation: Node) -> void:
	simulation = p_simulation


func create_forest() -> void:
	var cells := [
		Vector2i(-16, -15), Vector2i(-15, -18), Vector2i(-18, -12), Vector2i(-12, -19),
		Vector2i(16, -15), Vector2i(15, -18), Vector2i(18, -12), Vector2i(12, -19),
		Vector2i(-16, 15), Vector2i(-15, 18), Vector2i(-18, 12), Vector2i(-12, 19),
		Vector2i(16, 15), Vector2i(15, 18), Vector2i(18, 12), Vector2i(12, 19),
		Vector2i(-20, -5), Vector2i(-20, 5),
		Vector2i(20, -5), Vector2i(20, 5),
		Vector2i(-5, -20), Vector2i(5, -20),
		Vector2i(-5, 20), Vector2i(5, 20)
	]
	for cell in cells:
		var tree_position: Vector3 = simulation._cell_center(cell)
		simulation.tree_cells[cell] = true
		simulation.tree_positions.append(tree_position)
		_create_tree(tree_position, false)
		_create_grass_sources_near_tree(cell)
		_create_forage_sources_near_tree(cell)
	simulation._refresh_navigation_grid()
	_create_firefly_clusters()


func create_ponds() -> void:
	# Natural ponds are part of the terrain, not a building.
	for cell in [Vector2i(-9, 8), Vector2i(10, -7)]:
		var center: Vector3 = simulation._cell_center(cell)
		simulation.pond_positions.append(center)
		_create_pond_visual(center)
	simulation._refresh_navigation_grid()


func _create_pond_visual(center: Vector3) -> void:
	var pond: Node3D = PondScene.instantiate()
	pond.position = center
	simulation.add_landscape_object(pond)
	
	# Ponds and excavated terrain are part of the same routing obstacle map.
	for x in range(-2, 3):
		for z in range(-2, 3):
			simulation.terrain_blocked_cells[simulation._cell_from_position(center) + Vector2i(x, z)] = true


func _create_tree(position_on_board: Vector3, refresh_navigation := true) -> void:
	var tree: Node3D = TreeScene.instantiate()
	tree.position = position_on_board
	var initial_wood: int = simulation.random.randi_range(4, 7)
	tree.set_meta("initial_wood", initial_wood)
	tree.set_meta("remaining_wood", initial_wood)
	var initial_branches: int = simulation.random.randi_range(5, 9)
	tree.set_meta("initial_branches", initial_branches)
	tree.set_meta("remaining_branches", initial_branches)
	tree.set_meta("hand_branches", 0)
	
	var cell: Vector2i = simulation._cell_from_position(position_on_board)
	simulation.tree_nodes[cell] = tree
	simulation.add_landscape_object(tree)
	
	# Add the tree interaction selector group so first-person raycast can find it.
	var interaction_selector := tree.get_node_or_null("TreeInteractionSelector") as Area3D
	if interaction_selector != null:
		interaction_selector.add_to_group("tree_selector")

	# Crown colour is randomised per tree, so override the material in code.
	for crown_name in ["Crown1", "Crown2", "Crown3"]:
		var crown := tree.get_node(crown_name) as MeshInstance3D
		if crown != null:
			var crown_material := StandardMaterial3D.new()
			crown_material.albedo_color = Color("2d633b").lightened(simulation.random.randf_range(-0.06, 0.08))
			crown.material_override = crown_material
	
	simulation.terrain_blocked_cells[cell] = true
	if refresh_navigation:
		simulation._refresh_navigation_grid()


func _create_grass_sources_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(2, 0), Vector2i(-2, 1), Vector2i(1, -2)]:
		var cell: Vector2i = tree_cell + offset
		if simulation.grass_sources.has(cell) or simulation.tree_cells.has(cell) or simulation._is_navigation_cell_blocked(cell):
			continue
		var position: Vector3 = simulation._cell_center(cell)
		var node: MeshInstance3D = GrassSourceScene.instantiate()
		node.position = position + Vector3.UP * 0.05
		simulation.add_landscape_object(node)
		var initial_remaining: int = simulation.random.randi_range(2, 5)
		simulation.grass_sources[cell] = GrassSourceRecord.new(node, initial_remaining, initial_remaining)


func _create_forage_sources_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(3, 1), Vector2i(-3, -1)]:
		var cell: Vector2i = tree_cell + offset
		if simulation.forage_sources.has(cell) or simulation.tree_cells.has(cell) or simulation._is_navigation_cell_blocked(cell):
			continue
		var node: Node3D = ForageSourceScene.instantiate()
		node.position = simulation._cell_center(cell) + Vector3.UP * 0.05
		simulation._add_selector_to_node(node, "forage_selector", Vector3(0.5, 0.5, 0.5), Vector3.UP * 0.25)
		simulation.add_landscape_object(node)
		simulation.forage_sources[cell] = ForageSourceRecord.new(node)


func _create_firefly_clusters() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_create_firefly_cluster("FirefliesNorthWest", [Vector2i(-16, -15), Vector2i(-15, -18), Vector2i(-18, -12), Vector2i(-12, -19)], 38, 4.4, 3.5)
	_create_firefly_cluster("FirefliesNorthEast", [Vector2i(16, -15), Vector2i(15, -18), Vector2i(18, -12), Vector2i(12, -19)], 38, 4.4, 3.5)
	_create_firefly_cluster("FirefliesSouthWest", [Vector2i(-16, 15), Vector2i(-15, 18), Vector2i(-18, 12), Vector2i(-12, 19)], 38, 4.4, 3.5)
	_create_firefly_cluster("FirefliesSouthEast", [Vector2i(16, 15), Vector2i(15, 18), Vector2i(18, 12), Vector2i(12, 19)], 38, 4.4, 3.5)
	_create_firefly_cluster("FirefliesWestGrove", [Vector2i(-20, -5), Vector2i(-20, 5)], 24, 3.6, 2.8)
	_create_firefly_cluster("FirefliesEastGrove", [Vector2i(20, -5), Vector2i(20, 5)], 24, 3.6, 2.8)
	_create_firefly_cluster("FirefliesNorthGrove", [Vector2i(-5, -20), Vector2i(5, -20)], 24, 3.6, 2.8)
	_create_firefly_cluster("FirefliesSouthGrove", [Vector2i(-5, 20), Vector2i(5, 20)], 24, 3.6, 2.8)


func _create_firefly_cluster(cluster_name: String, cells: Array, amount_count: int, radius: float, height: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fireflies_node := FirefliesEffectScene.instantiate() as FirefliesEffect
	fireflies_node.name = cluster_name
	fireflies_node.position = _firefly_cluster_center(cells)
	fireflies_node.amount = amount_count
	fireflies_node.swarm_radius = radius
	fireflies_node.swarm_height = height
	fireflies_node.minimum_height = 0.45
	simulation.add_landscape_object(fireflies_node)
	simulation.fireflies.append(fireflies_node)


func _firefly_cluster_center(cells: Array) -> Vector3:
	var center := Vector3.ZERO
	for cell: Vector2i in cells:
		center += simulation._cell_center(cell)
	return center / float(cells.size()) + Vector3(0.0, 1.0, 0.0)


func setup_entrance_sign_node(entrance_stone: Node3D) -> void:
	if not is_instance_valid(entrance_stone):
		return
	var entrance_sign_light := entrance_stone.get_node_or_null("EntranceSignLight") as OmniLight3D
	if entrance_sign_light != null and not simulation.entrance_lights.has(entrance_sign_light):
		simulation.entrance_lights.append(entrance_sign_light)


func spawn_trash_piles() -> void:
	var trash_cells := [Vector2i(-10, -3), Vector2i(7, 12), Vector2i(-14, 6), Vector2i(5, -12)]
	var trash_contents := [
		{ResourceIds.GRASS: simulation.random.randi_range(8, 14), ResourceIds.BRANCHES: simulation.random.randi_range(4, 8)},
		{ResourceIds.GRASS: simulation.random.randi_range(6, 12), ResourceIds.BRANCHES: simulation.random.randi_range(3, 7)},
		{ResourceIds.GRASS: simulation.random.randi_range(10, 16), ResourceIds.BRANCHES: simulation.random.randi_range(5, 9)},
		{ResourceIds.GRASS: simulation.random.randi_range(4, 8), ResourceIds.BRANCHES: simulation.random.randi_range(2, 5), "gloves": 1},
	]
	for i in range(trash_cells.size()):
		var cell: Vector2i = trash_cells[i]
		if not simulation._is_board_cell(cell) or simulation.terrain_blocked_cells.has(cell):
			continue
		var pile: Node3D = simulation._create_resource_pile(simulation._cell_center(cell), trash_contents[i]) as Node3D
		# These are authored world loot, unlike piles dropped by citizens or
		# logistics. Keep their visuals under the territory while the logistics
		# service continues to own their resource record.
		if pile != null:
			pile.set_meta("landscape_owned", true)
			simulation.add_landscape_object(pile)


func spawn_initial_rabbits() -> void:
	for tree_cell in simulation.tree_cells.keys():
		if simulation.rabbit_sources.size() >= simulation.RABBIT_MAX_COUNT:
			break
		_spawn_rabbit_near_tree(tree_cell as Vector2i)


func _spawn_rabbit_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(4, 0), Vector2i(-4, 2), Vector2i(2, -4)]:
		var cell: Vector2i = tree_cell + offset
		if simulation.rabbit_sources.has(cell) or simulation.tree_cells.has(cell) or simulation._is_navigation_cell_blocked(cell):
			continue
		var node: MeshInstance3D = RabbitScene.instantiate()
		node.position = simulation._cell_center(cell) + Vector3.UP * 0.16
		simulation._add_selector_to_node(node, "rabbit_selector", Vector3(0.5, 0.4, 0.5), Vector3.UP * 0.2)
		simulation.add_landscape_object(node)
		simulation.rabbit_sources[cell] = RabbitSourceRecord.new(node, Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized())


func update_wild_food(delta: float) -> void:
	for source in simulation.rabbit_sources.values():
		var rabbit: RabbitSourceRecord = source
		if not is_instance_valid(rabbit.node):
			continue
		var direction: Vector3 = rabbit.direction
		if simulation.random.randf() < delta * 0.7:
			direction = Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized()
			rabbit.direction = direction
		var next := rabbit.node.global_position + direction * delta * 0.7
		if simulation._is_navigation_cell_blocked(simulation._cell_from_position(next)):
			rabbit.direction = -direction
		else:
			rabbit.node.global_position = next
	for cell in simulation.forage_respawn_at.keys().duplicate():
		if simulation.runtime_seconds >= float(simulation.forage_respawn_at[cell]):
			_create_forage_sources_near_tree((cell as Vector2i) - Vector2i(3, 1))
			simulation.forage_respawn_at.erase(cell)
	for cell in simulation.rabbit_respawn_at.keys().duplicate():
		if simulation.runtime_seconds >= float(simulation.rabbit_respawn_at[cell]) and simulation.rabbit_sources.size() < simulation.RABBIT_MAX_COUNT:
			_spawn_rabbit_near_tree(cell as Vector2i)
			simulation.rabbit_respawn_at.erase(cell)
