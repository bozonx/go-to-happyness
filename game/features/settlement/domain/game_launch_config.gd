class_name GameLaunchConfig
extends RefCounted

## Typed record and factory for settlement game launch configurations.
## Configures starting era, landscape/biome, starting economy, and extra parameters.

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var era_id: StringName = &"tent"
var era_type: int = 0 # Matches SettlementState.Era.TENT
## Atmosphere and vegetation defaults. Since maps arrived the biome no longer
## owns the ground: relief comes from `map_document` (map_editor.md §14.1).
var biome_id: StringName = &"summer_valley"

## The map this session runs on, as a runtime key (`green_valley` or
## `user:green_valley`). Empty means the legacy flat board — the one seam through
## which maps enter the game (map_editor.md §14.1).
var map_ref: StringName = &""
## The loaded package. `GameLaunchManager` fills it from `map_ref` before the
## scene changes, so the bootstrap never waits on disk mid-startup. Null is a
## valid state and means "flat board of the default size".
var map_document: MapDocument = null
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


## Board size of this session. From the map when there is one, otherwise the
## caller's legacy constant — which is the whole reason `BOARD_CELLS` stops being
## the source of truth (map_editor.md §14.1).
func board_cells(fallback: int) -> int:
	if map_document != null and map_document.board_cells() > 0:
		return map_document.board_cells()
	return fallback


## Applies whatever the map states over the era defaults. Fields the map omits are
## left exactly as the era config set them (§7).
func apply_map_start() -> void:
	if map_document == null:
		return
	var start := map_document.meta.start
	era_id = start.era
	var economy := start.economy
	if economy.has("money"):
		starting_money = int(economy["money"])
	if economy.has("population"):
		starting_population = int(economy["population"])
	if economy.has("wellbeing"):
		starting_wellbeing = int(economy["wellbeing"])
	if economy.has("resources"):
		starting_resources = (economy["resources"] as Dictionary).duplicate(true)
	if economy.has("equipment"):
		starting_equipment = (economy["equipment"] as Dictionary).duplicate(true)


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
