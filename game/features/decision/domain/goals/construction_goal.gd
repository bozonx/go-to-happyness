class_name ConstructionGoal
extends AICitizenGoal

const ConstructionWorkStepScript = preload("res://game/features/decision/domain/behavior/construction_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"construction")
	# Construction progress is shared by all assigned builders. An interrupted
	# resident may be replaced immediately by the next director publication.
	resumable = false


func score(
	snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind not in [&"construction", &"demolition"]:
		return 0.0
	if order.issuer == &"player":
		return clampf(order.priority, 0.0, 1.0)
	if not bool(citizen.facts.value(&"work.construction.worker", false)):
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	var move_target: Variant = order.target_position if order != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target),
		ConstructionWorkStepScript.new(),
	]), false, "Build or demolish site")
