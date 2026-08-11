class_name ScatterBrush
extends RefCounted

## Кисть-разброс: мазок ставит много объектов сразу
## (`map_fill_mode.md` §9.2).
##
## **Кисть запекает записи, а не оставляет правило.** Соблазн хранить «здесь лес
## с плотностью 0.4, seed 1234» велик и экономит место, но тогда автор не сможет
## убрать одно конкретное дерево, не сломав генерацию, — а он захочет, потому что
## именно там пройдёт дорога. Две модели, правило и ручные исключения, неизбежно
## разойдутся; поэтому модель одна — записи в `MapScatterLayer`.
##
## **Seed — состояние инструмента, а не свойство карты.** Тот же seed и та же
## маска дают тот же мазок, и это нужно ровно для одного: попробовать, отменить,
## поправить плотность и попробовать снова на том же месте.
##
## Где объект может стоять, кисть не решает: спрашивает `EntityPlacementProbe`,
## то есть ту же политику архетипа, по которой предупреждает одиночная
## постановка и по которой сажает генератор (`VegetationScatter`). Свои маски
## кисти — только те, которых у политики нет и быть не должно: высота и радиус
## мазка принадлежат жесту автора, а не ассету.

## Смесь архетипов с весами. Пустая — мазок не ставит ничего, и это нормальное
## состояние кисти до того, как автор выбрал, чем красить.
class Mix:
	extends RefCounted
	var archetype_ids: Array[StringName] = []
	var weights: PackedFloat32Array = PackedFloat32Array()

	func add(archetype_id: StringName, weight := 1.0) -> void:
		archetype_ids.append(archetype_id)
		weights.append(maxf(weight, 0.0))

	func is_empty() -> bool:
		return archetype_ids.is_empty() or total_weight() <= 0.0

	func total_weight() -> float:
		var total := 0.0
		for weight in weights:
			total += weight
		return total

	## Выбор по весам. Один бросок на кандидата — не на мазок: смесь «девять
	## сосен на одну берёзу» обязана быть смесью в каждом мазке, а не чередованием
	## однородных пятен.
	func pick(roll: float) -> StringName:
		var target := roll * total_weight()
		var running := 0.0
		for index in archetype_ids.size():
			running += weights[index]
			if target <= running:
				return archetype_ids[index]
		return archetype_ids[archetype_ids.size() - 1]


class Settings:
	extends RefCounted
	## Радиус мазка в клетках.
	var radius_cells := 4
	## Доля клеток мазка, в которые ставится объект.
	var density := 0.35
	## Минимальный интервал между поставленными объектами, в метрах. Ноль — брать
	## у ассета.
	var min_spacing_m := 0.0
	## Диапазон высот доски, вне которого кисть не ставит. Пусто — вся доска.
	## Это маска ЖЕСТА, а не свойство ассета: «еловый пояс выше третьей террасы»
	## говорит автор, а не ель.
	var height_range := Vector2i(-1000, 1000)
	var mix := Mix.new()
	var seed_value := 0
	## Варьировать поворот и масштаб в границах ассета. Выключенное значит «ровный
	## строй», и это осмысленный выбор для аллеи.
	var vary := true

	func is_ready() -> bool:
		return radius_cells > 0 and density > 0.0 and not mix.is_empty()


