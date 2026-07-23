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
	test_apply_launch_config_null_defaults_to_tent()
	test_apply_launch_config_reset_progress_false()
	test_apply_launch_config_with_equipment()
	test_apply_tent_start_backward_compat()
	test_create_custom_default_equipment_and_params()
	test_apply_launch_config_clears_state()
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


static func test_apply_launch_config_null_defaults_to_tent() -> void:
	var state := SettlementStateScript.new()
	state.apply_launch_config(null)
	# Null config must default to for_tent_era().
	assert(int(state.era) == 0)
	assert(state.money == 500)
	assert(state.wellbeing == 75)
	assert(state.backpack_amount(ResourceIds.FOOD) == 16)
	assert(state.backpack_amount(ResourceIds.WATER) == 8)


static func test_apply_launch_config_reset_progress_false() -> void:
	var state := SettlementStateScript.new()
	state.apply_launch_config(GameLaunchConfigScript.for_tent_era())
	# Simulate some buildings and unlock progress.
	state.buildings = {"tent": 1}
	state.unlock_state.unlocked_building_levels["tent"] = true
	# Re-apply with reset_progress=false — buildings and unlocks must survive.
	state.apply_launch_config(GameLaunchConfigScript.for_tent_era(), false)
	assert(not state.buildings.is_empty())
	assert(bool(state.unlock_state.unlocked_building_levels.get("tent", false)))
	# But economy fields are still reset.
	assert(state.money == 500)


static func test_apply_launch_config_with_equipment() -> void:
	var state := SettlementStateScript.new()
	var custom_eq := {"flint_steel": {"owned": true}, "pickaxe": {"sets": 2, "active_durability": 80.0}}
	var config := GameLaunchConfigScript.create_custom(
		&"tent", 0, &"summer_valley",
		500, 75, 4,
		{},
		custom_eq
	)
	state.apply_launch_config(config)
	assert(state.equipment_state.equipment.has("flint_steel"))
	assert(state.equipment_state.equipment.has("pickaxe"))


static func test_apply_tent_start_backward_compat() -> void:
	var state := SettlementStateScript.new()
	state.apply_tent_start()
	assert(int(state.era) == 0)
	assert(state.money == 500)
	assert(state.wellbeing == 75)
	assert(state.backpack_amount(ResourceIds.FOOD) == 16)
	assert(state.backpack_amount(ResourceIds.WATER) == 8)
	# apply_tent_start must produce the same result as apply_launch_config(for_tent_era()).
	var state2 := SettlementStateScript.new()
	state2.apply_launch_config(GameLaunchConfigScript.for_tent_era())
	assert(state.money == state2.money)
	assert(state.wellbeing == state2.wellbeing)
	assert(state.backpack_amount(ResourceIds.FOOD) == state2.backpack_amount(ResourceIds.FOOD))


static func test_create_custom_default_equipment_and_params() -> void:
	var config := GameLaunchConfigScript.create_custom(
		&"tent", 0, &"summer_valley",
		500, 75, 4, {}
	)
	assert(config.starting_equipment.is_empty())
	assert(config.custom_parameters.is_empty())
	# create_custom must deep-duplicate dictionaries so caller mutations don't leak.
	var res := {ResourceIds.FOOD: 10}
	var config2 := GameLaunchConfigScript.create_custom(
		&"tent", 0, &"summer_valley",
		500, 75, 4, res
	)
	res[ResourceIds.FOOD] = 999
	assert(int(config2.starting_resources[ResourceIds.FOOD]) == 10)


static func test_apply_launch_config_clears_state() -> void:
	var state := SettlementStateScript.new()
	state.apply_launch_config(GameLaunchConfigScript.for_tent_era())
	# Pollute state fields that apply_launch_config must reset.
	state.trade_sales = 5
	state.research.tech_id = "some_tech"
	state.warehouse_ever_built = true
	state.campfire_story_effect = "some_effect"
	state.campfire_story_target_role = "builder"
	state.campfire_story_target_day = 3
	# Re-apply — all transient state must be cleared.
	state.apply_launch_config(GameLaunchConfigScript.for_tent_era())
	assert(state.trade_sales == 0)
	assert(state.research.tech_id == "")
	assert(not state.warehouse_ever_built)
	assert(state.campfire_story_effect == "")
	assert(state.campfire_story_target_role == "")
	assert(state.campfire_story_target_day == -1)
