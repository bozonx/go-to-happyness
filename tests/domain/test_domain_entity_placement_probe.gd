class_name TestDomainEntityPlacementProbe
extends RefCounted

## Правила размещения как один владелец (`map_fill_mode.md` §3.3, §9.3).
##
## Проверяется не «красиво ли стоит дерево», а то, ради чего правила уехали из
## редактора в домен: один и тот же вопрос о клетке даёт один и тот же ответ, кто
## бы его ни задал — рука автора, кисть-разброс или стадия генератора. И то, что
## отказ и предупреждение остались разными вещами: вне доски — нельзя, на лаве —
## можно, но с оговоркой.

const BOARD := 16


static func run_all() -> void:
	_test_surface_kind_reads_the_water_layer()
	_test_only_geometry_refuses_a_place()
	_test_policy_warnings_come_from_the_grids()
	_test_mass_placement_reads_warnings_as_rejection()
	_test_stored_height_is_relative_to_the_ground()
	print("    [PASS] Entity Placement Probe Tests")


static func _terrain() -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD)
	return terrain


static func _water() -> WaterGrid:
	var water := WaterGrid.new()
	water.configure(1.0, BOARD)
	return water


## Копает бассейн и наливает в него воду до уровня `level`.
static func _dig_lake(terrain: TerrainGrid, water: WaterGrid, cells: Array, depth: int, level := 0) -> WaterBody:
	var body := water.create_body(WaterBody.Type.LAKE, level)
	water.add_body(body)
	for cell: Vector2i in cells:
		assert(terrain.set_height(cell, -depth))
		assert(water.set_cell(cell, body.id, level))
	return body


static func _test_surface_kind_reads_the_water_layer() -> void:
	var terrain := _terrain()
	var water := _water()
	# Отрицательные клетки намеренно: доска центрирована на начале координат, и
	# фикстура целиком к востоку от origin не проверяет ничего.
	var shallow := Vector2i(-4, -4)
	var deep := Vector2i(-6, -6)
	_dig_lake(terrain, water, [shallow], 1)
	_dig_lake(terrain, water, [deep], WaterGrid.FORD_MAX_DEPTH_STEPS + 3)

	assert(EntityPlacementProbe.surface_kind(terrain, water, Vector2i(2, 2))
		== AssetPlacementPolicy.SURFACE_GROUND)
	assert(EntityPlacementProbe.surface_kind(terrain, water, shallow)
		== AssetPlacementPolicy.SURFACE_SHALLOW, "брод — это мелководье, а не вода")
	assert(EntityPlacementProbe.surface_kind(terrain, water, deep)
		== AssetPlacementPolicy.SURFACE_WATER)

	# Лёд — состояние водоёма, а не отдельный слой: замёрзшая та же клетка меняет
	# поверхность, не трогая ни землю, ни глубину.
	assert(water.set_frozen(shallow, true))
	assert(EntityPlacementProbe.surface_kind(terrain, water, shallow)
		== AssetPlacementPolicy.SURFACE_ICE)

	# Карта без воды вообще — обычный случай, а не особый.
	assert(EntityPlacementProbe.surface_kind(terrain, null, Vector2i(0, 0))
		== AssetPlacementPolicy.SURFACE_GROUND)


static func _test_only_geometry_refuses_a_place() -> void:
	var terrain := _terrain()
	assert(EntityPlacementProbe.is_placeable(terrain, Vector2i(-8, -8)),
		"клетка на краю доски существует")
	assert(not EntityPlacementProbe.is_placeable(terrain, Vector2i(-9, 0)),
		"за доской ставить нечего")
	assert(terrain.set_hole(Vector2i(1, 1), true))
	assert(not EntityPlacementProbe.is_placeable(terrain, Vector2i(1, 1)),
		"в вырезе нет поверхности")
	# След 2×2, зацепивший вырез углом, непригоден целиком — иначе объект стоял бы
	# на трёх клетках из четырёх.
	assert(not EntityPlacementProbe.are_cells_placeable(terrain, Rect2i(0, 0, 2, 2)))
	assert(EntityPlacementProbe.are_cells_placeable(terrain, Rect2i(-4, -4, 2, 2)))


