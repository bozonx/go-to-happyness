class_name UtilityArbiter
extends RefCounted

## Deterministic utility selection with centralized hysteresis.

var minimum_utility := 0.001
var stickiness_bonus := 0.08
var switch_margin := 0.03
## How long a failed goal remains unavailable before only a critical need may
## select it again (simulation seconds).
var cooldown_window := 6.0
## A goal may bypass its cooldown only when it reaches an explicitly critical
## utility. Scores are normalized to [0, 1] by concrete goals.
var cooldown_emergency_utility := 0.95
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
	var simulation_seconds := snapshot.simulation_seconds if snapshot != null else 0.0
	for goal in _goals:
		var raw_utility := goal.score(snapshot, citizen, order, blackboard)
		if not is_finite(raw_utility):
			continue
		var utility := clampf(raw_utility, 0.0, 1.0)
		if blackboard != null:
			var penalty := blackboard.cooldown_penalty(goal.id, simulation_seconds, cooldown_window)
			if penalty > 0.0 and utility < cooldown_emergency_utility:
				continue
			if penalty > 0.0:
				# A critical need must win on its actual severity, not on a damped value.
				utility = maxf(utility, cooldown_emergency_utility)
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
