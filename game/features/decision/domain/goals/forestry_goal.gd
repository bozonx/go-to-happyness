class_name ForestryGoal
extends AICitizenGoal

const ForestryWorkStepScript = preload("res://game/features/decision/domain/behavior/forestry_work_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"forestry")
	# A personal need cancels the current cycle and releases its tree. The director
	# will publish a fresh order after the citizen becomes available again.
	resumable = false
	blocks_personal_needs = true


func score(
	snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind != &"forestry":
		return 0.0
	if wellbeing_too_low_for_work(snapshot):
		return 0.0
	if not bool(citizen.facts.value(&"work.forestry.worker", false)):
		return 0.0
	return clampf(order.priority, 0.0, 1.0)


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	var move_target: Variant = order.payload.value(&"work.tree_access", Vector3.INF) if order != null and order.payload != null else Vector3.INF
	if not (move_target is Vector3) or move_target == Vector3.INF:
		return null
	var tree_id := order.payload.value(&"work.tree_id", &"") as StringName
	if tree_id == &"":
		return null
	return BehaviorTask.new(id, SequenceStepScript.new([
		MoveToStepScript.new(move_target, 0.25, [&"forestry.tree", tree_id]),
		ForestryWorkStepScript.new(),
	]), false, "Harvest tree for sawmill")
