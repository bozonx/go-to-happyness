class_name GatheringGoal
extends AICitizenGoal

const GatheringWorkStepScript = preload("res://game/features/decision/domain/behavior/gathering_work_step.gd")


func _init() -> void:
	super(&"gathering")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"gathering":
		return 0.0
	if order.issuer == &"player":
		return clampf(order.priority, 0.0, 1.0)
	return clampf(order.priority, 0.0, 1.0) if bool(citizen.facts.value(&"work.gathering.worker", false)) else 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, _order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	return BehaviorTask.new(id, GatheringWorkStepScript.new(), false, "Gather resource for warehouse")
