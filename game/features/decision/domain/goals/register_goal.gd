class_name RegisterGoal
extends AICitizenGoal

const RegisterStepScript = preload("res://game/features/decision/domain/behavior/register_step.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const SequenceStepScript = preload("res://game/features/decision/domain/behavior/sequence_step.gd")


func _init() -> void:
	super(&"register")
	resumable = false
	blocks_personal_needs = true


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order == null or order.kind != &"register":
		return 0.0
	
	var worker_data: Dictionary = citizen.facts.value(&"workforce.worker_data", {})
	if worker_data.is_empty() or worker_data.get("workforce_status") != "unregistered":
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
		RegisterStepScript.new(),
	]), false, "Go to employment center and register")
