class_name AmbientSpawner
extends Node3D

const HarvestSourceRecord = preload("res://game/features/production/domain/harvest_source_record.gd")
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
	## Asset the archetype draws itself with. Two archetypes may share one gameplay
	## kind and differ only here — that is how a spruce is a tree.
	var asset_id: StringName = &""
	var appearance: Dictionary = {}


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
		entry.asset_id = archetype.asset_id
		entry.appearance = placed.appearance.duplicate(true)
		result.append(entry)
	return result


## Scene of a catalog asset, or null when the pack that owns it is not installed.
## A missing asset must not take the session down with it (`map_fill_mode.md` §11):
## the entity is skipped and the rest of the map still loads.
func _scene_of(asset_id: StringName) -> PackedScene:
	var asset := WorldAssetCatalog.get_asset(asset_id)
	if asset == null or not ResourceLoader.exists(asset.scene_path):
		push_warning("AmbientSpawner: ассет «%s» не найден в каталоге" % asset_id)
		return null
	return load(asset.scene_path) as PackedScene


## Authored appearance wins; whatever the author left alone is drawn from the
## world seed, so a hand-placed forest still is not a row of identical clones. The
## record stays the single owner of what an object looks like — this only fills
## the keys it never spoke about.
##
## The draw is seeded by the cell, not taken from the shared world RNG, and that
## is the whole point: a reloaded save recreates its bushes in a different order
## and would otherwise recolour the meadow every time the player loads.
func _apply_appearance(node: Node3D, entry: NaturalEntry) -> void:
	var asset := WorldAssetCatalog.get_asset(entry.asset_id)
	if asset == null or not node.has_method("apply_decor_properties"):
		return
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([entry.asset_id, cell.x, cell.y, simulation.random.seed])
	var appearance := asset.default_appearance()
	appearance.merge(asset.random_appearance(rng), true)
	appearance.merge(entry.appearance, true)
	node.call("apply_decor_properties", appearance)


func create_forest() -> void:
	for entry in _entities_of_kind(&"tree"):
		var tree_position: Vector3 = entry.position
		var cell: Vector2i = simulation.cell_from_position(tree_position)
		simulation.tree_cells[cell] = true
		simulation.tree_positions.append(tree_position)
		_create_tree(entry, false)
	for entry in _entities_of_kind(&"grass_source"):
		_create_grass_source_at(entry, int(entry.props.get(&"amount", 3)))
	for entry in _entities_of_kind(&"bush"):
		_create_bush_at(entry, int(entry.props.get(&"branches", 3)))
	for entry in _entities_of_kind(&"forage_source"):
		_create_forage_source_at(entry)
	simulation.world_navigation_controller.refresh_navigation_grid()
	# Fireflies are no longer spawned here: they are authored as `core:fireflies`
	# map entities and rendered by MapEntityPresenter, which publishes each
	# instance into WorldSetup.fireflies for the weather controller.


func _create_tree(entry: NaturalEntry, refresh_navigation := true) -> void:
	var scene := _scene_of(entry.asset_id)
	if scene == null:
		return
	var tree: Node3D = scene.instantiate()
	tree.position = entry.position
	var initial_wood := int(entry.props.get(&"wood", simulation.random.randi_range(4, 7)))
	var initial_branches := int(entry.props.get(&"branches", simulation.random.randi_range(5, 9)))

	var cell: Vector2i = simulation.cell_from_position(entry.position)
	var tree_state: Variant = simulation.world_resource_state.create_tree(cell, initial_wood, initial_branches)
	_sync_tree_visual_state(tree, tree_state)
	simulation.tree_nodes[cell] = tree
	simulation.world_navigation_controller.add_landscape_object(tree)

	# Add the tree interaction selector group so first-person raycast can find it.
	var interaction_selector := tree.get_node_or_null("TreeInteractionSelector") as Area3D
	if interaction_selector != null:
		interaction_selector.add_to_group("tree_selector")

	_apply_appearance(tree, entry)

	simulation.terrain_blocked_cells[cell] = true
	if refresh_navigation:
		simulation.world_navigation_controller.refresh_navigation_grid()


func _create_grass_source_at(entry: NaturalEntry, amount: int) -> void:
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	if not simulation.is_board_cell(cell) or simulation.grass_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node := _instantiate_source(entry, "grass_selector", Vector3(1.2, 0.9, 1.2), Vector3.UP * 0.4)
	if node == null:
		return
	simulation.grass_sources[cell] = HarvestSourceRecord.new(node, amount, amount)


func _create_bush_at(entry: NaturalEntry, branches: int) -> void:
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	if not simulation.is_board_cell(cell) or simulation.bush_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node := _instantiate_source(entry, "bush_selector", Vector3(1.2, 1.0, 1.2), Vector3.UP * 0.45)
	if node == null:
		return
	simulation.bush_sources[cell] = HarvestSourceRecord.new(node, branches, branches)


