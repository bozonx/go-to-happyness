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
	var package := MapDocumentService.package_path(
		MapDocumentService.SOURCE_BUILTIN, &"green_valley",
	)

	# Preserve authored entities, anchors, rules and future opaque sections when
	# refreshing the built-in terrain. Recreating the document here used to erase
	# everything that was not hard-coded in this maintenance script.
	var valley := service.load_package(package)
	if valley == null:
		valley = MapDocument.create(&"green_valley", "Зелёная долина", 96)
	valley.meta.author = "Go To Happyness"
	valley.meta.start.game_definition = &"core:settlement"
	valley.meta.start.day_of_year = 120
	valley.meta.start.latitude = 54.0
	valley.meta.start.time_of_day = MapStart.DEFAULT_TIME_OF_DAY
	_author_green_valley_terrain(valley.terrain)
	_author_green_valley_pond_basin(valley.terrain)
	if valley.water.body_count() == 0:
		_author_green_valley_water(valley.terrain, valley.water)

	var path := service.save_map_to(valley, package)
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


func _author_green_valley_pond_basin(terrain: TerrainGrid) -> void:
	# A small fresh-water pond near the settlement centre so citizens have
	# somewhere to draw water. Dig a shallow basin with a deeper middle:
	# the rim is one step deep (a ford), the centre is four steps / 2 m deep,
	# beyond the 1.5 m walking limit.
	var pond_centre := Vector2i(10, -7)
	var pond_radius := 3
	for z in range(pond_centre.y - pond_radius, pond_centre.y + pond_radius + 1):
		for x in range(pond_centre.x - pond_radius, pond_centre.x + pond_radius + 1):
			var cell := Vector2i(x, z)
			if not terrain.is_inside(cell):
				continue
			var dx := cell.x - pond_centre.x
			var dz := cell.y - pond_centre.y
			var dist_sq := dx * dx + dz * dz
			if dist_sq <= 1:
				terrain.set_height(cell, -4)
			elif dist_sq <= pond_radius * pond_radius:
				terrain.set_height(cell, -1)


func _author_green_valley_water(terrain: TerrainGrid, water: WaterGrid) -> void:
	var pond_centre := Vector2i(10, -7)
	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	if lake == null:
		return
	var flooded := water.flood_cells(terrain, pond_centre, 0, lake.id)
	for cell: Vector2i in flooded:
		water.set_cell(cell, lake.id, 0)
