class_name CoverageRasterizer
extends RefCounted

## Turns an authoring gesture into the cells it covers (map_editor.md §5.2.1).
##
## Two gestures, one output: a square brush stamp, and a stroke of a given width
## along a polyline. Both return plain cells, and that is the whole design.
##
## **The stroke is an input device, not stored geometry.** The curve is
## rasterised and dies with the gesture; neither it nor its width is written to
## the package. Storing it would create a second source of truth against the one
## property the layer depends on — a cell belongs to exactly one coverage — and
## junctions are then resolved by data instead of by fitting geometry together.
##
## The same rasteriser serves the settlement's own road building: the player
## drags, these cells become a construction order, and completion writes the layer
## the editor writes (`navigation_and_roads.md`, «Дороги и транспорт»). There is
## no second implementation of laying a road.

## Cells within `radius` of `centre`, clipped to the board. `radius` 0 is a single
## cell, matching the editor's brush size of 1.
static func stamp(centre: Vector2i, radius: int, layer: CoverageLayer) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var reach := maxi(radius, 0)
	for offset_z in range(-reach, reach + 1):
		for offset_x in range(-reach, reach + 1):
			var cell := centre + Vector2i(offset_x, offset_z)
			if layer == null or layer.is_inside(cell):
				cells.append(cell)
	return cells


## The cells of a stroke of `width` cells along a polyline of board positions,
## deduplicated and in a stable order.
##
## Width is measured in cells and rounded to a radius, because the layer is
## per-cell: a 3-cell path is a centre line plus one cell either side, and asking
## for 3.4 would only mean picking the same integer with more steps.
static func stroke(points: Array[Vector2i], width: int, layer: CoverageLayer) -> Array[Vector2i]:
	var radius := maxi(width - 1, 0) / 2
	var seen: Dictionary = {}
	for index in points.size():
		var from: Vector2i = points[index]
		for cell: Vector2i in stamp(from, radius, layer):
			seen[cell] = true
		if index + 1 < points.size():
			for cell: Vector2i in line(from, points[index + 1]):
				for brush_cell: Vector2i in stamp(cell, radius, layer):
					seen[brush_cell] = true
	return _sorted(seen)


## Bresenham between two cells, both ends included. A drag samples the cursor per
## frame, so consecutive samples can be several cells apart at speed; without this
## a fast stroke would lay a dotted road.
static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta_x := absi(to.x - from.x)
	var delta_y := absi(to.y - from.y)
	var step_x := 1 if to.x > from.x else -1
	var step_y := 1 if to.y > from.y else -1
	var error := delta_x - delta_y
	var cell := from
	while true:
		cells.append(cell)
		if cell == to:
			break
		var doubled := error * 2
		if doubled > -delta_y:
			error -= delta_y
			cell.x += step_x
		if doubled < delta_x:
			error += delta_x
			cell.y += step_y
	return cells


## Deterministic order, row by row. A stroke that produced its cells in cursor
## order would record an undo delta whose contents depend on how fast the author
## moved the mouse.
static func _sorted(seen: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in seen:
		result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result
