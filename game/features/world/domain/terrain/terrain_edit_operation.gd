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
}

var mode: int = Mode.SCULPT
var cells: Array[Vector2i] = []
## SCULPT / TERRACE: steps to add to every brush cell.
var height_delta: int = 0
## LEVEL: absolute height every brush cell is brought to.
var target_height: int = 0
## AUTO keeps the material's natural angle of repose. A ramp class forces the
## cascade to spend exactly that profile's footprint, after which SlopeAssigner
## writes chains of the same class. TERRACE mode ignores this field.
var slope_class := RampConnectionPlan.AUTO_CLASS


static func offset(
	brush_cells: Array[Vector2i], delta: int, mode: int = Mode.SCULPT,
	p_slope_class: int = RampConnectionPlan.AUTO_CLASS,
) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = mode
	operation.cells = brush_cells.duplicate()
	operation.height_delta = delta
	operation.slope_class = p_slope_class
	return operation


static func level(
	brush_cells: Array[Vector2i], height: int,
	p_slope_class: int = RampConnectionPlan.AUTO_CLASS,
) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = Mode.LEVEL
	operation.cells = brush_cells.duplicate()
	operation.target_height = height
	operation.slope_class = p_slope_class
	return operation


static func mode_name(mode: int) -> String:
	match mode:
		Mode.SCULPT: return "sculpt"
		Mode.TERRACE: return "terrace"
		Mode.LEVEL: return "level"
	return "unknown"
