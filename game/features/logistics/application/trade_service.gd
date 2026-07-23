class_name TradeService
extends RefCounted

const TradeOrderScript = preload("res://game/features/logistics/domain/trade_order.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _queued_trades: Array = []
var _pending_trades: Dictionary = {}
var _warehouse_positions: Array[Vector3] = []
var _market_menu: Variant
var _selected_market_getter: Callable
var _entrance_stone_getter: Callable
var _get_delivery_position: Callable
var _update_interface: Callable
var _refresh_market_menu: Callable
var _request_courier_dispatch: Callable
var _total_game_minutes: Callable
var _citizen_for_ai_id: Callable
var _create_resource_pile: Callable
var _update_workers: Callable
var entrance_expeditions: Dictionary = {} # citizen ai_id -> TradeOrder


func configure(
	p_settlement: SettlementState,
	p_citizens: Array,
	p_queued_trades: Array,
	p_pending_trades: Dictionary,
	p_warehouse_positions: Array[Vector3],
	p_market_menu: Variant,
	p_selected_market_getter: Callable,
	p_entrance_stone_getter: Callable,
	p_get_delivery_position: Callable,
	p_update_interface: Callable,
	p_refresh_market_menu: Callable,
	p_request_courier_dispatch: Callable,
	p_total_game_minutes: Callable,
	p_citizen_for_ai_id: Callable,
	p_create_resource_pile: Callable,
	p_update_workers: Callable
) -> void:
	_settlement = p_settlement
	_citizens = p_citizens
	_queued_trades = p_queued_trades
	_pending_trades = p_pending_trades
	_warehouse_positions = p_warehouse_positions
	_market_menu = p_market_menu
	_selected_market_getter = p_selected_market_getter
	_entrance_stone_getter = p_entrance_stone_getter
	_get_delivery_position = p_get_delivery_position
	_update_interface = p_update_interface
	_refresh_market_menu = p_refresh_market_menu
	_request_courier_dispatch = p_request_courier_dispatch
	_total_game_minutes = p_total_game_minutes
	_citizen_for_ai_id = p_citizen_for_ai_id
	_create_resource_pile = p_create_resource_pile
	_update_workers = p_update_workers


func buy_food(quantity: int, unit_price: int) -> void:
	var selected_market: Node3D = _selected_market_getter.call()
	if selected_market == null:
		return
	var room := maxi(0, _settlement.storage_room_for(ResourceIds.FOOD) - trade_incoming_resource(ResourceIds.FOOD))
	var buyable := mini(quantity, mini(room, available_trade_money() / unit_price))
	if buyable <= 0:
		_update_interface.call("Cannot buy food: check storage space and available coins.")
		return
	start_trade({"kind": "buy_resource", "resource": ResourceIds.FOOD, "quantity": buyable, "price": unit_price}, selected_market.global_position, _get_delivery_position.call())
	_refresh_market_menu.call()


func sell_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	var selected_market: Node3D = _selected_market_getter.call()
	if selected_market == null:
		return
	if _settlement.amount(resource_type) < quantity:
		_update_interface.call("Not enough %s to sell." % resource_type)
		return
	_settlement.add(resource_type, -quantity)
	start_trade({"kind": "sell", "resource": resource_type, "quantity": quantity, "price": unit_price}, _get_delivery_position.call(), selected_market.global_position)
	_refresh_market_menu.call()


func buy_tool(tool_id: String, price: int) -> void:
	var selected_market: Node3D = _selected_market_getter.call()
	if selected_market == null:
		return
	if not _settlement.tools.has(tool_id) or bool(_settlement.tools[tool_id]) or trade_has_tool_order(tool_id) or available_trade_money() < price:
		_update_interface.call("Cannot buy %s. Check money or check if already owned." % tool_id.replace("_", " "))
		return
	start_trade({"kind": "buy_tool", "tool": tool_id, "price": price}, selected_market.global_position, _get_delivery_position.call())
	_refresh_market_menu.call()


func buy_courier_equipment(courier: Citizen, equipment_id: String, price: int) -> void:
	var selected_market: Node3D = _selected_market_getter.call()
	if selected_market == null or not is_instance_valid(courier):
		return
	if not courier.is_courier() or courier.courier_equipment == equipment_id or available_trade_money() < price:
		return
	start_trade({"kind": "buy_courier_equipment", "courier_id": courier.ai_id, "equipment": equipment_id, "price": price}, selected_market.global_position, _get_delivery_position.call())
	_refresh_market_menu.call()


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
	_queued_trades.append(order)
	_request_courier_dispatch.call()


func start_entrance_purchase(trade: Dictionary) -> void:
	var entrance_stone: Node3D = _entrance_stone_getter.call()
	if not is_instance_valid(entrance_stone):
		return
	start_trade_order(TradeOrderScript.entrance_purchase(
		trade,
		entrance_stone.global_position,
		_get_delivery_position.call()
	))


func buy_entrance_food(quantity: int, unit_price: int) -> void:
	if quantity <= 0 or available_trade_money() < quantity * unit_price:
		return
	start_entrance_purchase({"kind": "buy_resource", "resource": ResourceIds.FOOD, "quantity": quantity, "price": unit_price})


func buy_entrance_gloves(price: int) -> void:
	if available_trade_money() < price:
		return
	start_entrance_purchase({"kind": "buy_gloves", "price": price})


func buy_entrance_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	if quantity <= 0 or available_trade_money() < quantity * unit_price:
		return
	start_entrance_purchase({"kind": "buy_resource", "resource": resource_type, "quantity": quantity, "price": unit_price})


func buy_entrance_tool(tool_id: String, price: int) -> void:
	if available_trade_money() < price:
		return
	start_entrance_purchase({"kind": "buy_tool", "tool": tool_id, "price": price})


func trade_orders() -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for order in _queued_trades:
		orders.append(order.trade)
	for order in _pending_trades.values():
		orders.append(_payload_for_order(order))
	return orders


func trade_reserved_money() -> int:
	var reserved := 0
	for order in _all_orders():
		reserved += order.reserved_money()
	return reserved


func available_trade_money() -> int:
	return maxi(0, _settlement.money - trade_reserved_money())


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


func assign_order_to_worker(worker: Citizen, order: RefCounted) -> void:
	if not is_instance_valid(worker) or order == null:
		return
	_pending_trades[worker.ai_id] = order
	if _is_pending_entrance_expedition(order):
		worker.deliver_trade(order.source, order.source)
		_update_interface.call("%s is heading to the entrance sign for the outside trade trip." % ("Courier" if worker.is_courier() else "Daily courier"))
	else:
		worker.deliver_trade(order.source, order.destination)
		_update_interface.call("%s is carrying the trade order." % ("Courier" if worker.is_courier() else "Daily courier"))


func update() -> void:
	for worker_id in entrance_expeditions.keys().duplicate():
		var order: RefCounted = entrance_expeditions[worker_id]
		if _total_game_minutes.call() < order.return_at_minutes:
			continue
		var worker: Citizen = _citizen_for_ai_id.call(int(worker_id))
		entrance_expeditions.erase(worker_id)
		if not is_instance_valid(worker):
			continue
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		worker.visible = true
		worker.global_position = order.source
		worker.deliver_trade(order.source, order.destination)
		_update_interface.call("A resident returned from the outside trade trip.")


func _begin_entrance_expedition(worker: Citizen, order: RefCounted) -> void:
	worker.cancel_current_action()
	worker.visible = false
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	order.return_at_minutes = _total_game_minutes.call() + order.outside_duration_minutes
	entrance_expeditions[worker.ai_id] = order
	_update_interface.call("A resident left through the entrance sign and will return in 2 hours.")


func on_trade_delivery_finished(worker: Citizen) -> void:
	var order: RefCounted = _pending_trades.get(worker.ai_id, null)
	if order == null:
		return
	if _is_pending_entrance_expedition(order):
		_begin_entrance_expedition(worker, order)
		return
	var trade: Dictionary = order.trade
	_pending_trades.erase(worker.ai_id)
	match str(trade.kind):
		"sell":
			_settlement.money += int(trade.quantity) * int(trade.price)
			_settlement.trade_sales += 1
			_update_interface.call("Sold %d %s after delivery to the market." % [int(trade.quantity), str(trade.resource)])
		"buy_resource":
			var total := int(trade.quantity) * int(trade.price)
			if _settlement.money >= total:
				_settlement.money -= total
				if _warehouse_positions.is_empty():
					var entrance_stone: Node3D = _entrance_stone_getter.call()
					_create_resource_pile.call(entrance_stone.global_position, {str(trade.resource): int(trade.quantity)})
					_update_interface.call("Purchased %d %s; the order is waiting in an open pile at the entrance." % [int(trade.quantity), str(trade.resource)])
				else:
					_settlement.add(str(trade.resource), int(trade.quantity))
					_update_interface.call("Purchased %d %s after delivery to storage." % [int(trade.quantity), str(trade.resource)])
		"buy_tool":
			if _settlement.buy_tool(str(trade.tool), int(trade.price)):
				_update_workers.call()
				_update_interface.call("Purchased %s after delivery to storage." % str(trade.tool).replace("_", " "))
		"buy_gloves":
			var gloves_price := int(trade.price)
			if _settlement.money >= gloves_price:
				_settlement.money -= gloves_price
				_settlement.add_construction_glove_set()
				_update_interface.call("Purchased a construction glove set at the entrance sign.")
		"buy_courier_equipment":
			var price := int(trade.price)
			var courier: Citizen = _citizen_for_ai_id.call(int(trade.courier_id))
			if is_instance_valid(courier) and _settlement.money >= price:
				_settlement.money -= price
				courier.set_courier_equipment(str(trade.equipment))
				_update_interface.call("%s received %s." % [courier.role_label(), str(trade.equipment).replace("_", " ")])
	if _market_menu != null and _market_menu.visible:
		_refresh_market_menu.call()


func _is_pending_entrance_expedition(order: RefCounted) -> bool:
	return (
		order != null
		and order.source_endpoint == TradeOrderScript.ENDPOINT_ENTRANCE_STONE
		and order.outside_duration_minutes > 0.0
		and order.return_at_minutes < 0.0
	)


func _all_orders() -> Array:
	var orders: Array = []
	for order in _queued_trades:
		if order is TradeOrderScript:
			orders.append(order)
	for order in _pending_trades.values():
		if order is TradeOrderScript:
			orders.append(order)
	return orders


func _payload_for_order(order: Variant) -> Dictionary:
	if order is TradeOrderScript:
		return order.trade
	return order if order is Dictionary else {}


func is_seller_present_at(market_node: Node3D) -> bool:
	if not is_instance_valid(market_node):
		return false
	var service_position: Vector3 = market_node.get_meta("service_position", market_node.global_position)
	for citizen in _citizens:
		var is_seller: bool = citizen.permanent_role == "seller" or citizen.specialization == "seller"
		if not is_seller:
			continue
		if is_instance_valid(citizen.employment_workplace) and citizen.employment_workplace != market_node:
			continue
		if citizen.is_player_controlled:
			if citizen.global_position.distance_to(service_position) <= 3.5:
				return true
		elif citizen.state in [Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK]:
			if citizen.global_position.distance_to(service_position) <= 3.5:
				return true
	return false
