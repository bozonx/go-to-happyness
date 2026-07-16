class_name BehaviorTask
extends RefCounted

var goal_id: StringName
var root: BehaviorStep
var order_id: int
## Immutable assignment captured when the task starts. Steps must execute against
## this order instead of a later board publication for another target.
var order: CitizenOrder
var resumable: bool
var label: String
var failure_reason := BehaviorStep.FailureReason.NONE
## Hard watchdog for actuator actions that otherwise keep returning RUNNING.
var max_run_seconds := 180.0
var elapsed_seconds := 0.0
## Optional `(BehaviorContext) -> bool` predicate. Checked before a suspended task
## resumes: if the world moved on (target claimed, order expired, tree felled) the
## stale task is dropped instead of resumed, letting the arbiter build a fresh one.
var guard: Callable


func is_still_valid(context: BehaviorContext) -> bool:
	return invalid_reason(context) == BehaviorStep.FailureReason.NONE


func invalid_reason(context: BehaviorContext) -> BehaviorStep.FailureReason:
	if context == null or context.snapshot == null:
		return BehaviorStep.FailureReason.CONTEXT_INVALID
	if order != null:
		if order.is_expired(context.snapshot.simulation_seconds):
			return BehaviorStep.FailureReason.ORDER_EXPIRED
		if context.order == null or context.order.id != order_id:
			return BehaviorStep.FailureReason.ORDER_CHANGED
	elif order_id != 0:
		# Compatibility for manually assembled tasks that do not own an order.
		if context.order == null or context.order.id != order_id:
			return BehaviorStep.FailureReason.ORDER_CHANGED
	if guard.is_valid() and not bool(guard.call(context)):
		return BehaviorStep.FailureReason.GUARD_REJECTED
	return BehaviorStep.FailureReason.NONE


func _init(
	next_goal_id: StringName = &"",
	next_root: BehaviorStep = null,
	next_resumable: bool = true,
	next_label: String = ""
) -> void:
	goal_id = next_goal_id
	root = next_root
	resumable = next_resumable
	label = next_label
	order_id = 0
	order = null
