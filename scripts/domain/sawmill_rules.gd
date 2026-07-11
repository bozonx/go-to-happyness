class_name SawmillRules
extends RefCounted

## Deterministic production and delivery rules for a single sawmill stock.

static func new_stock(now_seconds: float) -> Dictionary:
	return {"logs": 0, "boards": 0, "process_time": 0.0, "last_courier_pickup": now_seconds}


static func advance(stock: Dictionary, delta: float, process_duration: float) -> Dictionary:
	var next := stock.duplicate()
	if int(next.logs) <= 0:
		next.process_time = 0.0
		return next
	if float(next.process_time) <= 0.0:
		next.process_time = process_duration
	next.process_time = float(next.process_time) - delta
	if float(next.process_time) <= 0.0:
		next.logs = int(next.logs) - 1
		next.boards = int(next.boards) + 1
		next.process_time = process_duration if int(next.logs) > 0 else 0.0
	return next


static func should_worker_deliver(stock: Dictionary, has_courier: bool, now_seconds: float, delivery_threshold: int, courier_late_seconds: float) -> bool:
	if int(stock.boards) <= 0:
		return false
	var courier_late := now_seconds - float(stock.last_courier_pickup) >= courier_late_seconds
	return not has_courier or (int(stock.boards) >= delivery_threshold and courier_late)
