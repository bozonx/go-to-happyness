class_name ExcavationGoal
extends AICitizenGoal

const ExcavationWorkStepScript = preload("res://game/features/decision/domain/behavior/excavation_work_step.gd")


func _init() -> void:
	super(&"excavation")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"excavation":
		return 0.0
	return clampf(order.priority, 0.0, 1.0) if bool(citizen.facts.value(&"work.excavation.worker", false)) else 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, _order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	return BehaviorTask.new(id, ExcavationWorkStepScript.new(), false, "Excavate resource layer")
