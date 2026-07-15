class_name CleaningGoal
extends AICitizenGoal

const CleaningWorkStepScript = preload("res://game/features/decision/domain/behavior/cleaning_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"cleaning")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"cleaning":
		return 0.0
	if order.issuer == &"player":
		return clampf(order.priority, 0.0, 1.0)
	return 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	var move_target: Variant = order.target_position if order != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target),
		CleaningWorkStepScript.new(),
	]), false, "Collect resource pile to warehouse")
