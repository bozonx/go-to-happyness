class_name ForagingService
extends RefCounted

const INTERACTION_RANGE := 2.8
const WILD_FOOD_RESPAWN_SECONDS := 90.0
const RABBIT_RESPAWN_SECONDS := 120.0
const HARVEST_DURATION := 3.5
const CitizenTaskStateScript = preload("res://game/features/citizens/domain/citizen_task_state.gd")
const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")
const ForageSourceRecord = preload("res://game/features/production/domain/forage_source_record.gd")
const RabbitSourceRecord = preload("res://game/features/production/domain/rabbit_source_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
var billboard_label_scene: PackedScene = null
var _random: RandomNumberGenerator

func set_billboard_label_scene(scene: PackedScene) -> void:
	billboard_label_scene = scene


func set_random(rng: RandomNumberGenerator) -> void:
	_random = rng

var forager_positions: Array[Vector3] = []
var forage_sources: Dictionary = {}
var forage_respawn_at: Dictionary = {}
var rabbit_sources: Dictionary = {}
var rabbit_respawn_at: Dictionary = {}
var grass_sources: Dictionary = {}
var tree_nodes: Dictionary = {}
var tree_positions: Array[Vector3] = []
var gather_progress_labels: Dictionary = {}

var settlement: RefCounted
var world_resource_state: RefCounted
var runtime_seconds: float = 0.0

func _rng() -> RandomNumberGenerator:
	return _random if _random != null else null

var terrain_height_query: Callable
var cell_query: Callable
var first_person_target_query: Callable

func setup(
	settlement_ref: RefCounted,
	world_state_ref: RefCounted,
	forager_pos_ref: Array[Vector3],
	forage_src_ref: Dictionary,
	forage_resp_ref: Dictionary,
	rabbit_src_ref: Dictionary,
	rabbit_resp_ref: Dictionary,
	grass_src_ref: Dictionary,
	tree_nodes_ref: Dictionary,
	tree_pos_ref: Array[Vector3],
	gather_labels_ref: Dictionary,
	terrain_fn: Callable = Callable(),
	cell_fn: Callable = Callable(),
	target_fn: Callable = Callable()
) -> void:
	settlement = settlement_ref
	world_resource_state = world_state_ref
	forager_positions = forager_pos_ref
	forage_sources = forage_src_ref
	forage_respawn_at = forage_resp_ref
	rabbit_sources = rabbit_src_ref
	rabbit_respawn_at = rabbit_resp_ref
	grass_sources = grass_src_ref
	tree_nodes = tree_nodes_ref
	tree_positions = tree_pos_ref
	gather_progress_labels = gather_labels_ref
	terrain_height_query = terrain_fn
	cell_query = cell_fn
	first_person_target_query = target_fn

func find_forage_position(citizen: Node3D) -> Vector3:
	if forager_positions.is_empty():
		return Vector3.INF
	var hut := forager_positions[0]
	var closest_dist := INF
	for pos in forager_positions:
		var dist := citizen.global_position.distance_squared_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			hut = pos
	var rng := _rng()
	var angle := rng.randf_range(0.0, 2.0 * PI) if rng != null else randf_range(0.0, 2.0 * PI)
	var radius := rng.randf_range(2.5, 6.0) if rng != null else randf_range(2.5, 6.0)
	var spot := hut + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if terrain_height_query.is_valid():
		var height: float = float(terrain_height_query.call(spot.x, spot.z, 0.0))
		if not is_nan(height):
			spot.y = height
	return spot

func harvest_wild_food(position: Vector3, worker: Node3D) -> String:
	var plant_cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	if forage_sources.has(plant_cell):
		var plant: ForageSourceRecord = forage_sources[plant_cell]
		if is_instance_valid(plant.node):
			plant.node.queue_free()
		forage_sources.erase(plant_cell)
		forage_respawn_at[plant_cell] = runtime_seconds + WILD_FOOD_RESPAWN_SECONDS
		return ResourceIds.FOOD
	for cell in rabbit_sources:
		var source: RabbitSourceRecord = rabbit_sources[cell]
		if is_instance_valid(source.node) and source.node.global_position.distance_to(position) <= 1.6:
			if worker is Citizen:
				worker.play_hunting_shot()
			source.node.queue_free()
			rabbit_sources.erase(cell)
			rabbit_respawn_at[cell] = runtime_seconds + RABBIT_RESPAWN_SECONDS
			var rng2 := _rng()
			var hide_roll := rng2.randf() if rng2 != null else randf()
			return ResourceIds.HIDES if hide_roll < 0.35 else ResourceIds.FOOD
	return ""

func consume_grass_source(position: Vector3) -> int:
	var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	if not grass_sources.has(cell):
		return 0
	var source: GrassSourceRecord = grass_sources[cell]
	if source.remaining <= 0:
		return 0
	source.remaining = maxi(0, source.remaining - 1)
	if source.remaining == 0:
		if is_instance_valid(source.node):
			source.node.queue_free()
		grass_sources.erase(cell)
	return 1

func consume_tree_branches(position: Vector3) -> int:
	var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	var tree_state: Variant = world_resource_state.tree_at(cell) if world_resource_state != null else null
	if tree_state == null:
		return 0
	var remaining: int = int(tree_state.remaining_branches)
	if remaining <= 0:
		return 0
	var hand_taken: int = int(tree_state.hand_branches)
	var hand_limit: int = ceili(float(tree_state.initial_branches) * 0.3)
	var has_axe := false
	if settlement != null and settlement.tools != null:
		has_axe = bool(settlement.tools.get("axe", false))
	if not has_axe and hand_taken >= hand_limit:
		return 0
	tree_state.remaining_branches = maxi(0, remaining - 1)
	if not has_axe:
		tree_state.hand_branches = hand_taken + 1
		if hand_taken + 1 >= hand_limit:
			mark_tree_branch_exhausted(cell)
	_sync_tree_visual_state(cell)
	return 1

## Snapshot every living tree's mutable state for the save file. The forest
## layout is fixed (see AmbientSpawner.create_forest), so only per-cell deltas —
## wood/branch depletion, felled and exhausted flags — need persisting.
func export_tree_state() -> Array:
	var result: Array = []
	return world_resource_state.export_tree_state() if world_resource_state != null else []


func mark_tree_branch_exhausted(cell: Vector2i) -> void:
	var tree_state: Variant = world_resource_state.tree_at(cell) if world_resource_state != null else null
	if tree_state == null or tree_state.branch_exhausted:
		return
	tree_state.branch_exhausted = true
	var tree: Node3D = tree_nodes.get(cell)
	if not is_instance_valid(tree):
		return
	_sync_tree_visual_state(cell)
	for child in tree.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not (mesh.mesh is SphereMesh):
			continue
		var material := mesh.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("6b4c2a")


func _sync_tree_visual_state(cell: Vector2i) -> void:
	var tree: Node3D = tree_nodes.get(cell)
	var state: Variant = world_resource_state.tree_at(cell) if world_resource_state != null else null
	if not is_instance_valid(tree) or state == null:
		return
	tree.set_meta("initial_wood", state.initial_wood)
	tree.set_meta("remaining_wood", state.remaining_wood)
	tree.set_meta("initial_branches", state.initial_branches)
	tree.set_meta("remaining_branches", state.remaining_branches)
	tree.set_meta("hand_branches", state.hand_branches)
	tree.set_meta("branch_exhausted", state.branch_exhausted)
	tree.set_meta("felled", state.felled)

func nearest_tree_node(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for position in tree_positions:
		var dist := from.distance_to(position)
		if dist > INTERACTION_RANGE:
			continue
		var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
		var tree: Node3D = tree_nodes.get(cell)
		var tree_state: Variant = world_resource_state.tree_at(cell) if world_resource_state != null else null
		if not is_instance_valid(tree) or tree_state == null or tree_state.felled:
			continue
		if dist < best_dist:
			best_dist = dist
			best = tree
	return best

func nearest_grass_node(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := INTERACTION_RANGE
	for cell in grass_sources:
		var source: GrassSourceRecord = grass_sources[cell]
		if source.remaining <= 0 or not is_instance_valid(source.node):
			continue
		var dist := from.distance_to(source.node.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = source.node
	return best

func player_gather_target_node(player_citizen: Node3D, interaction_resource: String) -> Node3D:
	if player_citizen == null:
		return null
	match interaction_resource:
		ResourceIds.WOOD, ResourceIds.BRANCHES: return nearest_tree_node(player_citizen.global_position)
		ResourceIds.GRASS: return nearest_grass_node(player_citizen.global_position)
	return null

func gather_node_at(position: Vector3, resource_type: String) -> Node3D:
	var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	if resource_type in [ResourceIds.WOOD, ResourceIds.BRANCHES, ResourceIds.LOGS]:
		return tree_nodes.get(cell)
	if resource_type == ResourceIds.GRASS:
		var source: GrassSourceRecord = grass_sources.get(cell)
		if source != null:
			return source.node
	return null

func gather_progress_amounts(resource_type: String, node: Node3D) -> Dictionary:
	var current := 0
	var max_amount := 1
	var tree_cell: Vector2i = cell_query.call(node.global_position) if cell_query.is_valid() else Vector2i.ZERO
	var tree_state: Variant = world_resource_state.tree_at(tree_cell) if world_resource_state != null else null
	if tree_state != null and tree_nodes.get(tree_cell) == node:
		if resource_type in [ResourceIds.WOOD, ResourceIds.LOGS]:
			max_amount = tree_state.initial_wood
			current = max_amount - tree_state.remaining_wood
		elif resource_type == ResourceIds.BRANCHES:
			max_amount = tree_state.initial_branches
			current = tree_state.hand_branches
	else:
		for cell in grass_sources:
			var source: GrassSourceRecord = grass_sources[cell]
			if source.node == node:
				max_amount = source.initial
				current = max_amount - source.remaining
				break
	return {"current": current, "max": max_amount}

func ensure_gather_progress_label(node: Node3D) -> Label3D:
	var existing := gather_progress_labels.get(node) as Label3D
	if is_instance_valid(existing):
		return existing
	var label := _get_billboard_label_scene().instantiate() as Label3D
	label.font_size = 22
	label.outline_size = 5
	label.modulate = Color("ffffff")
	var cell: Vector2i = cell_query.call(node.global_position) if cell_query.is_valid() else Vector2i.ZERO
	label.position = Vector3(0.0, 4.8, 0.0) if tree_nodes.get(cell) == node else Vector3(0.0, 0.5, 0.0)
	node.add_child(label)
	gather_progress_labels[node] = label
	return label

func update_gather_progress_label(node: Node3D, resource_type: String, partial: float) -> void:
	var amounts := gather_progress_amounts(resource_type, node)
	var value := float(amounts.current) + partial
	var max_amount := maxi(int(amounts.max), 1)
	var pct := clampi(int(value / float(max_amount) * 100.0), 0, 100)
	var label := ensure_gather_progress_label(node)
	if partial < 0.0:
		var remaining := max_amount - int(amounts.current)
		label.text = "%d/%d" % [remaining, max_amount]
		label.modulate = Color("abcfd6") if remaining > 0 else Color("c97b5e")
		label.font_size = 18
	else:
		label.text = "%d%%" % pct
		label.modulate = Color("76c893") if pct >= 100 else Color("ffffff")
		label.font_size = 22

func update_gathering_indicators(
	is_first_person: bool,
	interaction_action: String,
	interaction_resource: String,
	interaction_time: float,
	player_citizen: Node3D,
	citizens: Array
) -> void:
	var active_targets: Dictionary = {}
	if is_first_person and interaction_action == "harvesting" and player_citizen != null and interaction_resource in [ResourceIds.WOOD, ResourceIds.BRANCHES, ResourceIds.GRASS]:
		var node: Node3D = player_gather_target_node(player_citizen, interaction_resource)
		if is_instance_valid(node):
			active_targets[node] = {"resource_type": interaction_resource, "partial": clampf(interaction_time / HARVEST_DURATION, 0.0, 1.0)}
	elif is_first_person and interaction_action.is_empty() and player_citizen != null and first_person_target_query.is_valid():
		var target: Dictionary = first_person_target_query.call()
		var kind: String = str(target.get("kind", ""))
		if kind == "tree" and is_instance_valid(target.get("node")):
			var era_val: int = int(settlement.era) if settlement != null and "era" in settlement else 0
			var res_type := ResourceIds.BRANCHES if era_val < 1 else ResourceIds.WOOD
			active_targets[target.get("node")] = {"resource_type": res_type, "partial": -1.0}
		elif kind == "grass" and is_instance_valid(target.get("node")):
			active_targets[target.get("node")] = {"resource_type": ResourceIds.GRASS, "partial": -1.0}

	for citizen_item in citizens:
		var citizen := citizen_item as Node3D
		if not is_instance_valid(citizen):
			continue
		var citizen_state: int = int(citizen.get("state")) if "state" in citizen else -1
		var c_gather_type: String = str(citizen.get("gather_resource_type")) if "gather_resource_type" in citizen else ""
		var c_gather_pos: Vector3 = citizen.get("gather_source_position") if "gather_source_position" in citizen else Vector3.ZERO
		var c_source_pos: Vector3 = citizen.get("source_position") if "source_position" in citizen else Vector3.ZERO

		# State.GATHERING is 10, State.CHOPPING is 4
		if citizen_state == 10 and not c_gather_type.is_empty():
			var node: Node3D = gather_node_at(c_gather_pos, c_gather_type)
			if is_instance_valid(node):
				var task_timer: Variant = citizen.get("task_timer")
				var progress: float = task_timer.progress() if task_timer is CitizenTaskStateScript else 0.0
				active_targets[node] = {"resource_type": c_gather_type, "partial": progress}
		elif citizen_state == 4:
			var cell: Vector2i = cell_query.call(c_source_pos) if cell_query.is_valid() else Vector2i.ZERO
			var node: Node3D = tree_nodes.get(cell)
			if is_instance_valid(node):
				var task_timer: Variant = citizen.get("task_timer")
				var progress: float = task_timer.progress() if task_timer is CitizenTaskStateScript else 0.0
				active_targets[node] = {"resource_type": ResourceIds.WOOD, "partial": progress}

	var nodes_to_remove: Array = gather_progress_labels.keys().duplicate()
	for node in active_targets:
		nodes_to_remove.erase(node)
		var data: Dictionary = active_targets[node]
		update_gather_progress_label(node, data.resource_type, data.partial)
	for node in nodes_to_remove:
		var label: Label3D = gather_progress_labels.get(node)
		if is_instance_valid(label):
			label.queue_free()
		gather_progress_labels.erase(node)
