extends RefCounted

## Unit test suite for SaveData and SaveGameService.

const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")
const SaveGameServiceScript = preload("res://game/features/save_load/application/save_game_service.gd")

static func run_all() -> void:
	print("--- Running Save/Load Unit Tests ---")
	
	var save_data := SaveDataScript.new()
	save_data.settlement_state = {
		"money": 1250,
		"wellbeing": 90,
		"resources": {"food": 50, "wood": 100},
		"unlocked_building_levels": {"tent": 1},
		"unlocked_systems": {"primitive_fire": true},
		"equipment": {},
		"era": 0
	}
	save_data.clock_state = {"minutes": 450.5}
	save_data.citizens_state = [
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
	]
	save_data.forest_state = [
		{"cell": {"x": -16, "y": -15}, "felled": true, "remaining_branches": 2, "initial_branches": 7}
	]

	var test_path := "user://saves/test_quicksave.json"
	assert(save_data.save_to_file(test_path) == true, "Failed to save test_quicksave.json")

	var read_data := SaveDataScript.new()
	assert(read_data.load_from_file(test_path) == true, "Failed to load test_quicksave.json")
	assert(read_data.settlement_state.get("money") == 1250, "Settlement money mismatch")
	assert(read_data.citizens_state.size() == 1, "Citizens count mismatch")
	assert(read_data.citizens_state[0].get("first_name") == "Test", "Citizen name mismatch")
	assert(read_data.version == SaveDataScript.VERSION, "Current format version was not written")
	assert(read_data.forest_state.size() == 1, "Forest state count mismatch")
	assert(read_data.forest_state[0].get("felled") == true, "Forest felled flag mismatch")
	assert(read_data.forest_state[0].get("remaining_branches") == 2, "Forest branch count mismatch")

	# A v2 save predates the forest field; it must still load, with an empty forest.
	var v2_compat := SaveDataScript.new()
	assert(v2_compat.from_dict({
		"version": 2,
		"settlement": {}, "clock": {}, "world": {}, "buildings": [],
		"construction_sites": [], "citizens": [], "resource_piles": []
	}), "v2 save (no forest) should load")
	assert(v2_compat.forest_state.is_empty(), "Missing forest must default to empty")
	assert(v2_compat.version == SaveDataScript.VERSION, "Loaded save should be upgraded to current version")

	# v1 saves used one-resource pile entries. They must remain loadable after
	# the v2 pile schema switched to a resource map.
	var legacy := SaveDataScript.new()
	assert(legacy.from_dict({
		"version": 1,
		"settlement": {}, "clock": {}, "world": {}, "buildings": [],
		"construction_sites": [], "citizens": [],
		"resource_piles": [{"resource_id": "wood", "amount": 3, "position": {}}]
	}), "Legacy v1 save should migrate")
	assert(legacy.resource_piles_state[0].get("resources", {}).get("wood") == 3, "Legacy pile migration mismatch")

	var unsupported := SaveDataScript.new()
	assert(not unsupported.from_dict({"version": 999}), "Unsupported save version must be rejected")
	
	print("  => Save/Load Unit Tests PASSED!")
