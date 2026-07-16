class_name ExcavationGoal
extends AICitizenGoal

const ExcavationWorkStepScript = preload("res://game/features/decision/domain/behavior/excavation_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"excavation")
	resumable = false
	blocks_personal_needs = true


func score(snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"excavation":
		return 0.0
	if wellbeing_too_low_for_work(snapshot):
		return 0.0
	return clampf(order.priority, 0.0, 1.0) if bool(citizen.facts.value(&"work.excavation.worker", false)) else 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	var move_target: Variant = order.target_position if order != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	var site_id := order.payload.value(&"work.site_id", &"") as StringName
	if site_id == &"":
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target, 0.25, [&"excavation.site", site_id]),
		ExcavationWorkStepScript.new(),
	]), false, "Excavate resource layer")
