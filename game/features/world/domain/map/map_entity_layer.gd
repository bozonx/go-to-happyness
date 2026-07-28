class_name MapEntityLayer
extends RefCounted

## Typed owner of map `entities[]`. Zones own spatial labels; this layer owns
## the entities which may refer to them (map_fill_mode.md §10.4).

var entities: Array[MapEntityRecord] = []


func from_json(source: Variant) -> void:
	entities.clear()
	if not (source is Array):
		return
	for entry: Variant in source as Array:
		if entry is Dictionary:
			var record := MapEntityRecord.from_dict(entry as Dictionary)
			if record.is_valid():
				entities.append(record)


func to_json() -> Array:
	var result: Array = []
	for record: MapEntityRecord in entities:
		result.append(record.to_dict())
	return result


func by_id(entity_id: StringName) -> MapEntityRecord:
	for record: MapEntityRecord in entities:
		if record.id == entity_id:
			return record
	return null


func has_id(entity_id: StringName) -> bool:
	return by_id(entity_id) != null
