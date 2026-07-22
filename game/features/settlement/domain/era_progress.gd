class_name EraProgress
extends RefCounted

## Tracks the current era and provides era-scoped resource lists.
## Era values match SettlementState.Era: TENT=0, EARTH=1, CLAY=2, WOOD=3, STONE=4, BRICK=5.

## Resources available in each era. Each era cumulatively adds new resources.
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const ERA_RESOURCES = ResourceIds.ERA_RESOURCES

var era: int = 0


static func resources_for_era(p_era: int) -> Array[String]:
	var list: Array[String] = []
	for key in ERA_RESOURCES.get(p_era, []):
		list.append(str(key))
	return list


func era_resources() -> Array[String]:
	return resources_for_era(era)


func can_advance_to(next_era: int, population: int, housing_slots: int, state_context: Dictionary) -> bool:
	# state_context keys: has_tools(Array), is_research_completed(String), has_building(String), available_amount(String), money, trade_sales
	var has_tools_fn: Callable = state_context.get("has_tools", Callable())
	var is_research_completed_fn: Callable = state_context.get("is_research_completed", Callable())
	var has_building_fn: Callable = state_context.get("has_building", Callable())
	var available_amount_fn: Callable = state_context.get("available_amount", Callable())
	var money_val: int = state_context.get("money", 0)
	var trade_sales_val: int = state_context.get("trade_sales", 0)

	match next_era:
		1: # EARTH
			return era == 0 and has_tools_fn.call(["axe", "hand_saw", "shovel", "bucket"]) and is_research_completed_fn.call("earth_buildings")
		2: # CLAY
			return era == 1 and has_building_fn.call("earth_assembly") and has_building_fn.call("smithy") and has_building_fn.call("earth_market") and housing_slots >= population and available_amount_fn.call("clay") >= 5 and money_val >= 5 and trade_sales_val >= 3 and has_tools_fn.call(["hoe"]) and has_building_fn.call("toilet_earth_lvl3")
		3: # WOOD
			return era == 2 and has_building_fn.call("clay_lodge") and has_building_fn.call("clay_market") and available_amount_fn.call("water") >= population and available_amount_fn.call("logs") >= 10 and money_val >= 10 and has_building_fn.call("toilet_clay_lvl3")
		4: # STONE
			return era == 3 and has_building_fn.call("wood_town_hall") and has_building_fn.call("wood_market") and money_val >= 15 and has_tools_fn.call(["pickaxe"]) and has_building_fn.call("house_lvl3") and has_building_fn.call("toilet_wood_lvl3")
		5: # BRICK
			return era == 4 and has_building_fn.call("stone_prefecture") and has_building_fn.call("stone_market") and has_building_fn.call("masonry_workshop") and available_amount_fn.call("stone") >= 20 and money_val >= 20 and has_building_fn.call("toilet_stone_lvl3")
	return false


func advance_era(next_era: int, population: int, housing_slots: int, state_context: Dictionary, refresh_warehouses_fn: Callable) -> bool:
	if not can_advance_to(next_era, population, housing_slots, state_context):
		return false
	era = next_era
	refresh_warehouses_fn.call()
	return true

