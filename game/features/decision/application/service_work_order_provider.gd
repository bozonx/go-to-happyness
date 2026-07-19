class_name ServiceWorkOrderProvider
extends OrderProvider

## Service posts share one immutable workplace order. Research posts are
## explicit building assignments, not permanent professions or daily orders.


func _init() -> void:
	super(&"workforce.service")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.service.worker", false)):
			continue
		var in_progress := bool(citizen.facts.value(&"work.service.in_progress", false))
		var can_start := bool(citizen.facts.value(&"work.service.can_start", false))
		var role := citizen.facts.value(&"work.service.role", &"") as StringName
		var position: Variant = citizen.facts.value(&"work.service.position", Vector3.INF)
		if role not in [&"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher"]:
			continue
		if not in_progress and not can_start:
			continue
		if not (position is Vector3) or position == Vector3.INF:
			continue
		var order := CitizenOrder.new(
			citizen_id,
			&"service_work",
			id,
			0.45,
			AIFactSet.new({
				&"work.service.role": role,
				&"workplace.position": position,
			})
		)
		order.target_key = StringName("service:%s:%0.3f:%0.3f" % [str(role), position.x, position.z])
		order.target_position = position
		orders.append(order)
	return orders
