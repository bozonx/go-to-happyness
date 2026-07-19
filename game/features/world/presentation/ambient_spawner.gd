class_name AmbientSpawner
extends Node3D

const FirefliesEffectScript = preload("res://game/features/world/presentation/fireflies_effect.gd")

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
	var pond := Node3D.new()
	pond.position = center
	simulation.add_child(pond)
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 2.6
	rim_mesh.bottom_radius = 2.6
	rim_mesh.height = 0.3
	rim.mesh = rim_mesh
	rim.position.y = 0.12
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color("6f747a")
	rim.material_override = rim_material
	pond.add_child(rim)
	var surface := MeshInstance3D.new()
	var surface_mesh := CylinderMesh.new()
	surface_mesh.top_radius = 2.3
	surface_mesh.bottom_radius = 2.3
	surface_mesh.height = 0.24
	surface.mesh = surface_mesh
	surface.position.y = 0.2
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = Color("3f7fa0")
	surface_material.roughness = 0.2
	surface.material_override = surface_material
	pond.add_child(surface)
	
	# Ponds and excavated terrain are part of the same routing obstacle map.
	for x in range(-2, 3):
		for z in range(-2, 3):
			simulation.terrain_blocked_cells[simulation._cell_from_position(center) + Vector2i(x, z)] = true


func _create_tree(position_on_board: Vector3, refresh_navigation := true) -> void:
	var tree := Node3D.new()
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
	simulation.add_child(tree)
	
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.27
	trunk_mesh.height = 3.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.8
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("684630")
	trunk.material_override = trunk_material
	tree.add_child(trunk)
	
	for crown_data in [[Vector3(-0.35, 3.75, 0.0), 1.05], [Vector3(0.38, 4.05, 0.1), 1.16], [Vector3(0.0, 4.72, 0.0), 0.96]]:
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = crown_data[1]
		crown_mesh.height = crown_data[1] * 1.35
		crown.mesh = crown_mesh
		crown.position = crown_data[0]
		var crown_material := StandardMaterial3D.new()
		crown_material.albedo_color = Color("2d633b").lightened(simulation.random.randf_range(-0.06, 0.08))
		crown.material_override = crown_material
		tree.add_child(crown)
		
	var crown_occluder := StaticBody3D.new()
	crown_occluder.name = "TreeFlareOccluder"
	crown_occluder.collision_layer = SkyAndWeatherController.FLARE_OCCLUDER_LAYER
	crown_occluder.collision_mask = 0
	var crown_occluder_shape := CollisionShape3D.new()
	var crown_sphere := SphereShape3D.new()
	crown_sphere.radius = 1.5
	crown_occluder_shape.shape = crown_sphere
	crown_occluder_shape.position.y = 4.15
	crown_occluder.add_child(crown_occluder_shape)
	tree.add_child(crown_occluder)
	
	var collision_body := StaticBody3D.new()
	collision_body.name = "TreeCollision"
	var collision_shape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.18
	shape.height = 3.6
	collision_shape.shape = shape
	collision_shape.position.y = 1.8
	collision_body.add_child(collision_shape)
	tree.add_child(collision_body)
	
	simulation.terrain_blocked_cells[cell] = true
	if refresh_navigation:
		simulation._refresh_navigation_grid()


func _create_grass_sources_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(2, 0), Vector2i(-2, 1), Vector2i(1, -2)]:
		var cell: Vector2i = tree_cell + offset
		if simulation.grass_sources.has(cell) or simulation.tree_cells.has(cell) or simulation._is_navigation_cell_blocked(cell):
			continue
		var position: Vector3 = simulation._cell_center(cell)
		var node := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.3
		mesh.bottom_radius = 0.3
		mesh.height = 0.06
		node.mesh = mesh
		node.position = position + Vector3.UP * 0.05
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("4fbc55")
		material.emission_enabled = true
		material.emission = Color("245b2a")
		node.material_override = material
		simulation.add_child(node)
		var initial_remaining: int = simulation.random.randi_range(2, 5)
		simulation.grass_sources[cell] = {"node": node, "remaining": initial_remaining, "initial": initial_remaining}


func _create_forage_sources_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(3, 1), Vector2i(-3, -1)]:
		var cell: Vector2i = tree_cell + offset
		if simulation.forage_sources.has(cell) or simulation.tree_cells.has(cell) or simulation._is_navigation_cell_blocked(cell):
			continue
		var node := Node3D.new()
		node.position = simulation._cell_center(cell) + Vector3.UP * 0.05
		var stem := MeshInstance3D.new()
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.05
		stem_mesh.bottom_radius = 0.06
		stem_mesh.height = 0.16
		stem.mesh = stem_mesh
		stem.position.y = 0.08
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.16
		cap_mesh.height = 0.32
		cap.mesh = cap_mesh
		cap.position.y = 0.19
		cap.scale.y = 0.5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("75a84c")
		material.emission_enabled = true
		material.emission = Color("27451c")
		stem.material_override = material
		cap.material_override = material
		node.add_child(stem)
		node.add_child(cap)
		simulation._add_selector_to_node(node, "forage_selector", Vector3(0.5, 0.5, 0.5), Vector3.UP * 0.25)
		simulation.add_child(node)
		simulation.forage_sources[cell] = {"node": node}


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
	var fireflies_node: FirefliesEffect = FirefliesEffectScript.new()
	fireflies_node.name = cluster_name
	fireflies_node.position = _firefly_cluster_center(cells)
	fireflies_node.amount = amount_count
	fireflies_node.swarm_radius = radius
	fireflies_node.swarm_height = height
	fireflies_node.minimum_height = 0.45
	simulation.add_child(fireflies_node)
	simulation.fireflies.append(fireflies_node)


