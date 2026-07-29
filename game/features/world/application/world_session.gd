class_name WorldSession
extends RefCounted

## Runtime-owned projection of one authored map. A game supplies the scene host
## (territory/camera), but the session guarantees that terrain, water and map
## entities are built once from the same map document for every module.

const WorldSetupScene = preload("res://game/features/world/presentation/world_setup.tscn")

var map_document: MapDocument
var world_setup: WorldSetup = null


func _init(p_map_document: MapDocument = null) -> void:
	map_document = p_map_document


func build(
	scene_host: Node,
	camera: Camera3D,
	cell_size: float,
	board_cells: int,
	trail_field: RefCounted = null,
) -> WorldSetup:
	if world_setup != null:
		return world_setup
	if scene_host == null or camera == null or map_document == null:
		push_error("[world] session requires scene host, camera and map")
		return null
	world_setup = WorldSetupScene.instantiate() as WorldSetup
	world_setup.setup(camera, cell_size, board_cells, trail_field, map_document)
	scene_host.add_child(world_setup)
	world_setup.build(scene_host)
	return world_setup
