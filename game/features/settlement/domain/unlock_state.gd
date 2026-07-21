class_name UnlockState
extends RefCounted

## Tracks which systems and building upgrade levels have been unlocked
## through research or era progression.

var unlocked_systems := {
	"official": false,
	"outside_work_bonus": false,
}
var unlocked_building_levels := {
	"tent": false,
	"cook_campfire": false,
	"campfire_lvl2": false,
	"campfire_lvl3": false,
	"gathering_place": false,
	"cook_campfire_lvl2": false,
	"cook_campfire_lvl3": false,
	"forager_tent": false,
	"materials_yard": false,
	"craft_tent": false,
	"dew_collector": false,
	"straw_tent": false,
	"tarp_tent": false,
	"straw_forager_tent": false,
	"tarp_forager_tent": false,
	"straw_materials_yard": false,
	"tarp_materials_yard": false,
	"straw_craft_tent": false,
	"tarp_craft_tent": false,
	"advanced_dew_collector": false,
	"straw_warehouse": false,
	"tarp_warehouse": false,
	"straw_trade_tent": false,
	"tarp_trade_tent": false,
	"toilet_tent": false,
	"tarp_toilet": false,
	"house": false,
	"house_lvl2": false,
	"house_lvl3": false,
	"dugout_kitchen": false,
	"clay_bakery": false,
	"canteen": false,
	"stone_tavern": false,
	"brick_restaurant": false,
	"toilet_earth_lvl2": false,
	"toilet_earth_lvl3": false,
	"toilet_clay_lvl2": false,
	"toilet_clay_lvl3": false,
	"toilet_wood_lvl2": false,
	"toilet_wood_lvl3": false,
	"toilet_stone_lvl2": false,
	"toilet_stone_lvl3": false,
	"toilet_brick_lvl2": false,
	"toilet_brick_lvl3": false,
}


func reset() -> void:
	for system_id in unlocked_systems.keys():
		unlocked_systems[system_id] = false
	for building_type in unlocked_building_levels.keys():
		unlocked_building_levels[building_type] = _tent_start_unlock_for(building_type)


func _tent_start_unlock_for(building_type: String) -> bool:
	if building_type in ["tent", "cook_campfire", "dew_collector"]:
		return true
	return false


func is_building_unlocked(building_type: String, era: int) -> bool:
	if building_type == "settlement_flag":
		return true
	if building_type == "warehouse":
		return true
	if building_type == "campfire":
		return true
	if unlocked_building_levels.has(building_type):
		return bool(unlocked_building_levels.get(building_type, false))
	return era >= BuildingCatalog.era_for(building_type)


func is_research_completed(research_id: String) -> bool:
	if not BuildingCatalog.RESEARCH_TECHS.has(research_id):
		return false
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[research_id]
	var target_system := str(tech.get("target_system", ""))
	if not target_system.is_empty():
		return bool(unlocked_systems.get(target_system, false))
	var target_buildings: Array = tech.get("target_buildings", [])
	if not target_buildings.is_empty():
		for building_type in target_buildings:
			if not bool(unlocked_building_levels.get(building_type, false)):
				return false
		return true
	var target_building := str(tech.get("target_building", ""))
	return not target_building.is_empty() and bool(unlocked_building_levels.get(target_building, false))


func complete_research(research_id: String) -> String:
	if not BuildingCatalog.RESEARCH_TECHS.has(research_id):
		return ""
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[research_id]
	var target_system := str(tech.get("target_system", ""))
	if not target_system.is_empty():
		unlocked_systems[target_system] = true
		return target_system
	var target_buildings: Array = tech.get("target_buildings", [])
	if not target_buildings.is_empty():
		for building_type in target_buildings:
			unlocked_building_levels[building_type] = true
		return str(target_buildings[0])
	var target_building := str(tech.get("target_building", ""))
	if not target_building.is_empty():
		unlocked_building_levels[target_building] = true
	return target_building
