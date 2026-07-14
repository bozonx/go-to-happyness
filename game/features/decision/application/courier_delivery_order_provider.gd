class_name CourierDeliveryOrderProvider
extends OrderProvider

func _init() -> void:
	super(&"logistics.courier")

func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	var claimed: Dictionary = {}
	var shared_tasks: Array = snapshot.settlement.value(&"work.courier.tasks", []) as Array
	for citizen_id in snapshot.citizen_ids():
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.courier.worker", false)):
			continue
		if bool(citizen.facts.value(&"work.courier.in_progress", false)):
			var active_task_id := citizen.facts.value(&"work.courier.active_task_id", &"") as StringName
			var active_pickup: Variant = citizen.facts.value(&"work.courier.active_pickup", Vector3.INF)
			if active_task_id != &"" and active_pickup is Vector3:
				claimed[active_task_id] = true
				orders.append(_order_for_task(citizen_id, active_task_id, int(citizen.facts.value(&"work.courier.active_priority", 0)), active_pickup))
				continue
		if not bool(citizen.facts.value(&"work.courier.can_start", false)):
			continue
		var tasks: Array = shared_tasks if not shared_tasks.is_empty() else citizen.facts.value(&"work.courier.tasks", []) as Array
		for task_value in tasks:
			var task := task_value as Dictionary
			var task_id := task.get(&"id", &"") as StringName
			var pickup: Variant = task.get(&"pickup", Vector3.INF)
			if task_id == &"" or claimed.has(task_id) or not (pickup is Vector3):
				continue
			claimed[task_id] = true
			orders.append(_order_for_task(citizen_id, task_id, int(task.get(&"priority", 0)), pickup))
			break
	return orders


func _order_for_task(citizen_id: int, task_id: StringName, priority: int, pickup: Vector3) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"courier_delivery", id, clampf(float(priority) / 100.0, 0.0, 1.0), AIFactSet.new({&"courier.task_id": task_id}))
	order.target_position = pickup
	return order
