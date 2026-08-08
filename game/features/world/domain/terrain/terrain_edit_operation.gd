class_name TerrainEditOperation
extends RefCounted

## One request to change terrain heights (design_docs/engine/grid_terrain_system.md §4.1).
##
## The tool decides the mode; the mode decides whether the surrounding ground
## slumps. A player has to be able to build both a natural hill and a sheer
## terrace, so the cascade is a property of the tool, not a law of the world.

enum Mode {
	## Cascade on: raising a column drags its surroundings into a natural slope.
	SCULPT,
	## Cascade off: the edge stays vertical and needs an auto-rock face or a
	## retaining wall.
	TERRACE,
	## Cascade on, but the brush is levelled to one height instead of offset.
	LEVEL,
	## Placement merge (`building_placement.md` §4.3): every cell gets its OWN
	## absolute height, taken from a blueprint's `Terrain Base`, and the cells the
	## blueprint declares as openings are cut out instead of levelled. The pad is
	## then held still while the cascade and the auto-skirt work on the ground
	## around it — a building's floor is authored, and a wave that reshaped it
	## would deliver a different building from the one in the blueprint.
	PLACEMENT,
}

var mode: int = Mode.SCULPT
var cells: Array[Vector2i] = []
## SCULPT / TERRACE: steps to add to every brush cell.
var height_delta: int = 0
## LEVEL: absolute height every brush cell is brought to.
var target_height: int = 0
## Per-cell strength in [0, 1], parallel to `cells`; empty means every cell pulls
## its full weight, which is what a flat pad needs. The solver ROUNDS the scaled
## step, so a weighted brush still writes whole columns — §2.1 has no fractional
## height to write, and a falloff that produced one would be inventing data the
## save format cannot hold.
var weights := PackedFloat32Array()
## PLACEMENT: the absolute height of every cell, parallel to `cells`.
var target_heights := PackedInt32Array()
## PLACEMENT: cells carved out rather than levelled. They are not in `cells` —
## a hole has no height to level to.
var hole_cells: Array[Vector2i] = []
## AUTO keeps the material's natural angle of repose. A ramp class forces the
## cascade to spend exactly that profile's footprint, after which SlopeAssigner
## writes chains of the same class. TERRACE mode ignores this field.
var slope_class := RampConnectionPlan.AUTO_CLASS


static func offset(
	brush_cells: Array[Vector2i], delta: int, mode: int = Mode.SCULPT,
	p_slope_class: int = RampConnectionPlan.AUTO_CLASS,
	p_weights := PackedFloat32Array(),
) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = mode
	operation.cells = brush_cells.duplicate()
	operation.height_delta = delta
	operation.slope_class = p_slope_class
	operation.weights = p_weights
	return operation


static func level(
	brush_cells: Array[Vector2i], height: int,
	p_slope_class: int = RampConnectionPlan.AUTO_CLASS,
	p_weights := PackedFloat32Array(),
) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = Mode.LEVEL
	operation.cells = brush_cells.duplicate()
	operation.target_height = height
	operation.slope_class = p_slope_class
	operation.weights = p_weights
	return operation


## One pad of a building: per-cell heights plus the cells its blueprint leaves
## open. `cells` and `heights` are parallel and must be the same length.
static func placement(
	pad_cells: Array[Vector2i], heights: PackedInt32Array, cut_out: Array[Vector2i] = [],
) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = Mode.PLACEMENT
	operation.cells = pad_cells.duplicate()
	operation.target_heights = heights.duplicate()
	operation.hole_cells = cut_out.duplicate()
	return operation


## The absolute height cell `index` is brought to in PLACEMENT mode.
func target_height_at(index: int) -> int:
	if index < 0 or index >= target_heights.size():
		return target_height
	return target_heights[index]


## The strength of the cell at `index`, 1 when the operation carries no weights.
func weight_at(index: int) -> float:
	if index < 0 or index >= weights.size():
		return 1.0
	return clampf(weights[index], 0.0, 1.0)


static func mode_name(mode: int) -> String:
	match mode:
		Mode.SCULPT: return "sculpt"
		Mode.TERRACE: return "terrace"
		Mode.LEVEL: return "level"
		Mode.PLACEMENT: return "placement"
	return "unknown"
