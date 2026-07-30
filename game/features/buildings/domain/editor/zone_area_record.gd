class_name ZoneAreaRecord
extends RefCounted

## An **area** — one of the three active-zone primitives
## (design_docs/engine/active_zones.md §3, §5.1).
##
## The engine only knows three area roles. What an area *means* in a game is a
## `function` supplied by a content pack plus its `properties`; the engine never
## reads them (§2). That is what lets the same editor author a settlement
## bakery, an RPG inn and a shooter spawn room without touching the format.
##
##   room    — an addressable part of a building. Owns its anchors, fixtures and
##             objects; the player clicks it to open the menu.
##   region  — a named area on a map that rules and routes reference by id.
##             Owns nothing.
##   overlay — permissions (ZoneAccess) and effects (ZoneEffects). Owns nothing,
##             addresses nothing, overlaps anything including itself.
##
## The difference between `room` and `region` is ownership, not size: a room owns
## content and answers a click, a region only names a place.
##
## Geometry is a set of rectangles over the board plus a height range: a
## rectangle is free on a grid, several of them make an L-shaped room without
## giving up a single identity, and a file stays small.

const ROLE_ROOM := &"room"
const ROLE_REGION := &"region"
const ROLE_OVERLAY := &"overlay"

const ROLES: Array[StringName] = [ROLE_ROOM, ROLE_REGION, ROLE_OVERLAY]

## Roles that own anchors, fixtures and objects, and that a game menu addresses.
const OWNING_ROLES: Array[StringName] = [ROLE_ROOM]

var id: StringName = &"area_1"
var area_name: String = "Область"
var role: StringName = ROLE_ROOM
## Pack-defined meaning ("settlement:bakery"). Empty = a plain, inert area.
var function: StringName = &""
## Pack-defined parameters of the function (profession, capacity, opening hours).
var properties: Dictionary = {}
## Board rectangles making up the area, in cells.
var rects: Array[Rect2i] = []
## Inclusive height range in grid levels.
var y_min: int = 0
var y_max: int = 0
## `overlay` — permission mask over audiences (§4.1).
var allow: Array[StringName] = []
var deny: Array[StringName] = []
## `overlay` — corrections to what the engine already computes (§4.2).
var effects: Dictionary = {}


## Name for lists and messages. Access overlays are usually left unnamed, so the
## id has to carry them — an unnamed row in the zone list is unusable.
func display_name() -> String:
	return area_name if area_name != "" else String(id)


func is_room() -> bool:
	return role == ROLE_ROOM


func is_overlay() -> bool:
	return role == ROLE_OVERLAY


## True when the overlay actually changes something. An overlay that forbids
## nobody and corrects nothing is a no-op, and the validator says so.
func is_active_overlay() -> bool:
	return is_overlay() and not (allow.is_empty() and deny.is_empty() and effects.is_empty())


## True when the area owns content (anchors, fixtures, objects reference it).
func owns_content() -> bool:
	return role in OWNING_ROLES


func permits(audience: StringName) -> bool:
	return ZoneAccess.permits(allow, deny, audience)


func is_empty() -> bool:
	return rects.is_empty()


func add_rect(rect: Rect2i) -> void:
	var normalized := rect.abs()
	if normalized.size.x <= 0 or normalized.size.y <= 0:
		return
	if normalized not in rects:
		rects.append(normalized)


## Removes one cell while preserving the rest of the area. A rectangle covering
## the cell is deterministically split into at most four rectangles.
func remove_cell(cell: Vector2i) -> bool:
	var changed := false
	var next_rects: Array[Rect2i] = []
	for rect in rects:
		if not rect.has_point(cell):
			next_rects.append(rect)
			continue
		changed = true
		var top_height := cell.y - rect.position.y
		var bottom_height := rect.end.y - cell.y - 1
		var left_width := cell.x - rect.position.x
		var right_width := rect.end.x - cell.x - 1
		if top_height > 0:
			next_rects.append(Rect2i(rect.position, Vector2i(rect.size.x, top_height)))
		if bottom_height > 0:
			next_rects.append(Rect2i(
				Vector2i(rect.position.x, cell.y + 1), Vector2i(rect.size.x, bottom_height)))
		if left_width > 0:
			next_rects.append(Rect2i(
				Vector2i(rect.position.x, cell.y), Vector2i(left_width, 1)))
		if right_width > 0:
			next_rects.append(Rect2i(
				Vector2i(cell.x + 1, cell.y), Vector2i(right_width, 1)))
	if changed:
		rects = next_rects
	return changed


