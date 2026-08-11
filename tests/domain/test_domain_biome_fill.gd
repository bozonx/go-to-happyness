class_name TestDomainBiomeFill
extends RefCounted

## Таблица «биом → что в нём растёт» (`procedural_map_generation.md` §11.4).
##
## Это тест на КОНТЕНТ в той же мере, что и на код. Таблица — единственное место,
## где сказано, чем населять сгенерированную карту, и опечатка в имени архетипа
## здесь не роняет ничего: биом просто окажется пустым, а понять это можно будет
## только глядя на голую карту.


static func run_all() -> void:
	_test_tables_load_without_errors()
	_test_every_rule_names_a_real_archetype()
	_test_rules_only_say_what_and_how_much()
	_test_biomes_differ_from_each_other()
	_test_climate_window_narrows_within_a_biome()
	_test_density_above_one_and_stable_rule_keys_are_supported()
	print("    [PASS] Biome Fill Table Tests")


static func _test_tables_load_without_errors() -> void:
	BiomeFillCatalog.reload()
	assert(BiomeFillCatalog.load_errors.is_empty(),
		"таблицы биомов не читаются: %s" % ", ".join(BiomeFillCatalog.load_errors))
	assert(not BiomeFillCatalog.biomes().is_empty(), "не загружено ни одной таблицы")


static func _test_every_rule_names_a_real_archetype() -> void:
	for archetype_id: StringName in BiomeFillCatalog.referenced_archetypes():
		var archetype := EntityArchetypeCatalog.get_archetype(archetype_id)
		assert(archetype != null, "таблица ссылается на несуществующий архетип «%s»" % archetype_id)
		# И у архетипа обязан быть ассет: иначе сгенерированный лес — это поле
		# розовых заглушек.
		assert(EntityArchetypeCatalog.asset_of(archetype_id) != null,
			"архетип «%s» из таблицы биомов не нашёл свой ассет" % archetype_id)


## Правило говорит ЧТО, СКОЛЬКО и где климатически уместно. Где объект может стоять — ответ политики
## размещения архетипа, и второго ответа в таблице быть не должно: разойдясь,
## они дадут лес генератора, не совпадающий с лесом той же кисти.
static func _test_rules_only_say_what_and_how_much() -> void:
	for biome_id: StringName in BiomeFillCatalog.biomes():
		for rule: BiomeFillRule in BiomeFillCatalog.rules_for(biome_id):
			assert(rule.density > 0.0 and rule.density <= 1.0,
				"плотность «%s» в биоме %s вне разумного: %f" % [rule.archetype_id, biome_id, rule.density])
			var policy := EntityArchetypeCatalog.asset_of(rule.archetype_id).placement_policy()
			assert(policy != null, "у ассета правила нет политики размещения")


## Одинаковые таблицы у всех биомов означали бы, что биом ни на что не влияет, —
## а ради этого влияния слои 2–3 и считались.
static func _test_biomes_differ_from_each_other() -> void:
	var signatures: Dictionary = {}
	for biome_id: StringName in BiomeFillCatalog.biomes():
		var ids: Array[String] = []
		for rule: BiomeFillRule in BiomeFillCatalog.rules_for(biome_id):
			ids.append(String(rule.archetype_id))
		ids.sort()
		var signature := ",".join(ids)
		assert(not signatures.has(signature),
			"биомы %s и %s населены одинаково" % [biome_id, signatures.get(signature)])
		signatures[signature] = biome_id

	# Пустыня не может быть гуще леса: если это не так, «биом» — просто слово.
	var forest := _total_density(&"temperate_forest")
	var desert := _total_density(&"desert")
	var polar := _total_density(&"polar_desert")
	assert(forest > desert and desert > polar,
		"плотность обязана убывать от леса к пустыне и к полярной пустыне: %f / %f / %f"
			% [forest, desert, polar])


static func _test_climate_window_narrows_within_a_biome() -> void:
	var rule := BiomeFillRule.from_dict({
		"archetype": "core:fern", "density": 0.1, "moisture": [0.45, 1.0],
	})
	assert(rule.is_valid())
	assert(rule.accepts_climate(12.0, 0.7), "сырая часть леса — место папоротника")
	assert(not rule.accepts_climate(12.0, 0.2), "сухой склон того же леса — не место")
	# Границы включительные: правило, отвергающее собственный край, оставляет
	# полосу, где не растёт ничего.
	assert(rule.accepts_climate(12.0, 0.45))

	# Перевёрнутый диапазон — не ошибка автора, а недоразумение, и читается он так
	# же, как правильный.
	var flipped := BiomeFillRule.from_dict({
		"archetype": "core:tree", "density": 0.1, "temperature": [20.0, 5.0],
	})
	assert(flipped.accepts_climate(10.0, 0.5))

	# Правило без архетипа или с нулевой плотностью не должно попадать в таблицу.
	assert(not BiomeFillRule.from_dict({"density": 0.2}).is_valid())
	assert(not BiomeFillRule.from_dict({"archetype": "core:tree"}).is_valid())


static func _test_density_above_one_and_stable_rule_keys_are_supported() -> void:
	var dense := BiomeFillRule.from_dict({
		"id": "grove", "archetype": "core:tree", "density": 2.4,
	})
	dense.source_key = &"core/test"
	assert(dense.is_valid() and is_equal_approx(dense.density, 2.4),
		"density > 1 означает несколько кандидатов, а не скрытый clamp")
	var key := dense.stable_key()
	dense.density = 0.2
	assert(dense.stable_key() == key,
		"изменение плотности должно сохранять уже существующее подмножество")


static func _total_density(biome_id: StringName) -> float:
	var total := 0.0
	for rule: BiomeFillRule in BiomeFillCatalog.rules_for(biome_id):
		total += rule.density
	return total
