class_name ToiletGoal
extends AICitizenGoal

const RelieveStepScript = preload("res://game/features/decision/domain/behavior/relieve_step.gd")


const ACTIVE_GOAL_BLACKBOARD_KEY := &"brain.active_goal_id"


func _init() -> void:
	super(&"toilet")
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	blackboard: AIBlackboard
) -> float:
	if citizen == null or not bool(citizen.facts.value(&"needs.toilet_requested", false)):
		return 0.0
	var candidates: Array = citizen.facts.value(&"needs.relief_candidates", []) as Array
	if candidates.is_empty():
		return 0.0
	# Slightly above the standard work-order priority (0.82) so that, once the
	# citizen reaches an idle planning point, the pending need is chosen ahead of
	# starting the next work cycle. It cannot interrupt work in progress because
	# needs.can_start_toilet is only true while idle.
	if blackboard != null and blackboard.value(ACTIVE_GOAL_BLACKBOARD_KEY, &"") == id:
		return 0.84
	if not bool(citizen.facts.value(&"needs.can_start_toilet", false)):
		return 0.0
	return 0.84


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, RelieveStepScript.new(), true, "Use toilet")
