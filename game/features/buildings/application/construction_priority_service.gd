class_name ConstructionPriorityService
extends RefCounted

## Evaluates construction site priorities to decide which project builders
## and couriers should focus on next.

const SCORE_WAREHOUSE_FIRST := 1000.0
const SCORE_WAREHOUSE_LATER := 180.0
const SCORE_CAMPFIRE_FIRST := 950.0
const SCORE_CAMPFIRE_LATER := 120.0
const SCORE_HOUSING_FIRST := 850.0
const SCORE_HOUSING_LATER := 140.0
const SCORE_FOOD_FIRST := 700.0
const SCORE_FOOD_LATER := 160.0
const SCORE_CANTEEN_FIRST := 580.0
const SCORE_CANTEEN_LATER := 120.0
const SCORE_SAWMILL_FIRST := 420.0
const SCORE_SAWMILL_LATER := 100.0
const SCORE_LEISURE := 80.0
const SCORE_DEFAULT := 250.0
const SCORE_ERA_MULTIPLIER := 100.0
const SCORE_SUPPLIED_BONUS := 2.0
const FOOD_POPULATION_RATIO := 2

var _construction_sites: Array[ConstructionSite]
var _warehouse_positions: Array[Vector3]
var _sawmill_positions: Array[Vector3]
var _campfire_node_getter: Callable
var _canteen_getter: Callable
var _population_provider: Callable
var _housing_slots_provider: Callable
var _food_amount_provider: Callable


func configure(port: ConstructionPriorityRuntimePort) -> void:
	_construction_sites = port.construction_sites
	_warehouse_positions = port.warehouse_positions
	_sawmill_positions = port.sawmill_positions
	_campfire_node_getter = port.campfire_node_getter
	_canteen_getter = port.canteen_getter
	_population_provider = port.population_provider
	_housing_slots_provider = port.housing_slots_provider
	_food_amount_provider = port.food_amount_provider


func preferred_construction_site() -> ConstructionSite:
	var chosen: ConstructionSite = null
	var best_score := -INF
	for site in _construction_sites:
		if site == null or not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
			continue
		var score := development_priority(site)
		# A builder can only advance up to the fraction of materials already on
		# site. Prefer any project with work available over a higher-priority site
		# where everyone would only wait for a courier. If no site can advance,
		# publish no builder target at all; standing at a blocked site used to keep
		# a stale construction order alive indefinitely.
		if site.material_progress() <= site.progress + 0.0001:
			continue
		if score > best_score:
			chosen = site
			best_score = score
	return chosen


func development_priority(site: ConstructionSite) -> float:
	var building_type := site.building_type
	var score := float(BuildingCatalog.era_for(building_type)) * SCORE_ERA_MULTIPLIER
	var population := int(_population_provider.call())
	var campfire_node: Node3D = _campfire_node_getter.call() if _campfire_node_getter.is_valid() else null
	var canteen: Node3D = _canteen_getter.call() if _canteen_getter.is_valid() else null
	if BuildingTypes.is_warehouse(building_type):
		score += SCORE_WAREHOUSE_FIRST if _warehouse_positions.is_empty() else SCORE_WAREHOUSE_LATER
	elif BuildingTypes.is_civic(building_type):
		score += SCORE_CAMPFIRE_FIRST if not is_instance_valid(campfire_node) else SCORE_CAMPFIRE_LATER
	elif BuildingTypes.is_housing(building_type):
		score += SCORE_HOUSING_FIRST if int(_housing_slots_provider.call()) < population else SCORE_HOUSING_LATER
	elif building_type in ["forager_tent", "straw_forager_tent", "tarp_forager_tent", "farm"]:
		score += SCORE_FOOD_FIRST if int(_food_amount_provider.call()) < population * FOOD_POPULATION_RATIO else SCORE_FOOD_LATER
	elif BuildingTypes.is_kitchen(building_type):
		score += SCORE_CANTEEN_FIRST if not is_instance_valid(canteen) else SCORE_CANTEEN_LATER
	elif building_type == "sawmill":
		score += SCORE_SAWMILL_FIRST if _sawmill_positions.is_empty() else SCORE_SAWMILL_LATER
	elif building_type in ["gathering_place", "park", "leisure_center"]:
		score += SCORE_LEISURE
	else:
		score += SCORE_DEFAULT
	# Once a project has started receiving stock, preserve the focus and avoid
	# oscillating between equally valuable plans.
	var supplied := 0
	for resource_type in site.delivered_materials:
		supplied += int(site.delivered_materials[resource_type])
	return score + supplied * SCORE_SUPPLIED_BONUS
