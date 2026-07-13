class_name ReserveWorkGoal
extends AICitizenGoal

const ReserveWorkStepScript = preload("res://game/features/decision/domain/behavior/reserve_work_step.gd")


func _init() -> void:
	super(&"reserve_work")
	resumable = false


func score(_snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"reserve_work":
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, _order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	return BehaviorTask.new(id, ReserveWorkStepScript.new(), false, "Execute employment officer reserve assignment")
