class_name FarmingGoal
extends AICitizenGoal

const FarmingWorkStepScript = preload("res://game/features/decision/domain/behavior/farming_work_step.gd")


func _init() -> void:
	super(&"farming")
	# A personal need cancels the current production cycle. The provider issues a
	# fresh order after the resident becomes available again.
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind != &"farming":
		return 0.0
	if not bool(citizen.facts.value(&"work.farming.worker", false)):
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, FarmingWorkStepScript.new(), false, "Produce farm food")
