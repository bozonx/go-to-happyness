class_name TestDomainGameRuntime
extends RefCounted


static func run_all() -> void:
	test_core_settlement_definition_is_indexed()
	test_session_keeps_module_values_module_scoped()
	test_progression_is_resolved_by_the_host()
	test_modules_declare_their_start_parameters()
	test_host_input_profiles_are_allowlisted()
	test_definition_validation_rejects_unknown_module()
	test_definition_validation_rejects_dangling_menu_parameter()
	test_installed_user_pack_game_is_indexed_and_resolvable()
	test_definition_round_trips_description_and_menu_parameters()
	print("    [PASS] Game Runtime Domain Tests")


static func test_core_settlement_definition_is_indexed() -> void:
	var entry := ContentIndex.shared().get_entry(&"core:settlement")
	assert(entry != null)
	assert(entry.content_type == &"game")
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	assert(definition.pack_id == &"core")
	assert(definition.runtime_key == &"core:settlement")
	assert(definition.default_map == &"core:green_valley")
	assert(definition.module_ids == [&"core.world", &"gth.settlement"])
	assert(not definition.description.is_empty(), "settlement definition must have a description")
	assert(not definition.revision.is_empty(), "a shipped definition must carry a revision stamp")
	assert(GameModuleRegistry.validate_definition(definition).is_empty(),
		"the shipped definition must satisfy the host validator")


static func test_session_keeps_module_values_module_scoped() -> void:
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	var session := GameSessionConfig.create(definition, definition.default_map, null, {
		&"gth.settlement": {"starting_population": 7},
	})
	assert(session.map_ref == &"core:green_valley")
	var settlement_parameters := session.parameters_for(&"gth.settlement")
	assert(settlement_parameters["starting_population"] == 7, "player values override authored defaults")
	assert(settlement_parameters["biome"] == "summer_valley", "authored defaults survive a partial override")


## Progression is host functionality: a game declares eras, a map narrows them,
## and the session resolves the pair once. No module takes part in this.
static func test_progression_is_resolved_by_the_host() -> void:
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	var catalogue := definition.progression
	assert(catalogue.era_ids() == [&"tent", &"earth", &"clay", &"wood", &"stone", &"brick"])
	assert(catalogue.era_by_id(&"tent").display_name("ru") == "Палаточная")

	var inherit := SessionProgression.resolve(catalogue, ProgressionPolicy.new())
	assert(inherit.enabled)
	assert(inherit.era_ids == catalogue.era_ids())
	assert(inherit.current_era == &"tent")
	assert(inherit.is_selectable())

	var restricted_policy := ProgressionPolicy.from_dict({
		"mode": "restricted", "allowed_eras": ["earth", "clay"], "default_era": "clay"})
	var restricted := SessionProgression.resolve(catalogue, restricted_policy)
	assert(restricted.era_ids == [&"earth", &"clay"], "restricted keeps the game's own order")
	assert(restricted.current_era == &"clay")
	assert(restricted.current_rank() == catalogue.rank_of(&"clay"))
	assert(restricted.allowed_ranks() == [1, 2])

	var fixed := SessionProgression.resolve(catalogue,
		ProgressionPolicy.from_dict({"mode": "fixed", "default_era": "wood"}))
	assert(fixed.era_ids == [&"wood"])
	assert(not fixed.is_selectable(), "a single era is not a choice")

	# Disabled means nothing is locked, so the session starts fully advanced.
	var disabled := SessionProgression.resolve(catalogue, ProgressionPolicy.from_dict({"mode": "disabled"}))
	assert(not disabled.enabled)
	assert(disabled.current_era == &"brick")
	assert(disabled.allowed_ranks().size() == catalogue.eras.size())

	# The player's pick wins over the map default, but only within the policy.
	var picked := SessionProgression.resolve(catalogue, restricted_policy, &"earth")
	assert(picked.current_era == &"earth")
	var refused := SessionProgression.resolve(catalogue, restricted_policy, &"brick")
	assert(refused.current_era == &"clay", "a pick outside the policy falls back to the map default")

	# A game without eras resolves to an empty progression rather than a fake one.
	var empty := SessionProgression.resolve(GameProgressionDefinition.new(), ProgressionPolicy.new())
	assert(empty.is_empty())
	assert(empty.current_era.is_empty())

	# A map naming an era its game dropped is an authoring error, not a clamp.
	var bad := ProgressionPolicy.from_dict({"mode": "restricted", "allowed_eras": ["bronze"]})
	assert(bad.validate(catalogue.era_ids()).any(func(error: String) -> bool: return error.contains("bronze")))


static func test_modules_declare_their_start_parameters() -> void:
	assert(GameModuleRegistry.module_ids().has(&"gth.settlement"))
	var declared := GameModuleRegistry.start_parameters_of(&"gth.settlement")
	var population := StartParameterDef.find(declared, &"starting_population")
	assert(population != null, "the launch screen builds its controls from this declaration")
	assert(population.type == StartParameterDef.TYPE_INT)
	assert(population.coerce(999) == population.max_value, "declared bounds clamp authored values")
	assert(population.coerce("nonsense") == population.default_value)
	assert(GameModuleRegistry.start_parameters_of(&"core.world").is_empty())

	# `resolve_parameters` fills declared defaults and keeps unknown authored keys.
	var resolved := SettlementGameModule.new().resolve_parameters({"starting_money": 900, "custom": true})
	assert(resolved["starting_money"] == 900)
	assert(resolved["starting_population"] == 4)
	assert(resolved["custom"] == true)


static func test_host_input_profiles_are_allowlisted() -> void:
	assert(HostInputProfile.is_supported(&"rts"))
	assert(not HostInputProfile.is_supported(&"first_person"))
	assert(not HostInputProfile.is_supported(&"author_supplied_shortcuts"))


