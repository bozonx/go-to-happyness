class_name ServiceWorkGoal
extends AICitizenGoal

const ServiceWorkStepScript = preload("res://game/features/decision/domain/behavior/service_work_step.gd")


func _init() -> void:
	super(&"service_work")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"service_work":
		return 0.0
	return clampf(order.priority, 0.0, 1.0) if bool(citizen.facts.value(&"work.service.worker", false)) else 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, _order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	return BehaviorTask.new(id, ServiceWorkStepScript.new(), false, "Run permanent service workplace")
