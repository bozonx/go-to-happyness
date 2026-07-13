class_name ArbitrationResult
extends RefCounted

var goal: AICitizenGoal
var utility: float


func _init(next_goal: AICitizenGoal = null, next_utility: float = 0.0) -> void:
	goal = next_goal
	utility = next_utility
