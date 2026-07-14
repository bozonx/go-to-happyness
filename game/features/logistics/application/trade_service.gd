class_name TradeService
extends RefCounted

const TradeOrderScript = preload("res://game/features/logistics/domain/trade_order.gd")

var simulation: Node
var entrance_expeditions: Dictionary = {} # citizen id -> TradeOrder


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func buy_food(quantity: int, unit_price: int) -> void:
	if simulation.selected_market == null:
		return
	var room := maxi(0, simulation.settlement.storage_room_for("food") - trade_incoming_resource("food"))
	var buyable := mini(quantity, mini(room, available_trade_money() / unit_price))
	if buyable <= 0:
		simulation._update_interface("Cannot buy food: check storage space and available coins.")
		return
	start_trade({"kind": "buy_resource", "resource": "food", "quantity": buyable, "price": unit_price}, simulation.selected_market.global_position, simulation._get_delivery_position())
	simulation._refresh_market_menu()


func sell_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	if simulation.selected_market == null:
		return
	if simulation.settlement.amount(resource_type) < quantity:
		simulation._update_interface("Not enough %s to sell." % resource_type)
		return
	simulation.settlement.add(resource_type, -quantity)
	start_trade({"kind": "sell", "resource": resource_type, "quantity": quantity, "price": unit_price}, simulation._get_delivery_position(), simulation.selected_market.global_position)
	simulation._refresh_market_menu()


func buy_tool(tool_id: String, price: int) -> void:
	if simulation.selected_market == null:
		return
	if not simulation.settlement.tools.has(tool_id) or bool(simulation.settlement.tools[tool_id]) or trade_has_tool_order(tool_id) or available_trade_money() < price:
		simulation._update_interface("Cannot buy %s. Check money or check if already owned." % tool_id.replace("_", " "))
		return
	start_trade({"kind": "buy_tool", "tool": tool_id, "price": price}, simulation.selected_market.global_position, simulation._get_delivery_position())
	simulation._refresh_market_menu()


func buy_courier_equipment(courier: Citizen, equipment_id: String, price: int) -> void:
	if simulation.selected_market == null or not is_instance_valid(courier):
		return
	if not courier.is_courier() or courier.courier_equipment == equipment_id or available_trade_money() < price:
		return
	start_trade({"kind": "buy_courier_equipment", "courier_id": courier.get_instance_id(), "equipment": equipment_id, "price": price}, simulation.selected_market.global_position, simulation._get_delivery_position())
	simulation._refresh_market_menu()


func start_trade(
	trade: Dictionary,
	source: Vector3,
	destination: Vector3,
	source_endpoint := TradeOrderScript.ENDPOINT_MARKET,
	destination_endpoint := TradeOrderScript.ENDPOINT_STORAGE
) -> void:
	start_trade_order(TradeOrderScript.create(trade, source, destination, source_endpoint, destination_endpoint))


func start_trade_order(order: RefCounted) -> void:
	if order == null:
		return
	simulation.queued_trades.append(order)
	simulation._request_courier_dispatch()


func start_entrance_purchase(trade: Dictionary) -> void:
	if not is_instance_valid(simulation.entrance_stone):
		return
	start_trade_order(TradeOrderScript.entrance_purchase(
		trade,
		simulation.entrance_stone.global_position,
		simulation._get_delivery_position()
	))


func buy_entrance_food(quantity: int, unit_price: int) -> void:
	if quantity <= 0 or available_trade_money() < quantity * unit_price:
		return
	start_entrance_purchase({"kind": "buy_resource", "resource": "food", "quantity": quantity, "price": unit_price})


func buy_entrance_gloves(price: int) -> void:
	if available_trade_money() < price:
		return
	start_entrance_purchase({"kind": "buy_gloves", "price": price})


func trade_orders() -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for order in simulation.queued_trades:
		orders.append(order.trade)
	for order in simulation.pending_trades.values():
		orders.append(_payload_for_order(order))
	return orders


func trade_reserved_money() -> int:
	var reserved := 0
	for order in _all_orders():
		reserved += order.reserved_money()
	return reserved


func available_trade_money() -> int:
	return maxi(0, simulation.settlement.money - trade_reserved_money())


func trade_incoming_resource(resource_type: String) -> int:
	var incoming := 0
	for order in _all_orders():
		incoming += order.incoming_resource(resource_type)
	return incoming


func trade_has_tool_order(tool_id: String) -> bool:
	for order in _all_orders():
		if order.has_tool_order(tool_id):
			return true
	return false


func dispatch_queued_trades() -> void:
	if simulation.queued_trades.is_empty():
		return
	var candidates: Array[Citizen] = []
	for worker in simulation.citizens:
		if (
			worker.can_handle_entry_logistics()
			and worker.state == Citizen.State.IDLE
			and not simulation.pending_trades.has(worker.get_instance_id())
		):
			candidates.append(worker)
	# Dedicated couriers take new market work first; Helpers are a daily fallback.
	candidates.sort_custom(func(a: Citizen, b: Citizen): return a.is_courier() and not b.is_courier())
	for worker in candidates:
		if simulation.queued_trades.is_empty():
			return
		var order: RefCounted = simulation.queued_trades.pop_front()
		assign_order_to_worker(worker, order)
	if not simulation.queued_trades.is_empty():
		simulation._update_interface("Trade queued: assign a Helper or wait for a free Courier.")


