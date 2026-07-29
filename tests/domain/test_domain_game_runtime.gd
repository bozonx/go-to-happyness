class_name TestDomainGameRuntime
extends RefCounted


static func run_all() -> void:
	test_core_settlement_definition_is_indexed()
	test_session_keeps_settlement_values_module_scoped()
	test_host_input_profiles_are_allowlisted()
	test_definition_validation_rejects_unknown_module()
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
	var launch := GameLaunchConfig.for_tent_era()
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	var session := GameSessionConfig.from_settlement_launch(launch, definition)
	assert(session.map_ref == &"core:green_valley")
	var settlement_parameters: Dictionary = session.module_parameters[&"gth.settlement"]
	assert(settlement_parameters["era"] == "tent")
	assert(settlement_parameters["starting_population"] == 4)


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
