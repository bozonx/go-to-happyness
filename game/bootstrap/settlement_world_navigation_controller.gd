class_name SettlementWorldNavigationController
extends RefCounted

## Manages world setup, navigation grid refresh, terrain access positions,
## tree felling, trail overlay, and boundary markers.
## Extracted from SettlementGame to reduce its method count.

var navigation_runtime: WorldNavigationRuntimePort
var presentation_runtime: WorldNavigationPresentationPort
var world_session: WorldSession

## Kept alive for the session: it owns the published terrain field and, once the
## game gains terrain editing, the subscription that keeps it current.
var terrain_navigation_publisher := TerrainNavigationPublisher.new()
## The overlay-effect cost layer over the same grid (active_zones.md §4.2). Built
## once at session start from the map's zone layer; republishing on zone edits is
## the map editor's job, the same way terrain republishing is.
var overlay_navigation_publisher := OverlayNavigationPublisher.new()


func _init(p_navigation_runtime: WorldNavigationRuntimePort, p_presentation_runtime: WorldNavigationPresentationPort, p_world_session: WorldSession = null) -> void:
	navigation_runtime = p_navigation_runtime
	presentation_runtime = p_presentation_runtime
	world_session = p_world_session


func create_world() -> void:
	# CameraController is a declared child of settlement_game.tscn; only the world
	# itself is built here, because its construction needs the launched map.
	var world_setup: WorldSetup = world_session.build(
		presentation_runtime.territory_getter.call().get_parent(),
		presentation_runtime.camera_getter.call(),
		presentation_runtime.cell_size,
		presentation_runtime.board_cells,
		presentation_runtime.trail_field_getter.call(),
	) if world_session != null else _build_legacy_world()
	if world_setup == null:
		return
	presentation_runtime.world_setup_setter.call(world_setup)
	presentation_runtime.water_access_setter.call(world_setup.water_access)
	presentation_runtime.update_daylight.call()
	publish_terrain_navigation()
	refresh_navigation_grid()
	presentation_runtime.move_selection.call(Vector3.ZERO)


func _build_legacy_world() -> WorldSetup:
	var session := WorldSession.new(presentation_runtime.map_document_getter.call())
	var territory: TerritoryBase = presentation_runtime.territory_getter.call()
	return session.build(
		territory.get_parent() if territory != null else null,
		presentation_runtime.camera_getter.call(),
		presentation_runtime.cell_size,
		presentation_runtime.board_cells,
		presentation_runtime.trail_field_getter.call(),
	)


func add_landscape_object(node: Node) -> void:
	var territory: TerritoryBase = presentation_runtime.territory_getter.call()
	if territory != null:
		territory.add_landscape_object(node)
	else:
		presentation_runtime.add_to_scene.call(node)


func update_trail_overlay() -> void:
	var world_setup: WorldSetup = presentation_runtime.world_setup_getter.call()
	var trail_field: TrailFieldService = presentation_runtime.trail_field_getter.call()
	if world_setup == null or world_setup.trail_overlay_material == null or trail_field == null:
		return
	var trail_renderer: TrailTextureRenderer = presentation_runtime.trail_renderer_getter.call()
	if trail_renderer != null:
		world_setup.trail_overlay_material.set_shader_parameter("trail_map", trail_renderer.flush(trail_field, presentation_runtime.runtime_seconds_getter.call()))


func record_trail_movement(citizen_id: int, position_on_board: Vector3) -> void:
	var trail_field: TrailFieldService = presentation_runtime.trail_field_getter.call()
	if not presentation_runtime.is_tent_era.call() or trail_field == null:
		return
	trail_field.record_walker_position(citizen_id, position_on_board, presentation_runtime.road_walking_enabled.call())


## Hands the shape of the ground to routing (grid_terrain_system.md §10). Must run
## before the first obstacle publication: the connectivity flood fill built there
## is only correct once the grid knows which edges are cliffs.
func publish_terrain_navigation() -> void:
	var nav_grid: NavGrid = navigation_runtime.nav_grid_getter.call()
	var world_setup: WorldSetup = presentation_runtime.world_setup_getter.call()
	if nav_grid == null or world_setup == null:
		return
	# `configure` sizes the nav grid off the terrain, so the two cannot disagree
	# about cell size or board extent — a mismatch neither side could detect.
	# Water goes in with the ground: depth, fords, ice and lava are passability
	# (§9.7), and publishing the two separately would leave a window in which a
	# route could be planned across a lake.
	terrain_navigation_publisher.configure(
		world_setup.terrain_grid, nav_grid, null, world_setup.water_grid,
	)
	# The bank positions gameplay reads come off the same two grids; handing it the
	# nav grid as well is what puts them on the surface a citizen stands on rather
	# than at the stored column height.
	world_setup.water_access.configure(world_setup.water_grid, world_setup.terrain_grid, nav_grid)
	_publish_overlay_navigation(nav_grid)


