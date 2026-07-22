class_name ForestryGoal
extends "res://game/features/decision/domain/goals/work_goal_base.gd"

const ForestryWorkStepScript = preload("res://game/features/decision/domain/behavior/forestry_work_step.gd")


func _init() -> void:
	super(&"forestry", &"work.forestry.worker", "Harvest tree for sawmill")


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	var move_target: Variant = order.payload.value(&"work.tree_access", Vector3.INF) if order != null and order.payload != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	var tree_id := order.payload.value(&"work.tree_id", &"") as StringName
	if tree_id == &"":
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target, 0.25, [&"forestry.tree", tree_id]),
		ForestryWorkStepScript.new(),
	]), false, work_description)
