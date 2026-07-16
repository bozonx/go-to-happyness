class_name WorkforceOrderProvider
extends OrderProvider

func _init() -> void:
	super(&"workforce.coordination")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders

	var world_data: Dictionary = snapshot.settlement.value(&"workforce.world_data", {})
	var allocation_world := world_data.duplicate(true)
	allocation_world["assigned_roles"] = (world_data.get("assigned_roles", {}) as Dictionary).duplicate()
	var center_position: Variant = snapshot.settlement.value(&"workforce.employment_center_position", Vector3.INF)
	var employers: Dictionary = _available_employers(snapshot.settlement.value(&"workforce.role_employers", {}))

	if not world_data.is_empty() and center_position is Vector3 and center_position != Vector3.INF:
		var citizen_ids := snapshot.citizen_ids()
		citizen_ids.sort()
		for citizen_id in citizen_ids:
			var citizen := snapshot.citizen(citizen_id)
			if citizen == null or citizen.is_player_controlled:
				continue

			var worker_data: Dictionary = citizen.facts.value(&"workforce.worker_data", {})
			if worker_data.is_empty():
				continue
			var status := str(worker_data.get("workforce_status", ""))
			if status not in ["unregistered", "no_permanent_work", "registering"]:
				continue

			var pending_role := str(worker_data.get("pending_employment_role", "")) if status == "registering" else ""
			if pending_role.is_empty():
				if not bool(world_data.get("officer_available", true)):
					continue
				pending_role = WorkforcePolicy.permanent_vacancy_for(worker_data, allocation_world)

			if pending_role.is_empty():
				continue

			var employer_data: Dictionary = _claim_employer_slot(employers, pending_role) if status != "registering" else {}
			var workplace_pos: Variant = citizen.facts.value(&"workforce.pending_workplace_position", Vector3.INF) if status == "registering" else employer_data.get("position", Vector3.INF)
			var workplace_key: Variant = citizen.facts.value(&"workforce.pending_workplace_key", &"") if status == "registering" else employer_data.get("target_key", &"")

			var target_pos := workplace_pos as Vector3 if workplace_pos is Vector3 else Vector3.INF
			var target_key := workplace_key as StringName if workplace_key is StringName else &""
			# Tent-era couriers are registered professionals without a workplace node.
			# They still use the employment-centre position to complete registration.
			if target_pos == Vector3.INF or (target_key == &"" and pending_role != "courier"):
				continue

			var order := CitizenOrder.new(citizen_id, &"register", id, 0.74, AIFactSet.new({
				&"workplace.role": pending_role,
				&"workplace.position": target_pos,
				&"workplace.node_key": target_key,
				&"center.position": center_position,
			}))
			order.target_position = center_position
			orders.append(order)
			_increment_assigned_role(allocation_world, pending_role)

	return orders


func _available_employers(raw_employers: Dictionary) -> Dictionary:
	var employers: Dictionary = {}
	for role_value in raw_employers:
		var role := str(role_value)
		var raw_candidates: Variant = raw_employers[role_value]
		var candidates: Array = raw_candidates if raw_candidates is Array else [raw_candidates]
		var available: Array[Dictionary] = []
		for candidate_value in candidates:
			var candidate := candidate_value as Dictionary
			var position: Variant = candidate.get("position", Vector3.INF)
			var target_key: Variant = candidate.get("target_key", &"")
			if not (position is Vector3) or position == Vector3.INF or not (target_key is StringName) or (target_key == &"" and role != "courier"):
				continue
			var slots := int(candidate.get("available_slots", 1))
			if slots <= 0:
				continue
			var normalized := candidate.duplicate(true)
			normalized["available_slots"] = slots
			available.append(normalized)
		if not available.is_empty():
			employers[role] = available
	return employers


func _claim_employer_slot(employers: Dictionary, role: String) -> Dictionary:
	var candidates: Array = employers.get(role, []) as Array
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var slots := int(candidate.get("available_slots", 0))
		if slots <= 0:
			continue
		candidate["available_slots"] = slots - 1
		return candidate.duplicate(true)
	return {}


func _increment_assigned_role(world: Dictionary, role: String) -> void:
	if role.is_empty():
		return
	var assigned: Dictionary = world.get("assigned_roles", {})
	assigned[role] = int(assigned.get(role, 0)) + 1
	world["assigned_roles"] = assigned
