class_name EraProgress
extends RefCounted

## Tracks the current era and provides era-scoped resource lists.
## Era values match SettlementState.Era: TENT=0, EARTH=1, CLAY=2, WOOD=3, STONE=4, BRICK=5.

## Resources available in each era. Each era cumulatively adds new resources.
const ERA_RESOURCES := {
	0: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "construction_gloves"],
	1: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "construction_gloves", "soil", "wood"],
	2: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "construction_gloves", "soil", "wood", "clay"],
	3: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "construction_gloves", "soil", "wood", "clay", "logs", "boards"],
	4: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "construction_gloves", "soil", "wood", "clay", "logs", "boards", "stone"],
	5: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "construction_gloves", "soil", "wood", "clay", "logs", "boards", "stone", "bricks"],
}

var era: int = 0


static func resources_for_era(p_era: int) -> Array[String]:
	var list: Array[String] = []
	for key in ERA_RESOURCES.get(p_era, []):
		list.append(str(key))
	return list


func era_resources() -> Array[String]:
	return resources_for_era(era)
