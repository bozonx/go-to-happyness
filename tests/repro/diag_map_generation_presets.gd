extends SceneTree

## Runs every laboratory preset over a few seeds and prints the §6 verdict
## (design_docs/engine/procedural_map_generation.md §7.1).
##
## This is the regression set of the presets without a display attached: the
## `--capture` run of the laboratory produces the same numbers plus the images,
## but needs a window. Print-only, so it lives in `tests/repro`.

const SEEDS: Array[int] = [1, 2, 3]


func _init() -> void:
	var directory := DirAccess.open("res://tools/map_gen_lab/presets")
	if directory == null:
		print("no presets directory")
		quit(1)
		return
	var names := directory.get_files()
	names.sort()
	for name: String in names:
		if not name.ends_with(".gdmapgen.json"):
			continue
		var recipe := MapRecipe.from_json_path("res://tools/map_gen_lab/presets/%s" % name)
		if not recipe.is_valid():
			print("%-28s REFUSED: %s" % [name, "; ".join(recipe.errors)])
			continue
		for seed_value: int in SEEDS:
			_run(name, recipe, seed_value)
	quit(0)


func _run(name: String, recipe: MapRecipe, seed_value: int) -> void:
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

	var started := Time.get_ticks_msec()
	var result := service.generate(recipe, seed_value)
	var report := result.report
	print("%-28s seed %d  %-8s %6d ms  attempts %d" % [
		name, seed_value, report.verdict(), Time.get_ticks_msec() - started, result.attempts.size(),
	])
	for line: String in report.metric_lines(recipe):
		print("      ", line)
	for failure: String in report.failures:
		print("      ! ", failure)
	print("      timings: ", "  ".join(report.timing_lines()))
