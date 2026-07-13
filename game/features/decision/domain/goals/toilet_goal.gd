class_name ToiletGoal
extends AICitizenGoal

const RelieveStepScript = preload("res://game/features/decision/domain/behavior/relieve_step.gd")


func _init() -> void:
	super(&"toilet")
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or not bool(citizen.facts.value(&"needs.toilet_requested", false)):
		return 0.0
	var candidates: Array = citizen.facts.value(&"needs.relief_candidates", []) as Array
	return 0.82 if not candidates.is_empty() else 0.0


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, RelieveStepScript.new(), true, "Use toilet")
