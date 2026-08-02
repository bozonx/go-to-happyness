class_name AmbientSpawner
extends Node3D

const TreeScene = preload("res://game/features/world/presentation/tree.tscn")
const GrassSourceScene = preload("res://game/features/world/presentation/grass_source.tscn")
const ForageSourceScene = preload("res://game/features/world/presentation/forage_source.tscn")
const RabbitScene = preload("res://game/features/world/presentation/rabbit.tscn")
const EntranceSignScene = preload("res://game/features/world/presentation/entrance_sign.tscn")
const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")
const ForageSourceRecord = preload("res://game/features/production/domain/forage_source_record.gd")
const RabbitSourceRecord = preload("res://game/features/production/domain/rabbit_source_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const WorldResourceStateScript = preload("res://game/features/world/domain/world_resource_state.gd")

var simulation: Node
var map_document: MapDocument = null
## The entrance this session began at. Entities bound to another one are not
## created (`map_start.md` §3.2): a player who came in from the south must not
## find the cart the author put at the north gate.
var start_option: StringName = &""

class NaturalEntry:
	extends RefCounted
	var position := Vector3.ZERO
	var props: Dictionary = {}


func setup(p_simulation: Node, map_document: MapDocument = null, p_start_option: StringName = &"") -> void:
	simulation = p_simulation
	self.map_document = map_document
	start_option = p_start_option


func _entities_of_kind(kind: StringName) -> Array[NaturalEntry]:
	var result: Array[NaturalEntry] = []
	if map_document == null:
		return result
	for placed: MapEntityRecord in map_document.entities.entities:
		if not placed.belongs_to_start(start_option):
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype == null or not archetype.has_component(&"settlement_natural"):
			continue
		if StringName(archetype.component_data(&"settlement_natural").get("kind", "")) != kind:
			continue
		var entry := NaturalEntry.new()
		entry.position = placed.position
		entry.position.y = simulation.terrain_height_at(entry.position.x, entry.position.z, entry.position.y) + placed.position.y
		entry.props = archetype.resolved_properties(placed.props)
		result.append(entry)
	return result


func create_forest() -> void:
	for entry in _entities_of_kind(&"tree"):
		var tree_position: Vector3 = entry.position
		var cell: Vector2i = simulation.cell_from_position(tree_position)
		simulation.tree_cells[cell] = true
		simulation.tree_positions.append(tree_position)
		_create_tree(tree_position, false, int(entry.props.get(&"wood", 6)), int(entry.props.get(&"branches", 7)))
	for entry in _entities_of_kind(&"grass_source"):
		_create_grass_source_at(entry.position, int(entry.props.get(&"amount", 3)))
	for entry in _entities_of_kind(&"forage_source"):
		_create_forage_source_at(entry.position)
	simulation.world_navigation_controller.refresh_navigation_grid()
	# Fireflies are no longer spawned here: they are authored as `core:fireflies`
	# map entities and rendered by MapEntityPresenter, which publishes each
	# instance into WorldSetup.fireflies for the weather controller.


func _create_tree(position_on_board: Vector3, refresh_navigation := true, initial_wood := -1, initial_branches := -1) -> void:
	var tree: Node3D = TreeScene.instantiate()
	tree.position = position_on_board
	initial_wood = simulation.random.randi_range(4, 7) if initial_wood < 0 else initial_wood
	initial_branches = simulation.random.randi_range(5, 9) if initial_branches < 0 else initial_branches
	
	var cell: Vector2i = simulation.cell_from_position(position_on_board)
	var tree_state: Variant = simulation.world_resource_state.create_tree(cell, initial_wood, initial_branches)
	_sync_tree_visual_state(tree, tree_state)
	simulation.tree_nodes[cell] = tree
	simulation.world_navigation_controller.add_landscape_object(tree)
	
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
		simulation.world_navigation_controller.refresh_navigation_grid()


func _create_grass_source_at(position: Vector3, amount: int) -> void:
	var cell: Vector2i = simulation.cell_from_position(position)
	if not simulation.is_board_cell(cell) or simulation.grass_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node: MeshInstance3D = GrassSourceScene.instantiate()
	node.position = position + Vector3.UP * 0.05
	simulation.building_visuals.add_selector_to_node(node, "grass_selector", Vector3(1.2, 0.6, 1.2), Vector3.UP * 0.3)
	simulation.world_navigation_controller.add_landscape_object(node)
	simulation.grass_sources[cell] = GrassSourceRecord.new(node, amount, amount)


func _create_forage_source_at(position: Vector3) -> void:
	var cell: Vector2i = simulation.cell_from_position(position)
	if not simulation.is_board_cell(cell) or simulation.forage_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node: Node3D = ForageSourceScene.instantiate()
	node.position = position + Vector3.UP * 0.05
	simulation.building_visuals.add_selector_to_node(node, "forage_selector", Vector3(0.5, 0.5, 0.5), Vector3.UP * 0.25)
	simulation.world_navigation_controller.add_landscape_object(node)
	simulation.forage_sources[cell] = ForageSourceRecord.new(node)


func setup_entrance_sign_node(entrance_stone: Node3D) -> void:
	if not is_instance_valid(entrance_stone):
		return
	var entrance_sign_light := entrance_stone.get_node_or_null("EntranceSignLight") as OmniLight3D
	if entrance_sign_light != null and not simulation.entrance_lights.has(entrance_sign_light):
		simulation.entrance_lights.append(entrance_sign_light)


func spawn_trash_piles() -> void:
	for entry in _entities_of_kind(&"starter_loot"):
		var cell: Vector2i = simulation.cell_from_position(entry.position)
		if not simulation.is_board_cell(cell) or simulation.terrain_blocked_cells.has(cell):
			continue
		var pile: Node3D = simulation.resource_pile_service.create_resource_pile(entry.position, _loot_resources(entry.props)) as Node3D
		# These are authored world loot, unlike piles dropped by citizens or
		# logistics. Keep their visuals under the territory while the logistics
		# service continues to own their resource record.
		if pile != null:
			pile.set_meta("landscape_owned", true)
			simulation.world_navigation_controller.add_landscape_object(pile)


func _loot_resources(loot: Dictionary) -> Dictionary:
	var resources: Dictionary = {}
	for field in [{"name": &"grass", "resource": ResourceIds.GRASS}, {"name": &"branches", "resource": ResourceIds.BRANCHES}]:
		var amount := int(loot.get(field.name, 0))
		if amount > 0:
			resources[field.resource] = amount
	return resources


func spawn_initial_rabbits() -> void:
	for entry in _entities_of_kind(&"rabbit"):
		if simulation.rabbit_sources.size() >= simulation.RABBIT_MAX_COUNT:
			break
		_create_rabbit_source(simulation.cell_from_position(entry.position), entry.position + Vector3.UP * 0.16, Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized())


func update_wild_food(delta: float) -> void:
	# Wild food no longer respawns: a harvested bush or a caught rabbit is gone
	# for the rest of the session, which keeps the map finite and avoids
	# fabricating new positions. Only rabbit roaming animation runs here.
	for source in simulation.rabbit_sources.values():
		var rabbit: RabbitSourceRecord = source
		if not is_instance_valid(rabbit.node):
			continue
		var direction: Vector3 = rabbit.direction
		if simulation.random.randf() < delta * 0.7:
			direction = Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized()
			rabbit.direction = direction
		var next := rabbit.node.global_position + direction * delta * 0.7
		if simulation.navigation_blocked_cells.has(simulation.cell_from_position(next)):
			rabbit.direction = -direction
		else:
			rabbit.node.global_position = next


func export_resource_state() -> Dictionary:
	var state := WorldResourceStateScript.new()
	state.capture(
		simulation.grass_sources,
		simulation.forage_sources,
		simulation.rabbit_sources
	)
	return state.to_save_dict()


func restore_resource_state(data: Dictionary) -> void:
	if data.is_empty():
		return # Older saves retain the freshly generated natural resources.
	var state := WorldResourceStateScript.new()
	state.load_from_save_dict(data)
	_clear_natural_source_nodes()
	for entry: Dictionary in state.grass_sources:
		var cell := WorldResourceStateScript._dict_to_cell(entry.get("cell", {}))
		_create_grass_source(cell, int(entry.get("remaining", 0)), int(entry.get("initial", 0)))
	for cell in state.forage_cells:
		_create_forage_source(cell)
	for entry: Dictionary in state.rabbits:
		var cell := WorldResourceStateScript._dict_to_cell(entry.get("cell", {}))
		_create_rabbit_source(cell, WorldResourceStateScript._dict_to_vector(entry.get("position", {})), WorldResourceStateScript._dict_to_vector(entry.get("direction", {})))


func _clear_natural_source_nodes() -> void:
	for source in simulation.grass_sources.values():
		if is_instance_valid(source.node): source.node.queue_free()
	for source in simulation.forage_sources.values():
		if is_instance_valid(source.node): source.node.queue_free()
	for source in simulation.rabbit_sources.values():
		if is_instance_valid(source.node): source.node.queue_free()
	simulation.grass_sources.clear()
	simulation.forage_sources.clear()
	simulation.rabbit_sources.clear()


func _create_grass_source(cell: Vector2i, remaining: int, initial: int) -> void:
	var node: MeshInstance3D = GrassSourceScene.instantiate()
	node.position = simulation.nav_grid.cell_center(cell) if simulation.nav_grid != null else Vector3((cell.x + 0.5) * simulation.CELL_SIZE, 0.0, (cell.y + 0.5) * simulation.CELL_SIZE) + Vector3.UP * 0.05
	simulation.building_visuals.add_selector_to_node(node, "grass_selector", Vector3(1.2, 0.6, 1.2), Vector3.UP * 0.3)
	simulation.world_navigation_controller.add_landscape_object(node)
	simulation.grass_sources[cell] = GrassSourceRecord.new(node, remaining, initial)


func _create_forage_source(cell: Vector2i) -> void:
	var node: Node3D = ForageSourceScene.instantiate()
	node.position = simulation.nav_grid.cell_center(cell) if simulation.nav_grid != null else Vector3((cell.x + 0.5) * simulation.CELL_SIZE, 0.0, (cell.y + 0.5) * simulation.CELL_SIZE) + Vector3.UP * 0.05
	simulation.building_visuals.add_selector_to_node(node, "forage_selector", Vector3(0.5, 0.5, 0.5), Vector3.UP * 0.25)
	simulation.world_navigation_controller.add_landscape_object(node)
	simulation.forage_sources[cell] = ForageSourceRecord.new(node)


func _create_rabbit_source(cell: Vector2i, position: Vector3, direction: Vector3) -> void:
	var node: MeshInstance3D = RabbitScene.instantiate()
	node.position = position
	simulation.building_visuals.add_selector_to_node(node, "rabbit_selector", Vector3(0.5, 0.4, 0.5), Vector3.UP * 0.2)
	simulation.world_navigation_controller.add_landscape_object(node)
	simulation.rabbit_sources[cell] = RabbitSourceRecord.new(node, direction)


func _sync_tree_visual_state(tree: Node3D, state: Variant) -> void:
	# Compatibility projection for presentation code that has not yet moved to
	# WorldResourceState. Gameplay writes go through the state record.
	tree.set_meta("initial_wood", state.initial_wood)
	tree.set_meta("remaining_wood", state.remaining_wood)
	tree.set_meta("initial_branches", state.initial_branches)
	tree.set_meta("remaining_branches", state.remaining_branches)
	tree.set_meta("hand_branches", state.hand_branches)
	tree.set_meta("branch_exhausted", state.branch_exhausted)
	tree.set_meta("felled", state.felled)
