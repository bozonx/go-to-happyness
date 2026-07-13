class_name BehaviorRunner
extends RefCounted

## Executes one task and retains resumable tasks when a higher-utility goal
## interrupts them. Completed interrupt tasks automatically resume the prior one.

signal task_started(task: BehaviorTask)
signal task_finished(task: BehaviorTask, status: BehaviorStep.Status)
signal task_resumed(task: BehaviorTask)

var active_task: BehaviorTask
var _suspended: Array[BehaviorTask] = []


func start(task: BehaviorTask, context: BehaviorContext) -> bool:
	if task == null or task.root == null:
		return false
	_cancel_suspended_goal(task.goal_id, context)
	if active_task != null:
		if active_task.goal_id == task.goal_id:
			active_task.root.cancel(context)
		elif active_task.resumable:
			active_task.root.suspend(context)
			_suspended.append(active_task)
		else:
			active_task.root.cancel(context)
	active_task = task
	active_task.root.reset()
	task_started.emit(active_task)
	return true


func tick(context: BehaviorContext, delta: float) -> BehaviorStep.Status:
	if active_task == null:
		return BehaviorStep.Status.SUCCESS
	var completed_task := active_task
	var status := active_task.root.run(context, delta)
	if status == BehaviorStep.Status.RUNNING:
		return status
	active_task = null
	task_finished.emit(completed_task, status)
	_resume_previous(context)
	return status


func cancel_all(context: BehaviorContext) -> void:
	if active_task != null:
		active_task.root.cancel(context)
	active_task = null
	for task in _suspended:
		task.root.cancel(context)
	_suspended.clear()


func active_goal_id() -> StringName:
	return active_task.goal_id if active_task != null else &""


func suspended_count() -> int:
	return _suspended.size()


func _resume_previous(context: BehaviorContext) -> void:
	while not _suspended.is_empty():
		var candidate: BehaviorTask = _suspended.pop_back()
		if not candidate.is_still_valid(context):
			candidate.root.cancel(context)
			continue
		active_task = candidate
		active_task.root.resume(context)
		task_resumed.emit(active_task)
		return


func _cancel_suspended_goal(goal_id: StringName, context: BehaviorContext) -> void:
	for index in range(_suspended.size() - 1, -1, -1):
		if _suspended[index].goal_id == goal_id:
			_suspended[index].root.cancel(context)
			_suspended.remove_at(index)
