class_name ToiletGoal
extends AICitizenGoal

const RelieveStepScript = preload("res://game/features/decision/domain/behavior/relieve_step.gd")


const ACTIVE_GOAL_BLACKBOARD_KEY := &"brain.active_goal_id"
const INTERRUPT_UTILITY := 0.94


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
	# High enough to cross the arbiter's stickiness + switch margin above a daily
	# order (0.82), while remaining below critical hunger. The facade keeps this
	# fact disabled for active cargo deliveries and other atomic activities.
	if blackboard != null and blackboard.value(ACTIVE_GOAL_BLACKBOARD_KEY, &"") == id:
		return INTERRUPT_UTILITY
	if not bool(citizen.facts.value(&"needs.can_start_toilet", false)):
		return 0.0
	return INTERRUPT_UTILITY


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, RelieveStepScript.new(), true, "Use toilet")
