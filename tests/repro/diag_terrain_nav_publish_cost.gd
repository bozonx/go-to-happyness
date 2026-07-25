extends SceneTree

## Measures what publishing terrain into navigation actually costs. Two questions
## are being asked at once:
##
## 1. Can a terrain brush republish on every stroke, or only on release? That is
##    the incremental `refresh_cells` number, and it is what makes the editor
##    usable at all.
## 2. What does a map cost to *load*? Full publication is paid once when a map
##    opens, and it grows linearly with cell count. `map_editor.md` §6.2 sizes the
##    board presets off exactly this number and marks 512×512 experimental until
##    publication goes lazy (§17.6).
##
## Run it after touching the publisher or `NavGrid`'s hot paths.

## The board presets of `map_editor.md` §6.2, plus the 96 the settlement still
## hardcodes, so the numbers stay comparable with the earlier measurement.
const BOARDS: Array[int] = [96, 128, 256, 512]

## Only the smallest board pays for the incremental sample: a brush stroke costs
## the same everywhere, which is the point being made.
const STROKE_BOARD := 96
const STROKE_RADII: Array[int] = [1, 4, 16]


func _init() -> void:
	for cells: int in BOARDS:
		_measure_board(cells)
	quit(0)


func _measure_board(board_cells: int) -> void:
	var terrain := _hilly_board(board_cells)
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()

	var start := Time.get_ticks_usec()
	publisher.configure(terrain, nav)
	var full_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("board %d×%d (%d cells): full publish %.2f ms  (%.3f µs/cell)" % [
		board_cells, board_cells, board_cells * board_cells, full_ms,
		(full_ms * 1000.0) / float(board_cells * board_cells),
	])

	start = Time.get_ticks_usec()
	nav.refresh_connectivity()
	print("    connectivity flood fill: %.2f ms" % ((Time.get_ticks_usec() - start) / 1000.0))

	if board_cells != STROKE_BOARD:
		return
	# A brush stroke: one cell edited, plus whatever the cascade dragged with it.
	for radius: int in STROKE_RADII:
		var cells: Array[Vector2i] = []
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				cells.append(Vector2i(x, z))
		start = Time.get_ticks_usec()
		publisher.refresh_cells(cells)
		print("    refresh %d cells: %.2f ms" % [cells.size(), (Time.get_ticks_usec() - start) / 1000.0])


## A hilly board, not a flat one: corner lifts and ramp unrolling are the
## expensive part, and a flat board never pays them. The features are spaced in
## absolute cells so density stays the same as the board grows — otherwise a
## bigger board would look artificially cheap per cell.
func _hilly_board(board_cells: int) -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, board_cells)
	var half := board_cells / 2 - 8
	for z in range(-half, half, 4):
		for x in range(-half, half, 4):
			terrain.set_height(Vector2i(x, z), 2)
			terrain.place_ramp(Vector2i(x - 1, z), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E)
	return terrain
