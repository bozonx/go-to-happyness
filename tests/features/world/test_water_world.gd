extends SceneTree

## The two things `WaterWorld` owns that are not just triangles
## (design_docs/engine/grid_terrain_system.md §9.6, map_editor.md §6.1).
##
## A scene test rather than a unit one because both are nodes: the ice floor is a
## `StaticBody3D` that has to appear and disappear with the ice, and the border
## ocean is a mesh that has to exist only when the map header asks for it.

const BOARD_CELLS := 32
const TerritoryScene := preload("res://game/features/world/presentation/territory_base.tscn")


func _init() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	for z in range(-3, 4):
		for x in range(-3, 4):
			assert(terrain.set_height(Vector2i(x, z), -2))
	var water := WaterGrid.new()
	water.configure(1.0, BOARD_CELLS)
	var service := WaterService.new()
	service.configure(water, terrain)

	var world := WaterWorld.new()
	root.add_child(world)
	world.configure(water, terrain, service, null)

	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i.ZERO, lake.id, 0))
	world.rebuild_pending_now()
	assert(_ice_body_count(world) == 0, "open water has no collider — a ford is walked on the bed")

	# Freezing changes no geometry an author can see, but it does put a floor under
	# the route: routing walks a frozen cell at the water level, and without this the
	# walker falls through to the bottom of the lake.
	assert(service.set_body_frozen(lake.id, true))
	world.rebuild_pending_now()
	assert(_ice_body_count(world) > 0, "ice is a floor and needs a collider")

	assert(service.set_body_frozen(lake.id, false))
	world.rebuild_pending_now()
	assert(_ice_body_count(world) == 0, "and the floor goes when the ice does")

	# The border is a property of the map file, not of the water on it.
	assert(_border_node(world) == null, "no border was configured yet")
	world.configure_border(MapMeta.BORDER_OCEAN, -2)
	assert(_border_node(world) != null, "an ocean border draws a horizon")
	world.configure_border(MapMeta.BORDER_LAVA, -2)
	assert(_border_node(world) != null, "a lava border draws a horizon too")
	world.configure_border(MapMeta.BORDER_NOTHING, 0)
	assert(_border_node(world) == null, "and 'nothing' draws nothing at all")

	var territory := TerritoryScene.instantiate() as TerritoryBase
	root.add_child(territory)
	await process_frame
	territory.configure_terrain(1.0, BOARD_CELLS)
	_assert_boundary(territory)

	world.queue_free()
	territory.queue_free()
	print("  water world: ice collider and border ocean ok")
	quit(0)


func _ice_body_count(world: WaterWorld) -> int:
	var count := 0
	for child: Node in world.get_children():
		if child is StaticBody3D:
			count += 1
	return count


func _border_node(world: WaterWorld) -> Node:
	for child: Node in world.get_children():
		if child.name == "BorderPlane":
			return child
	return null


func _assert_boundary(territory: TerritoryBase) -> void:
	var north := territory.get_node("WorldBoundary/North/CollisionShape3D") as CollisionShape3D
	var south := territory.get_node("WorldBoundary/South/CollisionShape3D") as CollisionShape3D
	var east := territory.get_node("WorldBoundary/East/CollisionShape3D") as CollisionShape3D
	var west := territory.get_node("WorldBoundary/West/CollisionShape3D") as CollisionShape3D
	for collision: CollisionShape3D in [north, south, east, west]:
		assert(collision.shape is BoxShape3D, "every map side has a physical wall")
	assert(north.position.z < -BOARD_CELLS * 0.5 and south.position.z > BOARD_CELLS * 0.5)
	assert(west.position.x < -BOARD_CELLS * 0.5 and east.position.x > BOARD_CELLS * 0.5)
