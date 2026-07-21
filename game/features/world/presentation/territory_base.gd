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


func _ready() -> void:
	_init_terrain()


func _init_terrain() -> void:
	if terrain == null:
		return
	if terrain.data != null and terrain.data.get_region_count() == 0:
		for origin in SETTLEMENT_REGION_ORIGINS:
			terrain.data.add_region_blankp(origin)
		terrain.collision.build()
