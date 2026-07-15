class_name RestGoal
extends AICitizenGoal

const RestAtLeisureStepScript = preload("res://game/features/decision/domain/behavior/rest_at_leisure_step.gd")


const ACTIVE_GOAL_BLACKBOARD_KEY := &"brain.active_goal_id"


func _init() -> void:
	super(&"rest")
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	blackboard: AIBlackboard
) -> float:
	if citizen == null or not bool(citizen.facts.value(&"needs.rest_requested", false)):
		return 0.0
	if blackboard != null and blackboard.value(ACTIVE_GOAL_BLACKBOARD_KEY, &"") == id:
		return 0.35
	return 0.35 if bool(citizen.facts.value(&"needs.can_start_rest", false)) else 0.0


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, RestAtLeisureStepScript.new(), true, "Rest at leisure")
