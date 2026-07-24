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
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")

const FORMAT_VERSION := 1
const FILE_EXTENSION := "gdbuilding.json"

var version: int = FORMAT_VERSION
## `id` doubles as the in-game building_type key (e.g. "campfire"); the resolver
## maps a gameplay building_type to the blueprint file whose id matches.
var id: StringName = &"new_building"
var name: String = "Новое здание"
var construction_style: StringName = &"surface"  ## &"surface" | &"underground"
## Source compatibility for the first editor prototype. It is not serialized.
var building_type: String:
	get: return String(construction_style)
	set(value): construction_style = StringName(value)
var category: String = "tent"
## Standard building used when a referenced player file is unavailable.
var fallback_building_id: StringName = &"house"
var grid_bounds: Vector3i = Vector3i(8, 4, 8)
var pivot_offset: Vector3i = Vector3i.ZERO

## Gameplay placement metadata (footprint on the settlement board, entrance
## offsets). Kept here so a blueprint fully describes how it drops into the game.
var footprint: Vector2i = Vector2i(8, 8)
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
		"construction_style": String(construction_style),
		"category": category,
		"fallback_building_id": String(fallback_building_id),
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
	# `building_type` was used by the initial prototype for surface/underground.
	# It remains a read alias inside v1, but new files use the unambiguous name.
	bp.construction_style = StringName(data.get("construction_style", data.get("building_type", "surface")))
	bp.category = String(data.get("category", "tent"))
	bp.fallback_building_id = StringName(data.get("fallback_building_id", "house"))
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
	if not bp.blocks.is_empty():
		bp.recalculate_construction_cost()
	return bp


static func from_json(text: String) -> BuildingBlueprint:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	var bp := from_dict(json.data as Dictionary)
	return bp if bp.validation_errors().is_empty() else null


func recalculate_construction_cost() -> void:
	var calculated: Dictionary = {}
	for block in blocks:
		var resource_id := BuildingMaterialCatalogScript.resource_id(block.material_id)
		if resource_id == &"":
			continue
		var units := BuildingMaterialCatalogScript.cost_units(block.material_id)
		calculated[String(resource_id)] = int(calculated.get(String(resource_id), 0)) + units
	construction_cost = calculated


func content_revision() -> String:
	var data := to_dict()
	return "%08x" % (JSON.stringify(data).hash() & 0xffffffff)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if version != FORMAT_VERSION:
		errors.append("Unsupported blueprint format version: %d" % version)
	if not _valid_id(String(id)):
		errors.append("Blueprint id must contain only lowercase latin letters, digits, '_' or '-'")
	if name.strip_edges().is_empty():
		errors.append("Blueprint name is empty")
	if construction_style not in [&"surface", &"underground"]:
		errors.append("Unknown construction_style: %s" % construction_style)
	if category not in BuildingMaterialCatalogScript.ERA_ORDER:
		errors.append("Unknown era category: %s" % category)
	# Underground structures can only be dug from the earth era onward.
	elif construction_style == &"underground" and BuildingMaterialCatalogScript.era_rank(category) < BuildingMaterialCatalogScript.era_rank("earth"):
		errors.append("Underground construction requires the earth era or later")
	if grid_bounds.x <= 0 or grid_bounds.y <= 0 or grid_bounds.z <= 0:
		errors.append("grid_bounds must be positive")
	if footprint.x <= 0 or footprint.y <= 0:
		errors.append("footprint must be positive")
	var occupied: Dictionary = {}
	for block in blocks:
		if not BuildingBlockCatalogScript.has_block(block.block_id):
			errors.append("Unknown block id: %s" % block.block_id)
		if not BuildingMaterialCatalogScript.has_material(block.material_id):
			errors.append("Unknown material id: %s" % block.material_id)
		elif not BuildingMaterialCatalogScript.is_available_in_era(block.material_id, category):
			errors.append("Material %s requires a later era than %s" % [block.material_id, category])
		if occupied.has(block.pos):
			errors.append("Duplicate block position: %s" % block.pos)
		occupied[block.pos] = true
	var zone_ids: Dictionary = {}
	for zone in work_zones:
		if not _valid_id(String(zone.zone_id)):
			errors.append("Invalid zone id: %s" % zone.zone_id)
		if zone_ids.has(zone.zone_id):
			errors.append("Duplicate zone id: %s" % zone.zone_id)
		zone_ids[zone.zone_id] = true
		if zone.kind not in ActiveWorkZoneRecordScript.KINDS:
			errors.append("Unknown zone kind: %s" % zone.kind)
		if zone.max_workers < 0:
			errors.append("Zone %s has negative max_workers" % zone.zone_id)
	return errors


static func _valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for i in value.length():
		var c := value[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-"):
			return false
	return true


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
