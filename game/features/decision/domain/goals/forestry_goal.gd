class_name ForestryGoal
extends AICitizenGoal

const ForestryWorkStepScript = preload("res://game/features/decision/domain/behavior/forestry_work_step.gd")


func _init() -> void:
	super(&"forestry")
	# A personal need cancels the current cycle and releases its tree. The director
	# will publish a fresh order after the citizen becomes available again.
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind != &"forestry":
		return 0.0
	if not bool(citizen.facts.value(&"work.forestry.worker", false)):
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, ForestryWorkStepScript.new(), false, "Harvest tree for sawmill")
