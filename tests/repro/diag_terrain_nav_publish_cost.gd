extends SceneTree

## Measures what publishing terrain into navigation actually costs, on the board
## size the settlement uses. The answer decides whether a terrain brush can
## republish on every stroke or only on release.

const BOARD_CELLS := 96


func _init() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	# A hilly board, not a flat one: corner lifts and ramp unrolling are the
	# expensive part, and a flat board never pays them.
	for z in range(-40, 40, 4):
		for x in range(-40, 40, 4):
			terrain.set_height(Vector2i(x, z), 2)
			terrain.place_ramp(Vector2i(x - 1, z), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E)

	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()

	var start := Time.get_ticks_usec()
	publisher.configure(terrain, nav)
	var full_us := Time.get_ticks_usec() - start
	print("full publish (%d cells): %.2f ms" % [BOARD_CELLS * BOARD_CELLS, full_us / 1000.0])

	# A brush stroke: one cell edited, plus whatever the cascade dragged with it.
	for radius in [1, 4, 16]:
		var cells: Array[Vector2i] = []
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				cells.append(Vector2i(x, z))
		start = Time.get_ticks_usec()
		publisher.refresh_cells(cells)
		var patch_us := Time.get_ticks_usec() - start
		print("refresh %d cells: %.2f ms" % [cells.size(), patch_us / 1000.0])

	start = Time.get_ticks_usec()
	nav.refresh_connectivity()
	print("connectivity flood fill: %.2f ms" % ((Time.get_ticks_usec() - start) / 1000.0))

	quit(0)
