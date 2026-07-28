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
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")

const FORMAT_VERSION := 6
const MIN_LOAD_VERSION := FORMAT_VERSION
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
var grid_bounds: Vector3i = Vector3i(8, 4, 8)

## Footprint on the settlement board. Entrances are **not** stored: they are the
## `door` anchors, and deriving them keeps one authority (active_zones.md §5.2).
var footprint: Vector2i = Vector2i(8, 8)

var blocks: Array[BlueprintBlock] = []

## Active zones, organized by geometry (design_docs/engine/active_zones.md §3):
## `areas` are regions, `anchors` are points, `routes` are ordered lines over
## routing points.
var areas: Array[ZoneAreaRecord] = []
var anchors: Array[ZoneAnchorRecord] = []
var routes: Array[ZoneRouteRecord] = []

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
## (see `BuildingAccessPoints`). `objects[]` is serialized in that centre space and converted back to
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


## Whether a zone id is already taken. Areas and points share **one** namespace
## (active_zones.md §7.1): rules, routes, saves and selectors address them by the
## same name, so an area `till` and a point `till` in one file is an ambiguity,
## not two independent ids.
func zone_id_taken(zone_id: StringName, except: Variant = null) -> bool:
	for area in areas:
		if area.id == zone_id and area != except:
			return true
	for anchor in anchors:
		if anchor.id == zone_id and anchor != except:
			return true
	return false


func anchor_by_id(anchor_id: StringName) -> ZoneAnchorRecord:
	for anchor in anchors:
		if anchor.id == anchor_id:
			return anchor
	return null


func route_by_id(route_id: StringName) -> ZoneRouteRecord:
	for route in routes:
		if route.id == route_id:
			return route
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


func to_dict() -> Dictionary:
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
		"grid_bounds": {"x": grid_bounds.x, "y": grid_bounds.y, "z": grid_bounds.z},
		"footprint": [footprint.x, footprint.y],
		"blocks": block_dicts,
		"surface_finishes": surface_finishes,
		"decor_trims": decor_trims,
		"areas": area_dicts,
		"anchors": anchor_dicts,
		"routes": routes.map(func(route: ZoneRouteRecord) -> Dictionary: return route.to_dict()),
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
	# Old versions (<= FORMAT_VERSION) are migrated up; versions above the
	# current format are preserved so validation_errors() can reject them.
	var authored_version := int(data.get("version", FORMAT_VERSION))
	bp.version = FORMAT_VERSION if authored_version <= FORMAT_VERSION else authored_version
	bp.id = StringName(data.get("id", "new_building"))
	bp.role = StringName(data.get("role", bp.id))
	bp.era = StringName(data.get("era", "tent"))
	bp.style = StringName(data.get("style", "generic"))
	bp.kind = StringName(data.get("kind", "building"))
	bp.name = String(data.get("name", "Новое здание"))
	bp.revision = String(data.get("revision", ""))
	bp.construction_style = StringName(data.get("construction_style", "surface"))
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
	if raw_routes is Array:
		for raw_route in raw_routes:
			if raw_route is Dictionary:
				bp.routes.append(ZoneRouteRecord.from_dict(raw_route))

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
	# Preserve the authored version so validation_errors() can reject
	# unsupported ones; from_json() gates on validation_errors().is_empty().
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
## stored save stamp, so blueprints do too.
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
	errors.append_array(_decor_errors())
	errors.append_array(_fixture_errors())
	return errors


## Zone-layer validation (design_docs/engine/active_zones.md §8.1). Reachability
## over NavGrid is not decided here — the file alone cannot answer it; everything
## that *can* be decided from the file is decided here and nowhere else.
func zone_validation_errors() -> Array[String]:
	return _zone_errors()


