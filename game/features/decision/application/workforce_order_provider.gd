class_name WorkforceOrderProvider
extends OrderProvider


func _init() -> void:
	super(&"workforce.coordination")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders

	var world_data: Dictionary = snapshot.settlement.value(&"workforce.world_data", {})
	if world_data.is_empty():
		return orders

	var center_position: Variant = snapshot.settlement.value(&"workforce.employment_center_position", Vector3.INF)
	if not (center_position is Vector3) or center_position == Vector3.INF:
		return orders

	var employers: Dictionary = snapshot.settlement.value(&"workforce.role_employers", {})

	for citizen_id in snapshot.citizen_ids():
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or citizen.is_player_controlled:
			continue

		var worker_data: Dictionary = citizen.facts.value(&"workforce.worker_data", {})
		if worker_data.is_empty() or worker_data.get("workforce_status") != "unregistered":
			continue

		if not bool(world_data.get("officer_available", true)):
			continue
		var pending_role := WorkforcePolicy.permanent_vacancy_for(worker_data, world_data)

		if pending_role.is_empty():
			continue

		# Find employer information for the pending role
		var employer_data: Dictionary = employers.get(pending_role, {})
		var workplace_pos: Variant = employer_data.get("position", Vector3.INF)
		var workplace_key: Variant = employer_data.get("target_key", &"")

		var target_pos := workplace_pos as Vector3 if workplace_pos is Vector3 else Vector3.INF
		var target_key := workplace_key as StringName if workplace_key is StringName else &""
		if target_pos == Vector3.INF or target_key == &"":
			continue

		var order := CitizenOrder.new(
			citizen_id,
			&"register",
			id,
			0.95, # High priority to prioritize registration
			AIFactSet.new({
				&"workplace.role": pending_role,
				&"workplace.position": target_pos,
				&"workplace.node_key": target_key,
				&"center.position": center_position,
			})
		)
		order.target_position = center_position
		orders.append(order)

	return orders
