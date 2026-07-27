class_name BuildingBlueprint
extends RefCounted

## Full data model of a modular building, matching the open `.gdbuilding.json`
## format (see design_docs/engine/modular_building_editor.md).
##
## Frame-construction level only populates `blocks` and `construction_cost`;
## the decor / active-zone sections are preserved verbatim on load/save so the
## format stays forward-compatible with later editor modes.

const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")
const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")

## v3: `objects[].pos` is relative to the footprint centre (see `pivot_offset`).
## No migration branch for v2: every v2 file in the project places decor at the
## origin, which the centre reading interprets correctly.
## v5: active zones rebuilt on the shared model (design_docs/engine/active_zones.md).
## `place_zones`/`zone_anchors`/`work_zones` and the standalone `entrance`/
## `worker_entrances` fields are gone; there is no migration branch, because no
## shipped or authored file used the old zone arrays.
const FORMAT_VERSION := 5
const MIN_LOAD_VERSION := 1
const FILE_EXTENSION := "gdbuilding.json"

var version: int = FORMAT_VERSION
## `id` doubles as the in-game building_type key (e.g. "campfire"); the resolver
## maps a gameplay building_type to the blueprint file whose id matches.
var id: StringName = &"new_building"
## Gameplay identity, availability era and visual variant are deliberately
## independent from the file id (content_packaging.md §3).
var role: StringName = &"new_building"
var era: StringName = &"tent"
var style: StringName = &"generic"
var kind: StringName = &"building"
var name: String = "Новое здание"
## Stamp rewritten on every save, exactly like a map package's (design_docs/engine/
## content_packaging.md §7). A game save keeps it next to `blueprint_ref` so a
## session can tell the player the file was edited since — it never blocks loading.
var revision: String = ""
var construction_style: StringName = &"surface"  ## &"surface" | &"underground"
## @deprecated. Source compatibility for the first editor prototype. It is not
## serialized. Use `construction_style` directly in new code.
var building_type: String:
	get: return String(construction_style)
	set(value): construction_style = StringName(value)
## Compatibility alias for the pre-v4 editor and construction code. New content
## is serialized as `era`; callers can migrate at their own pace.
var category: StringName:
	get: return era
	set(value): era = value
## Standard building used when a referenced player file is unavailable.
var fallback_building_id: StringName = &"house"
var grid_bounds: Vector3i = Vector3i(8, 4, 8)

## Footprint on the settlement board. Entrances are **not** stored: they are the
## `door` anchors, and deriving them keeps one authority (active_zones.md §5.2).
var footprint: Vector2i = Vector2i(8, 8)

var blocks: Array[BlueprintBlock] = []

## Active zones, organized by geometry (design_docs/engine/active_zones.md §3):
## `areas` are regions, `anchors` are points, `routes` are ordered lines over
## routing points. Routes stay opaque until the line tool exists.
var areas: Array[ZoneAreaRecord] = []
var anchors: Array[ZoneAnchorRecord] = []
var routes: Array = []

## Placed decor and furnishing (authored in editor Mode 3, design §3.3).
var objects: Array[DecorObjectRecord] = []

## Functional fixtures (design_docs/engine/building_furnishing.md §3.2).
## Each entry is a FixtureDefinition describing a game-interactable element.
var fixtures: Array[FixtureDefinition] = []

## Later-mode sections are kept as opaque data until their editor modes exist.
var surface_finishes: Array = []
var decor_trims: Array = []
var construction_cost: Dictionary = {}
var cost_mode: StringName = &"auto"
var extra_costs: Dictionary = {}
var custom_material_costs: Dictionary = {}
var manual_costs: Dictionary = {}


