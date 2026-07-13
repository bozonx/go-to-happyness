class_name SleepGoal
extends AICitizenGoal

const SleepAtHomeStepScript = preload("res://game/features/decision/domain/behavior/sleep_at_home_step.gd")


func _init() -> void:
	super(&"sleep")


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null:
		return 0.0
	if not bool(citizen.facts.value(&"needs.should_sleep", false)):
		return 0.0
	if not bool(citizen.facts.value(&"needs.has_home", false)):
		return 0.0
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
