class_name ParallelStep
extends BehaviorStep

enum SuccessPolicy { ALL, ANY }

var children: Array[BehaviorStep]
var success_policy: SuccessPolicy
var _completed: Dictionary = {}


func _init(
	next_children: Array[BehaviorStep] = [],
	next_success_policy: SuccessPolicy = SuccessPolicy.ALL
) -> void:
	children = next_children.duplicate()
	success_policy = next_success_policy


func _tick(context: BehaviorContext, delta: float) -> Status:
	if children.is_empty():
		return Status.SUCCESS
	var success_count := 0
	for index in range(children.size()):
		if _completed.has(index):
			success_count += 1
			continue
		var status := children[index].run(context, delta)
		if status == Status.FAILURE:
			_cancel_unfinished(context, index)
			return Status.FAILURE
		if status == Status.SUCCESS:
			_completed[index] = true
			success_count += 1
			if success_policy == SuccessPolicy.ANY:
				_cancel_unfinished(context, index)
				return Status.SUCCESS
	return Status.SUCCESS if success_count == children.size() else Status.RUNNING


func _reset() -> void:
	_completed.clear()
	for child in children:
		child.reset()


func _cancel(context: BehaviorContext) -> void:
	for index in range(children.size()):
		if not _completed.has(index):
			children[index].cancel(context)


func _suspend(context: BehaviorContext) -> void:
	for index in range(children.size()):
		if not _completed.has(index):
			children[index].suspend(context)


func _resume(context: BehaviorContext) -> void:
	for index in range(children.size()):
		if not _completed.has(index):
			children[index].resume(context)


func _cancel_unfinished(context: BehaviorContext, except_index: int) -> void:
	for index in range(children.size()):
		if index != except_index and not _completed.has(index):
			children[index].cancel(context)
