class_name VegetationScatter
extends RefCounted

## Слой 4 генерации: растительность, ресурсы и фауна по биомам
## (`procedural_map_generation.md` §11.4).
##
## Стадия живёт в `application`, а не среди чистых стадий конвейера, и по той же
## причине, что уклоны, вода и вердикт: ей нужны настоящие сетки и каталог
## контента. Конвейер — это арифметика над буферами; здесь начинается мир.
##
## Три решения, определяющие результат:
##
## * **Что ставить — таблица пака (`BiomeFillCatalog`), где ставить — политика
##   архетипа (`EntityPlacementProbe`).** Спецификация требует «настоящую
##   `placement`-политику архетипа, без облегчённой копии правил»: сосна не
##   встанет на скале и камыш не вырастет на сухом склоне потому же, почему это
##   запрещает кисть автору, — правило одно, и оно одно на всех.
## * **Результат запекается записями, а не остаётся правилом.** Соблазн хранить
##   «здесь лес плотности 0.4, seed 1234» велик, но тогда автор не сможет убрать
##   одно дерево, не сдвинув остальные, — а он захочет, потому что именно там
##   пройдёт дорога (§9.2). Поэтому запись, и поэтому `objects.bin`.
## * **Детерминизм по клетке, а не по порядку обхода.** Бросок каждой клетки
##   посеян её координатами, поэтому добавление правила в таблицу не сдвигает
##   деревья, поставленные другим правилом. Общий курсор ГСЧ связал бы каждое
##   правило с каждым — ровно то, что §4.1 запрещает стадиям конвейера.

## Сколько клеток вокруг просматривается на предмет воды, если правило просит
## `near_water_cells`. Ограничение экономит проход: три клетки — это шесть
## метров, «у воды» в человеческом смысле.
const MAX_WATER_SEARCH := 6


class Outcome:
	extends RefCounted
	var placed := 0
	## Отвергнутые политикой размещения — по архетипам. Это не ошибка, а профиль
	## карты: «сосна отвергнута 4000 раз» на равнинной карте значит, что таблица
	## просит хвою там, где для неё слишком полого.
	var refused_by_policy: Dictionary = {}
	var refused_by_spacing := 0
	var refused_by_climate := 0
	var milliseconds := 0

	func note(reason: StringName, archetype_id: StringName) -> void:
		match reason:
			&"policy":
				refused_by_policy[archetype_id] = int(refused_by_policy.get(archetype_id, 0)) + 1
			&"spacing":
				refused_by_spacing += 1
			&"climate":
				refused_by_climate += 1

	func to_metrics() -> Dictionary:
		return {
			"scatter_placed": placed,
			"scatter_refused_spacing": refused_by_spacing,
			"scatter_refused_climate": refused_by_climate,
			"scatter_refused_policy": refused_by_policy.duplicate(),
			"scatter_milliseconds": milliseconds,
		}


## Заполняет слой наполнения документа по биомам, которые посчитал конвейер.
##
## Слой очищается целиком: генерация не правит карту, а создаёт её (§1), и лес
## предыдущей попытки не должен прорасти сквозь новую землю.
static func populate(
	document: MapDocument,
	context: GenerationContext,
	seeds: GenerationSeed
) -> Outcome:
	var outcome := Outcome.new()
	if document == null or context == null or seeds == null:
		return outcome
	var started := Time.get_ticks_msec()
	document.scatter.clear()

	var terrain := document.terrain
	var water := document.water
	var cell_size := maxf(terrain.cell_size, 0.001)
	# Один поток на стадию: добавление правила в таблицу не должно двигать
	# рельеф, а смена seed рельефа обязана двигать лес.
	var stream := seeds.stream_seed(&"vegetation")
	var rng := RandomNumberGenerator.new()

	# Занятые клетки — по архетипу. Общего «здесь уже что-то стоит» нет
	# намеренно: трава под деревом — это нормальная сцена, а два дерева в одной
	# клетке — нет, и разбирается это интервалом самого правила.
	var occupied: Dictionary = {}

	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		if not EntityPlacementProbe.is_placeable(terrain, cell):
			continue
		var biome_id := BiomeCatalog.id_of_index(context.biome_at_index(index))
		var rules := BiomeFillCatalog.rules_for(biome_id)
		if rules.is_empty():
			continue
		var temperature := context.temperature[index] if index < context.temperature.size() else 0.0
		var moisture := context.moisture[index] if index < context.moisture.size() else 0.5

		for rule_index in rules.size():
			var rule := rules[rule_index]
			if not rule.accepts_climate(temperature, moisture):
				outcome.note(&"climate", rule.archetype_id)
				continue
			# Бросок посеян клеткой И правилом: два правила в одной клетке — два
			# независимых броска, а не один общий, иначе трава и дерево всегда
			# выпадали бы вместе.
			rng.seed = hash([stream, cell.x, cell.y, rule_index])
			if rng.randf() >= rule.density:
				continue
			if rule.near_water_cells > 0 and not _has_water_near(
					terrain, water, cell, mini(rule.near_water_cells, MAX_WATER_SEARCH)):
				continue
			var asset := EntityArchetypeCatalog.asset_of(rule.archetype_id)
			if asset == null:
				continue
			var policy := asset.placement_policy()
			var footprint := Rect2i(cell, policy.footprint_cells)
			if not EntityPlacementProbe.accepts_cells(policy, terrain, water, footprint):
				outcome.note(&"policy", rule.archetype_id)
				continue
			var spacing := _spacing_cells(rule, policy, cell_size)
			if _is_crowded(occupied, rule.archetype_id, cell, spacing):
				outcome.note(&"spacing", rule.archetype_id)
				continue
			_occupy(occupied, rule.archetype_id, cell)
			document.scatter.add(_record_for(document.scatter, rule, asset, cell, rng))
			outcome.placed += 1

	outcome.milliseconds = Time.get_ticks_msec() - started
	return outcome


