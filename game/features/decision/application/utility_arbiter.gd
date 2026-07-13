class_name UtilityArbiter
extends RefCounted

## Deterministic utility selection with centralized hysteresis.

var minimum_utility := 0.001
var stickiness_bonus := 0.08
var switch_margin := 0.03
var _goals: Array[AICitizenGoal] = []


func configure(goals: Array[AICitizenGoal]) -> void:
	_goals = goals.duplicate()


func choose(
	snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	blackboard: AIBlackboard,
	current_goal_id: StringName = &""
) -> ArbitrationResult:
	var best_goal: AICitizenGoal
	var best_utility := minimum_utility
	var current_goal: AICitizenGoal
	var current_utility := 0.0
	for goal in _goals:
		var utility := maxf(0.0, goal.score(snapshot, citizen, order, blackboard))
		if goal.id == current_goal_id and utility >= minimum_utility:
			current_goal = goal
			current_utility = utility
			utility += stickiness_bonus
		if utility > best_utility:
			best_goal = goal
			best_utility = utility
	if current_goal != null and best_goal != current_goal:
		var challenger_utility := best_utility
		if challenger_utility < current_utility + stickiness_bonus + switch_margin:
			return ArbitrationResult.new(current_goal, current_utility + stickiness_bonus)
	return ArbitrationResult.new(best_goal, best_utility if best_goal != null else 0.0)


func goal_count() -> int:
	return _goals.size()
