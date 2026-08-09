class_name GameLaunchConfig
extends RefCounted

## Typed record and factory for settlement game launch configurations.
## Configures starting era, landscape/biome, starting economy, and extra parameters.

## Progression as the host resolved it for this session (`SessionProgression`).
## The settlement module copies it in; nothing here decides which eras a map
## allows.
var era_id: StringName = &"tent"
var era_type: int = 0 # Matches SettlementState.Era.TENT
var allowed_eras: Array[StringName] = []
var allowed_era_types: Array[int] = []
var era_names: Dictionary = {}
var progression_enabled := true
## Atmosphere and vegetation defaults. Since maps arrived the biome no longer
## owns the ground: relief comes from `map_document` (map_editor.md §14.1).
var biome_id: StringName = &"summer_valley"
## Chosen by the map, not a per-player cosmetic preference. Building content
## resolves visual variants against this value while gameplay remains keyed by
## role.
var world_style: StringName = &"generic"

## The map this session runs on, as a runtime key (`core:green_valley` or
## `pack:author.pack/green_valley`). A playable session always has a map.
var map_ref: StringName = &"core:green_valley"
## The loaded package. `RuntimeLaunchManager` fills it from `map_ref` before the
## scene changes, so the bootstrap never waits on disk mid-startup.
var map_document: MapDocument = null
## Editor test run only, copied from `GameSessionConfig`: the party starts here
## instead of at the map's authored spawn points. `Vector3.INF` means "use the
## map", which is every launch that is not a test run.
var spawn_override := Vector3.INF
## The entrance this session began at, and the spawn group it names
## (`map_start.md` §3, §4). The id is carried rather than the record so the
## settlement never reaches back into map structures it does not own; entities
## bound to another entrance are filtered by `includes_map_entity`.
var start_option: StringName = &""
var spawn_group: StringName = &""
## Where the overview camera looks from on the first frame — the world position of
## the entrance's `core:camera_start` anchor (`map_start.md` §4.1), or
## `Vector3.INF` when the entrance names no camera and the camera falls back to
## the party. Resolved on the module boundary, like `spawn_group`, so the
## settlement never reads the zone layer itself.
var camera_start := Vector3.INF
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
	return config


func has_spawn_override() -> bool:
	return spawn_override != Vector3.INF


func has_camera_start() -> bool:
	return camera_start != Vector3.INF


## Board size of this session. It is authored by the selected map.
func board_cells() -> int:
	return map_document.board_cells() if map_document != null else 0


## Applies game-neutral world properties authored by the map.
func apply_map_start() -> void:
	if map_document == null:
		return
	var start := map_document.meta.start
	world_style = start.style


## Whether an authored entity belongs to the entrance this session began at
## (`map_start.md` §3.2). A map's entities exist always unless they say otherwise,
## so an unbound entity answers yes and every v7 map keeps its contents.
func includes_map_entity(entity: MapEntityRecord) -> bool:
	return entity.belongs_to_start(start_option)


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
