class_name CourierDeliveryOrderProvider
extends OrderProvider

func _init() -> void:
	super(&"logistics.courier")

func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	var claimed: Dictionary = {}
	var shared_tasks: Array = snapshot.settlement.value(&"work.courier.tasks", []) as Array
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort_custom(func(left: int, right: int) -> bool:
		var left_citizen := snapshot.citizen(left)
		var right_citizen := snapshot.citizen(right)
		var left_permanent := left_citizen != null and bool(left_citizen.facts.value(&"work.courier.permanent", false))
		var right_permanent := right_citizen != null and bool(right_citizen.facts.value(&"work.courier.permanent", false))
		return left_permanent and not right_permanent
	)
	for citizen_id in citizen_ids:
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
		var personal_tasks: Array = citizen.facts.value(&"work.courier.tasks", []) as Array
		var use_personal_tasks := bool(citizen.facts.value(&"work.courier.use_personal_tasks", false))
		var tasks: Array = personal_tasks if use_personal_tasks else (shared_tasks if not shared_tasks.is_empty() else personal_tasks)
		for task_value in tasks:
			var task := task_value as Dictionary
			var task_id := task.get(&"id", &"") as StringName
			var pickup: Variant = task.get(&"pickup", Vector3.INF)
			var requested_courier_id := int(task.get(&"requested_courier_id", -1))
			var actor_instance_id := int(citizen.facts.value(&"work.courier.actor_instance_id", -1))
			if task_id == &"" or claimed.has(task_id) or not (pickup is Vector3) or (requested_courier_id >= 0 and requested_courier_id != actor_instance_id):
				continue
			claimed[task_id] = true
			orders.append(_order_for_task(citizen_id, task_id, int(task.get(&"priority", 0)), pickup))
			break
	return orders


func _order_for_task(citizen_id: int, task_id: StringName, priority: int, pickup: Vector3) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"courier_delivery", id, clampf(float(priority) / 100.0, 0.0, 1.0), AIFactSet.new({&"courier.task_id": task_id}))
	order.target_key = task_id
	order.target_position = pickup
	return order
