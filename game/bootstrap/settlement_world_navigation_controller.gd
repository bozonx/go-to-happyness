class_name SettlementWorldNavigationController
extends RefCounted

const CameraControllerScene = preload("res://game/features/world/presentation/camera_controller.tscn")
const WorldSetupScene = preload("res://game/features/world/presentation/world_setup.tscn")

## Manages world setup, navigation grid refresh, terrain access positions,
## tree felling, trail overlay, and boundary markers.
## Extracted from SettlementGame to reduce its method count.

var game: SettlementGame

## Kept alive for the session: it owns the published terrain field and, once the
## game gains terrain editing, the subscription that keeps it current.
var terrain_navigation_publisher := TerrainNavigationPublisher.new()


func _init(p_game: SettlementGame) -> void:
	game = p_game


func create_world() -> void:
	game.camera_controller = CameraControllerScene.instantiate() as CameraController
	game.add_child(game.camera_controller)
	game.world_setup = WorldSetupScene.instantiate() as WorldSetup
	game.world_setup.setup(game.camera, game.CELL_SIZE, game.board_cells, game.trail_field, game.launch_config.map_document)
	game.add_child(game.world_setup)
	game.world_setup.build(game)
	game.simulation_tick_controller.update_daylight()
	publish_terrain_navigation()
	refresh_navigation_grid()
	game.build_controller.move_selection(Vector3.ZERO)


func add_landscape_object(node: Node) -> void:
	var territory := game.get_node_or_null("WorldTerritory") as TerritoryBase
	if territory != null:
		territory.add_landscape_object(node)
	else:
		game.add_child(node)


func update_trail_overlay() -> void:
	if game.world_setup.trail_overlay_material == null or game.trail_field == null:
		return
	if game.trail_texture_renderer != null:
		game.world_setup.trail_overlay_material.set_shader_parameter("trail_map", game.trail_texture_renderer.flush(game.trail_field, game.runtime_seconds))


func record_trail_movement(citizen_id: int, position_on_board: Vector3) -> void:
	if game.settlement.era != SettlementState.Era.TENT or game.trail_field == null:
		return
	game.trail_field.record_walker_position(citizen_id, position_on_board, game.settlement.road_walking_order_enabled)


## Hands the shape of the ground to routing (grid_terrain_system.md §10). Must run
## before the first obstacle publication: the connectivity flood fill built there
## is only correct once the grid knows which edges are cliffs.
func publish_terrain_navigation() -> void:
	if game.nav_grid == null or game.world_setup == null:
		return
	# `configure` sizes the nav grid off the terrain, so the two cannot disagree
	# about cell size or board extent — a mismatch neither side could detect.
	# Water goes in with the ground: depth, fords, ice and lava are passability
	# (§9.7), and publishing the two separately would leave a window in which a
	# route could be planned across a lake.
	terrain_navigation_publisher.configure(
		game.world_setup.terrain_grid, game.nav_grid, null, game.world_setup.water_grid,
	)


func refresh_navigation_grid() -> void:
	if game.navigation_bridge != null:
		game.navigation_blocked_cells = game.navigation_bridge.refresh_navigation_grid(
			game.terrain_blocked_cells,
			game.building_registry.records(),
			game.service_pockets,
			game.NAVIGATION_CLEARANCE_MARGIN
		)


func rebuild_navigation_obstacles() -> void:
	refresh_navigation_grid()


func pond_access_position(from: Vector3, pond_center: Vector3) -> Vector3:
	var candidates := [
		pond_center + Vector3(3.0, 0.0, 0.0),
		pond_center + Vector3(-3.0, 0.0, 0.0),
		pond_center + Vector3(0.0, 0.0, 3.0),
		pond_center + Vector3(0.0, 0.0, -3.0)
	]
	var best := Vector3.INF
	var best_distance := INF
	for candidate in candidates:
		if game.navigation_blocked_cells.has(game._cell_from_position(candidate)):
			continue
		var distance := from.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == Vector3.INF:
		return Vector3.INF
	var terrain_height := game._terrain_height_at(best.x, best.z, pond_center.y)
	if not is_nan(terrain_height):
		best.y = terrain_height
	return best


func resource_access_position(from: Vector3, resource_position: Vector3) -> Vector3:
	var resource_cell := game._cell_from_position(resource_position)
	var best := Vector3.INF
	var best_distance := INF
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = resource_cell + offset
		if not game._is_board_cell(cell) or game.navigation_blocked_cells.has(cell):
			continue
		var candidate: Vector3 = game.nav_grid.cell_center(cell) if game.nav_grid != null else Vector3((cell.x + 0.5) * game.CELL_SIZE, 0.0, (cell.y + 0.5) * game.CELL_SIZE)
		if not game._is_route_reachable(from, candidate):
			continue
		var distance := from.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func fell_tree_at(position_on_board: Vector3) -> void:
	var cell := game._cell_from_position(position_on_board)
	var tree: Node3D = game.tree_nodes.get(cell)
	if not is_instance_valid(tree):
		return
	var tree_state: Variant = game.world_resource_state.tree_at(cell)
	if tree_state == null or tree_state.felled:
		return
	apply_tree_felled_visual(cell, tree)
	refresh_navigation_grid()
	game.settlement.add(ResourceIds.BRANCHES, 3)
	game._update_interface("A tree was felled. Its log is ready for delivery; the living tree is no longer available for gathering.")


## Lays a tree down and frees the cell it occupied. Shared by live felling and
## save restore so both paths produce identical geometry and navigation state.
func apply_tree_felled_visual(cell: Vector2i, tree: Node3D) -> void:
	var tree_state: Variant = game.world_resource_state.tree_at(cell)
	if tree_state != null:
		tree_state.felled = true
		tree.set_meta("felled", true) # Compatibility projection; state is authoritative.
	tree.rotation_degrees.z = 82.0
	var collision_body := tree.get_node_or_null("TreeCollision") as CollisionObject3D
	if collision_body != null:
		collision_body.queue_free()
	game.terrain_blocked_cells.erase(cell)


func refresh_boundary_markers() -> void:
	var territory: RefCounted = game.village_territory_service.territory()
	if game.world_setup.village_boundary_markers != null:
		game.world_setup.village_boundary_markers.refresh(territory)
	if game.world_setup.village_territory_overlay != null:
		game.world_setup.village_territory_overlay.refresh(territory)
