class_name TradeService
extends RefCounted

var simulation: Node


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


func start_trade(trade: Dictionary, source: Vector3, destination: Vector3) -> void:
	simulation.queued_trades.append({"trade": trade, "source": source, "destination": destination})
	dispatch_queued_trades()


func trade_orders() -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for order in simulation.queued_trades:
		orders.append(order.trade)
	for trade in simulation.pending_trades.values():
		orders.append(trade)
	return orders


func trade_reserved_money() -> int:
	var reserved := 0
	for trade in trade_orders():
		match str(trade.kind):
			"buy_resource": reserved += int(trade.quantity) * int(trade.price)
			"buy_tool": reserved += int(trade.price)
	return reserved


func available_trade_money() -> int:
	return maxi(0, simulation.settlement.money - trade_reserved_money())


func trade_incoming_resource(resource_type: String) -> int:
	var incoming := 0
	for trade in trade_orders():
		if str(trade.kind) == "buy_resource" and str(trade.resource) == resource_type:
			incoming += int(trade.quantity)
	return incoming


func trade_has_tool_order(tool_id: String) -> bool:
	for trade in trade_orders():
		if str(trade.kind) == "buy_tool" and str(trade.tool) == tool_id:
			return true
	return false


func dispatch_queued_trades() -> void:
	if simulation.queued_trades.is_empty():
		return
	var candidates: Array[Citizen] = []
	for worker in simulation.citizens:
		if WorkforcePolicy.can_take_queued_job({
			"player_controlled": worker.is_player_controlled,
			"idle": worker.state == Citizen.State.IDLE and worker.employment_state in [Citizen.EmploymentState.AUTO_RESERVE, Citizen.EmploymentState.MANUAL_COURIER],
			"manual_role": worker.manual_role,
			"has_queued_job": simulation.pending_trades.has(worker.get_instance_id()),
		}):
			candidates.append(worker)
	# Dedicated couriers take new market work first; other automatic workers are
	# valid fallbacks so an order cannot stall when no courier exists.
	candidates.sort_custom(func(a: Citizen, b: Citizen): return (a.specialization == "courier") and b.specialization != "courier")
	for worker in candidates:
		if simulation.queued_trades.is_empty():
			return
		var order: Dictionary = simulation.queued_trades.pop_front()
		simulation.pending_trades[worker.get_instance_id()] = order.trade
		worker.deliver_trade(order.source, order.destination)
		simulation._update_interface("A resident is carrying the trade order.")
	if not simulation.queued_trades.is_empty():
		simulation._update_interface("Trade queued: no resident is currently free to carry it.")


func on_trade_delivery_finished(worker: Citizen) -> void:
	var trade: Dictionary = simulation.pending_trades.get(worker.get_instance_id(), {})
	if trade.is_empty():
		return
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
				simulation.settlement.add(str(trade.resource), int(trade.quantity))
				simulation._update_interface("Purchased %d %s after delivery to storage." % [int(trade.quantity), str(trade.resource)])
		"buy_tool":
			if simulation.settlement.buy_tool(str(trade.tool), int(trade.price)):
				simulation._update_workers()
				simulation._update_interface("Purchased %s after delivery to storage." % str(trade.tool).replace("_", " "))
	if simulation.market_menu.visible:
		simulation._refresh_market_menu()