## Записи, которые мазок добавил бы в слой. Ничего не пишет сам: решение о
## записи — это команда отмены, и принимает её редактор.
##
## `occupied` — клетки, уже занятые этим же архетипом (обычно из самого слоя).
## Кисть дополняет его по ходу мазка, поэтому один мазок не ставит два дерева в
## одну клетку, а протяжка не ставит их поверх предыдущего кадра.
static func stroke(
	settings: Settings,
	layer: MapScatterLayer,
	terrain: TerrainGrid,
	water: WaterGrid,
	centre: Vector2i,
	occupied: ScatterSpacingIndex
) -> Array[MapScatterLayer.Record]:
	var placed: Array[MapScatterLayer.Record] = []
	if settings == null or not settings.is_ready() or terrain == null or layer == null:
		return placed

	var rng := RandomNumberGenerator.new()
	var radius := settings.radius_cells
	var cell_size := maxf(terrain.cell_size, 0.001)
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			# Круг, а не квадрат: квадратная кисть видна на глаз в первом же мазке.
			if dx * dx + dz * dz > radius * radius:
				continue
			var cell := centre + Vector2i(dx, dz)
			if not EntityPlacementProbe.is_placeable(terrain, cell):
				continue
			var height := terrain.height_of(cell)
			if height < settings.height_range.x or height > settings.height_range.y:
				continue
			# Бросок посеян клеткой, а не порядком обхода: протяжка кисти по одному
			# месту дважды не должна давать разный результат, иначе «тот же seed —
			# тот же мазок» перестаёт быть правдой при первом же движении мыши.
			rng.seed = hash([settings.seed_value, cell.x, cell.y])
			if rng.randf() >= settings.density:
				continue
			var archetype_id := settings.mix.pick(rng.randf())
			var archetype := EntityArchetypeCatalog.get_archetype(archetype_id)
			var asset := EntityArchetypeCatalog.asset_of(archetype_id)
			if asset == null:
				continue
			var exclusive_cell := archetype != null \
				and archetype.has_component(&"settlement_natural")
			if exclusive_cell and occupied.is_exclusive_cell_claimed(cell):
				continue
			var policy := asset.placement_policy()
			if not EntityPlacementProbe.accepts_cells(
					policy, terrain, water, Rect2i(cell, policy.footprint_cells)):
				continue
			var record := _record(layer, archetype_id, asset, cell, rng, settings.vary)
			var spacing := _spacing_metres(settings, policy) * record.scale
			if occupied.is_crowded(archetype_id, record, spacing):
				continue
			occupied.add(archetype_id, record, spacing)
			if exclusive_cell:
				occupied.claim_exclusive_cell(cell)
			placed.append(record)
	return placed


## Клетки, уже занятые каждым архетипом слоя. Строится один раз на мазок:
## перебирать весь слой на каждую клетку кисти — это радиус² проходов по лесу.
static func occupancy_of(layer: MapScatterLayer, cell_size := 1.0) -> ScatterSpacingIndex:
	var occupied := ScatterSpacingIndex.new()
	occupied.configure(cell_size)
	if layer == null:
		return occupied
	for record: MapScatterLayer.Record in layer.records:
		if record.is_empty():
			continue
		var archetype_id := layer.archetype_of(record)
		var archetype := EntityArchetypeCatalog.get_archetype(archetype_id)
		var asset := EntityArchetypeCatalog.asset_of(archetype_id)
		var spacing := asset.placement_policy().scatter_min_spacing_m * record.scale \
			if asset != null else 0.0
		occupied.add(archetype_id, record, spacing)
		if archetype != null and archetype.has_component(&"settlement_natural"):
			occupied.claim_exclusive_cell(record.cell)
	return occupied


static func _record(
	layer: MapScatterLayer,
	archetype_id: StringName,
	asset: WorldAssetDef,
	cell: Vector2i,
	rng: RandomNumberGenerator,
	vary: bool
) -> MapScatterLayer.Record:
	var record := MapScatterLayer.Record.new()
	record.archetype_index = layer.archetype_index_of(archetype_id)
	record.cell = cell
	record.offset = Vector2(
		rng.randf_range(-MapScatterLayer.OFFSET_RANGE, MapScatterLayer.OFFSET_RANGE),
		rng.randf_range(-MapScatterLayer.OFFSET_RANGE, MapScatterLayer.OFFSET_RANGE))
	record.variant = rng.randi_range(0, 255)
	if not vary:
		return record
	# Что именно вправе отличаться, решает ассет, а не кисть (§9.2.1): иначе
	# разброс зажигал бы костры, которые автор оставил потухшими.
	if asset.is_rotation_axis_allowed("y"):
		record.yaw_degrees = rng.randf_range(0.0, 360.0)
	if asset.scale_mode == WorldAssetDef.SCALE_FREE_UNIFORM and asset.allowed_scales.size() >= 2:
		record.scale = asset.normalized_scale(
			rng.randf_range(asset.allowed_scales[0], asset.allowed_scales[-1]))
	return record


static func _spacing_metres(settings: Settings, policy: AssetPlacementPolicy) -> float:
	return settings.min_spacing_m if settings.min_spacing_m > 0.0 else policy.scatter_min_spacing_m


## Стирание тем же кругом: кисть, которая только добавляет, заставляет автора
## отменять мазок целиком ради одного лишнего дерева.
static func erase(
	layer: MapScatterLayer,
	terrain: TerrainGrid,
	centre: Vector2i,
	radius_cells: int
) -> int:
	var removed := 0
	if layer == null or terrain == null:
		return removed
	for index in layer.records.size():
		var record := layer.records[index]
		if record.is_empty():
			continue
		var delta := record.cell - centre
		if delta.x * delta.x + delta.y * delta.y > radius_cells * radius_cells:
			continue
		if layer.remove_at(index):
			removed += 1
	return removed
