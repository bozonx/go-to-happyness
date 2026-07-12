class_name CourierDispatcher
extends RefCounted

## Single entry point for courier scheduling. Task producers may still keep
## their domain-specific reservation rules while migration to CourierTask is
## in progress, but only this dispatcher starts the scheduling pass.

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func dispatch() -> void:
	if simulation == null or not simulation._is_work_time():
		return
	simulation._dispatch_courier_tasks()
