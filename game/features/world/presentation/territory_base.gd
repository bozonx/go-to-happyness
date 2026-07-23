class_name TerritoryBase
extends Node3D

const SETTLEMENT_REGION_ORIGINS := [
	Vector3(-256.0, 0.0, -256.0),
	Vector3(0.0, 0.0, -256.0),
	Vector3(-256.0, 0.0, 0.0),
	Vector3.ZERO,
]

@export var biome_definition: BiomeDefinition
@onready var terrain: Terrain3D = get_node_or_null("Terrain3D") as Terrain3D
@onready var landscape_objects: Node3D = get_node_or_null("LandscapeObjects") as Node3D


func _ready() -> void:
	_init_terrain()


func _init_terrain() -> void:
	if terrain == null:
		return
	if terrain.data != null and terrain.data.get_region_count() == 0:
		for origin in SETTLEMENT_REGION_ORIGINS:
			terrain.data.add_region_blankp(origin)
		terrain.collision.build()


## Owns visual nodes that are naturally part of this territory: trees, ponds,
## wild plants, animals and their ambience. Gameplay services keep the matching
## runtime records; this method only establishes scene ownership.
func add_landscape_object(node: Node) -> void:
	if node == null:
		return
	if landscape_objects != null:
		if node.get_parent() != null:
			node.reparent(landscape_objects, true)
		else:
			landscape_objects.add_child(node)
	else:
		add_child(node)
