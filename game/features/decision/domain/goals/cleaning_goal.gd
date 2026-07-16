class_name CleaningGoal
extends AICitizenGoal

const CleaningWorkStepScript = preload("res://game/features/decision/domain/behavior/cleaning_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"cleaning")
	resumable = false
	blocks_personal_needs = true


func score(snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"cleaning":
		return 0.0
	if wellbeing_too_low_for_work(snapshot):
		return 0.0
	if order.issuer == &"player":
		return clampf(order.priority, 0.0, 1.0)
	return 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	var move_target: Variant = order.payload.value(&"target.access_position", Vector3.INF) if order != null and order.payload != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	var source_id := order.payload.value(&"work.source_id", &"") as StringName
	if source_id == &"":
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target, 0.25, [&"cleaning.pile", source_id]),
		CleaningWorkStepScript.new(),
	]), false, "Collect resource pile to warehouse")
