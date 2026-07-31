extends RefCounted

## Unit test suite for the sectioned SaveData envelope. SaveData carries only
## game/map/engine headers and a `modules` dictionary; each module section is
## versioned by its owner as `{"version": int, "data": {...}}`.

const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")

static func run_all() -> void:
	print("--- Running Save/Load Unit Tests ---")

	var save_data := SaveDataScript.new()
	save_data.game_header = {"pack": "core", "id": "settlement", "revision": "settlement-1"}
	save_data.map_header = {"source": "core", "id": "green_valley", "revision": "core-1"}
	save_data.engine_state = {"seed": 0}
	save_data.set_module_section(&"gth.settlement", 1, {
		"settlement": {
			"money": 1250,
			"wellbeing": 90,
			"resources": {"food": 50, "wood": 100},
			"unlocked_building_levels": {"tent": 1},
			"unlocked_systems": {"primitive_fire": true},
			"equipment": {},
			"era": 0
		},
		"clock": {"minutes": 450.5},
		"camera": {"target": {"x": 0.0, "y": 0.0, "z": 0.0}, "distance": 30.0, "yaw": 42.0, "pitch": 52.0},
		"world": {"next_ai_citizen_id": 1, "biome_id": "summer_valley"},
		"citizens": [
			{
				"ai_id": 1,
				"first_name": "Test",
				"last_name": "Citizen",
				"age": 30,
				"is_hero": true,
				"position": {"x": 1.0, "y": 0.0, "z": 2.0},
				"needs": {"hunger": 90.0, "fatigue": 10.0, "satisfaction": 80.0},
				"specialization": "builder",
				"active_role": "construction",
				"pockets": []
			}
		],
		"forest": [
			{"cell": {"x": -16, "y": -15}, "felled": true, "remaining_branches": 2, "initial_branches": 7}
		],
		"buildings": [{
			"cell": {"x": 4, "y": 7},
			"building_type": "pack:test_author.test_pack/test_house",
			"position": {"x": 4.0, "y": 0.0, "z": 7.0},
			"rotation_y": 90.0,
			"blueprint_ref": {
				"source": "player",
				"id": "test_house",
				"revision": "abcd1234",
			},
			"zone_state": [{
				"id": "zone_1",
				"profession_type": "craftsman",
				"assigned_citizen_ids": [1],
			}],
		}],
	})

	var test_path := "user://saves/test_quicksave.json"
	assert(save_data.save_to_file(test_path) == true, "Failed to save test_quicksave.json")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	assert(raw is Dictionary)
	assert(int((raw as Dictionary).get("format_version", 0)) == SaveDataScript.VERSION)
	assert((raw as Dictionary).get("game", {}) is Dictionary)
	assert((raw as Dictionary).get("engine", {}) is Dictionary)
	var raw_modules: Dictionary = (raw as Dictionary).get("modules", {})
	assert(raw_modules.has("gth.settlement"))
	assert(int((raw_modules["gth.settlement"] as Dictionary).get("version", 0)) == 1,
		"Each module section must record the version that wrote it")

	var read_data := SaveDataScript.new()
	assert(read_data.load_from_file(test_path) == true, "Failed to load test_quicksave.json")
	assert(read_data.module_section_version(&"gth.settlement") == 1)
	var read_section := read_data.module_section(&"gth.settlement")
	assert(read_section.get("settlement", {}).get("money") == 1250, "Settlement money mismatch")
	assert((read_section.get("citizens", []) as Array).size() == 1, "Citizens count mismatch")
	assert((read_section.get("citizens", []) as Array)[0].get("first_name") == "Test", "Citizen name mismatch")
	assert(read_data.version == SaveDataScript.VERSION, "Current format version was not written")
	assert((read_section.get("forest", []) as Array).size() == 1, "Forest state count mismatch")
	assert((read_section.get("forest", []) as Array)[0].get("felled") == true, "Forest felled flag mismatch")
	assert((read_section.get("buildings", []) as Array)[0].get("blueprint_ref", {}).get("id") == "test_house")
	assert(int((read_section.get("buildings", []) as Array)[0].get("zone_state", [])[0].get("assigned_citizen_ids", [0])[0]) == 1)
	assert(read_data.map_header.get("id") == "green_valley", "Map header must round-trip")
	assert(read_data.game_header.get("revision") == "settlement-1", "Game revision must round-trip")

	# A non-settlement game owns different module data. The host envelope must
	# accept it without manufacturing or requiring settlement state.
	var showcase_save := SaveDataScript.new()
	assert(showcase_save.from_dict({
		"format_version": SaveDataScript.VERSION,
		"game": {"pack": "core", "id": "world_showcase", "revision": ""},
		"map": {"source": "core", "id": "green_valley", "revision": ""},
		"engine": {"seed": 0},
		"modules": {"gth.world_showcase": {"version": 1, "data": {"camera": {"yaw": 42.0}}}},
	}), "Generic module save should load without gth.settlement")
	assert(showcase_save.module_sections.has("gth.world_showcase"))
	assert(not showcase_save.module_sections.has("gth.settlement"), "Showcase save must not fabricate a settlement section")
	assert(showcase_save.module_section(&"gth.world_showcase").get("camera", {}).get("yaw") == 42.0)
	assert(showcase_save.map_header.get("id") == "green_valley")

	# An envelope from another host version is refused, not guessed at. Module
	# sections migrate through their owning module, the envelope does not migrate.
	var unsupported := SaveDataScript.new()
	assert(not unsupported.from_dict({"format_version": SaveDataScript.VERSION - 1}),
		"Older envelope version must be rejected")
	assert(not unsupported.from_dict({"format_version": 999}), "Unsupported save version must be rejected")
	assert(not unsupported.from_dict({}), "Empty save must be rejected")

	print("  => Save/Load Unit Tests PASSED!")
