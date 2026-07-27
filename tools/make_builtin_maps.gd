extends SceneTree

## Writes the built-in map packages into `res://game/content/core/maps/`.
##
## Run it when a shipped map has to be regenerated:
##   godot --headless --path . --script res://tools/make_builtin_maps.gd
##
## `green_valley` is the default playable territory: a buildable central valley
## with authored terraces around its edge. It exercises the same terrain package
## path as a map saved from the editor.


func _init() -> void:
	var service := MapDocumentService.new()

	var valley := MapDocument.create(&"green_valley", "Зелёная долина", 96)
	valley.meta.author = "Go To Happyness"
	valley.meta.start.era = &"tent"
	valley.meta.start.day_of_year = 120
	valley.meta.start.latitude = 54.0
	valley.meta.start.time_of_day = MapStart.DEFAULT_TIME_OF_DAY
	valley.meta.start.mode_id = MapStart.MODE_SETTLEMENT
	_author_green_valley_terrain(valley.terrain)

	var path := service.save_map_to(valley, MapDocumentService.package_path(
		MapDocumentService.SOURCE_BUILTIN, valley.meta.id,
	))
	if path.is_empty():
		printerr("[maps] не записано: ", service.last_error)
		quit(1)
		return
	print("[maps] записано ", path)
	quit(0)


func _author_green_valley_terrain(terrain: TerrainGrid) -> void:
	# Keep the settlement's centre flat and buildable. The terraces sit at the
	# perimeter, so they are visible from the first camera position while leaving
	# room for the current start content and navigation smoke tests.
	var minimum := terrain.min_cell()
	var maximum := terrain.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			var edge_distance := mini(
				mini(cell.x - minimum.x, maximum.x - cell.x),
				mini(cell.y - minimum.y, maximum.y - cell.y),
			)
			if edge_distance < 5:
				terrain.set_height(cell, 3)
			elif edge_distance < 9:
				terrain.set_height(cell, 2)
			elif edge_distance < 13:
				terrain.set_height(cell, 1)
