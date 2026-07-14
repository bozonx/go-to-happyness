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
	var assigned_targets: Dictionary = {}
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.forestry.worker", false)):
			_assignments.erase(citizen_id)
			continue
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		if bool(citizen.facts.value(&"work.forestry.in_progress", false)) and not assignment.is_empty():
			assigned_targets[assignment.get(&"id", &"")] = true
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.forestry.worker", false)):
			continue
		var in_progress := bool(citizen.facts.value(&"work.forestry.in_progress", false))
		if not in_progress and not bool(citizen.facts.value(&"work.forestry.can_start", true)):
			_assignments.erase(citizen_id)
			continue
		var assignment := _assignments.get(citizen_id, {}) as Dictionary
		if in_progress:
			if assignment.is_empty():
				continue
			orders.append(_order_for(citizen_id, assignment))
			continue
		_assignments.erase(citizen_id)
		var next_assignment := _closest_free_candidate(snapshot, citizen, assigned_targets)
		if next_assignment.is_empty():
			continue
		_assignments[citizen_id] = next_assignment
		assigned_targets[next_assignment.get(&"id", &"")] = true
		orders.append(_order_for(citizen_id, next_assignment))
	return orders


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
		var distance := citizen.position.distance_squared_to(position)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and str(target_id) < str(best.get(&"id", &""))):
			best = candidate.duplicate(true)
			best_distance = distance
	if not best.is_empty():
		best[&"sawmill_position"] = citizen.facts.value(&"work.forestry.sawmill_position", best.get(&"sawmill_position", Vector3.INF))
		best[&"warehouse_position"] = citizen.facts.value(&"work.forestry.warehouse_position", best.get(&"warehouse_position", Vector3.INF))
	return best


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
	order.target_position = assignment.get(&"position", Vector3.INF)
	return order