## Distance from the board's `(0,0)` corner to the footprint centre.
##
## Two coordinate spaces meet in a blueprint, and the split is deliberate:
## integer grid cells (`blocks[].pos`) are array indices and stay non-negative
## `0…N-1`, while continuous placements are signed offsets from the footprint
## centre — which is the pivot the game rotates and positions a building around
## (see `BuildingEntrancePositions`, and `entrance`, which was always stored that
## way). `objects[]` is serialized in that centre space and converted back to
## corner space on load, so every editor tool keeps working in board-local
## coordinates and only the file format is centre-relative.
##
## Y is a layer height, not an offset, and is never shifted.
func pivot_offset() -> Vector3:
	return Vector3(float(footprint.x), 0.0, float(footprint.y)) * 0.5


func clear_blocks() -> void:
	blocks.clear()


func block_count() -> int:
	return blocks.size()


## Board offset of the main visitor door, relative to the footprint centre — the
## space the game places and rotates a building in. Derived from `door` anchors:
## the format has one authority on entrances, and it is the zone layer.
func entrance_offset() -> Vector2i:
	for anchor in anchors:
		if anchor.is_door() and anchor.permits(ZoneAccess.AUDIENCE_VISITOR):
			return _anchor_board_offset(anchor)
	for anchor in anchors:
		if anchor.is_door():
			return _anchor_board_offset(anchor)
	# No authored door: the near edge of the footprint, as before zones existed.
	return Vector2i(0, -footprint.y / 2)


## Board offsets of the doors staff and couriers use. A door open to staff counts,
## which means a single public door serves both without being authored twice.
func worker_entrance_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for anchor in anchors:
		if anchor.is_door() and anchor.permits(ZoneAccess.AUDIENCE_STAFF):
			var offset := _anchor_board_offset(anchor)
			if offset not in offsets:
				offsets.append(offset)
	return offsets


func _anchor_board_offset(anchor: ZoneAnchorRecord) -> Vector2i:
	var pivot := pivot_offset()
	return Vector2i(roundi(anchor.pos.x - pivot.x), roundi(anchor.pos.z - pivot.z))


func doors() -> Array[ZoneAnchorRecord]:
	var result: Array[ZoneAnchorRecord] = []
	for anchor in anchors:
		if anchor.is_door():
			result.append(anchor)
	return result


func area_by_id(area_id: StringName) -> ZoneAreaRecord:
	for area in areas:
		if area.id == area_id:
			return area
	return null


func anchors_of(area_id: StringName) -> Array[ZoneAnchorRecord]:
	var result: Array[ZoneAnchorRecord] = []
	for anchor in anchors:
		if anchor.owner_id == area_id:
			result.append(anchor)
	return result


func rooms() -> Array[ZoneAreaRecord]:
	var result: Array[ZoneAreaRecord] = []
	for area in areas:
		if area.is_room():
			result.append(area)
	return result


## Standard building substituted when a referenced player file is unavailable.
## The mapping from a zone function to a shipped building lives in the pack that
## declared the function (`fallback` in zone_functions.json), not here: the engine
## must not know that "kitchen" means a campfire in the tent era.
func infer_fallback_building_id() -> StringName:
	var era_key := String(era)
	for area in rooms():
		if area.function == &"":
			continue
		var fallbacks: Variant = ZoneFunctionCatalog.get_function(area.function).get("fallback", {})
		if not (fallbacks is Dictionary):
			continue
		var by_era: Dictionary = fallbacks
		if by_era.has(era_key):
			return StringName(by_era[era_key])
		if by_era.has("default"):
			return StringName(by_era["default"])
	match era_key:
		"tent": return &"tent"
		"earth": return &"earth_house"
		"clay": return &"clay_house"
		"stone": return &"stone_house"
		_: return &"house"


