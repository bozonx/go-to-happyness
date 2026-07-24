class_name BuildingBlueprint
extends RefCounted

## Full data model of a modular building, matching the open `.gdbuilding.json`
## format (see design_docs/content/modular_building_editor.md).
##
## Frame-construction level only populates `blocks` and `construction_cost`;
## the decor / active-zone sections are preserved verbatim on load/save so the
## format stays forward-compatible with later editor modes.

const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")
const ZoneAnchorRecordScript = preload("res://game/features/buildings/domain/editor/zone_anchor_record.gd")
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

## Active zones (authored in editor Mode 3), split into two tiers (see design_docs
## §3.4). `place_zones` are tier-1 identities; `zone_anchors` are the shared tier-2
## (slots) and tier-3 (routing) anchors that reference a place by `owner`.
var place_zones: Array[PlaceZoneRecord] = []
var zone_anchors: Array[ZoneAnchorRecord] = []

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
	var place_dicts: Array = []
	for zone in place_zones:
		place_dicts.append(zone.to_dict())
	var anchor_dicts: Array = []
	for anchor in zone_anchors:
		anchor_dicts.append(anchor.to_dict())
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
		"place_zones": place_dicts,
		"zone_anchors": anchor_dicts,
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

	for raw_zone in data.get("place_zones", []):
		if raw_zone is Dictionary:
			bp.place_zones.append(PlaceZoneRecordScript.from_dict(raw_zone))
	for raw_anchor in data.get("zone_anchors", []):
		if raw_anchor is Dictionary:
			bp.zone_anchors.append(ZoneAnchorRecordScript.from_dict(raw_anchor))
	# Legacy files stored a single `work_zones[]` bundling identity + anchors.
	# Split each into a place zone plus its slots/trays on load (design §7).
	if bp.place_zones.is_empty() and bp.zone_anchors.is_empty():
		for raw_zone in data.get("work_zones", []):
			if raw_zone is Dictionary:
				bp._migrate_legacy_zone(raw_zone)

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
	for zone in place_zones:
		if not _valid_id(String(zone.zone_id)):
			errors.append("Invalid place zone id: %s" % zone.zone_id)
		if zone_ids.has(zone.zone_id):
			errors.append("Duplicate place zone id: %s" % zone.zone_id)
		zone_ids[zone.zone_id] = true
		if zone.kind not in PlaceZoneRecordScript.KINDS:
			errors.append("Unknown zone kind: %s" % zone.kind)
		if zone.max_workers < 0:
			errors.append("Zone %s has negative max_workers" % zone.zone_id)
	var known_roles: Array[StringName] = ZoneAnchorRecordScript.SLOT_ROLES + ZoneAnchorRecordScript.ROUTING_ROLES
	for anchor in zone_anchors:
		if anchor.role not in known_roles:
			errors.append("Unknown anchor role: %s" % anchor.role)
		if anchor.owner_zone_id != &"" and not zone_ids.has(anchor.owner_zone_id):
			errors.append("Anchor %s references unknown place zone: %s" % [anchor.anchor_id, anchor.owner_zone_id])
	return errors


## Splits a legacy `work_zones[]` entry into a place zone plus its slots/trays.
func _migrate_legacy_zone(raw: Dictionary) -> void:
	var place := PlaceZoneRecordScript.from_dict(raw)
	place_zones.append(place)
	for raw_anchor in raw.get("work_anchors", []):
		if not (raw_anchor is Dictionary):
			continue
		var anchor := ZoneAnchorRecordScript.new()
		anchor.anchor_id = StringName(raw_anchor.get("id", "anchor_1"))
		anchor.owner_zone_id = place.zone_id
		var action := StringName(raw_anchor.get("action", "work"))
		anchor.role = action if action in ZoneAnchorRecordScript.SLOT_ROLES else ZoneAnchorRecordScript.ROLE_WORK
		anchor.pos = ZoneAnchorRecordScript._arr_to_vec3(raw_anchor.get("pos", []))
		anchor.rot = ZoneAnchorRecordScript._arr_to_vec3(raw_anchor.get("rot", []))
		zone_anchors.append(anchor)
	var raw_trays: Variant = raw.get("storage_trays", {})
	if raw_trays is Dictionary:
		for slot in raw_trays.keys():
			var tray: Variant = raw_trays[slot]
			if not (tray is Dictionary):
				continue
			var anchor := ZoneAnchorRecordScript.new()
			anchor.anchor_id = StringName("%s_%s" % [place.zone_id, slot])
			anchor.owner_zone_id = place.zone_id
			anchor.role = ZoneAnchorRecordScript.ROLE_INPUT_TRAY if String(slot) == "input" else ZoneAnchorRecordScript.ROLE_OUTPUT_TRAY
			anchor.pos = ZoneAnchorRecordScript._arr_to_vec3(tray.get("pos", []))
			anchor.capacity = int(tray.get("capacity", 0))
			zone_anchors.append(anchor)


## Denormalizes place zones + anchors back into one runtime dict per place zone —
## the shape BuildingRuntimeState/ActiveWorkZoneState consume unchanged. Slots
## become `work_anchors`, trays become `storage_trays`; routing anchors are
## excluded (see routing_anchor_definitions).
func runtime_zone_definitions() -> Array:
	var buckets: Dictionary = {}
	for anchor in zone_anchors:
		if anchor.is_routing():
			continue
		var bucket: Dictionary = buckets.get(anchor.owner_zone_id, {})
		if bucket.is_empty():
			bucket = {"work_anchors": [], "storage_trays": {}}
			buckets[anchor.owner_zone_id] = bucket
		if anchor.is_tray():
			var slot := "input" if anchor.role == ZoneAnchorRecordScript.ROLE_INPUT_TRAY else "output"
			bucket["storage_trays"][slot] = {"pos": [anchor.pos.x, anchor.pos.y, anchor.pos.z], "capacity": anchor.capacity}
		else:
			bucket["work_anchors"].append({
				"id": String(anchor.anchor_id),
				"pos": [anchor.pos.x, anchor.pos.y, anchor.pos.z],
				"rot": [anchor.rot.x, anchor.rot.y, anchor.rot.z],
				"action": String(anchor.role),
			})
	var defs: Array = []
	for zone in place_zones:
		var d := zone.to_dict()
		var bucket: Dictionary = buckets.get(zone.zone_id, {})
		d["work_anchors"] = bucket.get("work_anchors", [])
		d["storage_trays"] = bucket.get("storage_trays", {})
		defs.append(d)
	return defs


## Routing anchors (doors, transit stops) as flat dicts, for navigation. World-
## level anchors (empty owner) are included alongside building-owned ones.
func routing_anchor_definitions() -> Array:
	var defs: Array = []
	for anchor in zone_anchors:
		if anchor.is_routing():
			defs.append(anchor.to_dict())
	return defs


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
