class_name CourierDeliveryOrderProvider
extends OrderProvider

func _init() -> void:
	super(&"logistics.courier")

func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	var claimed: Dictionary = {}
	var shared_tasks: Array = snapshot.settlement.value(&"work.courier.tasks", []) as Array
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	# Couriers already carrying a delivery keep their active task; the rest enter a
	# free pool that is matched to work by distance below.
	var free_couriers: Array[Dictionary] = []
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
		var candidate_source: Array = personal_tasks if use_personal_tasks else (shared_tasks if not shared_tasks.is_empty() else personal_tasks)
		var actor_id := int(citizen.facts.value(&"work.courier.actor_id", citizen.id))
		var candidates: Dictionary = {}
		for task_value in candidate_source:
			if task_value is CourierTask:
				var task := task_value as CourierTask
				var requested_courier_id := int(task.payload.get("courier_ai_id", 0))
				if task.id == &"" or task.pickup == Vector3.INF or (requested_courier_id > 0 and requested_courier_id != actor_id):
					continue
				candidates[task.id] = {&"priority": task.priority, &"pickup": task.pickup}
			elif task_value is Dictionary:
				var task := task_value as Dictionary
				var task_id := task.get(&"id", &"") as StringName
				var pickup: Variant = task.get(&"pickup", Vector3.INF)
				var requested_courier_id := int(task.get(&"requested_courier_id", -1))
				if task_id == &"" or not (pickup is Vector3) or (requested_courier_id > 0 and requested_courier_id != actor_id):
					continue
				candidates[task_id] = {&"priority": int(task.get(&"priority", 0)), &"pickup": pickup}

		if candidates.is_empty():
			continue
		free_couriers.append({
			&"citizen_id": citizen_id,
			&"position": citizen.position,
			&"permanent": bool(citizen.facts.value(&"work.courier.permanent", false)),
			&"candidates": candidates,
		})

	# Greedy nearest-first matching. Each round assigns the highest-priority task
	# any free courier can reach to the best-matched courier for it: dedicated
	# couriers outrank daily fallbacks, then the nearest one wins so routes stop
	# crossing, with ids keeping ties deterministic.
	while not free_couriers.is_empty():
		var chosen_index := -1
		var chosen_task_id: StringName = &""
		var chosen_priority := -1
		var chosen_permanent := false
		var chosen_distance := INF
		var chosen_citizen_id := 0
		for index in free_couriers.size():
			var courier: Dictionary = free_couriers[index]
			var courier_id := int(courier[&"citizen_id"])
			var permanent := bool(courier[&"permanent"])
			var position: Vector3 = courier[&"position"]
			for task_id: StringName in courier[&"candidates"]:
				if claimed.has(task_id):
					continue
				var info: Dictionary = courier[&"candidates"][task_id]
				var priority := int(info[&"priority"])
				var distance := position.distance_squared_to(info[&"pickup"] as Vector3)
				if _is_better_pair(priority, permanent, distance, courier_id, task_id, chosen_priority, chosen_permanent, chosen_distance, chosen_citizen_id, chosen_task_id):
					chosen_index = index
					chosen_task_id = task_id
					chosen_priority = priority
					chosen_permanent = permanent
					chosen_distance = distance
					chosen_citizen_id = courier_id
		if chosen_index < 0:
			break
		var winner: Dictionary = free_couriers[chosen_index]
		var pickup: Vector3 = (winner[&"candidates"][chosen_task_id] as Dictionary)[&"pickup"]
		claimed[chosen_task_id] = true
		orders.append(_order_for_task(int(winner[&"citizen_id"]), chosen_task_id, chosen_priority, pickup))
		free_couriers.remove_at(chosen_index)
	return orders


func _is_better_pair(priority: int, permanent: bool, distance: float, courier_id: int, task_id: StringName, best_priority: int, best_permanent: bool, best_distance: float, best_courier_id: int, best_task_id: StringName) -> bool:
	if priority != best_priority:
		return priority > best_priority
	if permanent != best_permanent:
		return permanent
	if not is_equal_approx(distance, best_distance):
		return distance < best_distance
	if courier_id != best_courier_id:
		return courier_id < best_courier_id
	return String(task_id) < String(best_task_id)


func _order_for_task(citizen_id: int, task_id: StringName, priority: int, pickup: Vector3) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"courier_delivery", id, clampf(float(priority) / 100.0, 0.0, 1.0), AIFactSet.new({&"courier.task_id": task_id}))
	order.target_key = task_id
	order.target_position = pickup
	return order
