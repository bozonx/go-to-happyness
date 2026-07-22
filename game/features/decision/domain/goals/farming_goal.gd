class_name FarmingGoal
extends "res://game/features/decision/domain/goals/work_goal_base.gd"

const FarmingWorkStepScript = preload("res://game/features/decision/domain/behavior/farming_work_step.gd")


func _init() -> void:
	super(&"farming", &"work.farming.worker", "Produce farm food")


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
		FarmingWorkStepScript.new(),
	]), false, work_description)
