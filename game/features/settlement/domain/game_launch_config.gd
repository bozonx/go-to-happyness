class_name GameLaunchConfig
extends RefCounted

## Typed record and factory for settlement game launch configurations.
## Configures starting era, landscape/biome, starting economy, and extra parameters.

var era_id: StringName = &"tent"
var era_type: int = 0 # Matches SettlementState.Era.TENT
## Atmosphere and vegetation defaults. Since maps arrived the biome no longer
## owns the ground: relief comes from `map_document` (map_editor.md §14.1).
var biome_id: StringName = &"summer_valley"
## Chosen by the map, not a per-player cosmetic preference. Building content
## resolves visual variants against this value while gameplay remains keyed by
## role.
var world_style: StringName = &"generic"

## The map this session runs on, as a runtime key (`core:green_valley` or
## `user:green_valley`). A playable session always has a map.
var map_ref: StringName = &"core:green_valley"
## The loaded package. `RuntimeLaunchManager` fills it from `map_ref` before the
## scene changes, so the bootstrap never waits on disk mid-startup.
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
	config.map_ref = &"core:green_valley"
	config.starting_money = 500
	config.starting_wellbeing = 75
	config.starting_population = 4
	config.starting_equipment = {
		"flint_steel": {"owned": true},
	}
	return config


## Board size of this session. It is authored by the selected map.
func board_cells() -> int:
	return map_document.board_cells() if map_document != null else 0


## Applies whatever the map states over the era defaults. Fields the map omits are
## left exactly as the era config set them (§7).
func apply_map_start() -> void:
	if map_document == null:
		return
	var start := map_document.meta.start
	era_id = start.era
	world_style = start.style


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
