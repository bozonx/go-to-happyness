class_name MapPlacementRecord
extends RefCounted

## One building standing on a map (design_docs/engine/building_placement.md §12).
##
## The record holds a **reference to a blueprint, never a copy of one**. Editing
## the blueprint therefore reaches every map it stands on, and `required_content[]`
## can be filled from the references at save time. The price is that a map can
## name a blueprint that is not installed — which is a state the editor has to
## survive, not prevent (see `MapPlacementLayer`).
##
## Two things deliberately absent:
##
## * **the terrain delta.** The ground already lies in `terrain.bin`. A second copy
##   of the same fact would disagree with it the first time a brush touched the
##   pad.
## * **the pad's own geometry.** `level.value` is what was applied and has to
##   reproduce byte for byte; `level.mode` beside it is the author's *intent*,
##   which is what a re-placement or a change of blueprint revision needs. Storing
##   only one of the two loses one of those two jobs.

const STATE_READY := &"ready"

var id: StringName = &""
## `{source, id, role, revision}` — exactly what `BuildingBlueprintLibrary`
## produces and consumes.
var blueprint_ref: Dictionary = {}
## North-west cell of the oriented footprint.
var cell: Vector2i = Vector2i.ZERO
## 0|1|2|3 = N/E/S/W. Never an angle: see `BuildingFootprint`.
var orientation := 0
var level_mode: StringName = PlacementLevel.MODE_MEDIAN
var level_value := 0
## `ready` by default, plus `construction_site`, `ruin`, `mothballed` and anything
## else the blueprint declares (`map_fill_mode.md` §6).
var state: StringName = STATE_READY
var owner: StringName = &""
var tags: Array[StringName] = []


func is_valid() -> bool:
	return id != &"" and not blueprint_ref.is_empty()


func blueprint_source() -> StringName:
	return StringName(blueprint_ref.get("source", "core"))


func blueprint_id() -> StringName:
	return StringName(blueprint_ref.get("id", ""))


func blueprint_role() -> StringName:
	return StringName(blueprint_ref.get("role", ""))


func blueprint_revision() -> String:
	return String(blueprint_ref.get("revision", ""))


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"blueprint_ref": blueprint_ref.duplicate(true),
		"cell": [cell.x, cell.y],
		"orientation": orientation,
		"level": {"mode": String(level_mode), "value": level_value},
		"state": String(state),
		"owner": String(owner),
		"tags": tags.map(func(tag: StringName) -> String: return String(tag)),
	}


static func from_dict(data: Dictionary) -> MapPlacementRecord:
	var record := MapPlacementRecord.new()
	record.id = StringName(data.get("id", ""))
	var reference: Variant = data.get("blueprint_ref", {})
	record.blueprint_ref = (reference as Dictionary).duplicate(true) if reference is Dictionary else {}
	var raw_cell: Variant = data.get("cell", [])
	if raw_cell is Array and (raw_cell as Array).size() >= 2:
		record.cell = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	record.orientation = BuildingFootprint.normalized_orientation(int(data.get("orientation", 0)))
	var raw_level: Variant = data.get("level", {})
	if raw_level is Dictionary:
		var level := raw_level as Dictionary
		var mode := StringName(level.get("mode", PlacementLevel.MODE_MEDIAN))
		record.level_mode = mode if PlacementLevel.is_valid_mode(mode) else PlacementLevel.MODE_MEDIAN
		record.level_value = int(level.get("value", 0))
	# An unknown `state` is kept as authored rather than reset: the dictionary of
	# states belongs to the blueprint, and this build has no business deciding a
	# later one is wrong. The validator reports it; the loader does not eat it.
	record.state = StringName(data.get("state", STATE_READY))
	record.owner = StringName(data.get("owner", ""))
	var raw_tags: Variant = data.get("tags", [])
	if raw_tags is Array:
		for tag: Variant in raw_tags as Array:
			record.tags.append(StringName(tag))
	return record
