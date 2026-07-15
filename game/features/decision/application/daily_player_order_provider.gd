class_name DailyPlayerOrderProvider
extends OrderProvider

const DAILY_PRIORITY := 0.82

var _gathering_assignments: Dictionary = {}
var _cleaning_assignments: Dictionary = {}


func _init() -> void:
	super(&"player")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	for citizen_id in _gathering_assignments.keys():
		if not snapshot.has_citizen(citizen_id):
			_gathering_assignments.erase(citizen_id)
	for citizen_id in _cleaning_assignments.keys():
		if not snapshot.has_citizen(citizen_id):
			_cleaning_assignments.erase(citizen_id)
	var assigned_sources := _running_gathering_sources(snapshot)
	var assigned_piles := _running_cleaning_piles(snapshot)
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"daily.order.active", false)):
			_gathering_assignments.erase(citizen_id)
			_cleaning_assignments.erase(citizen_id)
			continue
		var role := str(citizen.facts.value(&"daily.order.role", ""))
		match role:
			"construction":
				var construction_order := _construction_order(snapshot, citizen)
				if construction_order != null:
					orders.append(construction_order)
			"gather_branches", "gather_grass", "gather_water":
				var gathering_order := _gathering_order(snapshot, citizen, assigned_sources)
				if gathering_order != null:
					orders.append(gathering_order)
			"cleaning":
				var cleaning_order := _cleaning_order(snapshot, citizen, assigned_piles)
				if cleaning_order != null:
					orders.append(cleaning_order)
			_:
				_gathering_assignments.erase(citizen_id)
				_cleaning_assignments.erase(citizen_id)
	return orders


func _running_gathering_sources(snapshot: WorldSnapshot) -> Dictionary:
	var assigned_sources: Dictionary = {}
	for citizen_id in snapshot.citizen_ids():
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null:
			continue
		var assignment := _gathering_assignments.get(citizen_id, {}) as Dictionary
		if bool(citizen.facts.value(&"daily.gathering.in_progress", false)) and not assignment.is_empty():
			assigned_sources[assignment.get(&"id", &"")] = true
	return assigned_sources


func _running_cleaning_piles(snapshot: WorldSnapshot) -> Dictionary:
	var assigned_piles: Dictionary = {}
	for citizen_id in snapshot.citizen_ids():
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null:
			continue
		var assignment := _cleaning_assignments.get(citizen_id, {}) as Dictionary
		if bool(citizen.facts.value(&"daily.cleaning.in_progress", false)) and not assignment.is_empty():
			assigned_piles[assignment.get(&"id", &"")] = true
	return assigned_piles


func _construction_order(snapshot: WorldSnapshot, citizen: CitizenSnapshot) -> CitizenOrder:
	if not bool(citizen.facts.value(&"daily.construction.in_progress", false)) and not bool(citizen.facts.value(&"daily.construction.can_start", false)):
		return null
	var mode := citizen.facts.value(&"daily.construction.mode", &"") as StringName
	var target_key := citizen.facts.value(&"daily.construction.target_key", &"") as StringName
	var target_position: Variant = citizen.facts.value(&"daily.construction.position", Vector3.INF)
	if mode not in [&"construction", &"demolition"] or target_key == &"" or not (target_position is Vector3) or target_position == Vector3.INF:
		return null
	var order := CitizenOrder.new(
		citizen.id,
		mode,
		id,
		DAILY_PRIORITY,
		AIFactSet.new({
			&"work.construction.mode": mode,
			&"daily.role": "construction",
			&"daily.workday_id": int(citizen.facts.value(&"daily.order.workday_id", 0)),
		})
	)
	order.workday_id = int(citizen.facts.value(&"daily.order.workday_id", 0))
	order.expires_at = float(citizen.facts.value(&"daily.order.expires_at", -1.0))
	order.target_key = target_key
	order.target_position = target_position
	return order


func _gathering_order(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assigned_sources: Dictionary) -> CitizenOrder:
	var citizen_id := citizen.id
	var in_progress := bool(citizen.facts.value(&"daily.gathering.in_progress", false))
	if not in_progress and not bool(citizen.facts.value(&"daily.gathering.can_start", false)):
		_gathering_assignments.erase(citizen_id)
		return null
	var assignment := _gathering_assignments.get(citizen_id, {}) as Dictionary
	if in_progress:
		if assignment.is_empty():
			return null
		return _gathering_order_for(citizen, assignment)
	_gathering_assignments.erase(citizen_id)
	var next_assignment := _closest_free_gathering_candidate(snapshot, citizen, assigned_sources)
	if next_assignment.is_empty():
		return null
	_gathering_assignments[citizen_id] = next_assignment
	assigned_sources[next_assignment.get(&"id", &"")] = true
	return _gathering_order_for(citizen, next_assignment)