func to_dict() -> Dictionary:
	fallback_building_id = infer_fallback_building_id()
	var block_dicts: Array = []
	for block in blocks:
		block_dicts.append(block.to_dict())
	var area_dicts: Array = []
	for area in areas:
		area_dicts.append(area.to_dict())
	var anchor_dicts: Array = []
	for anchor in anchors:
		anchor_dicts.append(anchor.to_dict())
	var object_dicts: Array = []
	var pivot := pivot_offset()
	for decor_object in objects:
		var object_dict := decor_object.to_dict()
		object_dict["pos"] = [decor_object.pos.x - pivot.x, decor_object.pos.y, decor_object.pos.z - pivot.z]
		object_dicts.append(object_dict)
	return {
		"version": FORMAT_VERSION,
		"id": String(id),
		"role": String(role),
		"era": String(era),
		"style": String(style),
		"kind": String(kind),
		"name": name,
		"revision": revision,
		"construction_style": String(construction_style),
		"fallback_building_id": String(fallback_building_id),
		"grid_bounds": {"x": grid_bounds.x, "y": grid_bounds.y, "z": grid_bounds.z},
		"footprint": [footprint.x, footprint.y],
		"blocks": block_dicts,
		"surface_finishes": surface_finishes,
		"decor_trims": decor_trims,
		"areas": area_dicts,
		"anchors": anchor_dicts,
		"routes": routes,
		"objects": object_dicts,
		"fixtures": fixtures.map(func(f: FixtureDefinition) -> Dictionary: return f.to_dict()),
		"cost_mode": String(cost_mode),
		"extra_costs": extra_costs,
		"custom_material_costs": custom_material_costs,
		"manual_costs": manual_costs,
		"construction_cost": construction_cost,
	}


func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")


static func from_dict(data: Dictionary) -> BuildingBlueprint:
	var bp := BuildingBlueprint.new()
	bp.version = int(data.get("version", FORMAT_VERSION))
	bp.id = StringName(data.get("id", "new_building"))
	# v3 -> v4: category became era and the missing axes receive their safe
	# defaults. Keep `category` populated for existing gameplay consumers.
	bp.role = StringName(data.get("role", bp.id))
	bp.era = StringName(data.get("era", data.get("category", "tent")))
	bp.style = StringName(data.get("style", "generic"))
	bp.kind = StringName(data.get("kind", "building"))
	bp.name = String(data.get("name", "Новое здание"))
	bp.revision = String(data.get("revision", ""))
	# `building_type` was used by the initial prototype for surface/underground.
	# It remains a read alias inside v1, but new files use the unambiguous name.
	bp.construction_style = StringName(data.get("construction_style", data.get("building_type", "surface")))
	bp.fallback_building_id = StringName(data.get("fallback_building_id", "house"))
	bp.grid_bounds = _vec3i_from(data.get("grid_bounds", {}), Vector3i(8, 4, 8))
	bp.footprint = _vec2i_from(data.get("footprint", []), Vector2i.ZERO)

	var raw_blocks: Variant = data.get("blocks", [])
	if raw_blocks is Array:
		for entry in raw_blocks:
			if entry is Dictionary:
				bp.blocks.append(BlueprintBlockScript.from_dict(entry))

	var raw_areas: Variant = data.get("areas", [])
	if raw_areas is Array:
		for raw_area in raw_areas:
			if raw_area is Dictionary:
				bp.areas.append(ZoneAreaRecord.from_dict(raw_area))

	var raw_anchors: Variant = data.get("anchors", [])
	if raw_anchors is Array:
		for raw_anchor in raw_anchors:
			if raw_anchor is Dictionary:
				bp.anchors.append(ZoneAnchorRecord.from_dict(raw_anchor))

	var raw_routes: Variant = data.get("routes", [])
	bp.routes = (raw_routes as Array).duplicate(true) if raw_routes is Array else []

	var raw_objects: Variant = data.get("objects", [])
	if raw_objects is Array:
		var pivot := bp.pivot_offset()  # `footprint` is already parsed above.
		for raw_object in raw_objects:
			if raw_object is Dictionary:
				var record: DecorObjectRecord = DecorObjectRecordScript.from_dict(raw_object)
				record.pos += Vector3(pivot.x, 0.0, pivot.z)
				bp.objects.append(record)

	bp.surface_finishes = data.get("surface_finishes", [])
	bp.decor_trims = data.get("decor_trims", [])
	bp.cost_mode = StringName(data.get("cost_mode", "auto"))
	bp.extra_costs = data.get("extra_costs", {})
	bp.custom_material_costs = data.get("custom_material_costs", {})
	bp.manual_costs = data.get("manual_costs", {})
	bp.construction_cost = data.get("construction_cost", {})
	var raw_fixtures: Variant = data.get("fixtures", [])
	bp.fixtures.clear()
	if raw_fixtures is Array:
		for fd_data in raw_fixtures:
			if fd_data is Dictionary:
				bp.fixtures.append(FixtureDefinitionScript.from_dict(fd_data))
	# Upgrade in-memory version so a save writes v2, even if the file was v1.
	# Out-of-range versions are left as-is so validation_errors can reject them.
	if bp.version >= MIN_LOAD_VERSION and bp.version <= FORMAT_VERSION:
		bp.version = FORMAT_VERSION
	bp.recalculate_construction_cost()
	return bp


