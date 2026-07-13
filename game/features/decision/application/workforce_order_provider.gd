class_name WorkforceOrderProvider
extends OrderProvider

var _reserve_assignments: Dictionary = {}

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
	var employers: Dictionary = snapshot.settlement.value(&"workforce.role_employers", {})

	if not world_data.is_empty() and center_position is Vector3 and center_position != Vector3.INF:
		var citizen_ids := snapshot.citizen_ids()
		citizen_ids.sort()
		for citizen_id in citizen_ids:
			var citizen := snapshot.citizen(citizen_id)
			if citizen == null or citizen.is_player_controlled:
				_reserve_assignments.erase(citizen_id)
				continue

			var worker_data: Dictionary = citizen.facts.value(&"workforce.worker_data", {})
			if worker_data.is_empty() or worker_data.get("workforce_status") != "unregistered":
				continue

			if not bool(world_data.get("officer_available", true)):
				continue
			var pending_role := WorkforcePolicy.permanent_vacancy_for(worker_data, allocation_world)

			if pending_role.is_empty():
				continue

			var employer_data: Dictionary = employers.get(pending_role, {})
			var workplace_pos: Variant = employer_data.get("position", Vector3.INF)
			var workplace_key: Variant = employer_data.get("target_key", &"")

			var target_pos := workplace_pos as Vector3 if workplace_pos is Vector3 else Vector3.INF
			var target_key := workplace_key as StringName if workplace_key is StringName else &""
			if target_pos == Vector3.INF or target_key == &"":
				continue

			var order := CitizenOrder.new(citizen_id, &"register", id, 0.95, AIFactSet.new({
				&"workplace.role": pending_role,
				&"workplace.position": target_pos,
				&"workplace.node_key": target_key,
				&"center.position": center_position,
			}))
			order.target_position = center_position
			orders.append(order)
			_reserve_assignments.erase(citizen_id)
			_increment_assigned_role(allocation_world, pending_role)

	var reserve_ids := snapshot.citizen_ids()
	reserve_ids.sort()
	for citizen_id in reserve_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or citizen.is_player_controlled:
			continue
		var worker_data: Dictionary = citizen.facts.value(&"workforce.worker_data", {})
		if worker_data.is_empty() or str(worker_data.get("workforce_status", "")) != "active":
			_reserve_assignments.erase(citizen_id)
			continue
		if not bool(citizen.facts.value(&"workforce.reserve.eligible", false)):
			_reserve_assignments.erase(citizen_id)
			continue
		var assignment := _reserve_assignments.get(citizen_id, {}) as Dictionary
		if bool(citizen.facts.value(&"workforce.reserve.in_progress", false)):
			if not assignment.is_empty():
				orders.append(_reserve_order(citizen_id, assignment))
			continue
		var role := WorkforcePolicy.role_for(worker_data, allocation_world)
		if not WorkforcePolicy.can_assign(worker_data, allocation_world):
			_reserve_assignments.erase(citizen_id)
			continue
		var commands: Dictionary = citizen.facts.value(&"workforce.reserve.commands", {})
		var command: Dictionary = commands.get(StringName(role), {})
		if command.is_empty():
			_reserve_assignments.erase(citizen_id)
			continue
		_reserve_assignments[citizen_id] = command.duplicate(true)
		orders.append(_reserve_order(citizen_id, command))
		_increment_assigned_role(allocation_world, role)

	return orders


func _reserve_order(citizen_id: int, command: Dictionary) -> CitizenOrder:
	var target_position: Variant = command.get(&"target.position", Vector3.INF)
	var target_key: Variant = command.get(&"target.key", &"")
	var payload := command.duplicate(true)
	payload.erase(&"target.position")
	payload.erase(&"target.key")
	var order := CitizenOrder.new(citizen_id, &"reserve_work", id, 0.40, AIFactSet.new(payload))
	order.target_position = target_position as Vector3 if target_position is Vector3 else Vector3.INF
	order.target_key = target_key as StringName if target_key is StringName else &""
	return order


func _increment_assigned_role(world: Dictionary, role: String) -> void:
	if role.is_empty():
		return
	var assigned: Dictionary = world.get("assigned_roles", {})
	assigned[role] = int(assigned.get(role, 0)) + 1
	world["assigned_roles"] = assigned
