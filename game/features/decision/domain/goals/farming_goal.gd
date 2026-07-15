class_name FarmingGoal
extends AICitizenGoal

const FarmingWorkStepScript = preload("res://game/features/decision/domain/behavior/farming_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


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
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	var move_target: Variant = order.target_position if order != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target),
		FarmingWorkStepScript.new(),
	]), false, "Produce farm food")
