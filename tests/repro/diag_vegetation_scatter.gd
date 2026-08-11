extends SceneTree

## Сколько и чего ставит слой 4 на каждом встроенном рецепте
## (`procedural_map_generation.md` §11.4, `VegetationScatter`).
##
## Печатает и не проверяет: «хороший ли это лес» — вопрос вкуса и вида на экране,
## а числа здесь нужны, чтобы заметить обратное — пустой биом, задавленное
## интервалом правило или стадию, которая вдруг стала стоить секунды.
##
## Читается так: `placed` — сколько объектов встало, `policy` — сколько раз
## политика размещения архетипа отказала (нормально: таблица просит хвою и на
## равнине тоже), `spacing` — сколько съел минимальный интервал.


func _init() -> void:
	for entry: Dictionary in MapRecipeLibrary.list():
		if not bool(entry.get("builtin", false)):
			continue
		_report(String(entry["path"]))
	quit(0)


func _report(path: String) -> void:
	var recipe := MapRecipeLibrary.load_for_board(path, 96)
	if not recipe.errors.is_empty():
		print("%s: рецепт отклонён — %s" % [path.get_file(), ", ".join(recipe.errors)])
		return
	var document := MapDocument.create(&"diag", "diag", 96)
	document.terrain.configure(1.0, 96)
	document.water.configure(1.0, 96)

	var terrain_service := TerrainService.new()
	terrain_service.configure(document.terrain)
	var water_service := WaterService.new()
	water_service.configure(document.water, document.terrain)
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	publisher.configure(document.terrain, nav, terrain_service, document.water, water_service)
	var generation := TerrainGenerationService.new()
	generation.configure(
		document.terrain, document.water, terrain_service, water_service, publisher, nav)
	var service := MapGenerationService.new()
	service.configure(generation)

	var result := service.generate_into(document, recipe, 7)
	var metrics: Dictionary = result.report.metrics if result.report != null else {}
	var counts: Dictionary = {}
	for record: MapScatterLayer.Record in document.scatter.records:
		var archetype_id := document.scatter.archetype_of(record)
		counts[archetype_id] = int(counts.get(archetype_id, 0)) + 1
	var names: Array = counts.keys()
	names.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	var top: Array[String] = []
	for name in names.slice(0, 6):
		top.append("%s×%d" % [String(name).replace("core:", ""), counts[name]])

	print("%s: placed=%d за %d мс, spacing=%d, climate=%d, байт=%d"
		% [path.get_file(), int(metrics.get("scatter_placed", 0)),
			int(metrics.get("scatter_milliseconds", 0)),
			int(metrics.get("scatter_refused_spacing", 0)),
			int(metrics.get("scatter_refused_climate", 0)),
			MapScatterCodec.encode(document.scatter).size()])
	print("    ", ", ".join(top))
