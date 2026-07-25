class_name TerrainEditOperation
extends RefCounted

## One request to change terrain heights (design_docs/core/grid_terrain_system.md §4.1).
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


static func offset(brush_cells: Array[Vector2i], delta: int, mode: int = Mode.SCULPT) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = mode
	operation.cells = brush_cells.duplicate()
	operation.height_delta = delta
	return operation


static func level(brush_cells: Array[Vector2i], height: int) -> TerrainEditOperation:
	var operation := TerrainEditOperation.new()
	operation.mode = Mode.LEVEL
	operation.cells = brush_cells.duplicate()
	operation.target_height = height
	return operation


static func mode_name(mode: int) -> String:
	match mode:
		Mode.SCULPT: return "sculpt"
		Mode.TERRACE: return "terrace"
		Mode.LEVEL: return "level"
	return "unknown"
