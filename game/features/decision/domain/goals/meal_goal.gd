class_name MealGoal
extends AICitizenGoal

const EatAtCanteenStepScript = preload("res://game/features/decision/domain/behavior/eat_at_canteen_step.gd")


func _init() -> void:
	super(&"meal")
	# Personal needs are short trips; if interrupted they should be rebuilt
	# from current facts instead of resuming a stale trip.
	resumable = false


const ACTIVE_GOAL_BLACKBOARD_KEY := &"brain.active_goal_id"


func score(
	snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	blackboard: AIBlackboard
) -> float:
	if citizen == null:
		return 0.0
	if not bool(citizen.facts.value(&"needs.meal_requested", false)):
		return 0.0
	if blackboard != null and blackboard.value(ACTIVE_GOAL_BLACKBOARD_KEY, &"") == id:
		return 0.9
	if not bool(citizen.facts.value(&"needs.can_start_meal", false)):
		return 0.0
	return 0.9


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, EatAtCanteenStepScript.new(), true, "Eat at canteen")
