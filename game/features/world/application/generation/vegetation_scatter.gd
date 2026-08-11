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
	var refused_by_water := 0
	var missing_content: Dictionary = {}
	var placed_by_rule: Dictionary = {}
	var milliseconds := 0

	func note(reason: StringName, archetype_id: StringName) -> void:
		match reason:
			&"policy":
				refused_by_policy[archetype_id] = int(refused_by_policy.get(archetype_id, 0)) + 1
			&"spacing":
				refused_by_spacing += 1
			&"climate":
				refused_by_climate += 1
			&"water":
				refused_by_water += 1
			&"missing":
				missing_content[archetype_id] = int(missing_content.get(archetype_id, 0)) + 1

	func note_placed(rule_key: StringName) -> void:
		var key := String(rule_key)
		placed_by_rule[key] = int(placed_by_rule.get(key, 0)) + 1

	func to_metrics() -> Dictionary:
		return {
			"scatter_placed": placed,
			"scatter_refused_spacing": refused_by_spacing,
			"scatter_refused_climate": refused_by_climate,
			"scatter_refused_near_water": refused_by_water,
			"scatter_refused_policy": refused_by_policy.duplicate(),
			"scatter_missing_content": missing_content.duplicate(),
			"scatter_placed_by_rule": placed_by_rule.duplicate(),
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

	# Занятость — по архетипу. Общего «здесь уже что-то стоит» нет
	# намеренно: трава под деревом — это нормальная сцена, а два дерева в одной
	# клетке — нет, и разбирается это интервалом самого правила.
	var occupied := ScatterSpacingIndex.new()
	occupied.configure(cell_size)
	# Catalog, stable-key formatting and policy resolution are content work, not
	# per-column work. A 512² board must not repeat them a quarter-million times.
	var rule_data: Dictionary = {}
	for biome_id: StringName in BiomeFillCatalog.biomes():
		for rule: BiomeFillRule in BiomeFillCatalog.rules_for(biome_id):
			if rule_data.has(rule):
				continue
			var asset := EntityArchetypeCatalog.asset_of(rule.archetype_id)
			var archetype := EntityArchetypeCatalog.get_archetype(rule.archetype_id)
			rule_data[rule] = {
				"key": rule.stable_key(),
				"asset": asset,
				"policy": asset.placement_policy() if asset != null else null,
				"exclusive_cell": archetype != null \
					and archetype.has_component(&"settlement_natural"),
			}

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

		for rule: BiomeFillRule in rules:
			var cached: Dictionary = rule_data[rule]
			var rule_key: StringName = cached["key"]
			if not rule.accepts_climate(temperature, moisture):
				outcome.note(&"climate", rule.archetype_id)
				continue
			var whole := floori(rule.density)
			var candidates := whole
			rng.seed = hash([stream, cell.x, cell.y, rule_key, &"count"])
			if rng.randf() < rule.density - float(whole):
				candidates += 1
			if candidates == 0:
				continue
			if rule.near_water_cells > 0 and not _has_near_water(
					terrain, water, cell, mini(rule.near_water_cells, MAX_WATER_SEARCH)):
				for _candidate in candidates:
					outcome.note(&"water", rule.archetype_id)
				continue
			var asset: WorldAssetDef = cached["asset"]
			if asset == null:
				for _candidate in candidates:
					outcome.note(&"missing", rule.archetype_id)
				continue
			var policy: AssetPlacementPolicy = cached["policy"]
			var footprint := Rect2i(cell, policy.footprint_cells)
			if not EntityPlacementProbe.accepts_cells(policy, terrain, water, footprint):
				for _candidate in candidates:
					outcome.note(&"policy", rule.archetype_id)
				continue
			for candidate_index in candidates:
				# Seed адресует правило, а не его позицию в таблице: соседняя новая
				# строка не перекрашивает и не передвигает существующий вид.
				rng.seed = hash([stream, cell.x, cell.y, rule_key, candidate_index])
				var record := _record_for(document.scatter, rule, asset, cell, rng)
				if bool(cached["exclusive_cell"]) \
						and occupied.is_exclusive_cell_claimed(record.cell):
					outcome.note(&"spacing", rule.archetype_id)
					continue
				var spacing_metres := _spacing_metres(rule, policy) * record.scale
				if occupied.is_crowded(rule.archetype_id, record, spacing_metres):
					outcome.note(&"spacing", rule.archetype_id)
					continue
				occupied.add(rule.archetype_id, record, spacing_metres)
				if bool(cached["exclusive_cell"]):
					occupied.claim_exclusive_cell(record.cell)
				document.scatter.add(record)
				outcome.placed += 1
				outcome.note_placed(rule_key)

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


## Интервал в метрах. Ноль в правиле значит «взять у ассета» — там он объявлен
## вместе с остальной политикой разброса.
static func _spacing_metres(rule: BiomeFillRule, policy: AssetPlacementPolicy) -> float:
	return rule.min_spacing_m if rule.min_spacing_m > 0.0 else policy.scatter_min_spacing_m


## Есть ли мокрая клетка в радиусе. Дороже, чем хочется, поэтому спрашивается
## только правилами, которые об этом попросили: камышу без этого разрешено расти
## посреди луга, потому что политика размещения ему сушу не запрещает.
static func _has_near_water(
	terrain: TerrainGrid,
	water: WaterGrid,
	cell: Vector2i,
	radius: int,
) -> bool:
	if water == null:
		return false
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nearby := cell + Vector2i(dx, dz)
			if terrain.is_inside(nearby) and water.is_wet(terrain, nearby):
				return true
	return false
