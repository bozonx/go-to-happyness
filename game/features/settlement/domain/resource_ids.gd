class_name ResourceIds
extends RefCounted

## Central registry of all resource identifiers used in the game.
## Use these StringName constants instead of raw string literals to prevent
## typos and enable refactor-safe references across the codebase.

const BRANCHES := &"branches"
const GRASS := &"grass"
const WATER := &"water"
const FOOD := &"food"
const HIDES := &"hides"
const GOODS := &"goods"
const LOGS := &"logs"
const WOOD := &"wood"
const SOIL := &"soil"
const CLAY := &"clay"
const BOARDS := &"boards"
const STONE := &"stone"
const BRICKS := &"bricks"
const TARP := &"tarp"
const CONSTRUCTION_GLOVES := &"construction_gloves"

const ALL: Array[StringName] = [
	BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS,
	LOGS, WOOD, SOIL, CLAY, BOARDS, STONE, BRICKS, TARP, CONSTRUCTION_GLOVES
]

## Resources available in each era. Each era cumulatively adds new resources.
## Era values match SettlementState.Era: TENT=0, EARTH=1, CLAY=2, WOOD=3, STONE=4, BRICK=5.
const ERA_RESOURCES: Dictionary = {
	0: [BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS, TARP, CONSTRUCTION_GLOVES],
	1: [BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS, TARP, CONSTRUCTION_GLOVES, SOIL, WOOD],
	2: [BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS, TARP, CONSTRUCTION_GLOVES, SOIL, WOOD, CLAY],
	3: [BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS, TARP, CONSTRUCTION_GLOVES, SOIL, WOOD, CLAY, LOGS, BOARDS],
	4: [BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS, TARP, CONSTRUCTION_GLOVES, SOIL, WOOD, CLAY, LOGS, BOARDS, STONE],
	5: [BRANCHES, GRASS, WATER, FOOD, HIDES, GOODS, TARP, CONSTRUCTION_GLOVES, SOIL, WOOD, CLAY, LOGS, BOARDS, STONE, BRICKS],
}

const STORAGE_WEIGHTS: Dictionary = {
	BRANCHES: 1.0, GRASS: 1.0, WATER: 0.5, FOOD: 1.0,
	HIDES: 1.0, GOODS: 1.0, LOGS: 2.0, WOOD: 2.0,
	SOIL: 1.0, CLAY: 1.0, BOARDS: 1.5, STONE: 2.0, BRICKS: 2.0,
	TARP: 1.0,
	CONSTRUCTION_GLOVES: 1.0,
}


static func resources_for_era(p_era: int) -> Array[String]:
	var list: Array[String] = []
	for key in ERA_RESOURCES.get(p_era, []):
		list.append(str(key))
	return list
