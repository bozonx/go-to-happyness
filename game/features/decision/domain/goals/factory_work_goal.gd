class_name FactoryWorkGoal
extends "res://game/features/decision/domain/goals/work_goal_base.gd"

const FactoryWorkStepScript = preload("res://game/features/decision/domain/behavior/factory_work_step.gd")


func _init() -> void:
	super(&"factory_work", &"work.factory.worker", "Staff factory production")


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
		FactoryWorkStepScript.new(),
	]), false, work_description)
