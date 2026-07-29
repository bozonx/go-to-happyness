class_name TestDomainGameRuntime
extends RefCounted


static func run_all() -> void:
	test_core_settlement_definition_is_indexed()
	test_session_keeps_settlement_values_module_scoped()
	test_host_input_profiles_are_allowlisted()
	test_definition_validation_rejects_unknown_module()
	test_installed_user_pack_game_is_indexed_and_resolvable()
	print("    [PASS] Game Runtime Domain Tests")


static func test_core_settlement_definition_is_indexed() -> void:
	var index := ContentIndex.new()
	index.rebuild()
	var entry := index.get_entry(&"core:settlement")
	assert(entry != null)
	assert(entry.content_type == &"game")
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	assert(definition.pack_id == &"core")
	assert(definition.runtime_key == &"core:settlement")
	assert(definition.default_map == &"core:green_valley")
	assert(definition.module_ids == [&"core.world", &"gth.settlement"])


static func test_session_keeps_settlement_values_module_scoped() -> void:
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	assert(definition.start_parameters.has("era"))
	assert(definition.start_parameters["era"] == "tent")
	var session := GameSessionConfig.create(definition, definition.default_map, null, {
		&"gth.settlement": definition.start_parameters.duplicate(true),
	})
	assert(session.map_ref == &"core:green_valley")
	var settlement_parameters: Dictionary = session.module_parameters[&"gth.settlement"]
	assert(settlement_parameters["era"] == "tent")
	assert(settlement_parameters["biome"] == "summer_valley")


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


const _TEST_PACK_DIR := "user://content/installed/test_author.test_pack"
const _TEST_PACK_RUNTIME_KEY := &"pack:test_author.test_pack/test_game"


static func test_installed_user_pack_game_is_indexed_and_resolvable() -> void:
	_setup_test_pack()
	var index := ContentIndex.new()
	index.rebuild()
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
	assert(definition.start_parameters.is_empty(), "showcase game has no start parameters")
	_teardown_test_pack()


static func _setup_test_pack() -> void:
	var dir := DirAccess.open("user://content")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("user://content")
	DirAccess.make_dir_recursive_absolute(_TEST_PACK_DIR.path_join("games"))
	var pack_json := {
		"format_version": 1,
		"id": "test_pack",
		"name": "Test Pack",
		"author": "test_author",
		"version": "1.0",
	}
	_write_json(_TEST_PACK_DIR.path_join("pack.json"), pack_json)
	var game_json := {
		"format_version": 1,
		"id": "test_game",
		"name": "Test Game",
		"pack": "test_pack",
		"modules": ["core.world", "gth.world_showcase"],
		"default_map": "core:green_valley",
		"clock": "realtime_pauseable",
		"input_profile": "rts",
	}
	_write_json(_TEST_PACK_DIR.path_join("games/test_game.gdgame.json"), game_json)


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
