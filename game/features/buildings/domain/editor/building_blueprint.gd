class_name BuildingBlueprint
extends RefCounted

## Full data model of a modular building, matching the open `.gdbuilding.json`
## format (see design_docs/content/modular_building_editor.md).
##
## Frame-construction level only populates `blocks` and `construction_cost`;
## the decor / active-zone sections are preserved verbatim on load/save so the
## format stays forward-compatible with later editor modes.

const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const ActiveWorkZoneRecordScript = preload("res://game/features/buildings/domain/editor/active_work_zone_record.gd")

const FORMAT_VERSION := 1
const FILE_EXTENSION := "gdbuilding.json"

var version: int = FORMAT_VERSION
## `id` doubles as the in-game building_type key (e.g. "campfire"); the resolver
## maps a gameplay building_type to the blueprint file whose id matches.
var id: StringName = &"new_building"
var name: String = "Новое здание"
var building_type: String = "surface"  ## "surface" | "underground" (construction style)
var grid_bounds: Vector3i = Vector3i(8, 4, 8)
var pivot_offset: Vector3i = Vector3i.ZERO

## Gameplay placement metadata (footprint on the settlement board, entrance
## offsets). Kept here so a blueprint fully describes how it drops into the game.
var footprint: Vector2i = Vector2i.ZERO
var entrance: Vector2i = Vector2i.ZERO
var worker_entrances: Array[Vector2i] = []

var blocks: Array[BlueprintBlock] = []

## Active work zones (authored in editor Mode 3). Typed records.
var work_zones: Array[ActiveWorkZoneRecord] = []

## Later-mode sections are kept as opaque data until their editor modes exist.
var surface_finishes: Array = []
var decor_trims: Array = []
var objects: Array = []
var construction_cost: Dictionary = {}


func clear_blocks() -> void:
	blocks.clear()


func block_count() -> int:
	return blocks.size()


func to_dict() -> Dictionary:
	var block_dicts: Array = []
	for block in blocks:
		block_dicts.append(block.to_dict())
	var zone_dicts: Array = []
	for zone in work_zones:
		zone_dicts.append(zone.to_dict())
	var worker_entrance_dicts: Array = []
	for we in worker_entrances:
		worker_entrance_dicts.append([we.x, we.y])
	return {
		"version": version,
		"id": String(id),
		"name": name,
		"building_type": building_type,
		"grid_bounds": {"x": grid_bounds.x, "y": grid_bounds.y, "z": grid_bounds.z},
		"pivot_offset": {"x": pivot_offset.x, "y": pivot_offset.y, "z": pivot_offset.z},
		"footprint": [footprint.x, footprint.y],
		"entrance": [entrance.x, entrance.y],
		"worker_entrances": worker_entrance_dicts,
		"blocks": block_dicts,
		"surface_finishes": surface_finishes,
		"decor_trims": decor_trims,
		"work_zones": zone_dicts,
		"objects": objects,
		"construction_cost": construction_cost,
	}


func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")


static func from_dict(data: Dictionary) -> BuildingBlueprint:
	var bp := BuildingBlueprint.new()
	bp.version = int(data.get("version", FORMAT_VERSION))
	bp.id = StringName(data.get("id", "new_building"))
	bp.name = String(data.get("name", "Новое здание"))
	bp.building_type = String(data.get("building_type", "surface"))
	bp.grid_bounds = _vec3i_from(data.get("grid_bounds", {}), Vector3i(8, 4, 8))
	bp.pivot_offset = _vec3i_from(data.get("pivot_offset", {}), Vector3i.ZERO)
	bp.footprint = _vec2i_from(data.get("footprint", []), Vector2i.ZERO)
	bp.entrance = _vec2i_from(data.get("entrance", []), Vector2i.ZERO)
	for raw_we in data.get("worker_entrances", []):
		var we := _vec2i_from(raw_we, Vector2i.ZERO)
		bp.worker_entrances.append(we)

	var raw_blocks: Array = data.get("blocks", [])
	for entry in raw_blocks:
		if entry is Dictionary:
			bp.blocks.append(BlueprintBlockScript.from_dict(entry))

	for raw_zone in data.get("work_zones", []):
		if raw_zone is Dictionary:
			bp.work_zones.append(ActiveWorkZoneRecordScript.from_dict(raw_zone))

	bp.surface_finishes = data.get("surface_finishes", [])
	bp.decor_trims = data.get("decor_trims", [])
	bp.objects = data.get("objects", [])
	bp.construction_cost = data.get("construction_cost", {})
	return bp


static func from_json(text: String) -> BuildingBlueprint:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return from_dict(parsed)
	return BuildingBlueprint.new()


static func _vec3i_from(data: Variant, fallback: Vector3i) -> Vector3i:
	if data is Dictionary:
		return Vector3i(
			int(data.get("x", fallback.x)),
			int(data.get("y", fallback.y)),
			int(data.get("z", fallback.z)))
	return fallback


static func _vec2i_from(data: Variant, fallback: Vector2i) -> Vector2i:
	if data is Array and data.size() >= 2:
		return Vector2i(int(data[0]), int(data[1]))
	if data is Dictionary:
		return Vector2i(int(data.get("x", fallback.x)), int(data.get("y", fallback.y)))
	return fallback
