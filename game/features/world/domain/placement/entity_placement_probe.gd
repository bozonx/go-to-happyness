class_name EntityPlacementProbe
extends RefCounted

## Что земля и вода отвечают про клетку и как это читает политика размещения
## (`map_fill_mode.md` §3.3, §9.2, §9.3).
##
## Раньше этот перевод — «мокро ли, глубоко ли, круто ли» — жил внутри
## `fill_mode_controller`, то есть в презентации одного редактора. Пока ставили
## по одному объекту руками, это было незаметно. Кисть-разброс и стадия
## растительности генератора спрашивают ровно то же самое, и каждая написала бы
## свою версию: `procedural_map_generation.md` §11.4 прямо требует «настоящую
## `placement`-политику архетипа, без облегчённой копии правил». Копия и есть
## то, что здесь предотвращается.
##
## Всё статическое и без узлов: доска, вода и политика — единственные входы, и
## это позволяет проверять правила размещения без сцены и без редактора.
##
## Граница ответственности: probe отвечает, ЧТО в клетке, и переводит это в
## предупреждения политики. Занятость клеток другими объектами — вопрос
## документа, а не земли, и остаётся у того, кто держит список сущностей.


## Поверхность клетки в терминах `AssetPlacementPolicy`. Пять видов — ровно те,
## что слои умеют различить; шестого («болото», «песок») здесь не будет: это
## материал, а не поверхность.
static func surface_kind(terrain: TerrainGrid, water: WaterGrid, cell: Vector2i) -> StringName:
	if water == null or not water.is_wet(terrain, cell):
		return AssetPlacementPolicy.SURFACE_GROUND
	if water.is_lava(cell):
		return AssetPlacementPolicy.SURFACE_LAVA
	if water.is_frozen(cell):
		return AssetPlacementPolicy.SURFACE_ICE
	if water.depth_steps_at(terrain, cell) <= WaterGrid.FORD_MAX_DEPTH_STEPS:
		return AssetPlacementPolicy.SURFACE_SHALLOW
	return AssetPlacementPolicy.SURFACE_WATER


## Факты о клетке в том виде, в каком их читает `AssetPlacementPolicy.warnings_for`.
static func facts_at(terrain: TerrainGrid, water: WaterGrid, cell: Vector2i) -> Dictionary:
	var submerged := water != null and water.is_wet(terrain, cell) \
		and water.depth_steps_at(terrain, cell) > 0
	return {
		"surface": surface_kind(terrain, water, cell),
		"slope_class": terrain.slope_class_at(cell),
		"submerged": submerged,
	}


## Клетка существует и не вырезана. Это единственный вид отказа: всё остальное —
## предупреждение, потому что автор вправе поставить лодку на лаву (§3.3).
static func is_placeable(terrain: TerrainGrid, cell: Vector2i) -> bool:
	return terrain != null and terrain.is_inside(cell) and not terrain.is_hole(cell)


static func are_cells_placeable(terrain: TerrainGrid, cells: Rect2i) -> bool:
	for x in range(cells.position.x, cells.end.x):
		for z in range(cells.position.y, cells.end.y):
			if not is_placeable(terrain, Vector2i(x, z)):
				return false
	return true


static func warnings_at(
	policy: AssetPlacementPolicy,
	terrain: TerrainGrid,
	water: WaterGrid,
	cell: Vector2i
) -> Array[String]:
	if policy == null:
		return []
	return policy.warnings_for(facts_at(terrain, water, cell))


## Предупреждения по всему следу объекта, без повторов: ель, у которой под одним
## углом обрыв, нарушает уклон один раз, а не четырежды.
static func warnings_for_cells(
	policy: AssetPlacementPolicy,
	terrain: TerrainGrid,
	water: WaterGrid,
	cells: Rect2i
) -> Array[String]:
	var warnings: Array[String] = []
	if policy == null:
		return warnings
	for x in range(cells.position.x, cells.end.x):
		for z in range(cells.position.y, cells.end.y):
			for warning: String in warnings_at(policy, terrain, water, Vector2i(x, z)):
				if warning not in warnings:
					warnings.append(warning)
	return warnings


## «Место подходит без единой оговорки». Автору такой строгости не нужно — ему
## показывают жёлтый призрак и оставляют решение. Массовой постановке (кисть,
## генератор) нужна ровно она: тридцать тысяч предупреждений никто не прочитает,
## поэтому там правило превращается из совета в условие отбора.
static func accepts_cells(
	policy: AssetPlacementPolicy,
	terrain: TerrainGrid,
	water: WaterGrid,
	cells: Rect2i
) -> bool:
	if not are_cells_placeable(terrain, cells):
		return false
	return warnings_for_cells(policy, terrain, water, cells).is_empty()


## Высота, которую запись хранит: смещение ОТ ЗЕМЛИ, а не мировой Y (§9.3).
## Объект на воде получает уровень воды за вычетом земли под ним — тогда правка
## рельефа под ним поднимает и опускает его вместе с землёй, а лодка остаётся на
## поверхности озера, а не на его дне.
static func surface_offset(
	policy: AssetPlacementPolicy,
	terrain: TerrainGrid,
	water: WaterGrid,
	cell: Vector2i,
	ground_position: Vector3
) -> float:
	var offset := 0.0
	var surface := surface_kind(terrain, water, cell)
	if surface != AssetPlacementPolicy.SURFACE_GROUND:
		offset = water.surface_metres_at(cell) - terrain.height_at(ground_position)
	if policy != null:
		offset += policy.vertical_offset
	return offset
