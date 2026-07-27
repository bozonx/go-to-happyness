class_name BorderOceanService
extends RefCounted

## The rule behind `MapMeta.border_kind` (design_docs/engine/map_editor.md §6.1).
##
## An ocean or lava border is not decoration. It says the world continues as sea
## or lava at `border_level`, and the consequence an author feels is this: **dig
## at the rim below that level and the sea (or lava) comes in.** Not on a later
## pass, not when they remember to press a button — as part of the same stroke,
## because a channel cut to the coast that stays dry is a bug in every author's
## head.
##
## Why it is a service and not a branch in the water brush:
##
## * The rule is owned by the map header, so it must hold for every tool that ever
##   moves a column, not for the one that happens to exist today.
## * It writes through `WaterService` like everything else, so the fill lands on
##   the undo stack and republishes navigation. An ocean that appeared outside a
##   transaction would be water no route could see.
## * It is deliberately edge-seeded and never inland-seeded: a closed depression in
##   the middle of the map stays dry however deep it is, because it has no
##   connection to the sea. `WaterService.flood` is the tool for those, and it
##   needs an author to point at one.
##
## The body it fills with is the map's own `SEA` (ocean) or `LAVA` (lava border),
## created on first need. A map whose rim is entirely above the border level never
## gets one — an empty registry entry would show up in the author's palette as a
## lake they never made.

var water_service: WaterService = null
var terrain: TerrainGrid = null
var water: WaterGrid = null

var _kind: StringName = MapMeta.BORDER_NOTHING
var _level := 0


func configure(next_water_service: WaterService, next_terrain: TerrainGrid, next_water: WaterGrid, meta: MapMeta) -> void:
	water_service = next_water_service
	terrain = next_terrain
	water = next_water
	_kind = meta.border_kind if meta != null else MapMeta.BORDER_NOTHING
	_level = meta.border_level if meta != null else 0


## Applies the header's border rule to the board as it stands now.
##
## Returns true when it actually committed water, which is what lets a caller
## group the fill with the terrain stroke that caused it into one undo step.
## Returns false when there was nothing to do — the usual answer, because most
## strokes are nowhere near the rim.
func apply() -> bool:
	if not MapMeta.has_border_fill_static(_kind) or water_service == null or terrain == null or water == null:
		return false
	var border_id := border_body_id()
	if border_id == WaterBody.NO_BODY:
		if not _has_open_edge():
			return false
		var body_type := WaterBody.Type.SEA if _kind == MapMeta.BORDER_OCEAN else WaterBody.Type.LAVA
		var border_body := water_service.create_body(body_type, _level)
		if border_body == null:
			return false
		border_id = border_body.id
	return water_service.flood_from_edges(border_id, _level)


## The map's border body — its `SEA` for an ocean border, its `LAVA` for a lava
## border — or `NO_BODY` when it has none. The first matching body in id order:
## a map with two seas has two coastlines an author drew on purpose, and the
## border is the older one.
func border_body_id() -> int:
	if water == null:
		return WaterBody.NO_BODY
	var body_type := WaterBody.Type.SEA if _kind == MapMeta.BORDER_OCEAN else WaterBody.Type.LAVA
	for body: WaterBody in water.bodies():
		if body.type == body_type:
			return body.id
	return WaterBody.NO_BODY


## Whether a body is the border body — the one the border rule fills with. A
## border body cannot be deleted or retyped by the author; only raising the ground
## above the level drains it.
func is_border_body(body_id: int) -> bool:
	return body_id != WaterBody.NO_BODY and body_id == border_body_id()


func border_kind() -> StringName:
	return _kind


func border_level() -> int:
	return _level


## Whether any column on the rim lies below the border level. Checked before
## creating the body so that an inland map never grows a border it cannot see.
func _has_open_edge() -> bool:
	var minimum := terrain.min_cell()
	var maximum := terrain.max_cell()
	for x in range(minimum.x, maximum.x + 1):
		if _is_open(Vector2i(x, minimum.y)) or _is_open(Vector2i(x, maximum.y)):
			return true
	for z in range(minimum.y + 1, maximum.y):
		if _is_open(Vector2i(minimum.x, z)) or _is_open(Vector2i(maximum.x, z)):
			return true
	return false


func _is_open(cell: Vector2i) -> bool:
	return not terrain.is_hole(cell) and terrain.height_of(cell) < _level
