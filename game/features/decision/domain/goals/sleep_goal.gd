class_name SleepGoal
extends AICitizenGoal

const SleepAtHomeStepScript = preload("res://game/features/decision/domain/behavior/sleep_at_home_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


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
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	var home_position: Variant = citizen.facts.value(&"needs.home_position", Vector3.INF)
	if not (home_position is Vector3) or home_position == Vector3.INF:
		return null
	var approach := MoveToStepScript.new(home_position)
	var sleep := SleepAtHomeStepScript.new()
	return BehaviorTask.new(id, SequenceStepScript.new([approach, sleep]), true, "Sleep at home")
