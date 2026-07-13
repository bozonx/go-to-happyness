class_name CourierDeliveryOrderProvider
extends OrderProvider

func _init() -> void:
	super(&"logistics.courier")

func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	var claimed: Dictionary = {}
	for citizen_id in snapshot.citizen_ids():
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.courier.worker", false)) or not bool(citizen.facts.value(&"work.courier.can_start", false)):
			continue
		for task_value in citizen.facts.value(&"work.courier.tasks", []) as Array:
			var task := task_value as Dictionary
			var task_id := task.get(&"id", &"") as StringName
			var pickup: Variant = task.get(&"pickup", Vector3.INF)
			if task_id == &"" or claimed.has(task_id) or not (pickup is Vector3):
				continue
			claimed[task_id] = true
			var order := CitizenOrder.new(citizen_id, &"courier_delivery", id, clampf(float(task.get(&"priority", 0)) / 100.0, 0.0, 1.0), AIFactSet.new({&"courier.task_id": task_id}))
			order.target_position = pickup
			orders.append(order)
			break
	return orders