static func from_json(text: String) -> BuildingBlueprint:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	var bp := from_dict(json.data as Dictionary)
	return bp if bp.validation_errors().is_empty() else null


func recalculate_construction_cost() -> void:
	if cost_mode == &"manual":
		construction_cost = manual_costs.duplicate()
		return

	var raw_totals: Dictionary = {}
	for block in blocks:
		var comp: Dictionary = {}
		if custom_material_costs.has(block.material_id) and custom_material_costs[block.material_id] is Dictionary:
			comp = custom_material_costs[block.material_id]
		else:
			comp = BuildingMaterialCatalogScript.resource_composition(block.material_id)
		
		for res in comp.keys():
			var res_name := str(res)
			var amount := float(comp[res])
			raw_totals[res_name] = float(raw_totals.get(res_name, 0.0)) + amount

	var rounded_costs: Dictionary = {}
	for res in raw_totals.keys():
		var int_val := ceili(raw_totals[res])
		if int_val > 0:
			rounded_costs[res] = int_val

	for res in extra_costs.keys():
		var res_name := str(res)
		var extra_val := int(extra_costs[res])
		if extra_val > 0:
			rounded_costs[res_name] = int(rounded_costs.get(res_name, 0)) + extra_val

	construction_cost = rounded_costs


## Identity of this exact file version. Maps answer the same question with a
## stored save stamp, so blueprints do too; the content hash stays only as the
## answer for files written before `revision` existed (v2 and earlier).
func revision_id() -> String:
	return revision if not revision.is_empty() else content_revision()