static func test_definition_validation_rejects_unknown_module() -> void:
	var definition := GameDefinition.from_dict({
		"format_version": 1,
		"id": "broken",
		"pack": "core",
		"default_map": "core:green_valley",
		"modules": ["core.world", "unknown.module"],
	})
	var errors := GameModuleRegistry.validate_definition(definition)
	assert(errors.any(func(error: String) -> bool: return error.contains("unknown.module")))


## A menu parameter that names nothing would render as a blank control at launch.
static func test_definition_validation_rejects_dangling_menu_parameter() -> void:
	var definition := GameDefinition.from_dict({
		"format_version": 1,
		"id": "dangling",
		"pack": "core",
		"default_map": "core:green_valley",
		"modules": ["core.world", "gth.settlement"],
		"menu_parameters": [{"module": "gth.settlement", "id": "no_such_parameter"}],
	})
	var errors := GameModuleRegistry.validate_definition(definition)
	assert(errors.any(func(error: String) -> bool: return error.contains("no_such_parameter")))

	var era_without_eras := GameDefinition.from_dict({
		"format_version": 1,
		"id": "no_eras",
		"pack": "core",
		"default_map": "core:green_valley",
		"modules": ["core.world"],
		"menu_parameters": [{"type": "era"}],
	})
	assert(GameModuleRegistry.validate_definition(era_without_eras)
		.any(func(error: String) -> bool: return error.contains("эра")))


static func test_definition_round_trips_description_and_menu_parameters() -> void:
	var source := {
		"format_version": 1,
		"id": "roundtrip",
		"name": "Round Trip",
		"description": "Test description",
		"revision": "abc123",
		"pack": "core",
		"modules": ["core.world"],
		"default_map": "core:green_valley",
		"input_profile": "rts",
		"start": {"modules": {}},
		"menu_parameters": [{"type": "era"}],
		"progression": {"eras": [], "technologies": {}},
	}
	var definition := GameDefinition.from_dict(source)
	assert(definition != null)
	assert(definition.description == "Test description")
	assert(definition.revision == "abc123")
	assert(definition.menu_parameters.size() == 1)
	var serialized := definition.to_dict()
	assert(serialized["description"] == "Test description")
	assert(serialized["revision"] == "abc123")
	assert(not serialized.has("clock"), "the clock model had no consumer and was removed")
	assert(not serialized.has("ui_layout"), "the ui layout field had no consumer and was removed")
	var restored := GameDefinition.from_dict(serialized)
	assert(restored != null)
	assert(restored.menu_parameters.size() == 1)
	assert(StringName(restored.menu_parameters[0].get("type", "")) == GameDefinition.MENU_PARAMETER_ERA)


const _TEST_PACK_DIR := "user://content/installed/test_author.test_pack"
const _TEST_PACK_RUNTIME_KEY := &"pack:test_author.test_pack/test_game"


static func test_installed_user_pack_game_is_indexed_and_resolvable() -> void:
	_setup_test_pack()
	ContentIndex.invalidate()
	var index := ContentIndex.shared()
	var entry := index.get_entry(_TEST_PACK_RUNTIME_KEY)
	assert(entry != null, "installed pack game must be indexed")
	assert(entry.content_type == &"game")
	var definition := GameModuleRegistry.resolve_definition(_TEST_PACK_RUNTIME_KEY)
	assert(definition != null, "installed pack game must resolve to a definition")
	assert(definition.id == &"test_game")
	assert(definition.pack_id == &"test_pack")
	assert(definition.runtime_key == _TEST_PACK_RUNTIME_KEY)
	assert(definition.default_map == &"core:green_valley")
	assert(definition.module_ids == [&"core.world", &"gth.world_showcase"])
	assert(definition.start_module_parameters.is_empty(), "showcase game has no module start parameters")

	# The pack declares a dependency it does not ship with. The host must be able
	# to say so before a session starts, instead of loading a world with holes.
	assert(index.missing_requirements(&"pack:test_author.test_pack").is_empty())
	_write_json(_TEST_PACK_DIR.path_join("pack.json"), _pack_json([
		{"kind": "pack", "id": "absent_pack", "min_version": "1.0.0"}]))
	ContentIndex.invalidate()
	var problems := ContentIndex.shared().missing_requirements(&"pack:test_author.test_pack")
	assert(problems.any(func(error: String) -> bool: return error.contains("absent_pack")))

	_teardown_test_pack()
	ContentIndex.invalidate()


static func _pack_json(requires: Array) -> Dictionary:
	return {
		"format_version": 2,
		"id": "test_pack",
		"name": "Test Pack",
		"author_id": "test_author",
		"author_name": "Test Author",
		"version": "1.0",
		"requires": requires,
	}


static func _setup_test_pack() -> void:
	DirAccess.make_dir_recursive_absolute(_TEST_PACK_DIR.path_join("games"))
	_write_json(_TEST_PACK_DIR.path_join("pack.json"), _pack_json([]))
	_write_json(_TEST_PACK_DIR.path_join("games/test_game.gdgame.json"), {
		"format_version": 1,
		"id": "test_game",
		"name": "Test Game",
		"pack": "test_pack",
		"modules": ["core.world", "gth.world_showcase"],
		"default_map": "core:green_valley",
		"input_profile": "rts",
	})


static func _teardown_test_pack() -> void:
	_remove_dir_recursive(_TEST_PACK_DIR)


static func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "failed to write test file: %s" % path)
	file.store_string(JSON.stringify(data, "  "))
	file.close()


static func _remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var item := dir.get_next()
		while item != "":
			if item == "." or item == "..":
				item = dir.get_next()
				continue
			var full := path.path_join(item)
			if DirAccess.dir_exists_absolute(full):
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
			item = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(path)
