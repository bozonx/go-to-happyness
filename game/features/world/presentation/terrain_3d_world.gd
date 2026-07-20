@tool
extends Node3D

const SETTLEMENT_REGION_ORIGINS := [
	Vector3(-256.0, 0.0, -256.0),
	Vector3(0.0, 0.0, -256.0),
	Vector3(-256.0, 0.0, 0.0),
	Vector3.ZERO,
]

@onready var terrain: Terrain3D = $Terrain3D


func _ready() -> void:
	if terrain.data.get_region_count() > 0:
		return
	for origin in SETTLEMENT_REGION_ORIGINS:
		terrain.data.add_region_blankp(origin)
	# Regions are created after Terrain3D's initial collision build, so rebuild
	# once to make the new ground available to CharacterBody3D immediately.
	terrain.collision.build()
