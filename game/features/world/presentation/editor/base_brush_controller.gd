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

## Footprint of the brush. A square stamps the axis-aligned block the grid is made
## of and is what a terrace or a building pad wants; a circle is what a natural
## hill wants, and a square one was the reason every sculpted mound came out with
## four corners the cascade then had to round off.
enum Shape {
	SQUARE,
	CIRCLE,
}

## How the brush's effect falls off towards its rim (§4.1: the ground is integer
## columns, so this scales the height step a cell is asked to move, and the result
## is rounded — it never introduces a fractional height).
##
## `CONSTANT` is the original behaviour and stays the default: it is the only one
## that gives a flat pad, which is what levelling and terracing are for.
enum Falloff {
	CONSTANT,
	LINEAR,
	SMOOTH,
}

var brush_size := 1
var brush_shape: Shape = Shape.SQUARE
var brush_falloff: Falloff = Falloff.CONSTANT
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

## The in-bounds cells the brush covers, centred on `center`. Surface brushes
## (material, wear, coverage) use this and ignore the falloff: painting a texel is
## either done or not.
func brush_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var radius := brush_size - 1
	var limit := float(radius) + 0.5
	var limit_squared := limit * limit
	for offset_z in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			if brush_shape == Shape.CIRCLE and float(offset_x * offset_x + offset_z * offset_z) > limit_squared:
				continue
			var cell := center + Vector2i(offset_x, offset_z)
			if _pick_grid != null and _pick_grid.is_inside(cell):
				cells.append(cell)
	return cells


## The same footprint with each cell's weight in [0, 1], parallel to
## `brush_cells`. Height brushes multiply the step they ask for by it, so one
## stroke can raise a rounded mound instead of a flat-topped block the cascade
## then has to skirt on all four sides.
func brush_weights(center: Vector2i) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	if brush_falloff == Falloff.CONSTANT:
		weights.resize(brush_cells(center).size())
		weights.fill(1.0)
		return weights
	var radius := brush_size - 1
	if radius <= 0:
		weights.append(1.0)
		return weights
	var limit := float(radius) + 0.5
	var limit_squared := limit * limit
	for offset_z in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var distance_squared := float(offset_x * offset_x + offset_z * offset_z)
			if brush_shape == Shape.CIRCLE and distance_squared > limit_squared:
				continue
			var cell := center + Vector2i(offset_x, offset_z)
			if _pick_grid == null or not _pick_grid.is_inside(cell):
				continue
			weights.append(_falloff_at(sqrt(distance_squared) / limit))
	return weights


## `normalised` is 0 at the centre and 1 at the rim.
func _falloff_at(normalised: float) -> float:
	var edge := clampf(1.0 - normalised, 0.0, 1.0)
	match brush_falloff:
		Falloff.LINEAR:
			return edge
		Falloff.SMOOTH:
			return edge * edge * (3.0 - 2.0 * edge)
	return 1.0


func adjust_brush_size(delta: int) -> void:
	brush_size = clampi(brush_size + delta, 1, MAX_BRUSH_SIZE)


func cycle_brush_shape() -> void:
	brush_shape = ((brush_shape + 1) % Shape.size()) as Shape


func cycle_brush_falloff() -> void:
	brush_falloff = ((brush_falloff + 1) % Falloff.size()) as Falloff


func brush_shape_name() -> String:
	return "круг" if brush_shape == Shape.CIRCLE else "квадрат"


func brush_falloff_name() -> String:
	match brush_falloff:
		Falloff.LINEAR:
			return "линейный"
		Falloff.SMOOTH:
			return "плавный"
	return "ровный"