func _zone_errors() -> Array[String]:
	var errors: Array[String] = []
	# One namespace for areas and points (§7.1).
	var zone_ids: Dictionary = {}
	var area_ids: Dictionary = {}
	var rooms_seen: Array[ZoneAreaRecord] = []
	for area in areas:
		if not _valid_id(String(area.id)):
			errors.append("Недопустимый идентификатор области: %s" % area.id)
		if zone_ids.has(area.id):
			errors.append("Идентификатор занят дважды: %s" % area.id)
		zone_ids[area.id] = true
		area_ids[area.id] = true
		if area.role not in ZoneAreaRecord.ROLES:
			errors.append("Неизвестная роль области %s: %s" % [area.id, area.role])
		if area.function != &"" and not ZoneFunctionCatalog.has_function(area.function):
			errors.append("Область %s ссылается на неизвестную функцию: %s" % [area.id, area.function])
		if area.function != &"" and area.is_overlay():
			errors.append("Оверлей %s не может нести функцию: он ничего не адресует" % area.id)
		if area.y_max < area.y_min:
			errors.append("У области %s перевёрнут диапазон высот" % area.id)
		for audience in area.allow + area.deny:
			if not ZoneAccess.is_known_audience(audience) and not _valid_id(String(audience).replace(":", "_")):
				errors.append("Область %s ссылается на недопустимую аудиторию: %s" % [area.id, audience])
		for key in ZoneEffects.unknown_keys(area.effects):
			errors.append("У области %s неизвестный эффект: %s" % [area.id, key])
		if not area.is_overlay() and not (area.allow.is_empty() and area.deny.is_empty()):
			errors.append("Права есть только у оверлея, а %s — %s" % [
				area.id, ZoneAreaRecord.role_display_name(area.role)])
		if not area.is_overlay() and not area.effects.is_empty():
			errors.append("Эффекты есть только у оверлея, а %s — %s" % [
				area.id, ZoneAreaRecord.role_display_name(area.role)])
		# Rooms partition the building; only overlays may overlap (§7.3).
		if area.is_room():
			for other in rooms_seen:
				if area.overlaps(other):
					errors.append("Комнаты %s и %s пересекаются" % [area.id, other.id])
			rooms_seen.append(area)

	var doors_by_room: Dictionary = {}
	var slot_ids: Dictionary = {}
	for anchor in anchors:
		if not _valid_id(String(anchor.id)):
			errors.append("Недопустимый идентификатор точки: %s" % anchor.id)
		if zone_ids.has(anchor.id):
			errors.append("Идентификатор занят дважды: %s" % anchor.id)
		zone_ids[anchor.id] = true
		if anchor.role not in ZoneAnchorRecord.ROLES:
			errors.append("Неизвестная роль точки %s: %s" % [anchor.id, anchor.role])
		if anchor.owner_id != &"" and not area_ids.has(anchor.owner_id):
			errors.append("Точка %s принадлежит несуществующей области: %s" % [anchor.id, anchor.owner_id])
		if anchor.owner_id != &"" and area_ids.has(anchor.owner_id):
			var owner_area := area_by_id(anchor.owner_id)
			if owner_area != null and not owner_area.owns_content():
				errors.append("Точка %s принадлежит области %s, которая ничем не владеет" % [
					anchor.id, anchor.owner_id])
		if anchor.is_slot():
			slot_ids[anchor.id] = true
		if anchor.is_door() and anchor.owner_id != &"":
			doors_by_room[anchor.owner_id] = true
		if anchor.is_storage() and anchor.direction not in ZoneAnchorRecord.DIRECTIONS:
			errors.append("У поддона %s неизвестное направление: %s" % [anchor.id, anchor.direction])
		if anchor.fixture_id != &"" and not _has_fixture(anchor.fixture_id):
			errors.append("Точка %s ссылается на несуществующий предмет: %s" % [anchor.id, anchor.fixture_id])
		if not _cell_in_bounds(anchor.cell()):
			errors.append("Точка %s стоит за пределами доски" % anchor.id)
		# A slot standing where its own audience is denied can never be worked.
		if anchor.is_slot() and not _cell_permits(anchor.cell(), ZoneAccess.AUDIENCE_STAFF):
			errors.append("Место %s стоит там, куда персоналу вход запрещён" % anchor.id)
	for anchor in anchors:
		if anchor.is_queue() and not slot_ids.has(anchor.target_id):
			errors.append("Очередь %s ссылается на несуществующее место: %s" % [anchor.id, anchor.target_id])

	var route_ids: Dictionary = {}
	for route in routes:
		if not _valid_id(String(route.id)):
			errors.append("Недопустимый идентификатор маршрута: %s" % route.id)
		if route_ids.has(route.id):
			errors.append("Идентификатор маршрута занят дважды: %s" % route.id)
		route_ids[route.id] = true
		if route.cycle not in ZoneRouteRecord.CYCLES:
			errors.append("У маршрута %s неизвестный режим обхода: %s" % [route.id, route.cycle])
		if route.stops.size() < 2:
			errors.append("В маршруте %s должно быть хотя бы две точки" % route.id)
		for stop_id in route.stops:
			var stop := anchor_by_id(stop_id)
			if stop == null:
				errors.append("Маршрут %s ссылается на несуществующую точку: %s" % [route.id, stop_id])
			elif stop.role not in [ZoneAnchorRecord.ROLE_WAYPOINT,
					ZoneAnchorRecord.ROLE_SLOT, ZoneAnchorRecord.ROLE_DOOR]:
				errors.append("Маршрут %s не может проходить через %s (%s)" % [
					route.id, stop.id, ZoneAnchorRecord.role_display_name(stop.role)])

	# A room nobody can enter is not a room. A building-wide door counts.
	var has_building_door := false
	for anchor in anchors:
		if anchor.is_door() and anchor.owner_id == &"":
			has_building_door = true
	if not has_building_door:
		for area in rooms_seen:
			if not doors_by_room.has(area.id):
				errors.append("В комнату %s нет двери" % area.id)

	# Requirements declared by the pack that owns the function (§8.3).
	for area in areas:
		for cap in ZoneFunctionCatalog.required_capabilities(area.function):
			if not _capabilities_of(area.id).has(cap):
				errors.append("Области %s нужен предмет со свойством «%s»" % [area.id, cap])
	return errors