func _firefly_cluster_center(cells: Array) -> Vector3:
	var center := Vector3.ZERO
	for cell: Vector2i in cells:
		center += simulation._cell_center(cell)
	return center / float(cells.size()) + Vector3(0.0, 1.0, 0.0)


func create_entrance_stone() -> void:
	var entrance_stone := Node3D.new()
	entrance_stone.position = simulation._cell_center(Vector2i(-22, 1))
	entrance_stone.name = "EntranceSign"
	entrance_stone.rotation.y = PI * 0.5
	for x: float in [-0.62, 0.62]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.16, 1.55, 0.16)
		post.mesh = post_mesh
		post.position = Vector3(x, 0.78, 0.0)
		var post_material := StandardMaterial3D.new()
		post_material.albedo_color = Color("5c4033")
		post_material.roughness = 0.95
		post.material_override = post_material
		entrance_stone.add_child(post)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.8, 0.65, 0.14)
	board.mesh = board_mesh
	board.position = Vector3(0.0, 1.25, 0.0)
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color("8a6549")
	board_material.roughness = 0.9
	board.material_override = board_material
	entrance_stone.add_child(board)
	var label := Label3D.new()
	label.text = "Settlement"
	label.position = Vector3(0.0, 1.26, 0.09)
	label.font_size = 28
	label.modulate = Color("f0dfb2")
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	entrance_stone.add_child(label)
	var selector := Area3D.new()
	selector.add_to_group("entrance_selector")
	selector.collision_layer = 4
	selector.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.4, 1.0)
	collision.shape = shape
	collision.position.y = 1.1
	selector.add_child(collision)
	entrance_stone.add_child(selector)
	
	var entrance_highlight := MeshInstance3D.new()
	var hl_mesh := BoxMesh.new()
	hl_mesh.size = Vector3(2.4, 2.6, 1.2)
	entrance_highlight.mesh = hl_mesh
	entrance_highlight.position = Vector3(0.0, 1.1, 0.0)
	var hl_material := StandardMaterial3D.new()
	hl_material.albedo_color = Color(0.3, 0.85, 1.0, 0.25)
	hl_material.emission_energy_multiplier = 0.8
	hl_material.emission = Color(0.3, 0.85, 1.0)
	hl_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hl_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hl_material.no_depth_test = true
	entrance_highlight.material_override = hl_material
	entrance_highlight.visible = false
	entrance_stone.add_child(entrance_highlight)
	
	var entrance_sign_light := OmniLight3D.new()
	entrance_sign_light.light_color = Color("ffd58a")
	entrance_sign_light.light_energy = 2.0
	entrance_sign_light.omni_range = 5.0
	entrance_sign_light.shadow_enabled = true
	entrance_sign_light.position = Vector3(0.0, 2.2, 0.0)
	entrance_sign_light.visible = false
	entrance_stone.add_child(entrance_sign_light)
	
	simulation.entrance_lights.append(entrance_sign_light)
	simulation.add_child(entrance_stone)
	simulation.entrance_stone = entrance_stone
	simulation.entrance_highlight = entrance_highlight


func spawn_trash_piles() -> void:
	var trash_cells := [Vector2i(-10, -3), Vector2i(7, 12), Vector2i(-14, 6), Vector2i(5, -12)]
	var trash_contents := [
		{"grass": simulation.random.randi_range(8, 14), "branches": simulation.random.randi_range(4, 8)},
		{"grass": simulation.random.randi_range(6, 12), "branches": simulation.random.randi_range(3, 7)},
		{"grass": simulation.random.randi_range(10, 16), "branches": simulation.random.randi_range(5, 9)},
		{"grass": simulation.random.randi_range(4, 8), "branches": simulation.random.randi_range(2, 5), "gloves": 1},
	]
	for i in range(trash_cells.size()):
		var cell: Vector2i = trash_cells[i]
		if not simulation._is_board_cell(cell) or simulation.terrain_blocked_cells.has(cell):
			continue
		simulation._create_resource_pile(simulation._cell_center(cell), trash_contents[i])


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
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.48, 0.32, 0.32)
		node.mesh = mesh
		node.position = simulation._cell_center(cell) + Vector3.UP * 0.16
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d5d1c3")
		node.material_override = material
		simulation._add_selector_to_node(node, "rabbit_selector", Vector3(0.5, 0.4, 0.5), Vector3.UP * 0.2)
		simulation.add_child(node)
		simulation.rabbit_sources[cell] = {"node": node, "direction": Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized()}


func update_wild_food(delta: float) -> void:
	for source in simulation.rabbit_sources.values():
		var rabbit := source.get("node") as Node3D
		if not is_instance_valid(rabbit):
			continue
		var direction: Vector3 = source.get("direction", Vector3.FORWARD)
		if simulation.random.randf() < delta * 0.7:
			direction = Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized()
			source.direction = direction
		var next := rabbit.global_position + direction * delta * 0.7
		if simulation._is_navigation_cell_blocked(simulation._cell_from_position(next)):
			source.direction = -direction
		else:
			rabbit.global_position = next
	for cell in simulation.forage_respawn_at.keys().duplicate():
		if simulation.runtime_seconds >= float(simulation.forage_respawn_at[cell]):
			_create_forage_sources_near_tree((cell as Vector2i) - Vector2i(3, 1))
			simulation.forage_respawn_at.erase(cell)
	for cell in simulation.rabbit_respawn_at.keys().duplicate():
		if simulation.runtime_seconds >= float(simulation.rabbit_respawn_at[cell]) and simulation.rabbit_sources.size() < simulation.RABBIT_MAX_COUNT:
			_spawn_rabbit_near_tree(cell as Vector2i)
			simulation.rabbit_respawn_at.erase(cell)
