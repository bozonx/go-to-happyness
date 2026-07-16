class_name GatheringOrderProvider
extends OrderProvider

## Publishes one resource source per permanent gatherer. The provider uses only
## snapshot values; the task lease protects sources from concurrent native work.

var _assignments: Dictionary = {}


func _init() -> void:
	super(&"workforce.gathering")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	for citizen_id in _assignments.keys():
		if not snapshot.has_citizen(citizen_id):
			_assignments.erase(citizen_id)
	var assigned_sources: Dictionary = {}
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.gathering.worker", false)):
			_assignments.erase(citizen_id)
			continue
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		if not assignment.is_empty():
			assigned_sources[assignment.get(&"id", &"")] = true
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.gathering.worker", false)):
			continue
		var in_progress := bool(citizen.facts.value(&"work.gathering.in_progress", false))
		if not in_progress and not bool(citizen.facts.value(&"work.gathering.can_start", true)):
			_assignments.erase(citizen_id)
			continue
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		if not assignment.is_empty() and (in_progress or _contains_candidate(snapshot, citizen, assignment)):
			orders.append(_order_for(citizen_id, assignment))
			continue
		_assignments.erase(citizen_id)
		var next_assignment := _closest_free_candidate(snapshot, citizen, assigned_sources)
		if next_assignment.is_empty():
			continue
		_assignments[citizen_id] = next_assignment
		assigned_sources[next_assignment.get(&"id", &"")] = true
		orders.append(_order_for(citizen_id, next_assignment))
	return orders


func _contains_candidate(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assignment: Dictionary) -> bool:
	var source_id := assignment.get(&"id", &"") as StringName
	var role := citizen.facts.value(&"work.gathering.role", &"") as StringName
	var candidates: Array = citizen.facts.value(&"work.gathering.candidates", []) as Array
	if candidates.is_empty() and role == &"gather_food":
		candidates = snapshot.settlement.value(&"work.gathering.targets", []) as Array
	for candidate_value in candidates:
		if (candidate_value as Dictionary).get(&"id", &"") == source_id:
			return true
	return false


func _closest_free_candidate(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assigned_sources: Dictionary) -> Dictionary:
	var global_candidates: Array = snapshot.settlement.value(&"work.gathering.targets", []) as Array
	var role := citizen.facts.value(&"work.gathering.role", &"") as StringName
	var candidates: Array = citizen.facts.value(&"work.gathering.candidates", []) as Array
	if candidates.is_empty() and role == &"gather_food":
		candidates = global_candidates
	var best: Dictionary = {}
	var best_distance := INF
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var source_id := candidate.get(&"id", &"") as StringName
		var access: Variant = candidate.get(&"access", Vector3.INF)
		if source_id == &"" or not (access is Vector3) or access == Vector3.INF or assigned_sources.has(source_id):
			continue
		var distance := citizen.position.distance_squared_to(access)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and str(source_id) < str(best.get(&"id", &""))):
			best = candidate.duplicate(true)
			best_distance = distance
	if not best.is_empty():
		best[&"warehouse_position"] = citizen.facts.value(&"work.gathering.warehouse_position", best.get(&"warehouse_position", Vector3.INF))
	return best


func _order_for(citizen_id: int, assignment: Dictionary) -> CitizenOrder:
	var order := CitizenOrder.new(
		citizen_id,
		&"gathering",
		id,
		0.50,
		AIFactSet.new({
			&"work.source_id": assignment.get(&"id", &""),
			&"resource.type": assignment.get(&"resource_type", ""),
			&"target.access_position": assignment.get(&"access", Vector3.INF),
			&"warehouse.position": assignment.get(&"warehouse_position", Vector3.INF),
		})
	)
	order.target_key = StringName("source:%s" % str(assignment.get(&"id", &"")))
	order.target_position = assignment.get(&"position", Vector3.INF)
	return order
