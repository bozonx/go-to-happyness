class_name BehaviorStep
extends RefCounted

enum Status { RUNNING, SUCCESS, FAILURE }

var _entered := false
var _suspended := false


func run(context: BehaviorContext, delta: float) -> Status:
	if _suspended:
		return Status.RUNNING
	if not _entered:
		_entered = true
		_enter(context)
	return _tick(context, delta)


func reset() -> void:
	_entered = false
	_suspended = false
	_reset()


func cancel(context: BehaviorContext) -> void:
	if _entered:
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


func _suspend(_context: BehaviorContext) -> void:
	pass


func _resume(_context: BehaviorContext) -> void:
	pass
