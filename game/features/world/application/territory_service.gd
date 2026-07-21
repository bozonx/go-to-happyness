class_name TerritoryService
extends RefCounted

const BiomeDefinitionScript = preload("res://game/features/world/domain/biome_definition.gd")

var _biomes: Dictionary = {} # StringName -> BiomeDefinition
var _active_biome_id: StringName = &"summer_valley"


func register_biome(biome: BiomeDefinition) -> void:
	if biome == null or biome.id == &"":
		return
	_biomes[biome.id] = biome


func get_biome(biome_id: StringName) -> BiomeDefinition:
	return _biomes.get(biome_id, null) as BiomeDefinition


func set_active_biome(biome_id: StringName) -> void:
	if _biomes.has(biome_id):
		_active_biome_id = biome_id


func get_active_biome() -> BiomeDefinition:
	return get_biome(_active_biome_id)


func get_registered_biomes() -> Array[BiomeDefinition]:
	var list: Array[BiomeDefinition] = []
	for b in _biomes.values():
		if b is BiomeDefinition:
			list.append(b as BiomeDefinition)
	return list
