extends "res://game/features/decision/domain/citizen_goal.gd"

const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")

var fact_key: StringName
var work_description: String


func _init(goal_id: StringName = &"", fact_permission_key: StringName = &"", desc: String = "") -> void:
	super(goal_id)
	resumable = false
	fact_key = fact_permission_key
	work_description = desc


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind != id:
		return 0.0
	if fact_key != &"" and not bool(citizen.facts.value(fact_key, false)):
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func extract_target_position(order: CitizenOrder) -> Vector3:
	if order == null or not (order.target_position is Vector3) or order.target_position == Vector3.INF:
		return Vector3.INF
	return order.target_position
