class_name FactoryWorkGoal
extends AICitizenGoal

const FactoryWorkStepScript = preload("res://game/features/decision/domain/behavior/factory_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"factory_work")
	resumable = false
	blocks_personal_needs = true


func score(snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"factory_work":
		return 0.0
	if wellbeing_too_low_for_work(snapshot):
		return 0.0
	return clampf(order.priority, 0.0, 1.0) if bool(citizen.facts.value(&"work.factory.worker", false)) else 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	var move_target: Variant = order.target_position if order != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target),
		FactoryWorkStepScript.new(),
	]), false, "Staff factory production")