func content_revision() -> String:
	var data := to_dict()
	data.erase("revision")
	return "%08x" % JSON.stringify(data).hash()


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if version < MIN_LOAD_VERSION or version > FORMAT_VERSION:
		errors.append("Unsupported blueprint format version: %d" % version)
	if not _valid_id(String(id)):
		errors.append("Blueprint id must contain only lowercase latin letters, digits, '_' or '-'")
	if name.strip_edges().is_empty():
		errors.append("Blueprint name is empty")
	if construction_style not in [&"surface", &"underground"]:
		errors.append("Unknown construction_style: %s" % construction_style)
	if not _valid_id(String(role)):
		errors.append("Invalid blueprint role: %s" % role)
	if era not in BuildingMaterialCatalogScript.ERA_ORDER:
		errors.append("Unknown era: %s" % era)
	if not _valid_id(String(style)):
		errors.append("Invalid blueprint style: %s" % style)
	if kind not in [&"building", &"scenery"]:
		errors.append("Unknown blueprint kind: %s" % kind)
	# Underground structures can only be dug from the earth era onward.
	elif construction_style == &"underground" and BuildingMaterialCatalogScript.era_rank(era) < BuildingMaterialCatalogScript.era_rank(&"earth"):
		errors.append("Underground construction requires the earth era or later")
	if grid_bounds.x <= 0 or grid_bounds.y <= 0 or grid_bounds.z <= 0:
		errors.append("grid_bounds must be positive")
	if footprint.x <= 0 or footprint.y <= 0:
		errors.append("footprint must be positive")
	var placement_keys: Dictionary = {}
	for block in blocks:
		if not BuildingBlockCatalogScript.has_block(block.block_id):
			errors.append("Unknown block id: %s" % block.block_id)
		if not BuildingMaterialCatalogScript.has_material(block.material_id):
			errors.append("Unknown material id: %s" % block.material_id)
		elif not BuildingMaterialCatalogScript.is_available_in_era(block.material_id, era):
			errors.append("Material %s requires a later era than %s" % [block.material_id, era])
		var normalized_variant := BuildingBlockCatalogScript.normalize_variant(block.block_id, block.variant)
		if block.variant != &"" and normalized_variant != block.variant:
			errors.append("Unknown size %s for block %s" % [block.variant, block.block_id])
		var placement_key := "%s|%s|%s|%d|%d|%d|%d" % [
			block.pos, block.block_id, normalized_variant, block.anchor, block.rot, block.rot_x, block.rot_z]
		if placement_keys.has(placement_key):
			errors.append("Duplicate block placement: %s" % placement_key)
		placement_keys[placement_key] = true
	for i in range(blocks.size()):
		var left: BlueprintBlock = blocks[i]
		if not BuildingBlockCatalogScript.has_block(left.block_id):
			continue
		var left_aabb := BuildingBlockCatalogScript.occupied_aabb(left.pos, left.block_id,
			BuildingBlockCatalogScript.normalize_variant(left.block_id, left.variant), left.rot,
			left.anchor, left.rot_x, left.rot_z)
		for j in range(i + 1, blocks.size()):
			var right: BlueprintBlock = blocks[j]
			if not BuildingBlockCatalogScript.has_block(right.block_id):
				continue
			var right_aabb := BuildingBlockCatalogScript.occupied_aabb(right.pos, right.block_id,
				BuildingBlockCatalogScript.normalize_variant(right.block_id, right.variant), right.rot,
				right.anchor, right.rot_x, right.rot_z)
			if _interiors_intersect(left_aabb, right_aabb) and not _allows_structural_joint(left, right):
				errors.append("Overlapping block volumes: %s and %s" % [left.pos, right.pos])
	errors.append_array(_zone_errors())
	return errors


