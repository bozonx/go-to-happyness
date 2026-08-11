class_name TestDomainScatterBrush
extends RefCounted

## Кисть-разброс (`map_fill_mode.md` §9.2).
##
## Проверяются обещания кисти, а не её красота: мазок круглый и повторяемый,
## плотность управляет количеством, смесь соблюдает веса, а «где можно стоять»
## решает та же политика архетипа, что и у одиночной постановки и у генератора.

const BOARD := 48


static func run_all() -> void:
	_test_a_stroke_is_round_and_bounded()
	_test_density_controls_the_count()
	_test_the_same_seed_gives_the_same_stroke()
	_test_placement_policy_is_not_re_implemented()
	_test_a_mix_respects_its_weights()
	_test_spacing_uses_real_positions_and_stays_per_archetype()
	_test_erasing_uses_the_same_circle()
	print("    [PASS] Scatter Brush Tests")


static func _terrain() -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD)
	return terrain


static func _settings(density := 0.5, radius := 5) -> ScatterBrush.Settings:
	var settings := ScatterBrush.Settings.new()
	settings.radius_cells = radius
	settings.density = density
	settings.seed_value = 17
	settings.mix.add(&"core:tree")
	return settings


static func _stroke(
	settings: ScatterBrush.Settings,
	terrain: TerrainGrid,
	water: WaterGrid,
	centre: Vector2i
) -> Array[MapScatterLayer.Record]:
	var occupied := ScatterSpacingIndex.new()
	occupied.configure(terrain.cell_size)
	return ScatterBrush.stroke(
		settings, MapScatterLayer.new(), terrain, water, centre, occupied)


static func _test_a_stroke_is_round_and_bounded() -> void:
	var terrain := _terrain()
	# Центр западнее origin: доска центрирована, и мазок у восточного края ничего
	# не доказывает про арифметику клеток.
	var centre := Vector2i(-10, -10)
	var settings := _settings(1.0, 5)
	var placed := _stroke(settings, terrain, null, centre)
	assert(not placed.is_empty(), "мазок с плотностью 1.0 обязан что-то поставить")
	for record: MapScatterLayer.Record in placed:
		var delta := record.cell - centre
		# Квадратная кисть видна на глаз в первом же мазке.
		assert(delta.x * delta.x + delta.y * delta.y <= 25,
			"объект за пределами круга: %s" % record.cell)
		assert(absf(record.offset.x) <= MapScatterLayer.OFFSET_RANGE)

	# У края доски мазок обрезается, а не выходит за неё.
	var edge := _stroke(settings, terrain, null, Vector2i(-BOARD / 2, -BOARD / 2))
	for record: MapScatterLayer.Record in edge:
		assert(terrain.is_inside(record.cell), "мазок вышел за доску: %s" % record.cell)


static func _test_density_controls_the_count() -> void:
	var terrain := _terrain()
	var sparse := _stroke(_settings(0.15), terrain, null, Vector2i(-4, -4)).size()
	var dense := _stroke(_settings(0.9), terrain, null, Vector2i(-4, -4)).size()
	assert(dense > sparse * 2, "плотность обязана быть управлением, а не украшением: %d против %d"
		% [dense, sparse])
	# Нулевая плотность и пустая смесь — не ошибка, а невзведённая кисть.
	var empty := ScatterBrush.Settings.new()
	assert(not empty.is_ready())
	assert(_stroke(empty, terrain, null, Vector2i.ZERO).is_empty())


static func _test_the_same_seed_gives_the_same_stroke() -> void:
	var terrain := _terrain()
	var first := _stroke(_settings(), terrain, null, Vector2i(-6, 3))
	var second := _stroke(_settings(), terrain, null, Vector2i(-6, 3))
	assert(first.size() == second.size())
	for index in first.size():
		assert(first[index].cell == second[index].cell)
		assert(is_equal_approx(first[index].yaw_degrees, second[index].yaw_degrees))

	# Другой seed — другой мазок, иначе поле «seed» не значит ничего.
	var other := _settings()
	other.seed_value = 99
	var third := _stroke(other, terrain, null, Vector2i(-6, 3))
	var same_cells := true
	if third.size() == first.size():
		for index in first.size():
			if third[index].cell != first[index].cell:
				same_cells = false
				break
	else:
		same_cells = false
	assert(not same_cells, "другой seed обязан дать другой мазок")


## Кисть не переписывает правила размещения: озеро остаётся незасаженным потому
## же, почему одиночная постановка показала бы жёлтый призрак.
static func _test_placement_policy_is_not_re_implemented() -> void:
	var terrain := _terrain()
	var water := WaterGrid.new()
	water.configure(1.0, BOARD)
	var body := water.create_body(WaterBody.Type.LAKE, 0)
	water.add_body(body)
	var centre := Vector2i(-8, -8)
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			var cell := centre + Vector2i(dx, dz)
			assert(terrain.set_height(cell, -3))
			assert(water.set_cell(cell, body.id, 0))

	var placed := _stroke(_settings(1.0), terrain, water, centre)
	assert(placed.is_empty(), "кисть засадила озеро деревьями: %d штук" % placed.size())

	# Вырез — тоже отказ, и по другой причине: там нет поверхности.
	var dry := _terrain()
	assert(dry.set_hole(Vector2i(2, 2), true))
	for record: MapScatterLayer.Record in _stroke(_settings(1.0), dry, null, Vector2i(2, 2)):
		assert(record.cell != Vector2i(2, 2), "объект встал в вырезе")


