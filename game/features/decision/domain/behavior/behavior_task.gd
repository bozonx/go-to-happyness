class_name BehaviorTask
extends RefCounted

var goal_id: StringName
var root: BehaviorStep
var order_id: int
var resumable: bool
var label: String
## Optional `(BehaviorContext) -> bool` predicate. Checked before a suspended task
## resumes: if the world moved on (target claimed, order expired, tree felled) the
## stale task is dropped instead of resumed, letting the arbiter build a fresh one.
var guard: Callable


func is_still_valid(context: BehaviorContext) -> bool:
	if context == null or context.snapshot == null:
		return false
	if order_id != 0:
		if context.order == null or context.order.id != order_id:
			return false
		if context.order.is_expired(context.snapshot.simulation_seconds):
			return false
	return not guard.is_valid() or bool(guard.call(context))


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
