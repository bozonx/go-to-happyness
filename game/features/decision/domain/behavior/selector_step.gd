class_name SelectorStep
extends BehaviorStep

var children: Array[BehaviorStep]
var _current := 0


func _init(next_children: Array[BehaviorStep] = []) -> void:
	children = next_children.duplicate()


func _tick(context: BehaviorContext, delta: float) -> Status:
	while _current < children.size():
		var status := children[_current].run(context, delta)
		if status == Status.RUNNING:
			return Status.RUNNING
		if status == Status.SUCCESS:
			return Status.SUCCESS
		set_failure_reason(children[_current].failure_reason)
		_current += 1
	return Status.FAILURE


func _reset() -> void:
	_current = 0
	for child in children:
		child.reset()


func _cancel(context: BehaviorContext) -> void:
	if _current < children.size():
		children[_current].cancel(context)


func _suspend(context: BehaviorContext) -> void:
	if _current < children.size():
		children[_current].suspend(context)


func _resume(context: BehaviorContext) -> void:
	if _current < children.size():
		children[_current].resume(context)