## Active-zone overlay effects land on the same grid as the ground, one layer up
## (active_zones.md §4.2): a forest or a mud patch is not terrain passability but
## still multiplies a cell's cost. Runs after the terrain publisher so the
## overlay has a surface to multiply. A map with no overlay areas publishes an
## empty layer, which `set_overlay_cell_weights` turns into a no-op.
func _publish_overlay_navigation(nav_grid: NavGrid) -> void:
	var map_document: MapDocument = presentation_runtime.map_document_getter.call()
	if map_document == null:
		return
	var overlay_index := ZoneOverlayIndex.new()
	overlay_index.rebuild(map_document.zones, map_document.board_cells())
	overlay_navigation_publisher.configure(overlay_index, nav_grid)
	overlay_navigation_publisher.publish_all()


func refresh_navigation_grid() -> void:
	var navigation_bridge: NavigationBridge = navigation_runtime.navigation_bridge_getter.call()
	if navigation_bridge != null:
		navigation_runtime.navigation_blocked_cells_setter.call(navigation_bridge.refresh_navigation_grid(
			navigation_runtime.terrain_blocked_cells_getter.call(),
			navigation_runtime.building_records_getter.call(),
			navigation_runtime.service_pockets_getter.call(),
			navigation_runtime.clearance_margin
		))


func rebuild_navigation_obstacles() -> void:
	refresh_navigation_grid()


func resource_access_position(from: Vector3, resource_position: Vector3) -> Vector3:
	var resource_cell: Vector2i = navigation_runtime.cell_from_position.call(resource_position)
	var best := Vector3.INF
	var best_distance := INF
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = resource_cell + offset
		if not navigation_runtime.is_board_cell.call(cell) or (navigation_runtime.navigation_blocked_cells_getter.call() as Dictionary).has(cell):
			continue
		var nav_grid: NavGrid = navigation_runtime.nav_grid_getter.call()
		var candidate: Vector3 = nav_grid.cell_center(cell) if nav_grid != null else Vector3((cell.x + 0.5) * navigation_runtime.cell_size, 0.0, (cell.y + 0.5) * navigation_runtime.cell_size)
		if not navigation_runtime.is_route_reachable.call(from, candidate):
			continue
		var distance := from.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func fell_tree_at(position_on_board: Vector3) -> void:
	var cell: Vector2i = navigation_runtime.cell_from_position.call(position_on_board)
	var tree: Node3D = (navigation_runtime.tree_nodes_getter.call() as Dictionary).get(cell)
	if not is_instance_valid(tree):
		return
	var tree_state: Variant = navigation_runtime.tree_at.call(cell)
	if tree_state == null or tree_state.felled:
		return
	apply_tree_felled_visual(cell, tree)
	refresh_navigation_grid()
	navigation_runtime.settlement_add.call(ResourceIds.BRANCHES, 3)
	navigation_runtime.update_interface.call("A tree was felled. Its log is ready for delivery; the living tree is no longer available for gathering.")


## Lays a tree down and frees the cell it occupied. Shared by live felling and
## save restore so both paths produce identical geometry and navigation state.
func apply_tree_felled_visual(cell: Vector2i, tree: Node3D) -> void:
	var tree_state: Variant = navigation_runtime.tree_at.call(cell)
	if tree_state != null:
		tree_state.felled = true
		tree.set_meta("felled", true) # Compatibility projection; state is authoritative.
	tree.rotation_degrees.z = 82.0
	var collision_body := tree.get_node_or_null("TreeCollision") as CollisionObject3D
	if collision_body != null:
		collision_body.queue_free()
	navigation_runtime.terrain_blocked_cell_erase.call(cell)


func refresh_boundary_markers() -> void:
	var world_setup: WorldSetup = presentation_runtime.world_setup_getter.call()
	if world_setup == null:
		return
	var territory: RefCounted = presentation_runtime.village_territory_getter.call()
	if world_setup.village_boundary_markers != null:
		world_setup.village_boundary_markers.refresh(territory)
	if world_setup.village_territory_overlay != null:
		world_setup.village_territory_overlay.refresh(territory)
