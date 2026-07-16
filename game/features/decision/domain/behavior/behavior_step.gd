class_name BehaviorStep
extends RefCounted

enum Status { RUNNING, SUCCESS, FAILURE }
enum FailureReason {
	NONE,
	UNKNOWN,
	CONTEXT_INVALID,
	ORDER_EXPIRED,
	ORDER_CHANGED,
	GUARD_REJECTED,
	ACTUATOR_REJECTED,
	MOVEMENT_FAILED,
	RESERVATION_LOST,
	TIMEOUT,
	TARGET_INVALID,
	UNREACHABLE,
	STALE_ROUTE,
}

var _entered := false
var _suspended := false
var _finished := false
var _final_status := Status.RUNNING
var failure_reason := FailureReason.NONE


func run(context: BehaviorContext, delta: float) -> Status:
	if _suspended:
		return Status.RUNNING
	if _finished:
		return _final_status
	if not _entered:
		_entered = true
		_enter(context)
	var status := _tick(context, delta)
	if status != Status.RUNNING:
		if status == Status.FAILURE and failure_reason == FailureReason.NONE:
			failure_reason = FailureReason.UNKNOWN
		_finished = true
		_final_status = status
		_finish(context, status)
	return status


func reset() -> void:
	_entered = false
	_suspended = false
	_finished = false
	_final_status = Status.RUNNING
	failure_reason = FailureReason.NONE
	_reset()


func cancel(context: BehaviorContext) -> void:
	if _entered and not _finished:
		_cancel(context)
	reset()


func suspend(context: BehaviorContext) -> void:
	if _entered and not _suspended:
		_suspended = true
		_suspend(context)


func resume(context: BehaviorContext) -> void:
	if _suspended:
		_suspended = false
		_resume(context)


func _enter(_context: BehaviorContext) -> void:
	pass


func _tick(_context: BehaviorContext, _delta: float) -> Status:
	return Status.SUCCESS


func _reset() -> void:
	pass


func _cancel(_context: BehaviorContext) -> void:
	pass


## Called exactly once when `_tick` returns SUCCESS or FAILURE. Leaf steps release
## reservations and finish actuator-level work here; composites normally inherit it.
func _finish(_context: BehaviorContext, _status: Status) -> void:
	pass


func _suspend(_context: BehaviorContext) -> void:
	pass


func _resume(_context: BehaviorContext) -> void:
	pass


func fail(reason: FailureReason) -> Status:
	failure_reason = reason
	return Status.FAILURE


func set_failure_reason(reason: FailureReason) -> void:
	if failure_reason == FailureReason.NONE:
		failure_reason = reason
