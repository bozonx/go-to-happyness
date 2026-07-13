class_name MealGoal
extends AICitizenGoal

const EatAtCanteenStepScript = preload("res://game/features/decision/domain/behavior/eat_at_canteen_step.gd")


func _init() -> void:
	super(&"meal")


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null:
		return 0.0
	if not bool(citizen.facts.value(&"needs.meal_requested", false)):
		return 0.0
	if not bool(citizen.facts.value(&"needs.can_start_meal", false)):
		return 0.0
	return 0.9


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return BehaviorTask.new(id, EatAtCanteenStepScript.new(), true, "Eat at canteen")
