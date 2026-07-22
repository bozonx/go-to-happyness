class_name ForagingService
extends RefCounted

const INTERACTION_RANGE := 2.8
const WILD_FOOD_RESPAWN_SECONDS := 90.0
const RABBIT_RESPAWN_SECONDS := 120.0
const HARVEST_DURATION := 3.5
const CitizenTaskStateScript = preload("res://game/features/citizens/domain/citizen_task_state.gd")
var billboard_label_scene: PackedScene = null

func set_billboard_label_scene(scene: PackedScene) -> void:
	billboard_label_scene = scene


func _get_billboard_label_scene() -> PackedScene:
	if billboard_label_scene == null:
		billboard_label_scene = load("res://game/features/ui/presentation/billboard_label.tscn") as PackedScene
	return billboard_label_scene

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
var runtime_seconds: float = 0.0

var terrain_height_query: Callable
var cell_query: Callable
var first_person_target_query: Callable

func setup(
	settlement_ref: RefCounted,
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
	var angle := randf_range(0.0, 2.0 * PI)
	var radius := randf_range(2.5, 6.0)
	var spot := hut + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if terrain_height_query.is_valid():
		var height: float = float(terrain_height_query.call(spot.x, spot.z, 0.0))
		if not is_nan(height):
			spot.y = height
	return spot

func harvest_wild_food(position: Vector3, worker: Node3D) -> String:
	var plant_cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	if forage_sources.has(plant_cell):
		var plant := (forage_sources[plant_cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(plant):
			plant.queue_free()
		forage_sources.erase(plant_cell)
		forage_respawn_at[plant_cell] = runtime_seconds + WILD_FOOD_RESPAWN_SECONDS
		return "food"
	for cell in rabbit_sources:
		var source := rabbit_sources[cell] as Dictionary
		var rabbit := source.get("node") as Node3D
		if is_instance_valid(rabbit) and rabbit.global_position.distance_to(position) <= 1.6:
			if worker is Citizen:
				worker.play_hunting_shot()
			rabbit.queue_free()
			rabbit_sources.erase(cell)
			rabbit_respawn_at[cell] = runtime_seconds + RABBIT_RESPAWN_SECONDS
			return "hides" if randf() < 0.35 else "food"
	return ""

func consume_grass_source(position: Vector3) -> int:
	var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	if not grass_sources.has(cell):
		return 0
	var source: Dictionary = grass_sources[cell]
	if int(source.remaining) <= 0:
		return 0
	source.remaining = maxi(0, int(source.remaining) - 1)
	if int(source.remaining) == 0:
		if is_instance_valid(source.node):
			source.node.queue_free()
		grass_sources.erase(cell)
	else:
		grass_sources[cell] = source
	return 1

func consume_tree_branches(position: Vector3) -> int:
	var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	var tree: Node3D = tree_nodes.get(cell)
	if not is_instance_valid(tree):
		return 0
	var remaining := int(tree.get_meta("remaining_branches", 0))
	if remaining <= 0:
		return 0
	var hand_taken := int(tree.get_meta("hand_branches", 0))
	var hand_limit := ceili(float(int(tree.get_meta("initial_branches", remaining))) * 0.3)
	if not tree.has_meta("initial_branches"):
		tree.set_meta("initial_branches", remaining)
		hand_limit = ceili(float(remaining) * 0.3)
	var has_axe := false
	if settlement != null and settlement.tools != null:
		has_axe = bool(settlement.tools.get("axe", false))
	if not has_axe and hand_taken >= hand_limit:
		return 0
	tree.set_meta("remaining_branches", maxi(0, remaining - 1))
	if not has_axe:
		tree.set_meta("hand_branches", hand_taken + 1)
		if hand_taken + 1 >= hand_limit:
			mark_tree_branch_exhausted(tree)
	return 1

func mark_tree_branch_exhausted(tree: Node3D) -> void:
	if bool(tree.get_meta("branch_exhausted", false)):
		return
	tree.set_meta("branch_exhausted", true)
	for child in tree.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not (mesh.mesh is SphereMesh):
			continue
		var material := mesh.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color("6b4c2a")

func nearest_tree_node(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for position in tree_positions:
		var dist := from.distance_to(position)
		if dist > INTERACTION_RANGE:
			continue
		var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
		var tree: Node3D = tree_nodes.get(cell)
		if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)):
			continue
		if dist < best_dist:
			best_dist = dist
			best = tree
	return best

func nearest_grass_node(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := INTERACTION_RANGE
	for cell in grass_sources:
		var source: Dictionary = grass_sources[cell]
		if int(source.remaining) <= 0 or not is_instance_valid(source.node):
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
		"wood", "branches": return nearest_tree_node(player_citizen.global_position)
		"grass": return nearest_grass_node(player_citizen.global_position)
	return null

func gather_node_at(position: Vector3, resource_type: String) -> Node3D:
	var cell: Vector2i = cell_query.call(position) if cell_query.is_valid() else Vector2i.ZERO
	if resource_type in ["wood", "branches", "logs"]:
		return tree_nodes.get(cell)
	if resource_type == "grass":
		var source: Dictionary = grass_sources.get(cell)
		if source != null:
			return source.node
	return null

func gather_progress_amounts(resource_type: String, node: Node3D) -> Dictionary:
	var current := 0
	var max_amount := 1
	if node.has_meta("initial_wood"):
		if resource_type in ["wood", "logs"]:
			max_amount = int(node.get_meta("initial_wood", 1))
			current = max_amount - int(node.get_meta("remaining_wood", 0))
		elif resource_type == "branches":
			max_amount = int(node.get_meta("initial_branches", 1))
			current = int(node.get_meta("hand_branches", 0))
	else:
		for cell in grass_sources:
			var source: Dictionary = grass_sources[cell]
			if source.get("node") == node:
				max_amount = int(source.get("initial", 1))
				current = max_amount - int(source.get("remaining", 0))
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
	label.position = Vector3(0.0, 4.8, 0.0) if node.has_meta("initial_wood") else Vector3(0.0, 0.5, 0.0)
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
	if is_first_person and interaction_action == "harvesting" and player_citizen != null and interaction_resource in ["wood", "branches", "grass"]:
		var node: Node3D = player_gather_target_node(player_citizen, interaction_resource)
		if is_instance_valid(node):
			active_targets[node] = {"resource_type": interaction_resource, "partial": clampf(interaction_time / HARVEST_DURATION, 0.0, 1.0)}
	elif is_first_person and interaction_action.is_empty() and player_citizen != null and first_person_target_query.is_valid():
		var target: Dictionary = first_person_target_query.call()
		var kind: String = str(target.get("kind", ""))
		if kind == "tree" and is_instance_valid(target.get("node")):
			var era_val: int = int(settlement.era) if settlement != null and "era" in settlement else 0
			var res_type := "branches" if era_val < 1 else "wood"
			active_targets[target.get("node")] = {"resource_type": res_type, "partial": -1.0}
		elif kind == "grass" and is_instance_valid(target.get("node")):
			active_targets[target.get("node")] = {"resource_type": "grass", "partial": -1.0}

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
				active_targets[node] = {"resource_type": "wood", "partial": progress}

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
