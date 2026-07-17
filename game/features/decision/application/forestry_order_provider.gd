class_name ForestryOrderProvider
extends OrderProvider

## Publishes one stable forestry assignment per permanent sawmill worker. Target
## selection uses snapshot values only; execution and reservation stay with the
## citizen's native task.

var _assignments: Dictionary = {}


func _init() -> void:
	super(&"workforce.forestry")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	for citizen_id in _assignments.keys():
		if not snapshot.has_citizen(citizen_id):
			_assignments.erase(citizen_id)
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	var assigned_targets: Dictionary = {}
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		if (
			citizen != null
			and bool(citizen.facts.value(&"work.forestry.worker", false))
			and bool(citizen.facts.value(&"work.forestry.in_progress", false))
			and not assignment.is_empty()
		):
			assigned_targets[assignment.get(&"id", &"")] = true
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.forestry.worker", false)):
			_assignments.erase(citizen_id)
			continue
		var in_progress := bool(citizen.facts.value(&"work.forestry.in_progress", false))
		if not in_progress and not bool(citizen.facts.value(&"work.forestry.can_start", true)):
			_assignments.erase(citizen_id)
			continue
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		var assignment_id := assignment.get(&"id", &"") as StringName
		if in_progress and not assignment.is_empty():
			orders.append(_order_for(citizen_id, assignment))
			continue
		if not assignment.is_empty() and not assigned_targets.has(assignment_id):
			var refreshed := _candidate_for(snapshot, citizen, assignment_id)
			if not refreshed.is_empty():
				_assignments[citizen_id] = refreshed
				assigned_targets[assignment_id] = true
				orders.append(_order_for(citizen_id, refreshed))
				continue
		_assignments.erase(citizen_id)
		var next_assignment := _closest_free_candidate(snapshot, citizen, assigned_targets)
		if next_assignment.is_empty():
			continue
		_assignments[citizen_id] = next_assignment
		assigned_targets[next_assignment.get(&"id", &"")] = true
		orders.append(_order_for(citizen_id, next_assignment))
	return orders


func _candidate_for(snapshot: WorldSnapshot, citizen: CitizenSnapshot, target_id: StringName) -> Dictionary:
	var candidates: Array = citizen.facts.value(&"work.forestry.candidates", []) as Array
	if candidates.is_empty():
		candidates = snapshot.settlement.value(&"work.forestry.targets", []) as Array
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		if candidate.get(&"id", &"") == target_id:
			return _decorate_candidate(citizen, candidate)
	return {}


func _closest_free_candidate(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assigned_targets: Dictionary) -> Dictionary:
	var candidates: Array = citizen.facts.value(&"work.forestry.candidates", []) as Array
	if candidates.is_empty():
		candidates = snapshot.settlement.value(&"work.forestry.targets", []) as Array
	var best: Dictionary = {}
	var best_distance := INF
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var target_id := candidate.get(&"id", &"") as StringName
		var position: Variant = candidate.get(&"position", Vector3.INF)
		if target_id == &"" or not (position is Vector3) or position == Vector3.INF or assigned_targets.has(target_id):
			continue
		var distance := float(candidate.get(&"route_cost", citizen.position.distance_squared_to(position)))
		if distance < best_distance or (is_equal_approx(distance, best_distance) and str(target_id) < str(best.get(&"id", &""))):
			best = candidate.duplicate(true)
			best_distance = distance
	if not best.is_empty():
		best = _decorate_candidate(citizen, best)
	return best


func _decorate_candidate(citizen: CitizenSnapshot, candidate: Dictionary) -> Dictionary:
	var decorated := candidate.duplicate(true)
	decorated[&"sawmill_position"] = citizen.facts.value(&"work.forestry.sawmill_position", decorated.get(&"sawmill_position", Vector3.INF))
	decorated[&"warehouse_position"] = citizen.facts.value(&"work.forestry.warehouse_position", decorated.get(&"warehouse_position", Vector3.INF))
	return decorated


func _order_for(citizen_id: int, assignment: Dictionary) -> CitizenOrder:
	var order := CitizenOrder.new(
		citizen_id,
		&"forestry",
		id,
		0.55,
		AIFactSet.new({
			&"work.tree_id": assignment.get(&"id", &""),
			&"work.tree_access": assignment.get(&"access", Vector3.INF),
			&"work.sawmill_position": assignment.get(&"sawmill_position", Vector3.INF),
			&"work.warehouse_position": assignment.get(&"warehouse_position", Vector3.INF),
		})
	)
	order.target_key = StringName("tree:%s" % str(assignment.get(&"id", &"")))
	order.target_position = assignment.get(&"position", Vector3.INF)
	return order