## Zone-layer validation (design_docs/engine/active_zones.md §8.1). Reachability
## over NavGrid is checked by the editor, which has the navigation data; what can
## be decided from the file alone is decided here.
func _zone_errors() -> Array[String]:
	var errors: Array[String] = []
	var area_ids: Dictionary = {}
	var rooms_seen: Array[ZoneAreaRecord] = []
	for area in areas:
		if not _valid_id(String(area.id)):
			errors.append("Invalid area id: %s" % area.id)
		if area_ids.has(area.id):
			errors.append("Duplicate area id: %s" % area.id)
		area_ids[area.id] = true
		if area.role not in ZoneAreaRecord.ROLES:
			errors.append("Unknown area role: %s" % area.role)
		if area.function != &"" and not ZoneFunctionCatalog.has_function(area.function):
			errors.append("Area %s references unknown function: %s" % [area.id, area.function])
		if area.y_max < area.y_min:
			errors.append("Area %s has an inverted height range" % area.id)
		for audience in area.allow + area.deny:
			if not ZoneAccess.is_known_audience(audience):
				errors.append("Area %s references unknown audience: %s" % [area.id, audience])
		# Rooms partition the building; only overlays may overlap (§7.3).
		if area.is_room():
			for other in rooms_seen:
				if area.overlaps(other):
					errors.append("Rooms %s and %s overlap" % [area.id, other.id])
			rooms_seen.append(area)

	var anchor_ids: Dictionary = {}
	var doors_by_room: Dictionary = {}
	var slot_ids: Dictionary = {}
	for anchor in anchors:
		if anchor_ids.has(anchor.id):
			errors.append("Duplicate anchor id: %s" % anchor.id)
		anchor_ids[anchor.id] = true
		if anchor.role not in ZoneAnchorRecord.ROLES:
			errors.append("Unknown anchor role: %s" % anchor.role)
		if anchor.owner_id != &"" and not area_ids.has(anchor.owner_id):
			errors.append("Anchor %s references unknown area: %s" % [anchor.id, anchor.owner_id])
		if anchor.is_slot():
			slot_ids[anchor.id] = true
		if anchor.is_door() and anchor.owner_id != &"":
			doors_by_room[anchor.owner_id] = true
		if anchor.is_storage() and anchor.direction not in ZoneAnchorRecord.DIRECTIONS:
			errors.append("Storage anchor %s has unknown direction: %s" % [anchor.id, anchor.direction])
		if anchor.fixture_id != &"" and not _has_fixture(anchor.fixture_id):
			errors.append("Anchor %s references unknown fixture: %s" % [anchor.id, anchor.fixture_id])
		# A slot standing where its own audience is denied can never be worked.
		if anchor.is_slot() and not _cell_permits(anchor.cell(), ZoneAccess.AUDIENCE_STAFF):
			errors.append("Slot %s stands where staff are denied entry" % anchor.id)
	for anchor in anchors:
		if anchor.is_queue() and not slot_ids.has(anchor.target_id):
			errors.append("Queue anchor %s references unknown slot: %s" % [anchor.id, anchor.target_id])

	# A room nobody can enter is not a room. A building-wide door counts.
	var has_building_door := false
	for anchor in anchors:
		if anchor.is_door() and anchor.owner_id == &"":
			has_building_door = true
	if not has_building_door:
		for area in rooms_seen:
			if not doors_by_room.has(area.id):
				errors.append("Room %s has no door" % area.id)

	# Requirements declared by the pack that owns the function (§8.3).
	for area in areas:
		for cap in ZoneFunctionCatalog.required_capabilities(area.function):
			if not _capabilities_of(area.id).has(cap):
				errors.append("Area %s requires capability %s but no fixture provides it" % [area.id, cap])
	return errors


## Non-fatal remarks shown next to the zone list (§8.2). The file still runs.
func validation_warnings() -> Array[String]:
	var warnings: Array[String] = []
	var referenced_slots: Dictionary = {}
	for anchor in anchors:
		if anchor.is_queue():
			referenced_slots[anchor.target_id] = true
	for area in rooms():
		var owned := anchors_of(area.id)
		var has_slot := false
		var has_intake := false
		var has_dispatch := false
		for anchor in owned:
			if anchor.is_slot():
				has_slot = true
			elif anchor.is_storage():
				if anchor.direction == ZoneAnchorRecord.DIRECTION_IN:
					has_intake = true
				else:
					has_dispatch = true
		if not has_slot:
			warnings.append("Комната «%s» без мест: жители встанут где придётся" % area.display_name())
		if (has_intake or has_dispatch) and not (has_intake and has_dispatch):
			warnings.append("Склад «%s»: нет %s" % [area.display_name(),
				"выдачи" if has_intake else "приёмки"])
	for anchor in anchors:
		# An anchor sitting inside exactly one room but owned by nobody reads as a
		# forgotten `owner`, which is the most common authoring slip.
		if anchor.owner_id == &"":
			var containing := _rooms_containing(anchor.cell())
			if containing.size() == 1 and not anchor.is_door():
				warnings.append("Якорь «%s» стоит в комнате «%s», но ничьей не является" % [
					anchor.id, containing[0].display_name()])
	return warnings


func _has_fixture(fixture_id: StringName) -> bool:
	for fixture in fixtures:
		if fixture.id == fixture_id:
			return true
	return false


## Capabilities available to an area: its own fixtures plus building-wide ones.
func _capabilities_of(area_id: StringName) -> Dictionary:
	var caps: Dictionary = {}
	for fixture in fixtures:
		if fixture.owner_zone_id == &"" or fixture.owner_zone_id == area_id:
			for cap in fixture.capabilities:
				caps[cap] = true
	return caps


