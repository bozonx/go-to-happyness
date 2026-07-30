class_name GameProgressionDefinition
extends RefCounted

## Authored progression catalogue owned by one game definition. Maps may narrow
## or disable it, but never define what an era means.

var eras: Array[EraDefinition] = []
var technologies: Dictionary = {}


static func from_dict(source: Dictionary) -> GameProgressionDefinition:
	var progression := GameProgressionDefinition.new()
	for raw: Variant in source.get("eras", []):
		if raw is Dictionary:
			var era := EraDefinition.from_dict(raw)
			if era != null and progression.era_by_id(era.id) == null:
				progression.eras.append(era)
	var raw_technologies: Variant = source.get("technologies", {})
	if raw_technologies is Dictionary:
		progression.technologies = (raw_technologies as Dictionary).duplicate(true)
	return progression


func to_dict() -> Dictionary:
	return {
		"eras": eras.map(func(era: EraDefinition) -> Dictionary: return era.to_dict()),
		"technologies": technologies.duplicate(true),
	}


func era_by_id(era_id: StringName) -> EraDefinition:
	for era: EraDefinition in eras:
		if era.id == era_id:
			return era
	return null


func era_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for era: EraDefinition in eras:
		result.append(era.id)
	return result


func rank_of(era_id: StringName) -> int:
	for index in eras.size():
		if eras[index].id == era_id:
			return index
	return -1
