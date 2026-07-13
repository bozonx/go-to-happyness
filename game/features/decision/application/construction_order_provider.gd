class_name ConstructionOrderProvider
extends OrderProvider

## Construction work is collaborative, so multiple permanent builders may receive
## the same supplied site. CourierDispatcher owns material reservations and cargo.


func _init() -> void:
	super(&"workforce.construction")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.construction.worker", false)):
			continue
		var in_progress := bool(citizen.facts.value(&"work.construction.in_progress", false))
		if not in_progress and not bool(citizen.facts.value(&"work.construction.can_start", false)):
			continue
		var mode := citizen.facts.value(&"work.construction.mode", &"") as StringName
		var target_id := int(citizen.facts.value(&"work.construction.target_id", -1))
		var target_position: Variant = citizen.facts.value(&"work.construction.position", Vector3.INF)
		if mode not in [&"construction", &"demolition"] or target_id < 0 or not (target_position is Vector3) or target_position == Vector3.INF:
			continue
		var order := CitizenOrder.new(
			citizen_id,
			mode,
			id,
			0.60,
			AIFactSet.new({&"work.construction.mode": mode})
		)
		order.target_entity_id = target_id
		order.target_position = target_position
		orders.append(order)
	return orders
