class_name ExcavationGoal
extends "res://game/features/decision/domain/goals/work_goal_base.gd"

const ExcavationWorkStepScript = preload("res://game/features/decision/domain/behavior/excavation_work_step.gd")


func _init() -> void:
	super(&"excavation", &"work.excavation.worker", "Excavate resource layer")


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	var move_target := extract_target_position(order)
	if move_target == Vector3.INF:
		return null
	var site_id := order.payload.value(&"work.site_id", &"") as StringName
	if site_id == &"":
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target, 0.25, [&"excavation.site", site_id]),
		ExcavationWorkStepScript.new(),
	]), false, work_description)
