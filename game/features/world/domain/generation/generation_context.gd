class_name GenerationContext
extends RefCounted

## The buffers one generation run passes from stage to stage
## (procedural_map_generation.md §4).
##
## Nothing here is a Node, a file or a service: a stage is a pure function over
## these `Packed*Array`s, which is what makes the pipeline testable without an
## editor and reproducible without a scene. The context is also the only place
## that knows how a cell maps to an index, so no stage has to repeat the
## board-is-centred-on-the-origin arithmetic that this codebase keeps getting
## wrong.

## Sentinel for "this cell drains nowhere": a sink, a sea cell or the board edge.
const NO_FLOW := 255

var recipe: MapRecipe = null
var seeds: GenerationSeed = null

var board_cells := 0
var half_cells := 0
var cell_count := 0

## Correction the composition solver carries between passes: the land share is a
## property of the FINISHED integer board, and the stages after the threshold —
## the border blend, quantisation, the shelf — each move it by a little. Rather
## than model every one of them, the pipeline measures the result and asks stage 1
## for that much more or less land next time (§5.3).
var land_fraction_bias := 0.0

## Stage 1 — continental composition.
## Signed distance to the coastline in cells: positive inland, negative at sea.
var shore_distance := PackedFloat32Array()
var is_land := PackedByteArray()

## Stage 2 — the continuous relief of the plains, normalised to 0…1.
var relief := PackedFloat32Array()

## Stage 3 — mountain uplift in height steps, and the skeleton that produced it.
var uplift := PackedFloat32Array()
## Each entry: {"position": Vector2, "height": float}
var peaks: Array[Dictionary] = []
## Each entry: PackedVector2Array — the polyline of one range's crest.
var ridges: Array[PackedVector2Array] = []
## Saddles pushed through the crests so a range never seals the map (§3.5).
var passes: Array[Vector2] = []

## Stage 4/5 — the continuous height field in steps, before quantisation.
var height_field := PackedFloat32Array()
## Cells the border stage authored as an impassable wall. Three consumers depend
## on this mask: the repose pass leaves them alone (a wall is a face on purpose,
## not a slope that failed to settle), the pass carver refuses to tunnel through
## them, and the metrics exclude them from the land — a frame around the map is
## not ground the recipe was describing.
var border_locked := PackedByteArray()
## Cells the border stage will drown whatever the composition says. Known before
## stage 1 so the land-fraction solver can count them as sea instead of being
## surprised by them afterwards.
var border_sea := PackedByteArray()

## Stage 6 — the integer heights that become `TerrainGrid`.
var heights := PackedInt32Array()

## Stage 7 — hydrology over the integer heights.
var flow_dir := PackedByteArray()
var flow_accum := PackedFloat32Array()
## Depression-filled surface: the heights water would see once every pit is full.
var filled := PackedInt32Array()
## The order the priority flood settled cells in, ascending by filled height. It
## is a topological order of the drainage tree, which is what lets accumulation
## and river tracing be single passes.
var flow_order := PackedInt32Array()
## Each entry: {"cells": Array[Vector2i], "spill": int, "floor": int, "outlet": Vector2i}
var basins: Array[Dictionary] = []

## Stages 8–9 — what the water stage will author.
## Each entry: {"type": WaterBody.Type, "level": int, "cells": Array[Vector2i],
##              "flow": Dictionary(cell -> Vector2i(direction, strength))}
var water_plan: Array[Dictionary] = []
## cell -> {"bed": int, "sill": bool, "direction": int} for every column a river
## channel occupies.
var river_cells: Dictionary = {}
## How many rivers were traced and how many of them actually reached a receiver —
## sea, lake, another river or the board edge. A river ending on a hillside is a
## generation error, so the ratio is a metric and not a curiosity (§3.6).
var river_stats: Dictionary = {"traced": 0, "terminated": 0}

## Stage 14 — what the ground is made of (`SurfacePainter`). One catalog index and
## one packed detail byte per column, exactly as `TerrainGrid` stores them, so the
## commit copies rather than decides. Material was a single recipe-wide constant
## until this layer existed, which is why every generated map used to be stone.
var materials := PackedByteArray()
var details := PackedByteArray()

## Free-form notes a stage wants the report to carry ("2 passes carved", …).
var notes: Array[String] = []
## stage id -> milliseconds.
var stage_times: Dictionary = {}


func configure(next_recipe: MapRecipe, next_seeds: GenerationSeed) -> void:
	recipe = next_recipe
	seeds = next_seeds
	board_cells = next_recipe.board_size
	half_cells = board_cells / 2
	cell_count = board_cells * board_cells
	shore_distance = _new_floats()
	is_land = _new_bytes()
	relief = _new_floats()
	uplift = _new_floats()
	height_field = _new_floats()
	border_locked = _new_bytes()
	border_sea = _new_bytes()
	heights = _new_ints()
	flow_dir = _new_bytes()
	flow_dir.fill(NO_FLOW)
	flow_accum = _new_floats()
	filled = _new_ints()
	river_stats = {"traced": 0, "terminated": 0}


func _new_floats() -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(cell_count)
	return buffer


func _new_ints() -> PackedInt32Array:
	var buffer := PackedInt32Array()
	buffer.resize(cell_count)
	return buffer


func _new_bytes() -> PackedByteArray:
	var buffer := PackedByteArray()
	buffer.resize(cell_count)
	return buffer


# --- Geometry -----------------------------------------------------------------

func min_coordinate() -> int:
	return -half_cells


func max_coordinate() -> int:
	return board_cells - half_cells - 1


func contains(x: int, z: int) -> bool:
	return x >= -half_cells and x <= board_cells - half_cells - 1 and z >= -half_cells and z <= board_cells - half_cells - 1


func index_of(x: int, z: int) -> int:
	return (z + half_cells) * board_cells + (x + half_cells)


func cell_index(cell: Vector2i) -> int:
	return (cell.y + half_cells) * board_cells + (cell.x + half_cells)


func cell_of_index(index: int) -> Vector2i:
	return Vector2i(index % board_cells - half_cells, index / board_cells - half_cells)


## Board coordinates in −1…1, used by every stage that thinks in composition
## rather than in cells.
func normalised(x: int, z: int) -> Vector2:
	var span := float(board_cells)
	return Vector2(
		(float(x + half_cells) + 0.5) / span * 2.0 - 1.0,
		(float(z + half_cells) + 0.5) / span * 2.0 - 1.0,
	)


func land_cell_count() -> int:
	var total := 0
	for index in cell_count:
		if is_land[index] != 0:
			total += 1
	return total


func note(text: String) -> void:
	notes.append(text)


## Land is "above the sea", and that is a statement about the integer heights.
## Every stage that moves a column calls this afterwards rather than patching the
## mask as it goes: a mask maintained by hand in six places is a mask that is
## wrong in one of them, and every metric downstream counts land from here.
func refresh_land_mask() -> void:
	var level := recipe.ocean_level
	for index in cell_count:
		is_land[index] = 1 if heights[index] > level else 0
