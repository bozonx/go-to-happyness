extends SceneTree

## Scratch: what actually fails, on every attempt, over a wide seed sweep.
## Prints one line per attempt with its failures so the retry loop stops being
## invisible.

const SEEDS := 10


func _init() -> void:
	var directory := DirAccess.open("res://tools/map_gen_lab/presets")
	var names := directory.get_files()
	names.sort()
	var failure_counts: Dictionary = {}
	var attempt_histogram: Dictionary = {}
	for name: String in names:
		if not name.ends_with(".gdmapgen.json"):
			continue
		var recipe := MapRecipe.from_json_path("res://tools/map_gen_lab/presets/%s" % name)
		for seed_value in range(1, SEEDS + 1):
			var result := _run(recipe, seed_value)
			var verdict := result.report.verdict()
			var attempts := result.attempts.size()
			attempt_histogram[attempts] = int(attempt_histogram.get(attempts, 0)) + 1
			var lines: PackedStringArray = []
			for i in result.attempts.size():
				var report: GenerationReport = result.attempts[i]
				var tags: PackedStringArray = []
				for failure: String in report.failures:
					var tag := failure.split(" ")[0]
					tags.append(tag)
					failure_counts[tag] = int(failure_counts.get(tag, 0)) + 1
				lines.append("#%d[%s]" % [i, ",".join(tags) if tags.size() > 0 else "ok"])
			print("%-30s seed %2d  %-8s  %s" % [name, seed_value, verdict, " ".join(lines)])
			for failure: String in result.report.failures:
				print("        ! ", failure)
	print("\n--- attempts histogram --- ", attempt_histogram)
	print("--- failure tags --- ", failure_counts)
	quit(0)


func _run(recipe: MapRecipe, seed_value: int) -> GenerationResult:
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
	return service.generate(recipe, seed_value)
