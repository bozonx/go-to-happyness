class_name SettlementQueryHelper
extends RefCounted

## Stateless query and formatting utilities extracted from SettlementGame.
## None of these methods mutate game state — they read from the game's
## services and collections to produce display strings, screen-to-world
## picks, and nearest-point searches.

const S = preload("res://game/features/ui/domain/game_strings.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func gather_action_name(resource_type: String) -> String:
	match resource_type:
		ResourceIds.WOOD: return S.GATHER_ACTION_WOOD
		ResourceIds.BRANCHES: return S.GATHER_ACTION_BRANCHES
		ResourceIds.GRASS: return S.GATHER_ACTION_GRASS
		ResourceIds.WATER: return S.GATHER_ACTION_WATER
		ResourceIds.FOOD: return S.GATHER_ACTION_FOOD
	return S.GATHER_ACTION_DEFAULT


func harvest_source_info(resource_type: String) -> String:
	if game.player_citizen == null:
		return ""
	match resource_type:
		ResourceIds.BRANCHES:
			var tree := game.foraging_service.nearest_tree_node(game.player_citizen.global_position)
			if is_instance_valid(tree):
				var tree_state: Variant = game.world_resource_state.tree_at(game.cell_from_position(tree.global_position))
				if tree_state != null:
					return S.SOURCE_INFO_BRANCHES % [tree_state.remaining_branches, maxi(1, tree_state.initial_branches)]
			return ""
		ResourceIds.GRASS:
			var node := game.foraging_service.nearest_grass_node(game.player_citizen.global_position)
			if is_instance_valid(node):
				for cell in game.grass_sources:
					var source: HarvestSourceRecord = game.grass_sources[cell]
					if source.node == node:
						var rem := source.remaining
						var init := maxi(1, source.initial)
						return S.SOURCE_INFO_GRASS % [rem, init]
			return ""
		ResourceIds.WOOD:
			return S.SOURCE_INFO_WOOD
		ResourceIds.WATER:
			return S.SOURCE_INFO_WATER
		ResourceIds.FOOD:
			return S.SOURCE_INFO_FOOD
	return ""


func citizen_state_name(state: int) -> String:
	match state:
		Citizen.State.TO_EMPLOYMENT_CENTER:
			return S.STATE_GOING_TO_EMPLOYMENT
		Citizen.State.EMPLOYMENT_PROCESSING:
			return S.STATE_PROCESSING_EMPLOYMENT
		Citizen.State.TO_ARRIVAL_ENTRANCE:
			return S.STATE_GOING_TO_MEET_ARRIVAL
		Citizen.State.ARRIVAL_MEETING:
			return S.STATE_MEETING_ARRIVAL
		Citizen.State.ARRIVAL_WAITING:
			return S.STATE_WAITING_MORNING_AT_ENTRANCE
		Citizen.State.TO_ARRIVAL_CENTER:
			return S.STATE_ESCORTING_ARRIVAL
	var state_names := Citizen.State.keys()
	if state < 0 or state >= state_names.size():
		return "Unknown state"
	return str(state_names[state]).capitalize().replace("_", " ")


func targeted_grass_info(target: Dictionary) -> Dictionary:
	return _targeted_source_info(game.grass_sources, target)


func targeted_bush_info(target: Dictionary) -> Dictionary:
	return _targeted_source_info(game.bush_sources, target)


func _targeted_source_info(sources: Dictionary, target: Dictionary) -> Dictionary:
	var target_node := target.get("node") as Node3D
	if not is_instance_valid(target_node):
		return {}
	for cell in sources:
		var source: HarvestSourceRecord = sources[cell]
		if source != null and source.node == target_node:
			return {"remaining": source.remaining, "initial": maxi(1, source.initial)}
	return {}


func terrain_point_at_screen_position(screen_position: Vector2) -> Variant:
	var from := game.camera.project_ray_origin(screen_position)
	var to := from + game.camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position as Vector3


func nearest_point_to_point_array(points: Array[Vector3], target: Vector3, max_distance: float) -> Vector3:
	var best := Vector3.INF
	var best_dist := max_distance
	for point in points:
		var dist := point.distance_to(target)
		if dist <= best_dist:
			best_dist = dist
			best = point
	return best


func nearest_grass_source_to_point(point: Vector3, max_distance: float) -> Vector3:
	var best := Vector3.INF
	var best_dist := max_distance
	var point_xz := Vector2(point.x, point.z)
	for cell in game.grass_sources:
		var source: HarvestSourceRecord = game.grass_sources[cell]
		if source.remaining <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = source.node.global_position
		var dist := point_xz.distance_to(Vector2(node_pos.x, node_pos.z))
		if dist <= best_dist:
			best_dist = dist
			best = node_pos
	return best
