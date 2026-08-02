class_name MapZoneLayer
extends RefCounted

## Typed active-zone layer of a map (§9 of map_editor.md).  It deliberately uses
## the same records as blueprints: geometry and engine roles are shared, while
## the editor decides which roles it offers for a map.

var areas: Array[ZoneAreaRecord] = []
var anchors: Array[ZoneAnchorRecord] = []
var routes: Array[ZoneRouteRecord] = []
## Party appearance, one level above the anchors (`map_start.md` §4.2). It lives
## in the zone layer and not in a file of its own because it is made entirely of
## zone primitives: slots point at anchors, the formation grows inside an area.
var spawn_groups: Array[MapSpawnGroup] = []


func clear() -> void:
	areas.clear()
	anchors.clear()
	routes.clear()
	spawn_groups.clear()


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


func spawn_group_by_id(id: StringName) -> MapSpawnGroup:
	for group in spawn_groups:
		if group.id == id:
			return group
	return null


func has_id(id: StringName) -> bool:
	return area_by_id(id) != null or anchor_by_id(id) != null or route_by_id(id) != null


## The board is centred on the world origin, exactly like `TerrainGrid` and
## `NavGrid`: a board of N cells runs `-N/2 … N-N/2-1` on both axes. Every reader
## of zone geometry asks this one question, and it is here rather than inlined so
## a `0 … N` check can never creep back in — that check silently dropped every
## zone in the western three quarters of a map from the cost and presence
## indexes while the editor happily drew them.
static func is_board_cell(cell: Vector2i, board_cells: int) -> bool:
	var half := board_cells / 2
	return cell.x >= -half and cell.y >= -half \
		and cell.x < board_cells - half and cell.y < board_cells - half


func to_json() -> Dictionary:
	return {
		"areas": areas.map(func(area: ZoneAreaRecord) -> Dictionary: return area.to_dict()),
		"anchors": anchors.map(func(anchor: ZoneAnchorRecord) -> Dictionary: return anchor.to_dict()),
		"routes": routes.map(func(route: ZoneRouteRecord) -> Dictionary: return route.to_dict()),
		"spawn_groups": spawn_groups.map(func(group: MapSpawnGroup) -> Dictionary: return group.to_dict()),
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
	for raw_group in source.get("spawn_groups", []):
		if raw_group is Dictionary:
			var group := MapSpawnGroup.from_dict(raw_group)
			if group.id != &"":
				spawn_groups.append(group)


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
			# `end` is exclusive, so the last cell it covers is `end - (1,1)`.
			if not is_board_cell(rect.position, board_cells) \
					or not is_board_cell(rect.end - Vector2i.ONE, board_cells):
				errors.append("область %s выходит за доску" % area.id)
	for anchor in anchors:
		_validate_id(anchor.id, ids, errors)
		if anchor.role not in ZoneAnchorRecord.ROLES:
			errors.append("точка %s: неизвестная роль %s" % [anchor.id, anchor.role])
		var cell := anchor.cell()
		if not is_board_cell(cell, board_cells):
			errors.append("точка %s выходит за доску" % anchor.id)
		# §5.2: a queue leads to a slot and a place in line. Authored without a
		# target it is a point the engine can do nothing with, and the map editor
		# used to be able to create exactly that.
		if anchor.is_queue() and (anchor.target_id == &"" or anchor_by_id(anchor.target_id) == null):
			errors.append("очередь %s не ссылается на существующее место" % anchor.id)
		if anchor.owner_id != &"":
			var owner := area_by_id(anchor.owner_id)
			if owner == null:
				errors.append("точка %s ссылается на отсутствующую область %s" % [anchor.id, anchor.owner_id])
			# §8.1: a point sits outside the y-range of its owner area — a launch error.
			# The owner's rectangles cover the footprint; the point's height must lie in
			# the area's inclusive y-band. Checked only when the footprint is valid, so a
			# dangling owner reference reports once, not twice.
			elif owner.contains_cell(cell) and (anchor.pos.y < float(owner.y_min) or anchor.pos.y > float(owner.y_max)):
				errors.append("точка %s вне уровня y области %s" % [anchor.id, anchor.owner_id])
	for route in routes:
		_validate_id(route.id, ids, errors)
		for stop in route.stops:
			if anchor_by_id(stop) == null:
				errors.append("маршрут %s ссылается на отсутствующую точку %s" % [route.id, stop])
	for group in spawn_groups:
		_validate_id(group.id, ids, errors)
		# A group made of neither places nor a clearing has nowhere to put anybody,
		# and the failure would otherwise surface as a launch error on a map that
		# looked complete in the editor (`map_start.md` §4.3).
		if group.slots.is_empty() and group.area_id == &"":
			errors.append("группа появления %s не имеет ни слотов, ни области" % group.id)
		if group.area_id != &"" and area_by_id(group.area_id) == null:
			errors.append("группа появления %s ссылается на отсутствующую область %s" % [group.id, group.area_id])
		for slot in group.slots:
			var anchor := anchor_by_id(slot.anchor_id)
			if anchor == null:
				errors.append("слот %s группы %s ссылается на отсутствующую точку %s" % [
					slot.id, group.id, slot.anchor_id])
			elif not anchor.is_spawn():
				errors.append("слот %s группы %s ссылается на точку %s с ролью %s вместо spawn" % [
					slot.id, group.id, anchor.id, anchor.role])
	return errors


## §8.2: things a map will launch with but the author very likely did not mean.
## Kept separate from `validate()` on purpose — errors block save, warnings do
## not, and folding them together would make every "you forgot to reference this
## region" notice refuse the file.
func warnings(board_cells: int) -> Array[String]:
	var warnings: Array[String] = []
	var referenced: Dictionary = {}
	for anchor in anchors:
		if anchor.owner_id != &"":
			referenced[anchor.owner_id] = true
	for route in routes:
		for stop in route.stops:
			var anchor := anchor_by_id(stop)
			if anchor != null and anchor.owner_id != &"":
				referenced[anchor.owner_id] = true
	# A region that no anchor owns and no route touches is almost certainly a
	# leftover. An overlay is exempt: it changes a calculation, it is not pointed
	# at by anything, and that is exactly what makes it an overlay.
	for area in areas:
		if area.role == ZoneAreaRecord.ROLE_REGION and not referenced.has(area.id):
			warnings.append("область %s ни на что не ссылается" % area.id)
	# A spawn or slot sealed off by its own audience's denial is a warning, not an
	# error (§8.2): the cell is passable, the agent simply may not plan there.
	for anchor in anchors:
		if anchor.role in [ZoneAnchorRecord.ROLE_SPAWN, ZoneAnchorRecord.ROLE_SLOT]:
			var cell := anchor.cell()
			for area in areas:
				if area.is_overlay() and area.contains_cell(cell) and ZoneAccess.permits(area.allow, area.deny, ZoneAccess.AUDIENCE_VISITOR) == false:
					warnings.append("точка %s в клетке, закрытой оверлеем для посетителя" % anchor.id)
	return warnings


func _validate_id(id: StringName, ids: Dictionary, errors: Array[String]) -> void:
	if id == &"":
		errors.append("у зоны нет id")
		return
	# §8.1: an id outside the `ContentId` alphabet — same rule for a point as for
	# an area. The alphabet is the one an id becomes a filename and a save
	# reference by, so a zone with `Вход` in it cannot survive the round trip.
	if not ContentId.is_valid_id(String(id)):
		errors.append("id зоны вне алфавита: %s" % id)
		return
	if ids.has(id):
		errors.append("дублирующийся id зоны: %s" % id)
		return
	ids[id] = true
