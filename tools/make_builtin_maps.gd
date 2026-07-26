extends SceneTree

## Writes the built-in map packages into `res://game/features/world/data/maps/`.
##
## Run it when a shipped map has to be regenerated:
##   godot --headless --path . --script res://tools/make_builtin_maps.gd
##
## `green_valley` deliberately reproduces the board the settlement had before maps
## existed: 96×96 cells, flat, default material. Selecting it must change nothing
## about how the game plays — that is what makes it a safe first map to route the
## whole launch path through. Its terrain layer is therefore not written at all
## (an untouched layer means "flat board of the default material"), so the package
## is three files' worth of nothing but intent.


func _init() -> void:
	var service := MapDocumentService.new()

	var valley := MapDocument.create(&"green_valley", "Зелёная долина", 96)
	valley.meta.author = "Go To Happyness"
	valley.meta.start.era = &"tent"
	valley.meta.start.day_of_year = 120
	valley.meta.start.latitude = 54.0
	valley.meta.start.time_of_day = MapStart.DEFAULT_TIME_OF_DAY
	valley.meta.start.mode_id = MapStart.MODE_SETTLEMENT

	var path := service.save_map_to(valley, MapDocumentService.package_path(
		MapDocumentService.SOURCE_BUILTIN, valley.meta.id,
	))
	if path.is_empty():
		printerr("[maps] не записано: ", service.last_error)
		quit(1)
		return
	print("[maps] записано ", path)
	quit(0)
