class_name ConstructionGoal
extends AICitizenGoal

const ConstructionWorkStepScript = preload("res://game/features/decision/domain/behavior/construction_work_step.gd")


func _init() -> void:
	super(&"construction")
	# Construction progress is shared by all assigned builders. An interrupted
	# resident may be replaced immediately by the next director publication.
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind not in [&"construction", &"demolition"]:
		return 0.0
	if not bool(citizen.facts.value(&"work.construction.worker", false)):
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, ConstructionWorkStepScript.new(), false, "Build or demolish site")
