class_name ReturnHomeWhenIdleGoal
extends AICitizenGoal

## A permanent employment contract remains valid when its provider has no work
## to publish. Residents with a home wait there for the next work cycle.

const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")

const HOME_ARRIVAL_RADIUS := 0.5


func _init() -> void:
	super(&"return_home_when_idle")
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order != null:
		return 0.0
	if not bool(citizen.facts.value(&"work.permanent.active", false)):
		return 0.0
	if not bool(citizen.facts.value(&"needs.has_home", false)):
		return 0.0
	if not bool(citizen.facts.value(&"needs.home_reachable", true)):
		return 0.0
	var home_position: Variant = citizen.facts.value(&"needs.home_position", Vector3.INF)
	if not (home_position is Vector3) or home_position == Vector3.INF:
		return 0.0
	if citizen.position.distance_to(home_position as Vector3) <= HOME_ARRIVAL_RADIUS:
		return 0.0
	return 0.20


func build_task(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	if citizen == null:
		return null
	var home_position: Variant = citizen.facts.value(&"needs.home_position", Vector3.INF)
	if not (home_position is Vector3) or home_position == Vector3.INF:
		return null
	return BehaviorTask.new(id, MoveToStepScript.new(home_position as Vector3, HOME_ARRIVAL_RADIUS), false, "Return home while work is unavailable")
