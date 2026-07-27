class_name MapZoneLayer
extends RefCounted

## Typed active-zone layer of a map (§9 of map_editor.md).  It deliberately uses
## the same records as blueprints: geometry and engine roles are shared, while
## the editor decides which roles it offers for a map.

var areas: Array[ZoneAreaRecord] = []
var anchors: Array[ZoneAnchorRecord] = []
var routes: Array[ZoneRouteRecord] = []


func clear() -> void:
	areas.clear()
	anchors.clear()
	routes.clear()


func area_by_id(id: StringName) -> ZoneAreaRecord:
	for area in areas:
		if area.id == id:
			return area
	return null


func anchor_by_id(id: StringName) -> ZoneAnchorRecord:
	for anchor in anchors:
		if anchor.id == id:
			return anchor
	return null


func route_by_id(id: StringName) -> ZoneRouteRecord:
	for route in routes:
		if route.id == id:
			return route
	return null


func has_id(id: StringName) -> bool:
	return area_by_id(id) != null or anchor_by_id(id) != null or route_by_id(id) != null


func to_json() -> Dictionary:
	return {
		"areas": areas.map(func(area: ZoneAreaRecord) -> Dictionary: return area.to_dict()),
		"anchors": anchors.map(func(anchor: ZoneAnchorRecord) -> Dictionary: return anchor.to_dict()),
		"routes": routes.map(func(route: ZoneRouteRecord) -> Dictionary: return route.to_dict()),
	}


func from_json(source: Dictionary) -> void:
	clear()
	for raw_area in source.get("areas", []):
		if raw_area is Dictionary:
			areas.append(ZoneAreaRecord.from_dict(raw_area))
	for raw_anchor in source.get("anchors", []):
		if raw_anchor is Dictionary:
			anchors.append(ZoneAnchorRecord.from_dict(raw_anchor))
	for raw_route in source.get("routes", []):
		if raw_route is Dictionary:
			routes.append(ZoneRouteRecord.from_dict(raw_route))


## Map-only role gate. Building-only rooms own fixtures and are supplied by a
## placed blueprint; a map names regions and overlays around them.
func validate(board_cells: int) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for area in areas:
		_validate_id(area.id, ids, errors)
		if area.role not in [ZoneAreaRecord.ROLE_REGION, ZoneAreaRecord.ROLE_OVERLAY]:
			errors.append("область %s: роль %s недопустима на карте" % [area.id, area.role])
		if area.rects.is_empty():
			errors.append("область %s не содержит прямоугольников" % area.id)
		for rect in area.rects:
			if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > board_cells or rect.end.y > board_cells:
				errors.append("область %s выходит за доску" % area.id)
	for anchor in anchors:
		_validate_id(anchor.id, ids, errors)
		if anchor.role not in ZoneAnchorRecord.ROLES:
			errors.append("точка %s: неизвестная роль %s" % [anchor.id, anchor.role])
		var cell := anchor.cell()
		if cell.x < 0 or cell.y < 0 or cell.x >= board_cells or cell.y >= board_cells:
			errors.append("точка %s выходит за доску" % anchor.id)
		if anchor.owner_id != &"" and area_by_id(anchor.owner_id) == null:
			errors.append("точка %s ссылается на отсутствующую область %s" % [anchor.id, anchor.owner_id])
	for route in routes:
		_validate_id(route.id, ids, errors)
		for stop in route.stops:
			if anchor_by_id(stop) == null:
				errors.append("маршрут %s ссылается на отсутствующую точку %s" % [route.id, stop])
	return errors


func _validate_id(id: StringName, ids: Dictionary, errors: Array[String]) -> void:
	if id == &"":
		errors.append("у зоны нет id")
		return
	if ids.has(id):
		errors.append("дублирующийся id зоны: %s" % id)
		return
	ids[id] = true
