extends SceneTree

## Cross-sections through a `mountain_wall` rim
## (design_docs/engine/procedural_map_generation.md §3.2).
##
## The two things §3.2 promises are hard to see in an aggregate: that the edge of
## the board is a mountainside with a ragged foot, and that somewhere inside it
## there is a contour nothing walks up. Both are obvious in a profile, so this
## prints profiles — a few slices inland from one side, with the height of every
## column, the contours marked and the risers measured.

const PRESET := "res://tools/map_gen_lab/presets/mountain_basin.gdmapgen.json"
const SLICES := 6
const DEPTH := 26


func _init() -> void:
	var recipe := MapRecipe.from_json_path(PRESET)
	if not recipe.is_valid():
		print("refused: ", "; ".join(recipe.errors))
		quit(1)
		return
	var grid := TerrainGrid.new()
	var water := WaterGrid.new()
	var terrain_service := TerrainService.new()
	var water_service := WaterService.new()
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	var service := TerrainGenerationService.new()
	grid.configure(1.0, recipe.board_size)
	water.configure(1.0, recipe.board_size)
	terrain_service.configure(grid)
	water_service.configure(water, grid)
	nav.configure(1.0, recipe.board_size)
	publisher.configure(grid, nav, terrain_service, water, water_service)
	service.configure(grid, water, terrain_service, water_service, publisher, nav)

	var result := service.generate(recipe, 1)
	var context := result.context
	print("verdict: ", result.report.verdict())
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var step := (high - low) / (SLICES + 1)
	print("\nprofiles from the WEST edge inwards (outer→inner), one row per slice")
	print("  height, then '|' on a seal contour and '.' on ordinary rim ground\n")
	for slice in range(1, SLICES + 1):
		var z := low + slice * step
		var row := PackedStringArray()
		for depth in DEPTH:
			var x := low + depth
			var index := context.index_of(x, z)
			var mark := " "
			if context.border_seal[index] != 0:
				mark = "|"
			elif context.border_locked[index] != 0:
				mark = ":"
			elif context.border_rim[index] != 0:
				mark = "."
			row.append("%2d%s" % [context.heights[index], mark])
		print("z=%4d  %s" % [z, " ".join(row)])

	print("\nwhat a walker meets crossing each contour, over the whole board:")
	_report_risers(context, nav, grid)
	print("\nrim walkable %.3f · ragged edge %.1f cells · walls sealed %s" % [
		result.report.metrics["rim_walkable"], result.report.metrics["rim_edge_spread"],
		result.report.metrics["walls_sealed"],
	])
	quit(0)


## Every boundary from inside the map onto the first contour, as a histogram of
## drops. Anything under `MIN_SEAL_RISER` in the first column is a step somebody
## can walk up, which is the failure this whole design has to not have.
func _report_risers(context: GenerationContext, nav: NavGrid, grid: TerrainGrid) -> void:
	var histogram: Dictionary = {}
	var passable := 0
	for index in context.cell_count:
		if context.border_outer[index] == 0:
			continue
		var cell := context.cell_of_index(index)
		for offset: Vector2i in BorderShaper.NEIGHBOURS_8:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			var neighbour_index := context.cell_index(neighbour)
			if context.border_outer[neighbour_index] != 0 or context.is_land[neighbour_index] == 0:
				continue
			var drop := grid.height_of(cell) - grid.height_of(neighbour)
			histogram[drop] = int(histogram.get(drop, 0)) + 1
			var planned := context.heights[index] - context.heights[neighbour_index]
			if planned < MapRecipe.MIN_SEAL_RISER:
				print("   ! the pipeline itself left %s a drop of %d" % [cell, planned])
			elif drop < MapRecipe.MIN_SEAL_RISER:
				print("   ! %s planned %d and the grid has %d" % [cell, planned, drop])
			if nav.is_walkable(cell, &"pedestrian") and nav.is_edge_passable(neighbour, cell, &"pedestrian"):
				passable += 1
	var drops: Array = histogram.keys()
	drops.sort()
	for drop: int in drops:
		print("   drop %+3d : %d boundaries" % [drop, histogram[drop]])
	print("   %d of them are edges navigation lets a pedestrian cross" % passable)
