class_name ServiceWorkGoal
extends "res://game/features/decision/domain/goals/work_goal_base.gd"

const ServiceWorkStepScript = preload("res://game/features/decision/domain/behavior/service_work_step.gd")


func _init() -> void:
	super(&"service_work", &"work.service.worker", "Run assigned service post")


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	var move_target := extract_target_position(order)
	if move_target == Vector3.INF:
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target),
		ServiceWorkStepScript.new(),
	]), false, work_description)