func _closest_free_gathering_candidate(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assigned_sources: Dictionary) -> Dictionary:
	var candidates: Array = citizen.facts.value(&"daily.gathering.candidates", []) as Array
	if candidates.is_empty():
		candidates = snapshot.settlement.value(&"work.gathering.targets", []) as Array
	var best: Dictionary = {}
	var best_distance := INF
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var source_id := candidate.get(&"id", &"") as StringName
		var position: Variant = candidate.get(&"position", Vector3.INF)
		if source_id == &"" or assigned_sources.has(source_id) or not (position is Vector3) or position == Vector3.INF:
			continue
		var distance := citizen.position.distance_squared_to(position)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and str(source_id) < str(best.get(&"id", &""))):
			best = candidate.duplicate(true)
			best_distance = distance
	if not best.is_empty():
		best[&"warehouse_position"] = citizen.facts.value(&"daily.gathering.warehouse_position", best.get(&"warehouse_position", Vector3.INF))
	return best


func _cleaning_order(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assigned_piles: Dictionary) -> CitizenOrder:
	var citizen_id := citizen.id
	var in_progress := bool(citizen.facts.value(&"daily.cleaning.in_progress", false))
	if not in_progress and not bool(citizen.facts.value(&"daily.cleaning.can_start", false)):
		_cleaning_assignments.erase(citizen_id)
		return null
	var assignment := _cleaning_assignments.get(citizen_id, {}) as Dictionary
	if in_progress:
		if assignment.is_empty():
			return null
		return _cleaning_order_for(citizen, assignment)
	_cleaning_assignments.erase(citizen_id)
	var next_assignment := _closest_free_cleaning_candidate(snapshot, citizen, assigned_piles)
	if next_assignment.is_empty():
		return null
	_cleaning_assignments[citizen_id] = next_assignment
	assigned_piles[next_assignment.get(&"id", &"")] = true
	return _cleaning_order_for(citizen, next_assignment)


func _closest_free_cleaning_candidate(snapshot: WorldSnapshot, citizen: CitizenSnapshot, assigned_piles: Dictionary) -> Dictionary:
	var candidates: Array = citizen.facts.value(&"daily.cleaning.candidates", []) as Array
	var best: Dictionary = {}
	var best_distance := INF
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var pile_id := candidate.get(&"id", &"") as StringName
		var position: Variant = candidate.get(&"position", Vector3.INF)
		if pile_id == &"" or assigned_piles.has(pile_id) or not (position is Vector3) or position == Vector3.INF:
			continue
		var distance := citizen.position.distance_squared_to(position)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and str(pile_id) < str(best.get(&"id", &""))):
			best = candidate.duplicate(true)
			best_distance = distance
	if not best.is_empty():
		best[&"warehouse_position"] = citizen.facts.value(&"daily.cleaning.warehouse_position", best.get(&"warehouse_position", Vector3.INF))
	return best


func _cleaning_order_for(citizen: CitizenSnapshot, assignment: Dictionary) -> CitizenOrder:
	var order := CitizenOrder.new(
		citizen.id,
		&"cleaning",
		id,
		DAILY_PRIORITY,
		AIFactSet.new({
			&"work.source_id": assignment.get(&"id", &""),
			&"resource.type": assignment.get(&"resource_type", ""),
			&"target.access_position": assignment.get(&"access", Vector3.INF),
			&"warehouse.position": assignment.get(&"warehouse_position", Vector3.INF),
			&"daily.role": str(citizen.facts.value(&"daily.order.role", "")),
			&"daily.workday_id": int(citizen.facts.value(&"daily.order.workday_id", 0)),
		})
	)
	order.workday_id = int(citizen.facts.value(&"daily.order.workday_id", 0))
	order.expires_at = float(citizen.facts.value(&"daily.order.expires_at", -1.0))
	order.target_position = assignment.get(&"position", Vector3.INF)
	return order


func _gathering_order_for(citizen: CitizenSnapshot, assignment: Dictionary) -> CitizenOrder:
	var order := CitizenOrder.new(
		citizen.id,
		&"gathering",
		id,
		DAILY_PRIORITY,
		AIFactSet.new({
			&"work.source_id": assignment.get(&"id", &""),
			&"resource.type": assignment.get(&"resource_type", ""),
			&"target.access_position": assignment.get(&"access", Vector3.INF),
			&"warehouse.position": assignment.get(&"warehouse_position", Vector3.INF),
			&"daily.role": str(citizen.facts.value(&"daily.order.role", "")),
			&"daily.workday_id": int(citizen.facts.value(&"daily.order.workday_id", 0)),
		})
	)
	order.workday_id = int(citizen.facts.value(&"daily.order.workday_id", 0))
	order.expires_at = float(citizen.facts.value(&"daily.order.expires_at", -1.0))
	order.target_position = assignment.get(&"position", Vector3.INF)
	return order
