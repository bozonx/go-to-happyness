extends SceneTree
func _init() -> void:
	var recipe := MapRecipe.from_json_path("res://game/content/mapgen/presets/mountain_basin.gdmapgen.json")
	var grid := TerrainGrid.new(); var water := WaterGrid.new()
	var ts := TerrainService.new(); var ws := WaterService.new()
	var nav := NavGrid.new(); var pub := TerrainNavigationPublisher.new()
	var svc := TerrainGenerationService.new()
	grid.configure(1.0, recipe.board_size); water.configure(1.0, recipe.board_size)
	ts.configure(grid); ws.configure(water, grid); nav.configure(1.0, recipe.board_size)
	pub.configure(grid, nav, ts, water, ws)
	svc.configure(grid, water, ts, ws, pub, nav)
	var result := svc.generate(recipe, 2)
	print("bodies: ", water.body_count(), "  wet cells: ", water.wet_cell_count())
	for id: int in water.body_ids():
		var body := water.body(id)
		print("   id=%d type=%d level=%d cells=%d" % [id, body.type, body.surface_height, water.cells_of_body(id).size()])
	print("height range: ", result.report.metrics["height_min"], " … ", result.report.metrics["height_max"])
	quit(0)