func _decor_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	var zone_ids: Dictionary = {}
	for area in areas:
		zone_ids[area.id] = true
	for obj in objects:
		var obj_errors := obj.validation_errors()
		for e in obj_errors:
			errors.append(e)
		if seen_ids.has(obj.id):
			errors.append("Duplicate decor object id: %s" % obj.id)
		seen_ids[obj.id] = true
		if obj.owner_zone_id != &"" and not zone_ids.has(obj.owner_zone_id):
			errors.append("Decor object %s references unknown place zone: %s" % [obj.id, obj.owner_zone_id])
	return errors


func _fixture_errors() -> Array[String]:
	var errors: Array[String] = []
	var object_ids: Dictionary = {}
	for obj in objects:
		object_ids[obj.id] = true
	var zone_ids: Dictionary = {}
	for area in areas:
		zone_ids[area.id] = true
	var visual_refs: Dictionary = {}
	for fixture in fixtures:
		var fe := fixture.validation_errors(object_ids, zone_ids)
		for e in fe:
			errors.append(e)
		if fixture.visual_object_id != "":
			if visual_refs.has(fixture.visual_object_id):
				errors.append("Fixture %s and %s reference the same visual object: %s" % [
					fixture.id, visual_refs[fixture.visual_object_id], fixture.visual_object_id])
			visual_refs[fixture.visual_object_id] = fixture.id
	return errors


