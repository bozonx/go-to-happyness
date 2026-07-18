class_name OrderBoard
extends RefCounted

## Keeps competing global proposals separate and exposes the highest-priority
## live order for each citizen.

var _orders_by_citizen: Dictionary = {}
var _orders_by_issuer: Dictionary = {}
var _next_order_id := 1


func replace_issuer_orders(
	issuer: StringName,
	orders: Array[CitizenOrder],
	simulation_seconds: float
) -> void:
	var previous_by_citizen: Dictionary = _orders_by_issuer.get(issuer, {})
	var next_by_citizen: Dictionary = {}
	for order in orders:
		if (
			order == null
			or order.citizen_id <= 0
			or order.kind == &""
			or order.is_expired(simulation_seconds)
			or order.payload == null
			or not AIFactSet.is_value_safe(order.payload.to_dictionary())
		):
			continue
		order.issuer = issuer
		var previous: Array = previous_by_citizen.get(order.citizen_id, [])
		# Providers submit proposals, not ids. Only a prior equivalent order from
		# this issuer may retain its board-assigned identity.
		var matching := _matching_order(previous, order)
		if matching != null:
			order.id = matching.id
			order.issued_at = matching.issued_at
		else:
			order.id = _next_order_id
			order.issued_at = simulation_seconds
			_next_order_id += 1
		var next_orders: Array = next_by_citizen.get(order.citizen_id, [])
		if _contains_equivalent_order(next_orders, order):
			continue
		next_orders.append(order)
		next_by_citizen[order.citizen_id] = next_orders
	_remove_issuer(issuer)
	_orders_by_issuer[issuer] = next_by_citizen
	for citizen_id: int in next_by_citizen:
		var citizen_orders: Dictionary = _orders_by_citizen.get(citizen_id, {})
		citizen_orders[issuer] = next_by_citizen[citizen_id]
		_orders_by_citizen[citizen_id] = citizen_orders


func order_for(citizen_id: int, simulation_seconds: float) -> CitizenOrder:
	var best: CitizenOrder
	for issuer_orders: Array in (_orders_by_citizen.get(citizen_id, {}) as Dictionary).values():
		for order: CitizenOrder in issuer_orders:
			if order.is_expired(simulation_seconds):
				continue
			if best == null or order.priority > best.priority or (
				is_equal_approx(order.priority, best.priority) and order.id < best.id
			):
				best = order
	return best


func remove_citizen(citizen_id: int) -> void:
	_orders_by_citizen.erase(citizen_id)
	for issuer: StringName in _orders_by_issuer.keys():
		var issuer_orders: Dictionary = _orders_by_issuer[issuer]
		issuer_orders.erase(citizen_id)


func clear_expired(simulation_seconds: float) -> void:
	var issuers := _orders_by_issuer.keys()
	for issuer: StringName in issuers:
		var retained: Array[CitizenOrder] = []
		var removed_any := false
		for orders: Array in (_orders_by_issuer[issuer] as Dictionary).values():
			for order: CitizenOrder in orders:
				if not order.is_expired(simulation_seconds):
					retained.append(order)
				else:
					removed_any = true
		if removed_any:
			replace_issuer_orders(issuer, retained, simulation_seconds)


func clear() -> void:
	_orders_by_citizen.clear()
	_orders_by_issuer.clear()


func candidate_count() -> int:
	var total := 0
	for issuer_orders: Dictionary in _orders_by_issuer.values():
		for orders: Array in issuer_orders.values():
			total += orders.size()
	return total


func _remove_issuer(issuer: StringName) -> void:
	var previous: Dictionary = _orders_by_issuer.get(issuer, {})
	for citizen_id: int in previous:
		var citizen_orders: Dictionary = _orders_by_citizen.get(citizen_id, {})
		citizen_orders.erase(issuer)
		if citizen_orders.is_empty():
			_orders_by_citizen.erase(citizen_id)
		else:
			_orders_by_citizen[citizen_id] = citizen_orders
	_orders_by_issuer.erase(issuer)


## Finds a previously issued order for the same logical assignment so its id and
## issued-at time can be reused across director ticks.
func _matching_order(previous: Array, proposal: CitizenOrder) -> CitizenOrder:
	for existing in previous:
		var typed_existing := existing as CitizenOrder
		if typed_existing != null and _orders_are_equivalent(typed_existing, proposal):
			return typed_existing
	return null


func _contains_equivalent_order(orders: Array, proposal: CitizenOrder) -> bool:
	for existing in orders:
		var typed_existing := existing as CitizenOrder
		if typed_existing != null and _orders_are_equivalent(typed_existing, proposal):
			return true
	return false


## Identity of an order includes every value a task may capture. Reusing an id for
## changed payload would leave an active task executing stale route or destination
## data, because tasks intentionally retain an immutable assignment while running.
func _orders_are_equivalent(left: CitizenOrder, right: CitizenOrder) -> bool:
	return (
		left.citizen_id == right.citizen_id
		and left.kind == right.kind
		and left.workday_id == right.workday_id
		and left.target_key == right.target_key
		and _positions_are_equivalent(left.target_position, right.target_position)
		and _payloads_are_equivalent(left.payload, right.payload)
	)


func _positions_are_equivalent(left: Vector3, right: Vector3) -> bool:
	if left == Vector3.INF or right == Vector3.INF:
		return left == right
	return left.is_equal_approx(right)


func _payloads_are_equivalent(left: AIFactSet, right: AIFactSet) -> bool:
	return left == right or (left != null and left.is_equal_to(right))


func next_expiration_after(simulation_seconds: float) -> float:
	var next_expiration := INF
	for issuer_orders: Dictionary in _orders_by_issuer.values():
		for orders: Array in issuer_orders.values():
			for order: CitizenOrder in orders:
				if order.expires_at > simulation_seconds:
					next_expiration = minf(next_expiration, order.expires_at)
	return next_expiration
