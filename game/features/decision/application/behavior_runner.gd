class_name BehaviorRunner
extends RefCounted

## Executes one task and retains resumable tasks when a higher-utility goal
## interrupts them. Completed interrupt tasks automatically resume the prior one.

signal task_started(task: BehaviorTask)
signal task_finished(task: BehaviorTask, status: BehaviorStep.Status)
signal task_resumed(task: BehaviorTask)

var active_task: BehaviorTask
var pending_task: BehaviorTask
var _suspended: Array[BehaviorTask] = []
var trace_limit := 20
var trace: Array[Dictionary] = []


func start(task: BehaviorTask, context: BehaviorContext) -> bool:
	if task == null or task.root == null:
		return false
	_cancel_pending(context)
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
	_record_trace(&"start", active_task, BehaviorStep.Status.RUNNING, BehaviorStep.FailureReason.NONE, context)
	task_started.emit(active_task)
	return true


func start_after_active(task: BehaviorTask, context: BehaviorContext) -> bool:
	if task == null or task.root == null:
		return false
	if active_task == null:
		return start(task, context)
	if has_pending(task.goal_id, task.order_id):
		return true
	_cancel_suspended_goal(task.goal_id, context)
	_cancel_pending(context)
	pending_task = task
	return true


func tick(context: BehaviorContext, delta: float) -> BehaviorStep.Status:
	if active_task == null:
		_start_pending_or_resume(context)
		return BehaviorStep.Status.SUCCESS
	var invalid_reason := active_task.invalid_reason(context)
	if invalid_reason != BehaviorStep.FailureReason.NONE:
		active_task.failure_reason = invalid_reason
		active_task.root.set_failure_reason(invalid_reason)
		active_task.root.cancel(context)
		_record_trace(&"invalid", active_task, BehaviorStep.Status.FAILURE, invalid_reason, context)
		active_task = null
		_start_pending_or_resume(context)
		return BehaviorStep.Status.FAILURE
	_bind_active_order(context)
	var completed_task := active_task
	var status := active_task.root.run(context, delta)
	if status == BehaviorStep.Status.RUNNING:
		return status
	active_task = null
	completed_task.failure_reason = completed_task.root.failure_reason if status == BehaviorStep.Status.FAILURE else BehaviorStep.FailureReason.NONE
	_record_trace(&"finish", completed_task, status, completed_task.failure_reason, context)
	task_finished.emit(completed_task, status)
	_start_pending_or_resume(context)
	return status


func cancel_all(context: BehaviorContext) -> void:
	if active_task != null:
		active_task.root.cancel(context)
	active_task = null
	_cancel_pending(context)
	for task in _suspended:
		task.root.cancel(context)
	_suspended.clear()


func active_goal_id() -> StringName:
	return active_task.goal_id if active_task != null else &""


func suspended_count() -> int:
	return _suspended.size()


func has_pending(goal_id: StringName, order_id: int) -> bool:
	return pending_task != null and pending_task.goal_id == goal_id and pending_task.order_id == order_id


func clear_pending(context: BehaviorContext) -> void:
	_cancel_pending(context)


func _resume_previous(context: BehaviorContext) -> void:
	while not _suspended.is_empty():
		var candidate: BehaviorTask = _suspended.pop_back()
		var invalid_reason := candidate.invalid_reason(context)
		if invalid_reason != BehaviorStep.FailureReason.NONE:
			candidate.failure_reason = invalid_reason
			candidate.root.set_failure_reason(invalid_reason)
			candidate.root.cancel(context)
			_record_trace(&"drop_suspended", candidate, BehaviorStep.Status.FAILURE, invalid_reason, context)
			continue
		active_task = candidate
		_bind_active_order(context)
		active_task.root.resume(context)
		_record_trace(&"resume", active_task, BehaviorStep.Status.RUNNING, BehaviorStep.FailureReason.NONE, context)
		task_resumed.emit(active_task)
		return


func _cancel_suspended_goal(goal_id: StringName, context: BehaviorContext) -> void:
	for index in range(_suspended.size() - 1, -1, -1):
		if _suspended[index].goal_id == goal_id:
			_suspended[index].root.cancel(context)
			_suspended.remove_at(index)


func _cancel_pending(context: BehaviorContext) -> void:
	if pending_task != null:
		pending_task.root.cancel(context)
	pending_task = null


func _start_pending_or_resume(context: BehaviorContext) -> void:
	if pending_task != null:
		var next_task := pending_task
		pending_task = null
		var invalid_reason := next_task.invalid_reason(context)
		if invalid_reason == BehaviorStep.FailureReason.NONE:
			start(next_task, context)
			return
		next_task.failure_reason = invalid_reason
		next_task.root.set_failure_reason(invalid_reason)
		next_task.root.cancel(context)
		_record_trace(&"drop_pending", next_task, BehaviorStep.Status.FAILURE, invalid_reason, context)
	_resume_previous(context)


func _bind_active_order(context: BehaviorContext) -> void:
	if active_task != null and active_task.order != null:
		context.order = active_task.order


func _record_trace(
	event: StringName,
	task: BehaviorTask,
	status: BehaviorStep.Status,
	reason: BehaviorStep.FailureReason,
	context: BehaviorContext
) -> void:
	if task == null:
		return
	trace.append({
		&"event": event,
		&"goal": task.goal_id,
		&"order_id": task.order_id,
		&"status": status,
		&"reason": reason,
		&"sequence": context.snapshot.sequence if context != null and context.snapshot != null else -1,
		&"time": context.snapshot.simulation_seconds if context != null and context.snapshot != null else 0.0,
	})
	while trace.size() > trace_limit:
		trace.pop_front()
