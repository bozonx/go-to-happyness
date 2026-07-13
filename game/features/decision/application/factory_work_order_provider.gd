class_name FactoryWorkOrderProvider
extends OrderProvider

## Factory orders unite factory workers, engineers, and idle builders assigned
## as materials-factory support. Building services retain production ownership.


func _init() -> void:
	super(&"workforce.factory")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.factory.worker", false)):
			continue
		var in_progress := bool(citizen.facts.value(&"work.factory.in_progress", false))
		var can_start := bool(citizen.facts.value(&"work.factory.can_start", false))
		var role := citizen.facts.value(&"work.factory.role", &"") as StringName
		var target_key := citizen.facts.value(&"work.factory.target_key", &"") as StringName
		var position: Variant = citizen.facts.value(&"work.factory.position", Vector3.INF)
		if role not in [&"factory_work", &"engineering", &"construction"] or target_key == &"" or not (position is Vector3) or position == Vector3.INF:
			continue
		if not in_progress and not can_start:
			continue
		var order := CitizenOrder.new(citizen_id, &"factory_work", id, 0.46, AIFactSet.new({&"factory.role": role}))
		order.target_key = target_key
		order.target_position = position
		orders.append(order)
	return orders
