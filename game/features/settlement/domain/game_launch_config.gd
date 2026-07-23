class_name GameLaunchConfig
extends RefCounted

## Typed record and factory for settlement game launch configurations.
## Configures starting era, landscape/biome, starting economy, and extra parameters.

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var era_id: StringName = &"tent"
var era_type: int = 0 # Matches SettlementState.Era.TENT
var biome_id: StringName = &"summer_valley"
var starting_money: int = 500
var starting_wellbeing: int = 75
var starting_population: int = 4
var starting_resources: Dictionary = {}
var starting_equipment: Dictionary = {}
var custom_parameters: Dictionary = {}


static func for_tent_era() -> GameLaunchConfig:
	var config := GameLaunchConfig.new()
	config.era_id = &"tent"
	config.era_type = 0 # Era.TENT
	config.biome_id = &"summer_valley"
	config.starting_money = 500
	config.starting_wellbeing = 75
	config.starting_population = 4
	config.starting_resources = {
		ResourceIds.FOOD: 16,
		ResourceIds.WATER: 8,
		ResourceIds.TARP: 1,
	}
	config.starting_equipment = {
		"flint_steel": {"owned": true},
		"construction_gloves": {"sets": 1, "active_durability": 100.0},
	}
	return config


static func create_custom(
	p_era_id: StringName,
	p_era_type: int,
	p_biome_id: StringName,
	p_starting_money: int,
	p_starting_wellbeing: int,
	p_starting_population: int,
	p_starting_resources: Dictionary,
	p_starting_equipment: Dictionary = {},
	p_custom_parameters: Dictionary = {}
) -> GameLaunchConfig:
	var config := GameLaunchConfig.new()
	config.era_id = p_era_id
	config.era_type = p_era_type
	config.biome_id = p_biome_id
	config.starting_money = p_starting_money
	config.starting_wellbeing = p_starting_wellbeing
	config.starting_population = p_starting_population
	config.starting_resources = p_starting_resources.duplicate(true)
	config.starting_equipment = p_starting_equipment.duplicate(true)
	config.custom_parameters = p_custom_parameters.duplicate(true)
	return config