func remove_rect_at(cell: Vector2i) -> bool:
	return remove_cell(cell)


func contains_cell(cell: Vector2i) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false


func contains_cell_3d(cell: Vector3i) -> bool:
	return cell.y >= y_min and cell.y <= y_max and contains_cell(Vector2i(cell.x, cell.z))


func overlaps(other: ZoneAreaRecord) -> bool:
	if other == null or other.y_max < y_min or other.y_min > y_max:
		return false
	for rect in rects:
		for other_rect in other.rects:
			if rect.intersects(other_rect):
				return true
	return false


## Board cells covered by the area, without height. Used by the editor overlay
## and by the runtime fallback point when a room has no authored slots.
func footprint_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for rect in rects:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, z)
				if cell not in cells:
					cells.append(cell)
	return cells


func cell_count() -> int:
	return footprint_cells().size()


## Local centre of the area at its lowest level — where a citizen stands when the
## room has no authored slots (active_zones.md §5.2).
func centroid() -> Vector3:
	var cells := footprint_cells()
	if cells.is_empty():
		return Vector3.INF
	var sum := Vector2.ZERO
	for cell in cells:
		sum += Vector2(cell) + Vector2(0.5, 0.5)
	sum /= cells.size()
	return Vector3(sum.x, float(y_min), sum.y)


func to_dict() -> Dictionary:
	var rect_dicts: Array = []
	for rect in rects:
		rect_dicts.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var data := {
		"id": String(id),
		"role": String(role),
		"rects": rect_dicts,
		"y": [y_min, y_max],
	}
	# Fields that only matter when set stay out of the file, so a hand-written
	# blueprint reads as what the author actually chose.
	if area_name != "":
		data["name"] = area_name
	if function != &"":
		data["function"] = String(function)
	if not properties.is_empty():
		data["properties"] = properties.duplicate(true)
	if not allow.is_empty():
		data["allow"] = ZoneAccess.audiences_to_json(allow)
	if not deny.is_empty():
		data["deny"] = ZoneAccess.audiences_to_json(deny)
	var effect_json := ZoneEffects.to_json(effects)
	if not effect_json.is_empty():
		data["effects"] = effect_json
	return data


static func from_dict(data: Dictionary) -> ZoneAreaRecord:
	var area := ZoneAreaRecord.new()
	area.id = StringName(data.get("id", "area_1"))
	area.area_name = String(data.get("name", ""))
	area.role = StringName(data.get("role", ROLE_ROOM))
	area.function = StringName(data.get("function", ""))
	var raw_properties: Variant = data.get("properties", {})
	area.properties = (raw_properties as Dictionary).duplicate(true) if raw_properties is Dictionary else {}
	for raw_rect in data.get("rects", []):
		if raw_rect is Array and raw_rect.size() >= 4:
			area.add_rect(Rect2i(int(raw_rect[0]), int(raw_rect[1]), int(raw_rect[2]), int(raw_rect[3])))
	var raw_y: Variant = data.get("y", [])
	if raw_y is Array and raw_y.size() >= 2:
		area.y_min = int(raw_y[0])
		area.y_max = int(raw_y[1])
	area.allow = ZoneAccess.parse_audiences(data.get("allow", []))
	area.deny = ZoneAccess.parse_audiences(data.get("deny", []))
	area.effects = ZoneEffects.parse(data.get("effects", {}))
	return area


static func role_display_name(area_role: StringName) -> String:
	match area_role:
		ROLE_ROOM: return "Комната"
		ROLE_REGION: return "Область карты"
		ROLE_OVERLAY: return "Оверлей"
		_: return String(area_role)


static func role_hint(area_role: StringName) -> String:
	match area_role:
		ROLE_ROOM: return "Владеет точками, предметами и меню. Комнаты не пересекаются."
		ROLE_REGION: return "Только имя места для правил. Ничем не владеет."
		ROLE_OVERLAY: return "Права и эффекты поверх любых зон. Ничем не владеет."
		_: return ""
