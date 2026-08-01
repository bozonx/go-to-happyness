class_name BaseBrushController
extends RefCounted

## Shared base for terrain and water brush controllers (map_editor.md §3.1).
##
## Both brushes pick the hovered column the same way — a ray into the terrain
## collider, nudged into the surface to resolve shared edges — and both stamp a
## square of cells centred on that column. The picking grid is always a
## `TerrainGrid`: the water surface has no collider (§9), so the water brush
## picks through the ground underneath.
##
## Derived classes set `_pick_grid` in their `configure` method and override
## `_on_hover_changed` to react to the cursor crossing into a new column during
## a drag.

const HOVER_RAY_LENGTH := 500.0
const MAX_BRUSH_SIZE := 8

var brush_size := 1
var hovered_cell := Vector2i.ZERO
var has_hover := false
var last_message := ""

## The grid used for ray picking and bounds checking. Both `TerrainGrid` and
## `WaterGrid` cover the same board, so either one answers `is_inside` correctly.
var _pick_grid: RefCounted


# --- Hover --------------------------------------------------------------------

## Picks the column under the cursor. Returns whether a column is hovered.
func update_hover(camera: Camera3D, space: PhysicsDirectSpaceState3D, mouse: Vector2) -> bool:
	if camera == null or space == null or _pick_grid == null:
		has_hover = false
		return false
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(mouse) * HOVER_RAY_LENGTH,
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	var previous := hovered_cell
	var had_hover := has_hover
	has_hover = not hit.is_empty()
	if has_hover:
		# Nudge into the surface so a hit exactly on a shared edge resolves to the
		# column the cursor is visually over.
		var point: Vector3 = hit["position"] - (hit["normal"] as Vector3) * 0.01
		hovered_cell = _pick_grid.cell_from_position(point)
		has_hover = _pick_grid.is_inside(hovered_cell)
	_on_hover_changed(previous, had_hover)
	return has_hover


func clear_hover() -> void:
	has_hover = false


## Called after hover state changes. Override to apply drag painting or other
## cursor-following behaviour.
func _on_hover_changed(_previous_cell: Vector2i, _had_hover: bool) -> void:
	pass


# --- Brush shape --------------------------------------------------------------

## The square of in-bounds cells the brush covers, centred on `center`.
func brush_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var radius := brush_size - 1
	for offset_z in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var cell := center + Vector2i(offset_x, offset_z)
			if _pick_grid != null and _pick_grid.is_inside(cell):
				cells.append(cell)
	return cells


func adjust_brush_size(delta: int) -> void:
	brush_size = clampi(brush_size + delta, 1, MAX_BRUSH_SIZE)
