class_name CleaningGoal
extends AICitizenGoal

const CleaningWorkStepScript = preload("res://game/features/decision/domain/behavior/cleaning_work_step.gd")


func _init() -> void:
	super(&"cleaning")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"cleaning":
		return 0.0
	if order.issuer == &"player":
		return clampf(order.priority, 0.0, 1.0)
	return 0.0


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, _order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	return BehaviorTask.new(id, CleaningWorkStepScript.new(), false, "Collect resource pile to warehouse")
