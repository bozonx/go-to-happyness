class_name ExcavationOrderProvider
extends OrderProvider

var _assignments: Dictionary = {}


func _init() -> void:
	super(&"workforce.excavation")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	for citizen_id in _assignments.keys():
		if not snapshot.has_citizen(citizen_id):
			_assignments.erase(citizen_id)
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	var assigned_sites: Dictionary = {}
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		if (
			citizen != null
			and bool(citizen.facts.value(&"work.excavation.worker", false))
			and bool(citizen.facts.value(&"work.excavation.in_progress", false))
			and not assignment.is_empty()
		):
			assigned_sites[assignment.get(&"id", &"")] = true
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.excavation.worker", false)):
			_assignments.erase(citizen_id)
			continue
		var in_progress := bool(citizen.facts.value(&"work.excavation.in_progress", false))
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		var assignment_id := assignment.get(&"id", &"") as StringName
		if in_progress and not assignment.is_empty():
			orders.append(_order_for(citizen_id, assignment))
			continue
		if not assignment.is_empty() and not assigned_sites.has(assignment_id):
			var refreshed := _candidate_for(citizen, assignment_id)
			if not refreshed.is_empty():
				_assignments[citizen_id] = refreshed
				assigned_sites[assignment_id] = true
				orders.append(_order_for(citizen_id, refreshed))
				continue
		_assignments.erase(citizen_id)
		var next_assignment := _closest_free_candidate(citizen, assigned_sites)
		if next_assignment.is_empty():
			continue
		_assignments[citizen_id] = next_assignment
		assigned_sites[next_assignment.get(&"id", &"")] = true
		orders.append(_order_for(citizen_id, next_assignment))
	return orders


func _candidate_for(citizen: CitizenSnapshot, site_id: StringName) -> Dictionary:
	for candidate_value in (citizen.facts.value(&"work.excavation.candidates", []) as Array):
		var candidate := candidate_value as Dictionary
		if candidate.get(&"id", &"") == site_id:
			return candidate.duplicate(true)
	return {}


func _closest_free_candidate(citizen: CitizenSnapshot, assigned_sites: Dictionary) -> Dictionary:
	var candidates: Array = citizen.facts.value(&"work.excavation.candidates", []) as Array
	var best: Dictionary = {}
	var best_distance := INF
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var site_id := candidate.get(&"id", &"") as StringName
		var position: Variant = candidate.get(&"position", Vector3.INF)
		if site_id == &"" or not (position is Vector3) or position == Vector3.INF or assigned_sites.has(site_id):
			continue
		var distance := float(candidate.get(&"route_cost", citizen.position.distance_squared_to(position)))
		if distance < best_distance or (is_equal_approx(distance, best_distance) and str(site_id) < str(best.get(&"id", &""))):
			best = candidate.duplicate(true)
			best_distance = distance
	return best


func _order_for(citizen_id: int, assignment: Dictionary) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"excavation", id, 0.50, AIFactSet.new({
		&"work.site_id": assignment.get(&"id", &""),
	}))
	order.target_key = assignment.get(&"target_key", &"") as StringName
	order.target_position = assignment.get(&"position", Vector3.INF)
	return order
