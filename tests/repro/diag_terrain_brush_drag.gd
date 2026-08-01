extends SceneTree

## Simulates a sculpt drag across flat ground and reports the height profile it
## leaves behind. A drag is expected to raise the swept band by one step; anything
## else means the stroke is not idempotent over its own overlap.

func _init() -> void:
	_drag(1)
	_drag(3)
	_wiggle()
	quit(0)


func _drag(brush_size: int) -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 64, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	var service := TerrainService.new()
	service.configure(grid)
	var brush := TerrainBrushController.new()
	brush.configure(grid, service)
	brush.brush_size = brush_size
	brush.edit_mode = TerrainEditOperation.Mode.SCULPT

	# Press at x = -10, then drag east to x = +10, one column at a time.
	brush.has_hover = true
	brush.hovered_cell = Vector2i(-10, 0)
	brush.set_paint_direction(1)
	for x in range(-9, 11):
		var previous := brush.hovered_cell
		brush.hovered_cell = Vector2i(x, 0)
		brush._on_hover_changed(previous, true)
	brush.set_paint_direction(0)

	var profile := PackedInt32Array()
	for x in range(-12, 13):
		profile.append(grid.height_of(Vector2i(x, 0)))
	print("drag east, brush %d: heights x=-12..12 -> %s" % [brush_size, str(profile)])


func _wiggle() -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 64, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	var service := TerrainService.new()
	service.configure(grid)
	var brush := TerrainBrushController.new()
	brush.configure(grid, service)
	brush.brush_size = 1
	brush.edit_mode = TerrainEditOperation.Mode.SCULPT
	brush.has_hover = true
	brush.hovered_cell = Vector2i(0, 0)
	brush.set_paint_direction(1)
	# The cursor jitters between two columns without leaving them.
	for _pass in 10:
		var previous := brush.hovered_cell
		brush.hovered_cell = Vector2i(1, 0)
		brush._on_hover_changed(previous, true)
		previous = brush.hovered_cell
		brush.hovered_cell = Vector2i(0, 0)
		brush._on_hover_changed(previous, true)
	brush.set_paint_direction(0)
	print("wiggle between two columns, 10 round trips: h(0,0)=%d h(1,0)=%d (one press expected +1)" % [
		grid.height_of(Vector2i(0, 0)), grid.height_of(Vector2i(1, 0)),
	])
