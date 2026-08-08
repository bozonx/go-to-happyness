class_name MapPlacementLayer
extends RefCounted

## Typed owner of `placements[]` (design_docs/engine/building_placement.md §12).
##
## The key has existed since format v7 and travelled through the editor as opaque
## JSON; this is the phase that interprets it. No second file and no second key: a
## building on a map is a row here, and everything that addresses one — scenario
## rules, quests, saves — addresses its `id`.
##
## The layer is pure data and knows nothing about blueprints. Resolving a
## reference to a file is `BuildingPlacementService`'s job, because a missing
## blueprint must not stop a map from opening: the record keeps every field, the
## editor shows a placeholder, and the game looks for a current variant of the
## same `role`.

var placements: Array[MapPlacementRecord] = []


func from_json(source: Variant) -> void:
	placements.clear()
	if not (source is Array):
		return
	for entry: Variant in source as Array:
		if not (entry is Dictionary):
			continue
		var record := MapPlacementRecord.from_dict(entry as Dictionary)
		if record.is_valid():
			placements.append(record)


func to_json() -> Array:
	var result: Array = []
	for record: MapPlacementRecord in placements:
		result.append(record.to_dict())
	return result


func by_id(placement_id: StringName) -> MapPlacementRecord:
	for record: MapPlacementRecord in placements:
		if record.id == placement_id:
			return record
	return null


func has_id(placement_id: StringName) -> bool:
	return by_id(placement_id) != null


func remove(placement_id: StringName) -> bool:
	for index in range(placements.size() - 1, -1, -1):
		if placements[index].id == placement_id:
			placements.remove_at(index)
			return true
	return false


## An id no record uses yet. Ids are stable identity — a rule, a quest or a save
## refers to one — so they are never renumbered, only extended.
func next_id(prefix: String) -> StringName:
	var number := 1
	while has_id(StringName("%s_%d" % [prefix, number])):
		number += 1
	return StringName("%s_%d" % [prefix, number])


## Every blueprint reference on this map, as `{source, id}` pairs, for
## `required_content[]`.
func referenced_blueprints() -> Array[Dictionary]:
	var seen: Dictionary = {}
	var result: Array[Dictionary] = []
	for record: MapPlacementRecord in placements:
		var key := "%s:%s" % [record.blueprint_source(), record.blueprint_id()]
		if seen.has(key):
			continue
		seen[key] = true
		result.append({"source": record.blueprint_source(), "id": record.blueprint_id()})
	return result
