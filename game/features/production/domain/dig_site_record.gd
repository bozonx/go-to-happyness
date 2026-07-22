class_name DigSiteRecord
extends RefCounted

## Mutable runtime state for one excavation dig site.

var cell: Vector2i = Vector2i.ZERO
var node: Node3D = null
var pit: MeshInstance3D = null
var grass_limit: int = 0
var soil_limit: int = 0
var clay_limit: int = 0
var stone_limit: int = 0
var depth: int = 0


func _init(
	next_cell: Vector2i = Vector2i.ZERO,
	next_node: Node3D = null,
	next_pit: MeshInstance3D = null,
	next_grass_limit: int = 0,
	next_soil_limit: int = 0,
	next_clay_limit: int = 0,
	next_stone_limit: int = 0,
	next_depth: int = 0,
) -> void:
	cell = next_cell
	node = next_node
	pit = next_pit
	grass_limit = next_grass_limit
	soil_limit = next_soil_limit
	clay_limit = next_clay_limit
	stone_limit = next_stone_limit
	depth = next_depth
