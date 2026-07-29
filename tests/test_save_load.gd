extends RefCounted

## Unit test suite for the sectioned SaveData envelope and the one-time legacy
## adapter. SaveData carries only game/map/engine headers and a `modules`
## dictionary; settlement state lives under `modules["gth.settlement"]`.

const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")

static func run_all() -> void:
	print("--- Running Save/Load Unit Tests ---")

	var save_data := SaveDataScript.new()
	save_data.game_header = {"pack": "core", "id": "settlement", "revision": ""}
	save_data.map_header = {"source": "core", "id": "green_valley", "revision": "core-1"}
	save_data.engine_state = {"clock": {}}
	save_data.module_states["gth.settlement"] = {
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
			"building_type": "user:test_house",
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
	}

	var test_path := "user://saves/test_quicksave.json"
	assert(save_data.save_to_file(test_path) == true, "Failed to save test_quicksave.json")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	assert(raw is Dictionary)
	assert(int((raw as Dictionary).get("format_version", 0)) == SaveDataScript.VERSION)
	assert((raw as Dictionary).get("game", {}) is Dictionary)
	assert((raw as Dictionary).get("engine", {}) is Dictionary)
	assert((raw as Dictionary).get("modules", {}) is Dictionary)
	assert(((raw as Dictionary).get("modules", {}) as Dictionary).has("gth.settlement"))

	var read_data := SaveDataScript.new()
	assert(read_data.load_from_file(test_path) == true, "Failed to load test_quicksave.json")
	var read_section: Dictionary = read_data.module_states["gth.settlement"]
	assert(read_section.get("settlement", {}).get("money") == 1250, "Settlement money mismatch")
	assert((read_section.get("citizens", []) as Array).size() == 1, "Citizens count mismatch")
	assert((read_section.get("citizens", []) as Array)[0].get("first_name") == "Test", "Citizen name mismatch")
	assert(read_data.version == SaveDataScript.VERSION, "Current format version was not written")
	assert((read_section.get("forest", []) as Array).size() == 1, "Forest state count mismatch")
	assert((read_section.get("forest", []) as Array)[0].get("felled") == true, "Forest felled flag mismatch")
	assert((read_section.get("forest", []) as Array)[0].get("remaining_branches") == 2, "Forest branch count mismatch")
	assert((read_section.get("buildings", []) as Array)[0].get("blueprint_ref", {}).get("id") == "test_house")
	assert(int((read_section.get("buildings", []) as Array)[0].get("zone_state", [])[0].get("assigned_citizen_ids", [0])[0]) == 1)
	assert(read_data.map_header.get("id") == "green_valley", "Map header must round-trip")

	# A non-settlement game owns different module data. The host envelope must
	# accept it without manufacturing or requiring settlement state.
	var showcase_save := SaveDataScript.new()
	assert(showcase_save.from_dict({
		"format_version": SaveDataScript.VERSION,
		"game": {"pack": "core", "id": "world_showcase", "revision": ""},
		"map": {"source": "core", "id": "green_valley", "revision": ""},
		"engine": {"clock": {}},
		"modules": {"gth.world_showcase": {"camera": {"yaw": 42.0}}},
	}), "Generic module save should load without gth.settlement")
	assert(showcase_save.module_states.has("gth.world_showcase"))
	assert(not showcase_save.module_states.has("gth.settlement"), "Showcase save must not fabricate a settlement section")
	assert(showcase_save.map_header.get("id") == "green_valley")

	# A v3 save predates the sectioned envelope; the adapter packs its flat fields
	# into the settlement section once, lifts map_ref into the map header and
	# bumps the version. v3 has no forest field, so the section carries an empty one.
	var v3_compat := SaveDataScript.new()
	assert(v3_compat.from_dict({
		"version": 3,
		"settlement": {"money": 300}, "clock": {"minutes": 100.0},
		"world": {"map_ref": {"source": "core", "id": "old_valley", "revision": "r1"}},
		"buildings": [], "construction_sites": [], "citizens": [], "resource_piles": []
	}), "v3 save (no forest) should migrate")
	assert(v3_compat.version == SaveDataScript.VERSION, "Loaded save should be upgraded to current version")
	var migrated_section: Dictionary = v3_compat.module_states.get("gth.settlement", {})
	assert(migrated_section.get("settlement", {}).get("money") == 300, "Adapter must pack settlement state into the section")
	assert((migrated_section.get("forest", []) as Array).is_empty(), "Missing forest must default to empty")
	assert(v3_compat.map_header.get("id") == "old_valley", "Adapter must lift map_ref into the map header")
	assert(v3_compat.game_header.get("id") == "settlement", "Adapter must default the game header to settlement")

	# v1 saves used one-resource pile entries. They must remain loadable after
	# the v2 pile schema switched to a resource map.
	var legacy := SaveDataScript.new()
	assert(legacy.from_dict({
		"version": 1,
		"settlement": {}, "clock": {}, "world": {}, "buildings": [],
		"construction_sites": [], "citizens": [],
		"resource_piles": [{"resource_id": "wood", "amount": 3, "position": {}}]
	}), "Legacy v1 save should migrate")
	var legacy_piles: Array = legacy.module_states.get("gth.settlement", {}).get("resource_piles", [])
	assert(legacy_piles[0].get("resources", {}).get("wood") == 3, "Legacy pile migration mismatch")

	var unsupported := SaveDataScript.new()
	assert(not unsupported.from_dict({"version": 999}), "Unsupported save version must be rejected")

	print("  => Save/Load Unit Tests PASSED!")
