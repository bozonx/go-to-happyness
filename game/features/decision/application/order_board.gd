class_name OrderBoard
extends RefCounted

## Keeps competing global proposals separate and exposes the highest-priority
## live order for each citizen.

var _orders_by_citizen: Dictionary = {}
var _next_order_id := 1


func replace_issuer_orders(
	issuer: StringName,
	orders: Array[CitizenOrder],
	simulation_seconds: float
) -> void:
	var previous: Array[CitizenOrder] = []
	for citizen_orders: Array in _orders_by_citizen.values():
		for existing: CitizenOrder in citizen_orders:
			if existing.issuer == issuer:
				previous.append(existing)
	_remove_issuer(issuer)
	for order in orders:
		if order == null or order.citizen_id == 0 or order.is_expired(simulation_seconds):
			continue
		order.issuer = issuer
		if order.id == 0:
			var matching := _matching_order(previous, order)
			if matching != null:
				order.id = matching.id
				order.issued_at = matching.issued_at
			else:
				order.id = _next_order_id
				order.issued_at = simulation_seconds
				_next_order_id += 1
		var citizen_orders: Array[CitizenOrder] = []
		citizen_orders.assign(_orders_by_citizen.get(order.citizen_id, []))
		citizen_orders.append(order)
		_orders_by_citizen[order.citizen_id] = citizen_orders


func order_for(citizen_id: int, simulation_seconds: float) -> CitizenOrder:
	var best: CitizenOrder
	for order: CitizenOrder in _orders_by_citizen.get(citizen_id, []):
		if order.is_expired(simulation_seconds):
			continue
		if best == null or order.priority > best.priority or (
			is_equal_approx(order.priority, best.priority) and order.id < best.id
		):
			best = order
	return best


func remove_citizen(citizen_id: int) -> void:
	_orders_by_citizen.erase(citizen_id)


func clear_expired(simulation_seconds: float) -> void:
	for citizen_id: int in _orders_by_citizen.keys():
		var live: Array[CitizenOrder] = []
		for order: CitizenOrder in _orders_by_citizen[citizen_id]:
			if not order.is_expired(simulation_seconds):
				live.append(order)
		if live.is_empty():
			_orders_by_citizen.erase(citizen_id)
		else:
			_orders_by_citizen[citizen_id] = live


func candidate_count() -> int:
	var total := 0
	for orders: Array in _orders_by_citizen.values():
		total += orders.size()
	return total


func _remove_issuer(issuer: StringName) -> void:
	for citizen_id: int in _orders_by_citizen.keys():
		var retained: Array[CitizenOrder] = []
		for order: CitizenOrder in _orders_by_citizen[citizen_id]:
			if order.issuer != issuer:
				retained.append(order)
		if retained.is_empty():
			_orders_by_citizen.erase(citizen_id)
		else:
			_orders_by_citizen[citizen_id] = retained


## Identity of an order for id/issued-at carry-over relies on value equality of its
## fields. Order payloads must therefore hold only value types (numbers, strings,
## StringNames, vectors) — never scene nodes — or two identical proposals will look
## distinct and pointlessly churn their ids each director tick.
func _matching_order(previous: Array[CitizenOrder], proposal: CitizenOrder) -> CitizenOrder:
	for existing in previous:
		if (
			existing.citizen_id == proposal.citizen_id
			and existing.kind == proposal.kind
			and existing.target_entity_id == proposal.target_entity_id
			and existing.target_position == proposal.target_position
			and existing.payload.to_dictionary() == proposal.payload.to_dictionary()
		):
			return existing
	return null
