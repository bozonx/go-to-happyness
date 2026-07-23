class_name TestDomainLaunch
extends RefCounted

## Unit tests for GameLaunchConfig and launch configuration state application.

const GameLaunchConfigScript = preload("res://game/features/settlement/domain/game_launch_config.gd")
const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")


static func run_all() -> void:
	test_default_tent_config()
	test_custom_launch_config()
	test_apply_launch_config_to_settlement()
	print("    [PASS] Launch Configuration Tests")


static func test_default_tent_config() -> void:
	var config := GameLaunchConfigScript.for_tent_era()
	assert(config.era_id == &"tent")
	assert(config.era_type == 0) # TENT
	assert(config.biome_id == &"summer_valley")
	assert(config.starting_money == 500)
	assert(config.starting_wellbeing == 75)
	assert(config.starting_population == 4)
	assert(int(config.starting_resources.get(ResourceIds.FOOD, 0)) == 16)
	assert(int(config.starting_resources.get(ResourceIds.WATER, 0)) == 8)


static func test_custom_launch_config() -> void:
	var custom_res := {ResourceIds.WOOD: 50, ResourceIds.FOOD: 30}
	var custom_params := {"building_editor_mode": true, "seed": 12345}
	var config := GameLaunchConfigScript.create_custom(
		&"earth",
		1, # EARTH
		&"summer_plains",
		1000,
		90,
		6,
		custom_res,
		{},
		custom_params
	)
	assert(config.era_id == &"earth")
	assert(config.era_type == 1)
	assert(config.biome_id == &"summer_plains")
	assert(config.starting_money == 1000)
	assert(config.starting_wellbeing == 90)
	assert(config.starting_population == 6)
	assert(int(config.starting_resources.get(ResourceIds.WOOD, 0)) == 50)
	assert(bool(config.custom_parameters.get("building_editor_mode", false)) == true)


static func test_apply_launch_config_to_settlement() -> void:
	var state := SettlementStateScript.new()
	var custom_res := {ResourceIds.FOOD: 25, ResourceIds.WATER: 15}
	var config := GameLaunchConfigScript.create_custom(
		&"tent",
		0,
		&"summer_valley",
		750,
		80,
		5,
		custom_res
	)
	state.apply_launch_config(config)
	assert(int(state.era) == 0)
	assert(state.money == 750)
	assert(state.wellbeing == 80)
	assert(state.backpack_amount(ResourceIds.FOOD) == 25)
	assert(state.backpack_amount(ResourceIds.WATER) == 15)
