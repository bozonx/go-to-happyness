class_name EquipmentState
extends RefCounted

## Tracks owned tools, tool usage counters, and special equipment (gloves, flint).

const TENT_STARTING_EQUIPMENT := {
	"flint_steel": {"owned": true},
	"construction_gloves": {"sets": 1, "active_durability": 100.0},
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