static func _record_for(
	layer: MapScatterLayer,
	rule: BiomeFillRule,
	asset: WorldAssetDef,
	cell: Vector2i,
	rng: RandomNumberGenerator
) -> MapScatterLayer.Record:
	var record := MapScatterLayer.Record.new()
	record.archetype_index = layer.archetype_index_of(rule.archetype_id)
	record.cell = cell
	# Смещение внутри клетки и поворот — то, что превращает решётку в лес. Оба
	# берутся у того же посеянного клеткой ГСЧ, поэтому одна и та же карта
	# генерируется одинаково на любой машине.
	record.offset = Vector2(
		rng.randf_range(-MapScatterLayer.OFFSET_RANGE, MapScatterLayer.OFFSET_RANGE),
		rng.randf_range(-MapScatterLayer.OFFSET_RANGE, MapScatterLayer.OFFSET_RANGE))
	if asset.is_rotation_axis_allowed("y"):
		record.yaw_degrees = rng.randf_range(0.0, 360.0)
	# Разброс размера — в границах, объявленных ассетом, а не «плюс-минус
	# четверть»: у валуна и у травинки эти границы разные и заданы данными.
	if asset.scale_mode == WorldAssetDef.SCALE_FREE_UNIFORM and asset.allowed_scales.size() >= 2:
		record.scale = asset.normalized_scale(
			rng.randf_range(asset.allowed_scales[0], asset.allowed_scales[-1]))
	record.variant = rng.randi_range(0, 255)
	return record


## Интервал в клетках. Ноль в правиле значит «взять у ассета» — там он объявлен
## вместе с остальной политикой разброса.
static func _spacing_cells(rule: BiomeFillRule, policy: AssetPlacementPolicy, cell_size: float) -> int:
	var metres := rule.min_spacing_m if rule.min_spacing_m > 0.0 else policy.scatter_min_spacing_m
	return maxi(0, int(ceilf(metres / cell_size)) - 1)


static func _is_crowded(
	occupied: Dictionary,
	archetype_id: StringName,
	cell: Vector2i,
	spacing: int
) -> bool:
	var taken: Dictionary = occupied.get(archetype_id, {})
	if taken.has(cell):
		return true
	for dz in range(-spacing, spacing + 1):
		for dx in range(-spacing, spacing + 1):
			if taken.has(cell + Vector2i(dx, dz)):
				return true
	return false


static func _occupy(occupied: Dictionary, archetype_id: StringName, cell: Vector2i) -> void:
	var taken: Dictionary = occupied.get(archetype_id, {})
	taken[cell] = true
	occupied[archetype_id] = taken


## Есть ли мокрая клетка в радиусе. Дороже, чем хочется, поэтому спрашивается
## только правилами, которые об этом попросили: камышу без этого разрешено расти
## посреди луга, потому что политика размещения ему сушу не запрещает.
static func _has_water_near(
	terrain: TerrainGrid,
	water: WaterGrid,
	cell: Vector2i,
	radius: int
) -> bool:
	if water == null:
		return false
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var probe := cell + Vector2i(dx, dz)
			if terrain.is_inside(probe) and water.is_wet(terrain, probe):
				return true
	return false
