class_name SleepGoal
extends AICitizenGoal

const SleepAtHomeStepScript = preload("res://game/features/decision/domain/behavior/sleep_at_home_step.gd")


const ACTIVE_GOAL_BLACKBOARD_KEY := &"brain.active_goal_id"


func _init() -> void:
	super(&"sleep")
	# Personal needs are short trips; if interrupted they should be rebuilt
	# from current facts instead of resuming a stale trip.
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	blackboard: AIBlackboard
) -> float:
	if citizen == null:
		return 0.0
	if not bool(citizen.facts.value(&"needs.should_sleep", false)):
		return 0.0
	if not bool(citizen.facts.value(&"needs.has_home", false)):
		return 0.0
	if blackboard != null and blackboard.value(ACTIVE_GOAL_BLACKBOARD_KEY, &"") == id:
		return 1.0
	if not bool(citizen.facts.value(&"needs.can_start_sleep", false)):
		return 0.0
	return 1.0


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, SleepAtHomeStepScript.new(), true, "Sleep at home")
