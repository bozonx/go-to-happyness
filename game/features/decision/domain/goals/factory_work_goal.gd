class_name FactoryWorkGoal
extends AICitizenGoal

const FactoryWorkStepScript = preload("res://game/features/decision/domain/behavior/factory_work_step.gd")


func _init() -> void:
	super(&"factory_work")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"factory_work":
		return 0.0
	return clampf(order.priority, 0.0, 1.0) if bool(citizen.facts.value(&"work.factory.worker", false)) else 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, _order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	return BehaviorTask.new(id, FactoryWorkStepScript.new(), false, "Staff factory production")
