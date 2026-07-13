class_name RegisterGoal
extends AICitizenGoal

const RegisterStepScript = preload("res://game/features/decision/domain/behavior/register_step.gd")


func _init() -> void:
	super(&"register")
	resumable = false


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
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, RegisterStepScript.new(), false, "Go to employment center and register")