static func _test_policy_warnings_come_from_the_grids() -> void:
	var terrain := _terrain()
	var water := _water()
	var reeds := AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_SHALLOW] as Array[StringName],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_ALLOW)

	# На сухой земле камыш неуместен, и это говорит политика, а не редактор.
	assert(not EntityPlacementProbe.warnings_at(reeds, terrain, water, Vector2i(-2, -2)).is_empty())
	_dig_lake(terrain, water, [Vector2i(-2, -2)], 1)
	assert(EntityPlacementProbe.warnings_at(reeds, terrain, water, Vector2i(-2, -2)).is_empty(),
		"на мелководье камыш — ровно то, чего политика хочет")

	# Уклон в фактах — это уклон, который сообщает земля, а не число из политики.
	var flat_only := AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND] as Array[StringName], SlopeCatalog.CLASS_FLAT)
	var probed := EntityPlacementProbe.facts_at(terrain, water, Vector2i(3, 3))
	assert(int(probed["slope_class"]) == terrain.slope_class_at(Vector2i(3, 3)),
		"уклон обязан приходить из TerrainGrid, а не выдумываться пробой")

	# Одинаковое нарушение по всему следу перечисляется один раз, а не по клетке:
	# «объект под водой» четыре раза подряд — это не четыре проблемы.
	var lake_cells: Array = []
	for x in range(-3, -1):
		for z in range(-3, -1):
			lake_cells.append(Vector2i(x, z))
	_dig_lake(terrain, water, lake_cells, 3)
	var footprint := EntityPlacementProbe.warnings_for_cells(
		flat_only, terrain, water, Rect2i(-3, -3, 2, 2))
	# Нарушений здесь два — поверхность и погружение, — но каждое названо один
	# раз, а не по разу на клетку.
	assert(footprint.size() == 2,
		"предупреждения следа обязаны быть уникальными: %s" % [footprint])


static func _test_mass_placement_reads_warnings_as_rejection() -> void:
	var terrain := _terrain()
	var water := _water()
	var dry_land := AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND] as Array[StringName])
	var lake_cell := Vector2i(-5, -5)
	_dig_lake(terrain, water, [lake_cell], 2)

	# Автору вода под ёлкой — жёлтый призрак и его решение; массовой постановке
	# то же самое обязано быть отказом, иначе генератор засадит озеро лесом.
	assert(not EntityPlacementProbe.warnings_at(dry_land, terrain, water, lake_cell).is_empty())
	assert(not EntityPlacementProbe.accepts_cells(
		dry_land, terrain, water, Rect2i(lake_cell, Vector2i.ONE)))
	assert(EntityPlacementProbe.accepts_cells(
		dry_land, terrain, water, Rect2i(Vector2i(2, 2), Vector2i.ONE)))
	# Вне доски — тоже отказ, и по другой причине: там нет клетки.
	assert(not EntityPlacementProbe.accepts_cells(
		dry_land, terrain, water, Rect2i(Vector2i(BOARD, 0), Vector2i.ONE)))


static func _test_stored_height_is_relative_to_the_ground() -> void:
	var terrain := _terrain()
	var water := _water()
	var boat := AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_WATER] as Array[StringName],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_ALLOW)
	var cell := Vector2i(-6, -6)
	_dig_lake(terrain, water, [cell], 4)

	var centre := terrain.cell_center(cell)
	centre.y = 0.0
	var offset := EntityPlacementProbe.surface_offset(boat, terrain, water, cell, centre)
	# Хранится смещение ОТ ЗЕМЛИ: дно на четыре ступени ниже уровня воды, значит
	# лодка стоит на столько же выше дна. Мировой Y запись не хранит вовсе —
	# иначе правка рельефа оставляла бы объект висеть.
	assert(offset > 0.0, "лодка обязана оказаться над дном, а не на нём: %f" % offset)
	assert(is_equal_approx(terrain.height_at(centre) + offset, water.surface_metres_at(cell)),
		"земля плюс смещение обязаны дать ровно поверхность воды")

	# `vertical_offset` политики прибавляется поверх, а не заменяет собой высоту.
	boat.vertical_offset = 0.5
	var lifted := EntityPlacementProbe.surface_offset(boat, terrain, water, cell, centre)
	assert(is_equal_approx(lifted, offset + 0.5))
