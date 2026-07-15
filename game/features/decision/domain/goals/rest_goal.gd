class_name RestGoal
extends AICitizenGoal

const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const RelaxAtPositionStepScript = preload("res://game/features/decision/domain/behavior/relax_at_position_step.gd")


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
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	if citizen == null:
		return null
	var position: Variant = citizen.facts.value(&"needs.rest_position", Vector3.INF)
	if not (position is Vector3) or position == Vector3.INF:
		return null
	var sequence := SequenceStep.new([
		MoveToStepScript.new(position as Vector3, 0.25),
		RelaxAtPositionStepScript.new(),
	])
	return BehaviorTask.new(id, sequence, false, "Rest at leisure")
