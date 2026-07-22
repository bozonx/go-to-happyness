class_name EquipmentState
extends RefCounted

## Tracks owned tools, tool usage counters, and special equipment (gloves, flint).

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

const TENT_STARTING_EQUIPMENT := {
	"flint_steel": {"owned": true},
	ResourceIds.CONSTRUCTION_GLOVES: {"sets": 1, "active_durability": 100.0},
}

var tools := {
	"axe": false, "hand_saw": false, "shovel": false,
	"bucket": false, "hoe": false, "pickaxe": false,
}
var tool_uses := {}
var equipment: Dictionary = TENT_STARTING_EQUIPMENT.duplicate(true)


func reset() -> void:
	tools = {
		"axe": false, "hand_saw": false, "shovel": false,
		"bucket": false, "hoe": false, "pickaxe": false,
	}
	tool_uses = {}
	equipment = TENT_STARTING_EQUIPMENT.duplicate(true)


func has_tools(required: Array) -> bool:
	for tool_id in required:
		if not bool(tools.get(tool_id, false)):
			return false
	return true


func buy_tool(tool_id: String, price: int, money: int) -> bool:
	if not tools.has(tool_id) or bool(tools[tool_id]) or money < price:
		return false
	tools[tool_id] = true
	return true


func construction_gloves_available(stored_gloves_amount: int) -> bool:
	if int(equipment.get(ResourceIds.CONSTRUCTION_GLOVES, {}).get("sets", 0)) > 0:
		return true
	return stored_gloves_amount > 0


func wear_construction_gloves(wear_amount: float, take_from_storage_fn: Callable) -> bool:
	var gloves: Dictionary = equipment.get(ResourceIds.CONSTRUCTION_GLOVES, {})
	if int(gloves.get("sets", 0)) <= 0:
		if take_from_storage_fn.call():
			gloves = equipment.get(ResourceIds.CONSTRUCTION_GLOVES, {})
		else:
			return false
	gloves["active_durability"] = float(gloves.get("active_durability", 100.0)) - wear_amount
	while float(gloves["active_durability"]) <= 0.0 and int(gloves.get("sets", 0)) > 0:
		gloves["sets"] = int(gloves["sets"]) - 1
		gloves["active_durability"] = float(gloves["active_durability"]) + 100.0
	if int(gloves["sets"]) <= 0:
		if take_from_storage_fn.call():
			gloves = equipment.get(ResourceIds.CONSTRUCTION_GLOVES, {})
		else:
			gloves["active_durability"] = 0.0
	equipment[ResourceIds.CONSTRUCTION_GLOVES] = gloves
	return int(gloves.get("sets", 0)) > 0


func take_construction_gloves_from_storage(stored_gloves_amount: int) -> bool:
	if stored_gloves_amount <= 0:
		return false
	var gloves: Dictionary = equipment.get(ResourceIds.CONSTRUCTION_GLOVES, {})
	gloves["sets"] = int(gloves.get("sets", 0)) + 1
	if float(gloves.get("active_durability", 0.0)) <= 0.0:
		gloves["active_durability"] = 100.0
	equipment[ResourceIds.CONSTRUCTION_GLOVES] = gloves
	return true