func _cell_permits(cell: Vector2i, audience: StringName) -> bool:
	for area in areas:
		if area.is_access() and area.contains_cell(cell) and not area.permits(audience):
			return false
	return true


func _rooms_containing(cell: Vector2i) -> Array[ZoneAreaRecord]:
	var result: Array[ZoneAreaRecord] = []
	for area in rooms():
		if area.contains_cell(cell):
			result.append(area)
	return result


static func _interiors_intersect(a: AABB, b: AABB) -> bool:
	const EPSILON := 0.0001
	return a.position.x < b.end.x - EPSILON and b.position.x < a.end.x - EPSILON \
		and a.position.y < b.end.y - EPSILON and b.position.y < a.end.y - EPSILON \
		and a.position.z < b.end.z - EPSILON and b.position.z < a.end.z - EPSILON


static func _allows_structural_joint(left: BlueprintBlock, right: BlueprintBlock) -> bool:
	return BuildingBlockCatalogScript.allows_structural_joint(left.block_id) \
		and BuildingBlockCatalogScript.allows_structural_joint(right.block_id)


## Requirement checklist for the editor inspector: one entry per capability a
## zone function demands. Entries: {area_id, area_name, capability, satisfied}.
func zone_requirements_checklist() -> Array[Dictionary]:
	var checklist: Array[Dictionary] = []
	for area in areas:
		var required := ZoneFunctionCatalog.required_capabilities(area.function)
		if required.is_empty():
			continue
		var available := _capabilities_of(area.id)
		for cap in required:
			checklist.append({
				"area_id": String(area.id),
				"area_name": area.display_name(),
				"capability": String(cap),
				"satisfied": available.has(cap),
			})
	return checklist


## Denormalizes areas + anchors into one runtime dict per owning area — the shape
## ZoneRuntimeState consumes unchanged (active_zones.md §9). Doors and top-level
## points are excluded; navigation takes them from `routing_anchor_definitions`.
func runtime_zone_definitions() -> Array:
	var buckets: Dictionary = {}
	for anchor in anchors:
		if anchor.owner_id == &"" or anchor.is_door():
			continue
		var bucket: Dictionary = buckets.get(anchor.owner_id, {})
		if bucket.is_empty():
			bucket = {"slots": [], "queue": [], "storage": []}
			buckets[anchor.owner_id] = bucket
		if anchor.is_storage() or anchor.is_slot() or anchor.is_queue():
			var key := "storage" if anchor.is_storage() else ("queue" if anchor.is_queue() else "slots")
			bucket[key].append(anchor.to_dict())
	var defs: Array = []
	for area in areas:
		if not area.owns_content():
			continue
		var d := area.to_dict()
		var bucket: Dictionary = buckets.get(area.id, {})
		d["slots"] = bucket.get("slots", [])
		d["queue"] = bucket.get("queue", [])
		d["storage"] = bucket.get("storage", [])
		d["fallback_pos"] = _vec3_to_array(area.centroid())
		defs.append(d)
	return defs


## Points navigation consumes rather than occupancy: doors and every top-level
## point (a stop on a street, a spawn) regardless of role.
func routing_anchor_definitions() -> Array:
	var defs: Array = []
	for anchor in anchors:
		if anchor.is_door() or anchor.owner_id == &"":
			defs.append(anchor.to_dict())
	return defs


## Access overlays as flat dicts, so navigation can apply them without loading
## the whole blueprint (active_zones.md §4).
func access_overlay_definitions() -> Array:
	var defs: Array = []
	for area in areas:
		if area.is_access():
			defs.append(area.to_dict())
	return defs


static func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## The alphabet is owned by `ContentId` (content_packaging.md §3.3): maps answer the
## same question, and two copies of one rule drift.
static func _valid_id(value: String) -> bool:
	return ContentIdScript.is_valid_id(value)


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