func _cell_in_bounds(cell: Vector2i) -> bool:
	# A door is allowed to sit on the rim or one cell outside: that is the cell
	# one enters from (modular_building_editor.md §7.1).
	return cell.x >= -1 and cell.y >= -1 and cell.x <= footprint.x and cell.y <= footprint.y


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
		# More workers than places means the extra ones have nowhere to stand
		# (§13): capacity is bounded by the slots, not by the pack's wish.
		var slot_count := 0
		for anchor in owned:
			if anchor.is_slot():
				slot_count += 1
		var declared := int(area.properties.get("max_workers", 0))
		if slot_count > 0 and declared > slot_count:
			warnings.append("Комната «%s»: работников %d, а мест %d" % [
				area.display_name(), declared, slot_count])
	for anchor in anchors:
		# An anchor sitting inside exactly one room but owned by nobody reads as a
		# forgotten `owner`, which is the most common authoring slip.
		if anchor.owner_id == &"":
			var containing := _rooms_containing(anchor.cell())
			if containing.size() == 1 and not anchor.is_door():
				warnings.append("Точка «%s» стоит в комнате «%s», но ничьей не является" % [
					anchor.id, containing[0].display_name()])
		# A work place closed to visitors is normal; closed to everyone is a slip.
		if (anchor.is_spawn() or anchor.is_slot()) \
				and not _cell_permits(anchor.cell(), ZoneAccess.AUDIENCE_VISITOR) \
				and not _cell_permits(anchor.cell(), ZoneAccess.AUDIENCE_STAFF):
			warnings.append("Точка «%s» закрыта оверлеем для всех аудиторий" % anchor.id)
	for area in areas:
		if area.is_overlay() and not area.is_active_overlay():
			warnings.append("Оверлей «%s» ничего не запрещает и ничего не меняет" % area.display_name())
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
		if area.is_overlay() and area.contains_cell(cell) and not area.permits(audience):
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
##
## **This is the coordinate boundary.** Zones are authored and stored in board
## cells `[0…footprint]`, while a built building's node origin is the footprint
## centre. Everything leaving for the runtime is converted here, once, exactly
## like `entrance_offset()` does for doors — a slot converted differently from
## the door of its own building means citizens working half a footprint away, and
## no test that feeds the runtime hand-written dictionaries can see it.
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
			bucket[key].append(_anchor_runtime_dict(anchor))
	var defs: Array = []
	for area in areas:
		if not area.owns_content():
			continue
		var d := area.to_dict()
		var bucket: Dictionary = buckets.get(area.id, {})
		d["slots"] = bucket.get("slots", [])
		d["queue"] = bucket.get("queue", [])
		d["storage"] = bucket.get("storage", [])
		d["fallback_pos"] = _vec3_to_array(_to_pivot_space(area.centroid()))
		defs.append(d)
	return defs


## Points navigation consumes rather than occupancy: doors and every top-level
## point (a stop on a street, a spawn) regardless of role. Pivot-relative, as
## above.
func routing_anchor_definitions() -> Array:
	var defs: Array = []
	for anchor in anchors:
		if anchor.is_door() or anchor.owner_id == &"":
			defs.append(_anchor_runtime_dict(anchor))
	return defs


func route_definitions() -> Array:
	return routes.map(func(route: ZoneRouteRecord) -> Dictionary: return route.to_dict())


## Overlays as flat dicts, so navigation can apply permissions and effects
## without loading the whole blueprint (active_zones.md §4). Rectangles stay in
## **board cells**: they address cells of the frame, and a cell index has no
## meaning in pivot space — the consumer converts a world position to a board
## cell, not the other way round.
func overlay_definitions() -> Array:
	var defs: Array = []
	for area in areas:
		if area.is_overlay():
			defs.append(area.to_dict())
	return defs


func _anchor_runtime_dict(anchor: ZoneAnchorRecord) -> Dictionary:
	var data := anchor.to_dict()
	data["pos"] = _vec3_to_array(_to_pivot_space(anchor.pos))
	return data


## Board space `[0…footprint]` → building-local space around the pivot. Y is a
## layer height and is never shifted.
func _to_pivot_space(board_position: Vector3) -> Vector3:
	if board_position == Vector3.INF:
		return board_position
	var pivot := pivot_offset()
	return Vector3(board_position.x - pivot.x, board_position.y, board_position.z - pivot.z)


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
