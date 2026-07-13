class_name CitizenDecisionContext
extends RefCounted

enum Intent { EAT, WORK }

var is_night := false
var has_canteen := false
var meal_requested := false
var can_assign_work := false


func is_goal_valid(intent: int) -> bool:
	match intent:
		Intent.EAT: return meal_requested and not is_night and has_canteen
		Intent.WORK: return not is_night and not meal_requested and can_assign_work
	return false


func priority_for(intent: int) -> int:
	match intent:
		Intent.EAT: return 80
		Intent.WORK: return 10
	return 0
