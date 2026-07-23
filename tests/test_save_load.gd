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
		"unlocked_techs": ["primitive_fire"],
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
			"needs": {"hunger": 90.0, "fatigue": 10.0, "comfort": 80.0, "health": 100.0},
			"specialization": "builder",
			"active_role": "construction",
			"pockets": []
		}
	]
	
	var test_path := "user://saves/test_quicksave.json"
	assert(save_data.save_to_file(test_path) == true, "Failed to save test_quicksave.json")
	
	var read_data := SaveDataScript.new()
	assert(read_data.load_from_file(test_path) == true, "Failed to load test_quicksave.json")
	assert(read_data.settlement_state.get("money") == 1250, "Settlement money mismatch")
	assert(read_data.citizens_state.size() == 1, "Citizens count mismatch")
	assert(read_data.citizens_state[0].get("first_name") == "Test", "Citizen name mismatch")
	assert(read_data.version == SaveDataScript.VERSION, "Current format version was not written")

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
