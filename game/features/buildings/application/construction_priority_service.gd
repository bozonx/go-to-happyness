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
var _campfire_node: Node3D
var _canteen: Node3D
var _population_provider: Callable
var _housing_slots_provider: Callable
var _food_amount_provider: Callable


func configure(
	construction_sites: Array[ConstructionSite],
	warehouse_positions: Array[Vector3],
	sawmill_positions: Array[Vector3],
	campfire_node: Node3D,
	canteen: Node3D,
	population_provider: Callable,
	housing_slots_provider: Callable,
	food_amount_provider: Callable
) -> void:
	_construction_sites = construction_sites
	_warehouse_positions = warehouse_positions
	_sawmill_positions = sawmill_positions
	_campfire_node = campfire_node
	_canteen = canteen
	_population_provider = population_provider
	_housing_slots_provider = housing_slots_provider
	_food_amount_provider = food_amount_provider


func preferred_construction_site() -> ConstructionSite:
	var chosen: ConstructionSite = null
	var best_score := -INF
	var waiting_chosen: ConstructionSite = null
	var waiting_score := -INF
	for site in _construction_sites:
		if site == null or not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
			continue
		var score := development_priority(site)
		if score > waiting_score:
			waiting_chosen = site
			waiting_score = score
		# A builder can only advance up to the fraction of materials already on
		# site. Prefer any project with work available over a higher-priority site
		# where everyone would only wait for a courier.
		if site.material_progress() <= site.progress + 0.0001:
			continue
		if score > best_score:
			chosen = site
			best_score = score
	return chosen if chosen != null else waiting_chosen


func development_priority(site: ConstructionSite) -> float:
	var building_type := site.building_type
	var score := float(BuildingCatalog.era_for(building_type)) * SCORE_ERA_MULTIPLIER
	var population := int(_population_provider.call())
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse":
			score += SCORE_WAREHOUSE_FIRST if _warehouse_positions.is_empty() else SCORE_WAREHOUSE_LATER
		"campfire", "campfire_lvl2", "campfire_lvl3":
			score += SCORE_CAMPFIRE_FIRST if not is_instance_valid(_campfire_node) else SCORE_CAMPFIRE_LATER
		"tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "brick_house":
			score += SCORE_HOUSING_FIRST if int(_housing_slots_provider.call()) < population else SCORE_HOUSING_LATER
		"forager_tent", "straw_forager_tent", "tarp_forager_tent", "farm":
			score += SCORE_FOOD_FIRST if int(_food_amount_provider.call()) < population * FOOD_POPULATION_RATIO else SCORE_FOOD_LATER
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			score += SCORE_CANTEEN_FIRST if not is_instance_valid(_canteen) else SCORE_CANTEEN_LATER
		"sawmill":
			score += SCORE_SAWMILL_FIRST if _sawmill_positions.is_empty() else SCORE_SAWMILL_LATER
		"gathering_place", "park", "leisure_center":
			score += SCORE_LEISURE
		_:
			score += SCORE_DEFAULT
	# Once a project has started receiving stock, preserve the focus and avoid
	# oscillating between equally valuable plans.
	var supplied := 0
	for resource_type in site.delivered_materials:
		supplied += int(site.delivered_materials[resource_type])
	return score + supplied * SCORE_SUPPLIED_BONUS