## Веса решают ЖРЕБИЙ, а не итоговое соотношение, и это разные вещи. Интервал
## считается по каждому архетипу отдельно (два дуба не растут вплотную, дуб и
## берёза — растут), поэтому редкий вид занимает промежутки, оставленные частым, и
## смесь «девять к одному» даёт на земле заметно меньший перевес. Так ведёт себя
## настоящий подлесок, и подгонять под объявленные числа тут нечего — проверять
## надо то место, где веса действительно применяются.
static func _test_a_mix_respects_its_weights() -> void:
	var mix := ScatterBrush.Mix.new()
	mix.add(&"core:tree", 9.0)
	mix.add(&"core:birch_tree", 1.0)
	var counts: Dictionary = {}
	for step in 1000:
		var picked := mix.pick(float(step) / 1000.0)
		counts[picked] = int(counts.get(picked, 0)) + 1
	# Допуск в одну выборку: граница веса попадает ровно в узел развёртки, и
	# 901/99 — это правильный ответ, а не промах.
	assert(absi(int(counts.get(&"core:tree", 0)) - 900) <= 2,
		"жребий обязан следовать весам: %s" % [counts])
	assert(absi(int(counts.get(&"core:birch_tree", 0)) - 100) <= 2)

	# Края диапазона попадают в смесь, а не мимо неё.
	assert(mix.pick(0.0) == &"core:tree" and mix.pick(1.0) == &"core:birch_tree")
	# Нулевой вес означает «никогда», а не «изредка».
	var single := ScatterBrush.Mix.new()
	single.add(&"core:tree", 1.0)
	single.add(&"core:bush", 0.0)
	for step in 50:
		assert(single.pick(float(step) / 50.0) == &"core:tree")

	# И на земле оба вида смеси действительно встречаются: жребий, из которого
	# второй архетип не выпадает ни разу, — это не смесь.
	var terrain := _terrain()
	var settings := _settings(1.0, 12)
	settings.mix = mix
	var layer := MapScatterLayer.new()
	var occupied := ScatterSpacingIndex.new()
	occupied.configure(terrain.cell_size)
	var placed := ScatterBrush.stroke(
		settings, layer, terrain, null, Vector2i(-2, -2), occupied)
	var on_ground: Dictionary = {}
	for record: MapScatterLayer.Record in placed:
		var archetype_id := layer.archetypes[record.archetype_index]
		on_ground[archetype_id] = int(on_ground.get(archetype_id, 0)) + 1
	assert(placed.size() > 50, "выборка слишком мала, чтобы говорить о смеси")
	assert(int(on_ground.get(&"core:tree", 0)) > int(on_ground.get(&"core:birch_tree", 0)),
		"частый вид обязан остаться частым: %s" % [on_ground])
	assert(int(on_ground.get(&"core:birch_tree", 0)) > 0, "редкий вид не встретился ни разу")


static func _test_spacing_uses_real_positions_and_stays_per_archetype() -> void:
	var index := ScatterSpacingIndex.new()
	index.configure(2.0)
	var existing := MapScatterLayer.Record.new()
	existing.cell = Vector2i.ZERO
	existing.offset = Vector2(0.49, 0.0)
	index.add(&"core:tree", existing, 4.0)
	var candidate := MapScatterLayer.Record.new()
	candidate.cell = Vector2i(2, 0)
	candidate.offset = Vector2(-0.49, 0.0)
	assert(index.is_crowded(&"core:tree", candidate, 1.0),
		"offset сблизил центры, а большой интервал существующего экземпляра потерян")
	assert(not index.is_crowded(&"core:birch_tree", candidate, 4.0),
		"интервал одного архетипа не должен выталкивать другой")


static func _test_erasing_uses_the_same_circle() -> void:
	var terrain := _terrain()
	var layer := MapScatterLayer.new()
	var settings := _settings(1.0, 6)
	var occupied := ScatterSpacingIndex.new()
	occupied.configure(terrain.cell_size)
	for record: MapScatterLayer.Record in ScatterBrush.stroke(
			settings, layer, terrain, null, Vector2i(-3, -3), occupied):
		layer.add(record)
	var before := layer.live_count()
	assert(before > 0)

	# Стирание меньшим радиусом убирает часть, а не всё: кисть, которая только
	# добавляет, заставляет отменять мазок целиком ради одного лишнего дерева.
	var removed := ScatterBrush.erase(layer, terrain, Vector2i(-3, -3), 2)
	assert(removed > 0 and removed < before,
		"стёрто %d из %d — круг стирания не совпадает со своим радиусом" % [removed, before])
	assert(layer.live_count() == before - removed)
	# Записи помечены пустыми, а не выброшены: идентичность по индексу должна
	# пережить стирание (§8.3).
	assert(layer.records.size() == before)
