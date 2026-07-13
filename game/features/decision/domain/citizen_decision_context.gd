class_name CitizenDecisionContext
extends RefCounted

enum Intent { WORK }

var is_night := false
var can_assign_work := false


func is_goal_valid(intent: int) -> bool:
	match intent:
		Intent.WORK: return not is_night and can_assign_work
	return false


func priority_for(intent: int) -> int:
	match intent:
		Intent.WORK: return 10
	return 0
