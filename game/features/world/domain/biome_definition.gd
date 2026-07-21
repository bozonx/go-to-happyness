class_name BiomeDefinition
extends Resource

@export var id: StringName = &"summer_valley"
@export var display_name: String = "Summer Valley"
@export var theme: StringName = &"summer"

@export_group("Physics & Gameplay")
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export var base_temperature: float = 22.0
@export var has_breathable_atmosphere: bool = true

@export_group("Presentation")
@export var territory_scene: PackedScene
@export var terrain_data_directory: String = "res://game/features/world/data/terrain3d"
