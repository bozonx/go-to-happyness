extends SceneTree

## Массовое наполнение доезжает до экрана (`map_fill_mode.md` §9.4).
##
## «Лес есть в данных» и «лес виден» — разные утверждения, и ровно на этом стыке
## ломается тихо: слой прочитан, записи на месте, а рисовать их некому. Поэтому
## проверяется не формат, а число нарисованных экземпляров.
##
## И цена: тридцать тысяч деревьев нодами — это шестьсот тысяч нод. Здесь их
## столько, сколько пар «чанк × архетип», и тест держит именно это обещание.

const BOARD := 64


func _init() -> void:
	print("--- Running test_scatter_world.gd ---")
	_test_baking_flattens_a_scene_into_one_mesh()
	_test_records_become_instances_in_chunks()
	_test_a_touched_chunk_rebuilds_alone()
	_test_asset_vertical_offset_reaches_the_instance()
	_test_missing_content_does_not_take_the_map_down()
	print("--- test_scatter_world.gd PASSED ---")
	quit(0)


func _terrain() -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(2.0, BOARD)
	return terrain


## Ставит `count` деревьев подряд, начиная с юго-западного угла доски.
func _layer_with(count: int, archetype_id := &"core:tree") -> MapScatterLayer:
	var layer := MapScatterLayer.new()
	var index := layer.archetype_index_of(archetype_id)
	for step in count:
		var record := MapScatterLayer.Record.new()
		record.archetype_index = index
		# Клетки центрированы на начале координат — фикстура обязана начинаться
		# западнее origin, иначе половина проверок ничего не проверяет.
		record.cell = Vector2i(step % BOARD - BOARD / 2, step / BOARD - BOARD / 2)
		record.yaw_degrees = float(step % 360)
		record.variant = step % 256
		layer.add(record)
	return layer


func _test_baking_flattens_a_scene_into_one_mesh() -> void:
	ScatterMeshBaker.clear_cache()
	var asset := WorldAssetCatalog.get_asset(&"tree")
	assert(asset != null)
	var baked := ScatterMeshBaker.bake(asset)
	assert(baked != null and baked.mesh != null, "дерево должно выпекаться в меш")
	# Ствол и крона — разные материалы, значит разные поверхности одного меша.
	# Сплавить их в одну поверхность значило бы потерять шейдер качания.
	assert(baked.mesh.get_surface_count() >= 2,
		"материалы обязаны пережить сплавление: поверхностей %d" % baked.mesh.get_surface_count())
	assert(baked.has_instance_colour(),
		"у дерева объявлен варьирующийся цвет кроны — он должен ехать цветом экземпляра")
	# Кэш: тот же ассет не выпекается дважды, иначе тысяча деревьев — это тысяча
	# инстансирований сцены.
	assert(ScatterMeshBaker.bake(asset) == baked, "выпечка обязана кэшироваться")


func _test_records_become_instances_in_chunks() -> void:
	var terrain := _terrain()
	var layer := _layer_with(500)
	var world := ScatterWorld.new()
	world.configure(layer, terrain)

	assert(world.instance_count() == 500,
		"нарисовано %d из 500 записей" % world.instance_count())
	# Нарезка не украшение: один буфер на весь лес не отсекается камерой никогда
	# и перестраивается целиком после любого мазка.
	assert(world.chunk_count() > 1, "лес обязан быть нарезан чанками: %d" % world.chunk_count())
	# И это по-прежнему единицы нод, а не сотни тысяч.
	assert(world.get_child_count() <= world.chunk_count() * 2,
		"нод должно быть по числу пар «чанк × архетип», а не по числу деревьев: %d"
			% world.get_child_count())

	# Надгробие не рисуется: удалённое дерево исчезает с экрана, а не остаётся
	# стоять до следующего открытия карты.
	assert(layer.remove_at(0))
	world.rebuild_all()
	assert(world.instance_count() == 499)
	world.free()


func _test_a_touched_chunk_rebuilds_alone() -> void:
	var terrain := _terrain()
	var layer := _layer_with(300)
	var world := ScatterWorld.new()
	world.configure(layer, terrain)
	var before := world.instance_count()

	var chunk := terrain.chunk_of(layer.records[0].cell)
	assert(layer.remove_at(0))
	world.refresh_chunks([chunk])
	assert(world.instance_count() == before - 1,
		"перестройка одного чанка обязана убрать ровно одну запись")

	# Чанк, которого правка не коснулась, не трогается вовсе — ради этого
	# нарезка и заведена.
	var untouched := layer.records[layer.records.size() - 1].cell
	world.refresh_chunks([terrain.chunk_of(untouched)])
	assert(world.instance_count() == before - 1)
	world.free()


func _test_asset_vertical_offset_reaches_the_instance() -> void:
	var terrain := _terrain()
	var layer := _layer_with(1)
	# Ensure the pack catalog is loaded before mutating the shared asset fixture;
	# its first load may rebuild the content index and therefore the asset cache.
	assert(EntityArchetypeCatalog.get_archetype(&"core:tree") != null)
	var asset := WorldAssetCatalog.get_asset(&"tree")
	var previous := asset.placement.vertical_offset
	asset.placement.vertical_offset = 1.25
	assert(EntityArchetypeCatalog.asset_of(&"core:tree") == asset)
	assert(is_equal_approx(EntityPlacementProbe.surface_offset(
		asset.placement, terrain, null, layer.records[0].cell, Vector3.ZERO), 1.25))
	var world := ScatterWorld.new()
	world.configure(layer, terrain)
	var transform := world.transform_of(layer.records[0])
	assert(is_equal_approx(transform.origin.y, 1.25),
		"vertical_offset потерян в scatter transform: %f" % transform.origin.y)
	asset.placement.vertical_offset = previous
	world.free()


func _test_missing_content_does_not_take_the_map_down() -> void:
	var terrain := _terrain()
	var layer := _layer_with(10, &"pack.absent:ghost_tree")
	var world := ScatterWorld.new()
	# Карта, уехавшая без пака, обязана открыться (§11): слой с неизвестным
	# архетипом рисует ноль объектов и ничего не роняет.
	world.configure(layer, terrain)
	assert(world.instance_count() == 0)
	assert(world.chunk_count() == 0)

	# И пустой слой — тоже нормальный случай, а не повод для проверки на null у
	# каждого вызывающего.
	world.configure(MapScatterLayer.new(), terrain)
	assert(world.instance_count() == 0)
	world.configure(null, terrain)
	assert(world.instance_count() == 0)
	world.free()