func _create_forage_source_at(entry: NaturalEntry) -> void:
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	if not simulation.is_board_cell(cell) or simulation.forage_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node := _instantiate_source(entry, "forage_selector", Vector3(0.7, 0.6, 0.7), Vector3.UP * 0.3)
	if node == null:
		return
	simulation.forage_sources[cell] = ForageSourceRecord.new(node)


## Shared body of "put a small harvestable plant on the board": instantiate from
## the catalog, give it its click target, hand it to the landscape.
func _instantiate_source(
	entry: NaturalEntry,
	selector_group: String,
	selector_size: Vector3,
	selector_offset: Vector3
) -> Node3D:
	var scene := _scene_of(entry.asset_id)
	if scene == null:
		return null
	var node: Node3D = scene.instantiate()
	node.position = entry.position + Vector3.UP * 0.05
	simulation.building_visuals.add_selector_to_node(node, selector_group, selector_size, selector_offset)
	simulation.world_navigation_controller.add_landscape_object(node)
	_apply_appearance(node, entry)
	return node


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
		_create_rabbit_source(
			simulation.cell_from_position(entry.position),
			entry.position + Vector3.UP * 0.02,
			Vector3(simulation.random.randf_range(-1.0, 1.0), 0.0, simulation.random.randf_range(-1.0, 1.0)).normalized(),
			entry
		)


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
		simulation.rabbit_sources,
		simulation.bush_sources
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
	for entry: Dictionary in state.bush_sources:
		var bush_cell := WorldResourceStateScript._dict_to_cell(entry.get("cell", {}))
		_create_bush(bush_cell, int(entry.get("remaining", 0)), int(entry.get("initial", 0)))
	for cell in state.forage_cells:
		_create_forage_source(cell)
	for entry: Dictionary in state.rabbits:
		var cell := WorldResourceStateScript._dict_to_cell(entry.get("cell", {}))
		_create_rabbit_source(cell, WorldResourceStateScript._dict_to_vector(entry.get("position", {})), WorldResourceStateScript._dict_to_vector(entry.get("direction", {})))


func _clear_natural_source_nodes() -> void:
	for sources: Dictionary in [
		simulation.grass_sources,
		simulation.bush_sources,
		simulation.forage_sources,
		simulation.rabbit_sources,
	]:
		for source in sources.values():
			if is_instance_valid(source.node):
				source.node.queue_free()
		sources.clear()


func _create_grass_source(cell: Vector2i, remaining: int, initial: int) -> void:
	var node := _instantiate_source(
		_restored_entry(&"grass_source", _cell_position(cell)),
		"grass_selector", Vector3(1.2, 0.9, 1.2), Vector3.UP * 0.4
	)
	if node != null:
		simulation.grass_sources[cell] = HarvestSourceRecord.new(node, remaining, initial)


func _create_bush(cell: Vector2i, remaining: int, initial: int) -> void:
	var node := _instantiate_source(
		_restored_entry(&"bush", _cell_position(cell)),
		"bush_selector", Vector3(1.2, 1.0, 1.2), Vector3.UP * 0.45
	)
	if node != null:
		simulation.bush_sources[cell] = HarvestSourceRecord.new(node, remaining, initial)


func _create_forage_source(cell: Vector2i) -> void:
	var node := _instantiate_source(
		_restored_entry(&"forage_source", _cell_position(cell)),
		"forage_selector", Vector3(0.7, 0.6, 0.7), Vector3.UP * 0.3
	)
	if node != null:
		simulation.forage_sources[cell] = ForageSourceRecord.new(node)


func _create_rabbit_source(
	cell: Vector2i,
	position: Vector3,
	direction: Vector3,
	authored: NaturalEntry = null
) -> void:
	var entry := authored if authored != null else _restored_entry(&"rabbit", position)
	var scene := _scene_of(entry.asset_id)
	if scene == null:
		return
	var node: Node3D = scene.instantiate()
	node.position = position
	simulation.building_visuals.add_selector_to_node(node, "rabbit_selector", Vector3(0.5, 0.5, 0.5), Vector3.UP * 0.25)
	simulation.world_navigation_controller.add_landscape_object(node)
	_apply_appearance(node, entry)
	simulation.rabbit_sources[cell] = RabbitSourceRecord.new(node, direction)


## A save stores where a source stands and how much is left in it, not what it
## looked like. Rebuilding the entry from the engine default and letting the
## cell-seeded draw fill the rest is what makes the restored meadow match the one
## the player saved.
func _restored_entry(asset_id: StringName, position: Vector3) -> NaturalEntry:
	var entry := NaturalEntry.new()
	entry.asset_id = asset_id
	entry.position = position
	return entry


func _cell_position(cell: Vector2i) -> Vector3:
	if simulation.nav_grid != null:
		return simulation.nav_grid.cell_center(cell)
	return Vector3((cell.x + 0.5) * simulation.CELL_SIZE, 0.0, (cell.y + 0.5) * simulation.CELL_SIZE)


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
