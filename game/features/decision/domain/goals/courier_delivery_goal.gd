class_name CourierDeliveryGoal
extends AICitizenGoal

const CourierDeliveryStepScript = preload("res://game/features/decision/domain/behavior/courier_delivery_step.gd")

func _init() -> void:
	super(&"courier_delivery")
	resumable = false

func score(snapshot: WorldSnapshot, citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> float:
	if citizen == null or order == null or order.kind != &"courier_delivery":
		return 0.0
	if wellbeing_too_low_for_work(snapshot):
		return 0.0
	if not bool(citizen.facts.value(&"work.courier.worker", false)):
		return 0.0
	# An in-progress delivery (cargo already reserved) should not be dropped for a
	# personal need; boost it above typical need thresholds.
	if bool(citizen.facts.value(&"work.courier.in_progress", false)):
		return 1.0
	return order.priority

func build_task(_snapshot: WorldSnapshot, _citizen: CitizenSnapshot, order: CitizenOrder, _blackboard: AIBlackboard) -> BehaviorTask:
	if order == null:
		return null
	var task_id: Variant = order.payload.value(&"courier.task_id", &"") if order.payload != null else &""
	if not (task_id is StringName) or task_id == &"":
		return null
	return BehaviorTask.new(id, CourierDeliveryStepScript.new(), false, "Deliver logistics task")