func assign_order_to_worker(worker: Citizen, order: RefCounted) -> void:
	if not is_instance_valid(worker) or order == null:
		return
	simulation.pending_trades[worker.get_instance_id()] = order
	if _is_pending_entrance_expedition(order):
		worker.deliver_trade(order.source, order.source)
		simulation._update_interface("%s is heading to the entrance sign for the outside trade trip." % ("Courier" if worker.is_courier() else "Helper"))
	else:
		worker.deliver_trade(order.source, order.destination)
		simulation._update_interface("%s is carrying the trade order." % ("Courier" if worker.is_courier() else "Helper"))


func update() -> void:
	for worker_id in entrance_expeditions.keys().duplicate():
		var order: RefCounted = entrance_expeditions[worker_id]
		if simulation._total_game_minutes() < order.return_at_minutes:
			continue
		var worker := instance_from_id(int(worker_id)) as Citizen
		entrance_expeditions.erase(worker_id)
		if not is_instance_valid(worker):
			continue
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		worker.visible = true
		worker.global_position = order.source
		worker.deliver_trade(order.source, order.destination)
		simulation._update_interface("A resident returned from the outside trade trip.")


func _begin_entrance_expedition(worker: Citizen, order: RefCounted) -> void:
	worker.cancel_current_action()
	worker.visible = false
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	order.return_at_minutes = simulation._total_game_minutes() + order.outside_duration_minutes
	entrance_expeditions[worker.get_instance_id()] = order
	simulation._update_interface("A resident left through the entrance sign and will return in 2 hours.")


func on_trade_delivery_finished(worker: Citizen) -> void:
	var order: RefCounted = simulation.pending_trades.get(worker.get_instance_id(), null)
	if order == null:
		return
	if _is_pending_entrance_expedition(order):
		_begin_entrance_expedition(worker, order)
		return
	var trade: Dictionary = order.trade
	simulation.pending_trades.erase(worker.get_instance_id())
	match str(trade.kind):
		"sell":
			simulation.settlement.money += int(trade.quantity) * int(trade.price)
			simulation.settlement.trade_sales += 1
			simulation._update_interface("Sold %d %s after delivery to the market." % [int(trade.quantity), str(trade.resource)])
		"buy_resource":
			var total := int(trade.quantity) * int(trade.price)
			if simulation.settlement.money >= total:
				simulation.settlement.money -= total
				if simulation.warehouse_positions.is_empty():
					simulation._create_resource_pile(simulation.entrance_stone.global_position, {str(trade.resource): int(trade.quantity)})
					simulation._update_interface("Purchased %d %s; the order is waiting in an open pile at the entrance." % [int(trade.quantity), str(trade.resource)])
				else:
					simulation.settlement.add(str(trade.resource), int(trade.quantity))
					simulation._update_interface("Purchased %d %s after delivery to storage." % [int(trade.quantity), str(trade.resource)])
		"buy_tool":
			if simulation.settlement.buy_tool(str(trade.tool), int(trade.price)):
				simulation._update_workers()
				simulation._update_interface("Purchased %s after delivery to storage." % str(trade.tool).replace("_", " "))
		"buy_gloves":
			var gloves_price := int(trade.price)
			if simulation.settlement.money >= gloves_price:
				simulation.settlement.money -= gloves_price
				simulation.settlement.add_construction_glove_set()
				simulation._update_interface("Purchased a construction glove set at the entrance sign.")
		"buy_courier_equipment":
			var price := int(trade.price)
			var courier := instance_from_id(int(trade.courier_id)) as Citizen
			if is_instance_valid(courier) and simulation.settlement.money >= price:
				simulation.settlement.money -= price
				courier.set_courier_equipment(str(trade.equipment))
				simulation._update_interface("%s received %s." % [courier.role_label(), str(trade.equipment).replace("_", " ")])
	if simulation.market_menu.visible:
		simulation._refresh_market_menu()


func _is_pending_entrance_expedition(order: RefCounted) -> bool:
	return (
		order != null
		and order.source_endpoint == TradeOrderScript.ENDPOINT_ENTRANCE_STONE
		and order.outside_duration_minutes > 0.0
		and order.return_at_minutes < 0.0
	)


func _all_orders() -> Array:
	var orders: Array = []
	for order in simulation.queued_trades:
		if order != null and order.has_method("reserved_money"):
			orders.append(order)
	for order in simulation.pending_trades.values():
		if order != null and order.has_method("reserved_money"):
			orders.append(order)
	return orders


func _payload_for_order(order: Variant) -> Dictionary:
	if order != null and order is RefCounted and order.has_method("reserved_money"):
		return order.trade
	return order if order is Dictionary else {}
