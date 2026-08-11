extends SceneTree

## Why a generated board is not walkable: the slope-class histogram of the land,
## how many columns navigation refuses, and how big the walkable components are.
## Print-only companion to `diag_map_generation_presets.gd`.

func _init() -> void:
	var recipe := MapRecipe.from_json_path("res://game/content/mapgen/presets/continent_east_ranges.gdmapgen.json")
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
	var result := service.generate(recipe, 2)
	for note: String in result.report.notes:
		print("  note: ", note)
	print("  timings: ", "  ".join(result.report.timing_lines()))

	var stored: Dictionary = {}
	var surface: Dictionary = {}
	var land := 0
	var blocked := 0
	var wet := 0
	var field := nav.terrain_field()
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			if grid.height_of(cell) < recipe.ocean_level:
				continue
			land += 1
			var stored_class := grid.slope_class_at(cell)
			stored[stored_class] = int(stored.get(stored_class, 0)) + 1
			var surface_class := field.slope_class_at(cell)
			surface[surface_class] = int(surface.get(surface_class, 0)) + 1
			if water.is_wet(grid, cell):
				wet += 1
			if not nav.is_walkable(cell, &"pedestrian"):
				blocked += 1
	print("land %d  blocked %d  wet %d" % [land, blocked, wet])
	_components(grid, water, nav, recipe)
	print("stored slope classes:")
	for slope_class: int in stored:
		print("   %-12s %d" % [SlopeCatalog.id_of_class(slope_class), stored[slope_class]])
	print("navigation surface classes:")
	for slope_class: int in surface:
		print("   %-12s %d" % [SlopeCatalog.id_of_class(slope_class), surface[slope_class]])
	quit(0)


func _components(grid: TerrainGrid, water: WaterGrid, nav: NavGrid, recipe: MapRecipe) -> void:
	var walkable: Dictionary = {}
	var blocked_by_water := 0
	var blocked_by_slope := 0
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			if grid.height_of(cell) < recipe.ocean_level:
				continue
			if nav.is_walkable(cell, &"pedestrian"):
				walkable[cell] = true
			elif water.is_wet(grid, cell):
				blocked_by_water += 1
			else:
				blocked_by_slope += 1
	print("blocked by water %d  by slope %d" % [blocked_by_water, blocked_by_slope])
	var seen: Dictionary = {}
	var sizes: Array[int] = []
	for start: Vector2i in walkable:
		if seen.has(start):
			continue
		seen[start] = true
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			for direction in NavTerrainField.DIRECTION_COUNT:
				var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
				if seen.has(neighbour) or not walkable.has(neighbour):
					continue
				if not nav.is_edge_passable(cell, neighbour, &"pedestrian"):
					continue
				seen[neighbour] = true
				queue.append(neighbour)
		sizes.append(queue.size())
	sizes.sort()
	sizes.reverse()
	print("walkable %d in %d components, largest: %s" % [walkable.size(), sizes.size(), str(sizes.slice(0, 12))])
