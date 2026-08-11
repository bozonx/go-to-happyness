class_name TestDomainSeasonalEntities
extends RefCounted

## Сезонные состояния сущностей (`map_fill_mode.md` §6.1).
##
## Проверяется мёртвая ветка формата, а не красота осени. `seasonal` — состояние
## по умолчанию у КАЖДОЙ записи, и до появления службы его не разрешал никто:
## `state_for("season", …)` не вызывался нигде, кроме тестов, а презентер искал
## состояние с именем «seasonal» и не находил. Объявленные ассетами `autumn` и
## `winter` были недостижимы вообще ничем.


static func run_all() -> void:
	_test_seasonal_default_resolves_to_a_real_state()
	_test_a_pinned_state_is_not_overruled()
	_test_a_plant_without_this_season_keeps_what_it_has()
	_test_shipped_vegetation_declares_its_seasons()
	print("    [PASS] Seasonal Entity Tests")


## Карта с одной записью нужного архетипа. Архетипы берутся из пака, а не
## собираются в тесте: проверяется в том числе то, что поставляемый контент
## объявляет сезоны, — а собранный на месте архетип это как раз и скрыл бы.
static func _runtime_of(archetype_id: StringName, initial_state: StringName) -> MapEntityRuntime:
	assert(EntityArchetypeCatalog.get_archetype(archetype_id) != null,
		"архетип %s должен быть в паке" % archetype_id)
	var document := MapDocument.create(&"seasons", "Сезоны", 16)
	var record := MapEntityRecord.new()
	record.id = &"plant"
	record.archetype_id = archetype_id
	record.initial_state = initial_state
	document.entities.entities.append(record)
	var runtime := MapEntityRuntime.new()
	runtime.load_map(document)
	assert(runtime.by_id(&"plant") != null, "запись должна попасть в runtime")
	return runtime


static func _test_seasonal_default_resolves_to_a_real_state() -> void:
	var runtime := _runtime_of(&"core:tree", EntityStateSet.FOLLOW_SEASON)
	var service := SeasonalEntityService.new()
	service.configure(runtime, null)

	service.apply_season(&"autumn")
	assert(runtime.by_id(&"plant").state == &"autumn",
		"«seasonal» обязано разрешаться в состояние, которое умеет нарисовать ассет")
	# И дальше, а не один раз: переведённое службой дерево остаётся её делом.
	service.apply_season(&"winter")
	assert(runtime.by_id(&"plant").state == &"winter")
	service.apply_season(&"spring")
	assert(runtime.by_id(&"plant").state == &"summer", "весна выглядит как лето")


static func _test_a_pinned_state_is_not_overruled() -> void:
	var runtime := _runtime_of(&"core:tree", &"winter")
	var service := SeasonalEntityService.new()
	service.configure(runtime, null)

	service.apply_season(&"summer")
	# Автор, выбравший зиму одинокой ели посреди лета, сказал это осознанно.
	assert(runtime.by_id(&"plant").state == &"winter",
		"прикреплённое автором состояние сезон не переубеждает")


static func _test_a_plant_without_this_season_keeps_what_it_has() -> void:
	# У ели нет осеннего варианта — и архетип честно отправляет осень в лето.
	var runtime := _runtime_of(&"core:conifer_tree", EntityStateSet.FOLLOW_SEASON)
	var service := SeasonalEntityService.new()
	service.configure(runtime, null)

	service.apply_season(&"autumn")
	assert(runtime.by_id(&"plant").state == &"summer", "у ели нет осени, и это не повод её красить")
	service.apply_season(&"winter")
	assert(runtime.by_id(&"plant").state == &"winter")

	# Сезон, о котором архетип не сказал ничего, ничего и не меняет.
	service.apply_season(&"monsoon")
	assert(runtime.by_id(&"plant").state == &"winter")


## Ассеты объявляли `autumn`/`winter` вариантами, а архетипы — не объявляли
## состояний вовсе, поэтому механика была недостижима из данных. Это тест на
## контент: если у растения есть осенний вариант, у его архетипа обязано быть
## осеннее состояние, иначе вариант нарисовать нечем.
static func _test_shipped_vegetation_declares_its_seasons() -> void:
	var checked := 0
	for archetype: EntityArchetype in EntityArchetypeCatalog.all():
		var asset := WorldAssetCatalog.get_asset(archetype.asset_id)
		if asset == null:
			continue
		for season: StringName in [&"autumn", &"winter"]:
			if not asset.state_variants.has(String(season)):
				continue
			# `summer` в паре с ним обязателен: сезонный набор из одного состояния
			# ничего не переключает.
			if not asset.state_variants.has("summer"):
				continue
			checked += 1
			assert(archetype.states.state_for(&"season", season) != &"",
				"ассет «%s» умеет %s, а архетип «%s» не знает, когда это показывать"
					% [archetype.asset_id, season, archetype.id])
	assert(checked > 0, "в паке не нашлось ни одного сезонного растения — тест ничего не проверил")
